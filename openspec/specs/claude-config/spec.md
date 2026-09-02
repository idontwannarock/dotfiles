# claude-config Specification

## Purpose
規範 Claude Code 設定如何由 chezmoi 部署:`~/.claude/agents/` 以 `exact_` 目錄管理(chezmoi 獨佔),`commands/` 與 `skills/` 為非 `exact_` 目錄、退役項以 `.chezmoiremove` 點名修剪(因該處存在非 chezmoi 管理的檔案),plugin 安裝走 `run_onchange_` 腳本、Windows hook 修復由 PowerShell 腳本處理。寫入 `settings.json` 的 hook 註冊由 `modify_` 腳本 patch,退役時須主動刪除而非停止寫入。

## Requirements

### Requirement: Claude Code 設定透過 chezmoi exact_ 目錄部署
`~/.claude/agents/` SHALL 由 chezmoi 以 `exact_` 目錄（`dot_claude/exact_agents/`）管理，確保 repo 中移除的 agent 檔案在 apply 後自動從系統清除。

`exact_` 的前提是**該目錄的內容完全屬於 chezmoi**；僅在此前提成立時才 SHALL 使用它。`~/.claude/commands/` 與 `~/.claude/skills/` 不滿足此前提（見「退役的 Claude command 由 .chezmoiremove 跨機器修剪」requirement），故 SHALL NOT 改為 `exact_`。

`exact_` 的語意是**單層**，不遞迴：`exact_agents/` 只讓 `~/.claude/agents/` 的直接子項受控。
`exact_agents/` 底下的每一層子目錄 SHALL 同樣帶 `exact_` 前綴（`exact_engineering/`、
`exact_code-review/`），否則該子目錄內被刪除的 agent 會永久留在目標機器上。
此漏失是靜默的——apply 退出碼 0、`chezmoi diff` 空白、`chezmoi status` 也不列出該檔案。

#### Scenario: 新增 agent 後自動部署
- **WHEN** repo 中新增 `dot_claude/exact_agents/exact_engineering/new-agent.md` 並執行 chezmoi apply
- **THEN** `~/.claude/agents/engineering/new-agent.md` 出現在系統

#### Scenario: 移除 agent 後自動清除
- **WHEN** repo 中刪除 `dot_claude/exact_agents/exact_engineering/old-agent.md` 並執行 chezmoi apply
- **THEN** `~/.claude/agents/engineering/old-agent.md` 從系統移除

#### Scenario: 子目錄漏加 exact_ 則不修剪
- **WHEN** 子目錄為 `dot_claude/exact_agents/engineering/`（無 `exact_` 前綴），且 repo 中刪除其下某個 agent 但該目錄仍有其他檔案
- **THEN** `chezmoi status` 不會列出該刪除、apply 後目標檔案仍在系統上；新增子目錄時 SHALL 一律加上 `exact_` 前綴

#### Scenario: commands 不得改為 exact_
- **WHEN** 有人提議將 `dot_claude/commands/` 或 `dot_claude/skills/` 改為 `exact_` 前綴以取得自動修剪
- **THEN** SHALL 拒絕，因該目錄存在非 chezmoi 管理的檔案，`exact_` 會靜默刪除它們；退役修剪 SHALL 改用 `.chezmoiremove` 點名

### Requirement: review 觀點以 lens 檔案承載，不以 agent 承載
Code review 的每個觀點 SHALL 是 `~/.agent/reference/review-lenses/` 下的一個純檔案，由 `review-*` flow 指名路徑後交給 reviewer 讀取；SHALL NOT 是一個 agent 定義。

理由是載入時機：agent 與 skill 的 `description` 都會預載入每個 session 的 system prompt（模型必須看見才能決定要不要路由過去），普通檔案不會。觀點內容放在 agent 裡等於「無論有沒有跑 review 都付費」。此樹為 tool-agnostic，Claude 與 Codex 的 flow 指向同一批路徑。

`~/.claude/agents/` SHALL 只保留 `reviewer` 一個 agent，其 `tools` SHALL 明列為唯讀（`Read, Grep, Glob`）。省略 `tools` 欄位等於繼承全部工具（含 `Write`、`Edit`），review 的唯讀性 SHALL NOT 僅以散文宣告。

每個 lens SHALL 只回答一個問題，且 SHALL NOT 自帶評分尺——嚴重度由 flow 事後以單一尺度給定，lens 自帶尺度會讓跨 lens 的排序失效。lens SHALL NOT 主張其他專案的規範；判斷需要在地規則時，SHALL 指示讀取當前 repo 的 `CLAUDE.md` / `AGENTS.md` 與鄰近程式碼。

#### Scenario: 新增觀點
- **WHEN** 需要一個新的 review 觀點
- **THEN** 在 `dot_agent/reference/review-lenses/` 新增一個檔案並由 flow 指名，SHALL NOT 新增 agent 定義

#### Scenario: lens 改名或刪除
- **WHEN** 某 lens 檔案改名，而 flow 仍指向舊路徑
- **THEN** `tests/review-lens-refs.test.sh` 失敗；render 不會失敗，因為沒有任何東西在 render 期解析 lens 路徑

#### Scenario: 孤兒 lens
- **WHEN** `review-lenses/` 下存在沒有任何 flow 指名的檔案
- **THEN** 同一測試失敗——缺少的 lens 在第一次執行 flow 時就會現形，多出來的永遠不會

### Requirement: Claude plugin 安裝透過 run_onchange_ 腳本
superpowers marketplace 與所需 plugins 的安裝 SHALL 由 chezmoi `run_onchange_` 腳本處理，腳本內容改變時自動重新執行。所需 plugins 為 episodic-memory 與 elements-of-style（均來自 `obra/superpowers-marketplace`），以及 official marketplace 的 slack 與 explanatory-output-style。

已退役的 plugin SHALL NOT 被安裝，且腳本 SHALL 主動將其自既有機器移除，使移除隨 apply 傳播至所有機器，而非僅止於執行者當下那台。**僅刪除安裝那一行是不足的**：已 apply 過的機器會保留該 plugin，且 `run_update-claude-plugins` 依 `enabledPlugins` 迭代，會持續更新它。

退役清單 SHALL 以資料表形式維護（plugin id 加人類可讀的退役理由），由單一迴圈驅動 uninstall 與 cache 清理，SHALL NOT 為每個 plugin 複製一份控制流。退役清單為：

| Plugin | 退役理由 |
|---|---|
| `superpowers@claude-plugins-official` | workflow skills 已由 `~/.claude/skills/` 自家 discipline skills 取代 |
| `claude-md-management@claude-plugins-official` | 未使用 |
| `context7@claude-plugins-official` | 未使用 |
| `code-simplifier@claude-plugins-official` | 未使用；repo 曾有同名 agent，已隨 review lens 改制退役，與此 plugin 始終無關 |
| `playwright@claude-plugins-official` | 未使用 |
| `commit-commands@claude-plugins-official` | 未使用 |
| `security-guidance@claude-plugins-official` | 未使用 |
| `pr-review-toolkit@claude-plugins-official` | 未使用；repo 的 review 能力來自自家 `review-*` 指令，與此 plugin 無關 |
| `pyright-lsp@claude-plugins-official` | 未使用 |
| `jdtls-lsp@claude-plugins-official` | 未使用 |
| `claude-code-setup@claude-plugins-official` | 未使用 |

uninstall SHALL 先比對 `claude plugin list` 的快照，僅對實際已安裝者呼叫 CLI——對未安裝者盲目呼叫會噴 stderr，使 apply 輸出充滿雜訊。

cache 清理 SHALL 無條件執行，不以「本次是否 uninstall」為條件：uninstall 會清 `installed_plugins.json` 與 `enabledPlugins` 但保留 cache 目錄，因此先前已手動 uninstall、僅剩 cache 的機器仍需被清理。cache 路徑 SHALL 由 plugin id 推導為 `~/.claude/plugins/cache/<marketplace>/<id>`。既有的 `~/.claude/plugins/cache/superpowers-marketplace/superpowers` 防禦性清理 SHALL 保留（該路徑推導不出來）。

uninstall 與 cache 清除 SHALL 各自冪等，在 plugin 或 cache 不存在時靜默通過，SHALL NOT 中斷腳本後續的 jdtls、MCP、episodic-memory 修復步驟。

`obra/superpowers-marketplace` 的 marketplace 註冊 SHALL 保留，因 episodic-memory 與 elements-of-style 由其供應。

#### Scenario: 首次 apply 自動安裝 plugins
- **WHEN** 全新機器執行 chezmoi apply
- **THEN** `run_onchange_install-03-claude-config` 執行，加入 superpowers marketplace 並安裝 episodic-memory、elements-of-style、slack、explanatory-output-style，且不安裝任何退役清單上的 plugin

#### Scenario: Plugin 腳本更新時重新執行
- **WHEN** plugin 安裝腳本內容變更後執行 chezmoi apply
- **THEN** 腳本重新執行，套用最新的 plugin 設定

#### Scenario: 既有機器上主動移除所有退役 plugin
- **WHEN** 機器上任一退役清單項目仍為已安裝狀態且執行 chezmoi apply
- **THEN** 腳本逐一 uninstall，`installed_plugins.json` 與 `settings.json` 的 `enabledPlugins` 中不再有這些 plugin，且其 cache 目錄被刪除

#### Scenario: 僅剩 cache 的機器也被清理
- **WHEN** 某退役 plugin 早已被手動 uninstall，但 `~/.claude/plugins/cache/<marketplace>/<id>` 仍存在
- **THEN** cache 目錄仍被刪除（清理不以本次是否 uninstall 為條件）

#### Scenario: 已移除的機器重跑不報錯
- **WHEN** 機器上退役 plugin 早已不存在且腳本再次執行
- **THEN** 跳過 uninstall 並印出 skip，cache 清除為 no-op，腳本繼續執行後續步驟並正常結束

#### Scenario: 退役不影響 repo 自有的 review 流程
- **WHEN** `code-simplifier` 與 `pr-review-toolkit` plugin 被移除
- **THEN** `code:review-*` 指令不受影響——它們派工給 repo 自有的 `reviewer` agent，讀 `~/.agent/reference/review-lenses/` 下的 lens 檔案，兩者都不來自 plugin

#### Scenario: 移除 superpowers plugin 後 episodic-memory 不受影響
- **WHEN** superpowers plugin 已從系統移除，但 marketplace 與 episodic-memory 保留
- **THEN** episodic-memory 的 SessionStart sync hook 仍由其自身 `hooks/hooks.json` 註冊並正常運作，對話 search/archive 功能不中斷

#### Scenario: 移除後 marketplace 與 elements-of-style 保留
- **WHEN** superpowers plugin 已從系統移除
- **THEN** `obra/superpowers-marketplace` 仍註冊於 `settings.json` 的 `extraKnownMarketplaces`，elements-of-style 仍為已安裝且啟用狀態

#### Scenario: 移除後 plugin 更新迴圈不再觸及退役項目
- **WHEN** 退役 plugin 已移除後執行 chezmoi apply，`run_update-claude-plugins` 依 `enabledPlugins` 逐一更新
- **THEN** 更新清單中不含任何退役項目，apply 輸出不再出現其更新訊息
### Requirement: Windows hook 修復腳本由 chezmoi 管理
Windows 特有的 hook 路徑修復（cygpath workaround）與 BOM 清除 SHALL 由 chezmoi `run_onchange_` PowerShell 腳本處理，僅在 Windows 環境執行。

#### Scenario: Windows 環境自動執行 hook 修復
- **WHEN** chezmoi apply 在 Windows 執行，且修復腳本內容有變更
- **THEN** hook 路徑修復與 BOM 清除腳本執行

#### Scenario: 非 Windows 環境跳過修復腳本
- **WHEN** chezmoi apply 在 macOS 或 Linux 執行
- **THEN** Windows hook 修復腳本不執行（由 .chezmoiignore 或 template OS 判斷排除）

### Requirement: 退役的 Claude command 由 .chezmoiremove 跨機器修剪
`~/.claude/commands/` 與 `~/.claude/skills/` 為非 `exact_` 目錄，source 中不存在的檔案不會被自動修剪。已退役且未受 chezmoi 管理的 command 或 skill 檔案 SHALL 於 `home/.chezmoiremove` 中點名，使其在所有機器 apply 時一併移除。

此判準為結構性的：這兩個目錄天生會有非 chezmoi 管理的內容 —— 機器專屬的、實驗中的、或由 plugin 與其他工具寫入的檔案。因此 SHALL NOT 對其套用 `exact_`；**僅刪除 source 中的檔案是不足的**，已 apply 過的機器會永久保留該檔。

#### Scenario: 退役的 opsx:workflow command 被移除
- **WHEN** 機器上存在 `~/.claude/commands/opsx/workflow.md`（已由 `dev-workflow` skill 取代）且執行 chezmoi apply
- **THEN** 該檔案被移除，`/opsx:workflow` command 不再出現於 Claude Code

#### Scenario: 已移除的機器重跑不報錯
- **WHEN** 該路徑在機器上不存在且再次執行 chezmoi apply
- **THEN** apply 正常完成，不因缺少該路徑而失敗

#### Scenario: 退役 skill 同樣需點名
- **WHEN** 某 skill 自 `home/dot_claude/skills/` 或 `home/dot_codex/skills/` 移除
- **THEN** 其部署路徑 SHALL 於 `home/.chezmoiremove` 點名，否則已 apply 過的機器會保留該 skill

#### Scenario: 非 chezmoi 管理的檔案不受影響
- **WHEN** 機器上存在未被 chezmoi 管理的 command 或 skill（例如手動放置或由 plugin 寫入者）且執行 chezmoi apply
- **THEN** 該檔案 SHALL 保持不變，SHALL NOT 因 apply 而被刪除

### Requirement: 退役的跨 OS 腳本副本一併修剪
腳本正典位置改變後遺留的舊副本 SHALL 於 `home/.chezmoiremove` 中點名移除，不得僅刪除新位置以外的來源檔。在 WSL 環境下 PATH interop 會將 Windows 家目錄的 `~/.local/bin` 併入 PATH，因此以 bare 名稱呼叫的腳本可能命中 Windows 側的過時副本而非正典。

具體而言，`~/.local/bin/ensure-openspec.sh`（正典已移至 `~/.agent/bin/ensure-openspec.sh`）與 `~/.claude/commands/ensure-openspec.md`（功能已由 `dev-workflow` skill 開場步驟涵蓋，且其 bare 呼叫會命中前述過時副本）SHALL 被修剪。

#### Scenario: 過時的 ensure-openspec 腳本副本被移除
- **WHEN** 機器上存在 `~/.local/bin/ensure-openspec.sh` 且執行 chezmoi apply
- **THEN** 該檔案被移除，`~/.agent/bin/ensure-openspec.sh` 成為唯一副本

#### Scenario: 冗餘的 ensure-openspec command 被移除
- **WHEN** 機器上存在 `~/.claude/commands/ensure-openspec.md` 且執行 chezmoi apply
- **THEN** 該檔案被移除，OpenSpec 的初始化改由 `dev-workflow` 以絕對路徑 `~/.agent/bin/ensure-openspec.sh` 觸發

#### Scenario: 已修剪的機器重跑不報錯
- **WHEN** 兩個路徑皆不存在且再次執行 chezmoi apply
- **THEN** apply 正常完成，不因缺少路徑而失敗

### Requirement: 退役的 settings.json hook 註冊由 modify_ 腳本主動移除
`home/dot_claude/modify_settings.json.sh.tmpl` 為 chezmoi `modify_` 腳本——它 **patch** 既有的 `settings.json`，而非重新 render 整份檔案。因此停止寫入某個欄位 SHALL NOT 被視為移除該欄位：已 apply 過的機器會原地保留舊值。退役一個由此腳本註冊的 hook 時，該腳本 SHALL 明確刪除既有註冊，而不僅是刪掉寫入它的那段 jq。

刪除 SHALL 為**外科式**——以 `map(select(... | not))` 只濾掉目標 hook 的條目，SHALL NOT 整體覆寫或 `del` 掉該 hook key，因為 plugin 與其他工具可能於 runtime 在同一個 key 下註冊條目。當外科式移除後陣列為空時，該 key SHALL 被 `del` 掉，以免留下空陣列。

hook script 本身的部署路徑另 SHALL 依「退役的 Claude command 由 .chezmoiremove 跨機器修剪」於 `home/.chezmoiremove` 點名；兩者缺一都會留下殘骸——只刪 script 會留下指向不存在檔案的註冊，只刪註冊會留下孤兒 script。

#### Scenario: 退役的 rtk PreToolUse 註冊被移除
- **WHEN** 機器的 `settings.json` 內含 command 為 `bash ~/.claude/hooks/rtk-rewrite.sh` 的 `PreToolUse` 條目且執行 chezmoi apply
- **THEN** 該條目被移除；`PreToolUse` 因此為空陣列時，`hooks.PreToolUse` key 一併被刪除

#### Scenario: 其他工具註冊的同 key 條目不受影響
- **WHEN** `settings.json` 的 `hooks.PreToolUse` 同時存在非 chezmoi 寫入的條目
- **THEN** 該條目 SHALL 保持不變，僅目標 hook 的條目被濾除

#### Scenario: 已清理的機器重跑不報錯
- **WHEN** `settings.json` 內已無該 hook 條目且再次執行 chezmoi apply
- **THEN** apply 正常完成，`settings.json` 內容不再變動（冪等）

#### Scenario: 新機器 bootstrap 不產生空殼
- **WHEN** 機器上尚無 `settings.json`，以空物件 `{}` 為起點執行 chezmoi apply
- **THEN** 產出的 `settings.json` SHALL NOT 含 `hooks.PreToolUse` key

### Requirement: 退役的 hook script 與其設定目錄一併修剪
`~/.claude/hooks/` 與工具自有的設定目錄（如 `~/.config/<tool>/`、Windows 的 `~/AppData/Roaming/<tool>/`）皆非 `exact_` 管理，刪除 source 不會移除已部署的 target。退役一個工具時，其 hook script、設定目錄、以 external 部署的 binary，以及該工具寫下的 runtime state SHALL 於 `home/.chezmoiremove` 中點名。

跨 OS 的路徑 SHALL 一律列出而不加 template 條件判斷：移除該 OS 上不存在的路徑為 no-op，條件判斷只增加閱讀成本。

#### Scenario: rtk 的部署檔案跨機器移除
- **WHEN** 機器上存在 `~/.claude/hooks/rtk-rewrite.sh`、`~/.config/rtk/`、`~/AppData/Roaming/rtk/` 或 `~/.local/bin/rtk[.exe]` 之任一且執行 chezmoi apply
- **THEN** 存在的路徑被移除

#### Scenario: 不存在的跨 OS 路徑不造成失敗
- **WHEN** 在 Linux 上 apply，而 `.chezmoiremove` 列有 `AppData/Roaming/rtk`
- **THEN** apply 正常完成，該條目為 no-op

### Requirement: install 腳本在嚴格錯誤模式下不因 plugin 指令的 stderr 中斷
`run_onchange_install-03-claude-config.ps1.tmpl` 在 `$ErrorActionPreference = "Stop"` 下執行。PowerShell 的 `2>&1` 會將 native command 的 stderr 逐行轉為 `ErrorRecord`，在 `Stop` 下構成 terminating error。因此所有以 `2>&1` 重導向輸出的 `claude` 指令 SHALL 以 `$ErrorActionPreference = "Continue"` / `"Stop"` 包夾，使其 stderr 不致中斷腳本。

#### Scenario: plugin 指令輸出 stderr 時腳本仍完成
- **WHEN** 任一 `claude plugin install` 或 `claude plugin uninstall` 於 Windows 執行時輸出 stderr（警告、棄用通知、進度訊息）
- **THEN** 腳本不中斷，後續的 cache 清理、hook 路徑修復、BOM 移除、MCP 註冊等段落皆正常執行完畢

#### Scenario: 失敗不留下反覆重試的狀態
- **WHEN** plugin 指令失敗但腳本正常結束
- **THEN** chezmoi 記錄該 `run_onchange_` 腳本的執行狀態，下次 apply 不因同一錯誤重跑

### Requirement: cache 清理訊息須反映實際動作
`install-03-claude-config` 的 plugin cache 清理 SHALL 僅在目標路徑確實存在並被刪除時輸出移除訊息。`rm -rf` 對不存在的路徑仍以 0 結束，故 SHALL NOT 以其結束碼作為「已刪除」的判斷依據。

#### Scenario: 路徑不存在時不輸出移除訊息
- **WHEN** cache 路徑不存在且執行 chezmoi apply
- **THEN** 該路徑對應的 "Removed …" 訊息不出現於輸出

#### Scenario: 路徑存在時輸出移除訊息
- **WHEN** cache 路徑存在且執行 chezmoi apply
- **THEN** 該路徑被刪除並輸出對應的 "Removed …" 訊息

