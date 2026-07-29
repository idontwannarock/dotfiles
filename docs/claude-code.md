# Claude Code 設定

Claude Code 相關的個人設定檔案。

## 目錄結構

```
tools/statusline/           # 自訂狀態列程式
    statusline.go

dot_claude/                 # ~/.claude/ 設定（chezmoi 管理）
├── CLAUDE.md               # 全域指令
├── exact_commands/         # Commands（exact_：自動清理移除的檔案）
│   ├── git/                # Git 操作簡寫指令
│   └── code/               # Code Review 指令
└── exact_agents/           # Agents
```

## Global Instructions (CLAUDE.md)

全域指令檔，設定 Claude Code 的預設行為。

### 預設工作流程

安裝後，Claude Code 在收到實作需求時會先詢問是否要使用 **OpenSpec** 流程
（Small / Large / Skip）。流程與紀律全部由自家 cross-tool skills 提供
（chezmoi shared-body + per-tool name-map，Claude / Codex 同一份身體）：

| Skill | 角色 |
|-------|------|
| `dev-workflow` | Orchestrator — 流程選擇、workspace 隔離、OpenSpec 生命週期 |
| `grill` | Large 流程前端 — 一次一題訪談，共識確認前不動工；結論直接進 openspec artifacts |
| `tdd` | 實作紀律 — 只在預先同意的 seam 測試、red before green、垂直切片 |
| `diagnose` | Bug 進入點 — 先建 feedback loop 才准提假設；根因餵進 proposal 的 Why |
| `verify-done` | 完工前驗證 — 證據先於宣稱 |
| `worktree` | 隔離 workspace 建立（normal / bare+worktree 雙架構） |
| `finish-branch` | 分支收尾 — merge/PR/處置,雙架構原生支援 |

瑣碎任務（改 typo、一行修改）會自動跳過詢問。

設計討論的結論不寫獨立文件 — `grill` 直接分流進
`openspec/changes/<change>/` 的 design.md / proposal.md / spec deltas。
（歷史脈絡:舊流程用 superpowers `brainstorming`/`writing-plans`,需要把
design doc 改道到 `~/.local/share/superpowers/<repo>/`;該機制已隨
rework-dev-workflow-skills change 退役。superpowers plugin 已於
remove-superpowers-plugin change 移除 —— 已驗證 episodic-memory 不依賴它
(自帶 hooks、來自不同 marketplace),流程紀律全改由 `~/.claude/skills/` 自家 skills 提供。
該次移除只停止安裝、uninstall 靠手動,已套用過的機器因此留著 plugin;
retire-superpowers-plugin-cleanup change 改由 `install-03-claude-config`
主動 uninstall 並清 cache,移除才隨 apply 收斂到每台機器。)

### 前置需求

- **OpenSpec CLI** (`@fission-ai/openspec`) — 由 `dev-workflow` 開場執行 `~/.agent/bin/ensure-openspec.sh` 按需安裝

## Plugins

### Plugin 清單

| 名稱 | 來源 | 說明 |
|------|------|------|
| claude-md-management | `claude-plugins-official` | 審計與改善 CLAUDE.md |
| context7 | `claude-plugins-official` | MCP server — 即時查詢 library 文件 |
| code-simplifier | `claude-plugins-official` | 程式碼簡化 agent |
| playwright | `claude-plugins-official` | MCP server — headless 瀏覽器自動化 |
| commit-commands | `claude-plugins-official` | Git commit/push/clean_gone skills |
| security-guidance | `claude-plugins-official` | 安全性指引（背景生效） |
| pr-review-toolkit | `claude-plugins-official` | PR review agents（code-reviewer、silent-failure-hunter 等） |
| pyright-lsp | `claude-plugins-official` | Python type checking LSP |
| jdtls-lsp | `claude-plugins-official` | Java LSP（Eclipse JDT.LS），需 JDK 21+，透過 wrapper 自動選擇 JDK |
| explanatory-output-style | `claude-plugins-official` | 教育性 ★ Insight 解說輸出模式(取代 learning-output-style) |
| claude-code-setup | `claude-plugins-official` | 分析 codebase 推薦 automations |
| episodic-memory | `superpowers-marketplace` | 跨 session 對話記憶 |
| elements-of-style | `superpowers-marketplace` | Strunk 寫作風格改善 |

### On-demand 工具

| 名稱 | 觸發方式 | 說明 |
|------|----------|------|
| OpenSpec | `dev-workflow` 開場步驟 | 結構化變更管理，按需安裝 CLI 並初始化專案 |
| OPSX Commands | `/opsx:*` commands | OpenSpec 工作流程指令（openspec CLI 產生） |
| Git Commands | `/git:*` commands | Git 操作簡寫 |
| Code Commands | `/code:*` commands | Code Review 指令 |

### Marketplace

| 名稱 | 來源 | 說明 |
|------|------|------|
| claude-plugins-official | `anthropics/claude-plugins-official` | 內建預設 marketplace |
| superpowers-marketplace | `obra/superpowers-marketplace` | superpowers 系列插件 |

### 依賴

| 依賴 | 用途 | 備註 |
|------|------|------|
| [Claude Code](https://claude.com/claude-code) | `claude plugin` 指令 | 必須先安裝 |
| [jq](https://jqlang.github.io/jq/) | plugin hook 腳本 | Windows: `scoop install jq` |
| [dos2unix](https://dos2unix.sourceforge.io/) | 修復 hook CRLF (Windows) | Windows: `scoop install dos2unix` |
| [jdtls](https://github.com/eclipse-jdtls/eclipse.jdt.ls) | Java LSP server | Windows: `.chezmoiexternal.toml` 自動下載至 `~/.local/opt/jdtls`（Wave 11）；Linux: 同步腳本自動下載 |
| JDK 21+ | jdtls 執行環境 | wrapper (`~/.local/bin/jdtls`) 從 `JAVA_HOME` / `~/.local/opt/jdk-N` 選擇（Windows 經 uv-managed python 啟動 launcher） |

### Plugin Scope 管理

`enabledPlugins` 支援三個 scope：

| Scope | 檔案位置 | 用途 |
|-------|----------|------|
| User | `~/.claude/settings.json` | 每個 session 都啟用（預設此專案管理的位置） |
| Project | `<repo>/.claude/settings.json` | 只在該 repo 啟用，可 commit 給 team 共享 |
| Local | `<repo>/.claude/settings.local.json` | 只在該 repo 啟用，gitignore 不分享 |

**Plugin 本體只下載一次**到 `~/.claude/plugins/cache/`（user-level），scope 只控制可見性。user-level disable 不會刪除 cache，project-level 啟用時零下載成本。

**什麼時候用 project-level？**
- Plugin 負擔大（例如 playwright 的 27 個 MCP tools），但只在特定專案需要
- Team 共享：希望隊友進 repo 就自動啟用某些 plugin

**在 project 啟用某 plugin 的步驟**

1. 確認該 plugin 已在 user-level marketplace 註冊過（`~/.claude/settings.json` 的 `extraKnownMarketplaces` 有來源）
2. 在專案根目錄建立 `.claude/settings.json`（若沒有）
3. 加入 `enabledPlugins`：
   ```json
   {
     "enabledPlugins": {
       "playwright@claude-plugins-official": true
     }
   }
   ```
4. 若要分享給 team：`git add .claude/settings.json`；只自己用：改放 `.claude/settings.local.json`（已在 Claude Code 預設 gitignore）

參考：[Claude Code settings docs](https://code.claude.com/docs/en/settings.md)

### Skill Listing Budget（CC 2.x）

Claude Code 2.x 開始強制 `skillListingBudgetFraction`（預設 1%），超過時 skill description 會被截斷，`/doctor` 顯示警告：

> Skill listing will be truncated. N descriptions dropped (full descriptions kept for most-used skills) (X.X%/1% of context)

**Budget 是 token-based**（不是 char-based）。1% of 1M context = 10K tokens。每個啟用的 skill 的 description 都會占 budget；commands 在 default 設定下也會占（因為 model-invocable）。

#### 哪些東西占 budget

| 類型 | 預設行為 | 占 budget? |
|------|---------|------------|
| Skill | model-invocable（必須） | ✅ |
| Command 無 frontmatter flag | model-invocable | ✅ |
| Command 帶 `disable-model-invocation: true` | 只能 user 手打 `/name` | ❌ |
| Skill 帶 `user-invocable: false` | 從 `/` menu 隱藏，但仍 model-invocable | ✅（這個 flag 不省 budget） |

#### 三種應對

1. **砍重複/不用的 skill**：對於 wrapper skill（歷史例:曾有 `sp:tdd` 包 `superpowers:test-driven-development`,與現在的自家 `tdd` skill 無關）直接刪。對於 plugin 整包不用就 disable。
2. **Skill → Command + `disable-model-invocation: true`**：適用「user 通常自己打 `/name`、不依賴 model 自動觸發」的 skill。例如 `/handoff`、`/worklog-daily`。轉換後 description 不再進 system prompt，直接從 budget 移除。
3. **拉 budget**（兜底）：在 `dot_claude/modify_settings.json.sh.tmpl` 加 `.skillListingBudgetFraction = 0.02`（2%）。每 turn 多 ~5K input tokens，1M context 上完全無感。

#### 跨工具共用（Codex）skill 轉 command 的 chezmoitemplate 拆分

Codex CLI 沒有 command 概念，只有 skill。要讓「Claude 這邊轉 command 但 Codex 那邊維持 skill」，body 仍能共用 chezmoitemplate：

1. `.chezmoitemplates/skills/<name>.md` 拿掉 frontmatter，只留 markdown body
2. `dot_codex/skills/<name>/SKILL.md.tmpl` 加 skill frontmatter（`name:` + `description:`）後 `{{ template ... -}}`
3. `dot_claude/commands/<name>.md.tmpl` 加 command frontmatter（`description:` + `disable-model-invocation: true`）後 `{{ template ... -}}`
4. 刪 `dot_claude/skills/<name>/`（chezmoi 不會自動清 deployed orphan，需手動 `rm -rf ~/.claude/skills/<name>`）

實例：`handoff`、`worklog-daily`、`worklog-team-status` 走這個模式（commit `7a555e8` / 2026-05-06）。

#### 字元語言對 token 的影響（次要）

Claude tokenizer 對英文較友善（~0.25 tokens/char）、對中文較不友善（~0.6-1.0 tokens/char）。同義內容英文約省 30-50% tokens。但對少量 description 來說節省 token 數通常 < 0.05% of context，遠小於拉 budget 的成本。**不建議**為了省 budget 把中文 description 強制改英文，除非寫的是長 paragraph。

### Windows 已知問題：Plugin Hook Error

Windows 上安裝的 plugin hooks（`.sh` 腳本）會因為兩個問題而失敗：

| 問題 | 原因 | 修復方式 |
|------|------|----------|
| 路徑反斜線 | `${CLAUDE_PLUGIN_ROOT}` 展開為 `C:\...`，bash 將 `\` 當跳脫字元 | 用 `cygpath` 轉換路徑 |
| CRLF 換行符 | 部分 plugin 的 `.sh` 被存為 CRLF | 用 `dos2unix` 轉為 LF |
| UTF-8 BOM | `hooks.json` 帶有 BOM (`EF BB BF`)，Claude Code 的 JSON parser 無法解析 | 移除 BOM（安裝腳本已自動處理） |

**BOM 問題細節：** PowerShell 5.x 的 `-Encoding UTF8` 會寫入帶 BOM 的 UTF-8。安裝腳本 step 11 修補 hooks.json 後，檔案會被加上 BOM，導致所有 plugin hooks 載入失敗（`JSON Parse error: Unrecognized token '﻿'`）。安裝腳本 step 13 會自動移除 BOM。Plugin 更新後需重新執行安裝腳本。

安裝腳本 `run_onchange_install-claude-plugins` 已包含自動修復步驟。如果 plugin 更新後問題復發，重新執行安裝腳本即可。

**前置需求：**
- `jq` — hook 腳本用來解析 JSON（`scoop install jq`）
- `dos2unix` — 轉換換行符（`scoop install dos2unix`）

**追蹤 Issues：**
- [#21878](https://github.com/anthropics/claude-code/issues/21878) — Hook scripts fail on Windows: backslash paths
- [#22906](https://github.com/anthropics/claude-code/issues/22906) / [#22934](https://github.com/anthropics/claude-code/issues/22934) — SessionStart hook errors cause CLI freeze

待官方修復後可移除 workaround。

### episodic-memory MCP 連不上（plugin cache 不完整）

`claude mcp list` 顯示 `plugin:episodic-memory:episodic-memory - ✘ Failed to connect`。

| 項目 | 說明 |
|------|------|
| 症狀 | MCP server 啟動指令 `node .../cli/mcp-server-wrapper.js` 找不到檔案 |
| 根因 | plugin cache (`~/.claude/plugins/cache/superpowers-marketplace/episodic-memory/`) 被 Claude 內部 GC 誤刪目錄，缺 `cli/ dist/ src/ scripts/` 等，只剩 `docs/ skills/ test/`（會留下 `.orphaned_at` 標記） |
| 修復 | 重裝讓 Claude 重新 clone 完整 repo：`claude plugin uninstall episodic-memory@superpowers-marketplace` 後 `claude plugin install episodic-memory@superpowers-marketplace`（單純 install 不會修復已存在的壞 cache，需先 uninstall） |
| 首次啟動 | `cli/dist` 已隨 repo commit，但執行期依賴（better-sqlite3 等原生模組）需 `node_modules`；wrapper 首次啟動會自動 `npm install`（約 30–60 秒，含原生編譯），故第一次 health check 可能逾時顯示 failed，裝完即恢復 |

安裝腳本 `run_onchange_install-03-claude-config` 已包含 episodic-memory 安裝，新機器會自動裝；cache 損壞時手動重裝即可。

## ensure-openspec 腳本

按需安裝 OpenSpec CLI 並初始化當前專案。正典位置 `~/.agent/bin/ensure-openspec.sh`，
由 `dev-workflow` skill 的開場步驟以絕對路徑呼叫。

### 依賴

| 依賴 | 用途 | 備註 |
|------|------|------|
| [Node.js](https://nodejs.org/) / npm | 安裝 OpenSpec CLI (`npm install -g`) | 支援透過 [nvm](https://github.com/nvm-sh/nvm) 載入 |

### 功能

1. 檢查 OpenSpec CLI 是否已安裝，沒有則透過 npm 安裝
2. 檢查當前專案是否已 `openspec init`，沒有則執行初始化
3. 已初始化的專案會執行 `openspec update`，並以 `--tools claude,codex,antigravity` 補齊工具

### 使用方式

`dev-workflow` 會自動執行，一般不需手動觸發。要手動跑就用絕對路徑
`~/.agent/bin/ensure-openspec.sh`。

> 曾有 `/ensure-openspec` command 包裝它，已於 prune-ensure-openspec-orphans change
> 移除：該 command 以 bare 名稱呼叫，在 WSL 下會被 PATH interop 導到 `~/.local/bin`
> 底下的過時副本（`init --tools claude`，會砍掉 codex/antigravity surface）。
> 腳本互相呼叫一律用絕對路徑。

## RTK — Token-reducing CLI proxy

攔截 `Bash` tool call，將 `git` / `npm` / `docker` / `kubectl` 等指令透過 `rtk` binary 壓縮輸出，目標 60-90% token savings。

整合架構與黑名單配置細節見 [rtk.md](rtk.md)。重點：

- Binary 由 `.chezmoiexternal.toml` 下載（pin `0.36.0`）
- Hook 腳本 `dot_claude/hooks/executable_rtk-rewrite.sh` 為 RTK 官方 87 行模板
- Blacklist 單一 source 在 `.chezmoitemplates/rtk-config.toml`，預設排除本機沒裝的 20 個工具

## Status Line

自訂的 Claude Code 狀態列，使用 Go 編寫以獲得更好的效能。

### 顯示效果

```
[💛 Opus 4.5] 📂 project ⚡ main* | ██████░░░░ 52.8% 105.6k | 1h30m [2 sessions]
🔥 $4.00/hr │ 💰 Today: $6.83 │ ⏱ Reset: 2h 25m
MCP: ✓ context7, atlassian, playwright, chrome-devtools │ ✗ github
```

#### 第一行
- 模型名稱與 emoji（💛 Opus / 💠 Sonnet / 🌸 Haiku）
- 專案目錄名稱
- Git 分支（有未提交變更時顯示 `*`）
- Context 使用量進度條與百分比
- 今日累計使用時數
- 活躍 session 數量（同時開多個 Claude Code 時顯示）

#### 第二行
- Burn Rate（每小時消耗）
- 今日總花費
- Block Reset 倒數時間

#### 第三行
- MCP 伺服器狀態（顯示已連接與失敗的伺服器名稱）
- Plugin MCP server（`plugin:source:name` 格式）自動取最後一段作為顯示名稱

### 依賴

| 依賴 | 用途 | 備註 |
|------|------|------|
| [Go](https://go.dev/) 1.18+ | 編譯 statusline binary | |
| [Bun](https://bun.sh/) | 執行 ccusage | |
| [ccusage](https://github.com/ryoppippi/ccusage) | 費用統計 | 透過 `bunx ccusage` 自動下載執行 |
| [Claude Code](https://claude.com/claude-code) | MCP 狀態檢查 | `claude mcp list` |

### 安裝

#### 1. 安裝依賴

**Go（編譯 statusline 用）：**

```bash
# Ubuntu/Debian
sudo apt install -y golang-go

# macOS
brew install go

# Windows (Scoop)
scoop install go
```

**Bun（執行 ccusage 用）：**

```bash
# macOS/Linux
curl -fsSL https://bun.sh/install | bash

# Windows (PowerShell)
powershell -c "irm bun.sh/install.ps1 | iex"
```

安裝後重新載入 shell：
```bash
source ~/.bashrc  # 或 source ~/.zshrc
```

**ccusage（費用統計）：**

ccusage 不需要預先安裝，`bunx ccusage` 會自動下載並執行。首次執行會稍慢，之後會使用快取。

#### 2. 複製並編譯

```bash
# 整包編譯：statusline.go 依賴 build-tag 分流的 count_unix.go / count_windows.go，
# 單獨編譯 statusline.go 會 undefined: countClaudeProcesses。
cd tools/statusline
go build -o ~/.claude/statusline.exe .   # Windows
go build -o ~/.claude/statusline .       # macOS/Linux
```

#### 3. 設定 Claude Code

編輯 `~/.claude/settings.json`，加入 statusLine 設定：

**Windows:**
```json
{
  "statusLine": {
    "type": "command",
    "command": "bash -c '/c/Users/<username>/.claude/statusline.exe'",
    "padding": 0
  }
}
```

> **注意（Windows）**：必須用 `bash -c '...'` 包裝，直接呼叫 `.exe` 時 Claude Code 不會透過 shell 執行，stdin 無法 pipe 進去，導致 statusline 空白。

**macOS/Linux:**
```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline",
    "padding": 0
  }
}
```

#### 4. 重啟 Claude Code

### 資料來源

2026-04-01 重構移除 ccusage CLI、JSONL 掃描與 cache 系統，所有資料改從 Claude Code 注入的 stdin JSON 直接取得（context %、token、session cost、duration、rate limits、worktree）。外部 I/O 僅剩 git 命令與進程計數。

### 平行化與 timeout

主流程用 goroutine 平行跑兩個慢源 + 1 秒 `asyncTimeout`：

- `getGitInfo()` — 內部再分 3 個 goroutine：`git branch --show-current` / `git status --porcelain` / `git diff --shortstat`。Wall time = max(spawn) 而非 sum，Windows warm 中位數 428 ms（2026-04-24 平行化前為 1111 ms，常超時導致 branch/diff 段被吞掉）。
- `countClaudeProcesses()` — 計算活躍 CLI session 數。

兩支 goroutine 都未在 1 秒內完成時，對應段落會以空字串呈現（不阻塞 statusline 渲染）。

### Session 追蹤

**使用時間** 由 Claude Code stdin JSON 的 `cost.total_duration_ms` 直接提供，statusline 不再自行維護心跳。

**活躍 Session 數量**（排除非 conversation 進程）：
- Windows: `golang.org/x/sys/windows` 的 Toolhelp32 + `QueryFullProcessImageName`，過濾全路徑必須在 `~/.local/bin/claude.exe`（擋 Claude Desktop 與 chrome-native-host）。2026-04-24 從 WMI `Get-CimInstance Win32_Process` 換掉，冷啟動從 ~900 ms 降到 ~10 ms。
- macOS/Linux: `ps aux | grep claude`，排除 `--chrome-native-host` 等輔助進程。

### 參考

樣式參考自 [Claude Code Status Line](https://jackle.pro/articles/claude-code-status-line)

## Handoff 機制

切換 session 時的無縫接續機制。由 skill、hook、statusline 三者配合：

### 組件

| 角色 | 檔案 | 觸發 |
|---|---|---|
| Skill | `dot_claude/skills/handoff/`（+ `dot_codex/skills/handoff/`，共用 body 在 `.chezmoitemplates/skills/handoff.md`） | `/handoff`、「切 session」、reminder 後確認 |
| 提醒 hook | `dot_claude/hooks/executable_handoff-reminder.sh` | UserPromptSubmit；context 達 40/70/90% 各提醒一次 |
| Cache writer | `tools/statusline/statusline.go` 的 `writeContextWindowCache()` | 每次 statusline 渲染 |
| 註冊 | `dot_claude/modify_settings.json.sh.tmpl` jq patch | chezmoi apply 時生效 |

### 資料流

Statusline 每次渲染寫兩份 cache（`context_window_size > 0` 時）：

- `~/.cache/claude-handoff/session-<id>.cache` — 精確匹配當前 session
- `~/.cache/claude-handoff/latest.cache` — 跨 session fallback，永不清理

Reminder hook 解析當前 context 使用率的順序：

1. `$CLAUDE_HANDOFF_CONTEXT_WINDOW` env var（debug/override 專用）
2. `session-<id>.cache`（主要）
3. `latest.cache`（跨 session fallback）
4. Model name mapping → 200000
5. Default 200000

`latest.cache` 存在的原因：新 session 的首個 prompt 在 statusline 首次重繪前就進來時，`session-<id>.cache` 尚未寫出，靠它避免誤觸發 200k fallback。

Per-session 的 `session-<id>.cache` / `reminded-*` 哨兵刻意**不清理**：檔案僅 7B、以 session-id 命名永不撞號，留著無害；過去的 SessionEnd 清理 hook 因 SessionEnd 觸發不可靠（terminal 直接關、crash 都不跑）本就會洩漏，已移除。

### 產出

`/handoff` skill 的輸出：

- `<repo>/.claude/handoffs/<YYYY-MM-DD-HHMM>__<slug>.md` — 簡短 checkpoint（以 references 為主）
- Resumption prompt 複製到 clipboard（xclip/wl-copy/pbcopy/clip.exe 自動偵測）
- Skill 會自動將 `.claude/handoffs/` 加進該 repo 的 `.gitignore`

### 設定需求

- `jq` 必須安裝（hooks 依賴）
- `CLAUDE_HANDOFF_CONTEXT_WINDOW` env var **不要**放進 settings.json — 會破壞 cache-first 的動態性（每次都走 env 就不會讀 cache）

### 維護備註

- Per-session cache（`session-<id>.cache`、`reminded-<id>-<tier>`）無自動清理機制；單檔 7B、無功能影響。真要清空可手動 `rm ~/.cache/claude-handoff/session-* ~/.cache/claude-handoff/reminded-*`（保留 `latest.cache`）。
