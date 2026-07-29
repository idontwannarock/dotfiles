## MODIFIED Requirements

### Requirement: Claude plugin 安裝透過 run_onchange_ 腳本
superpowers marketplace 與所需 plugins 的安裝 SHALL 由 chezmoi `run_onchange_` 腳本處理，腳本內容改變時自動重新執行。所需 plugins 為 episodic-memory 與 elements-of-style（均來自 `obra/superpowers-marketplace`），以及 official marketplace 的 slack 與 explanatory-output-style。

已退役的 plugin SHALL NOT 被安裝，且腳本 SHALL 主動將其自既有機器移除，使移除隨 apply 傳播至所有機器，而非僅止於執行者當下那台。**僅刪除安裝那一行是不足的**：已 apply 過的機器會保留該 plugin，且 `run_update-claude-plugins` 依 `enabledPlugins` 迭代，會持續更新它。

退役清單 SHALL 以資料表形式維護（plugin id 加人類可讀的退役理由），由單一迴圈驅動 uninstall 與 cache 清理，SHALL NOT 為每個 plugin 複製一份控制流。退役清單為：

| Plugin | 退役理由 |
|---|---|
| `superpowers@claude-plugins-official` | workflow skills 已由 `~/.claude/skills/` 自家 discipline skills 取代 |
| `claude-md-management@claude-plugins-official` | 未使用 |
| `context7@claude-plugins-official` | 未使用 |
| `code-simplifier@claude-plugins-official` | 未使用；同名 agent 由 repo 的 `exact_agents/code-review/` 提供，與此 plugin 無關 |
| `playwright@claude-plugins-official` | 未使用 |
| `commit-commands@claude-plugins-official` | 未使用 |
| `security-guidance@claude-plugins-official` | 未使用 |
| `pr-review-toolkit@claude-plugins-official` | 未使用；`code-reviewer` 等 agent 由 repo 的 `exact_agents/` 提供 |
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

#### Scenario: 退役不影響 repo 自有的同名 agent
- **WHEN** `code-simplifier` 與 `pr-review-toolkit` plugin 被移除
- **THEN** `~/.claude/agents/code-review/` 下由 chezmoi 部署的 `code-simplifier.md`、`code-reviewer.md` 不受影響，兩個 agent 仍可使用

#### Scenario: 移除 superpowers plugin 後 episodic-memory 不受影響
- **WHEN** superpowers plugin 已從系統移除，但 marketplace 與 episodic-memory 保留
- **THEN** episodic-memory 的 SessionStart sync hook 仍由其自身 `hooks/hooks.json` 註冊並正常運作，對話 search/archive 功能不中斷

#### Scenario: 移除後 marketplace 與 elements-of-style 保留
- **WHEN** superpowers plugin 已從系統移除
- **THEN** `obra/superpowers-marketplace` 仍註冊於 `settings.json` 的 `extraKnownMarketplaces`，elements-of-style 仍為已安裝且啟用狀態

#### Scenario: 移除後 plugin 更新迴圈不再觸及退役項目
- **WHEN** 退役 plugin 已移除後執行 chezmoi apply，`run_update-claude-plugins` 依 `enabledPlugins` 逐一更新
- **THEN** 更新清單中不含任何退役項目，apply 輸出不再出現其更新訊息
