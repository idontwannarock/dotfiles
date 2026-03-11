# Claude Code 設定

Claude Code 相關的個人設定檔案。

## 目錄結構

```
claude/statusline/          # 自訂狀態列程式
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

安裝後，Claude Code 在收到實作需求時會先詢問是否要使用 **OpenSpec + Superpowers** 流程：

- **OpenSpec** — 結構化的變更管理流程（artifact-driven workflow）
- **Superpowers** — 進階技能集（brainstorming、TDD、systematic debugging 等）

瑣碎任務（改 typo、一行修改）會自動跳過詢問。

### 前置需求

- **superpowers** plugin — 提供 brainstorming 等技能
- **OpenSpec CLI** (`@fission-ai/openspec`) — 透過 `/ensure-openspec` skill 按需安裝

## Plugins

### Plugin 清單

| 名稱 | 來源 | 說明 |
|------|------|------|
| superpowers | `claude-plugins-official` | 核心技能引擎（brainstorming、TDD、debugging 等） |
| claude-md-management | `claude-plugins-official` | 審計與改善 CLAUDE.md |
| context7 | `claude-plugins-official` | MCP server — 即時查詢 library 文件 |
| code-simplifier | `claude-plugins-official` | 程式碼簡化 agent |
| playwright | `claude-plugins-official` | MCP server — headless 瀏覽器自動化 |
| commit-commands | `claude-plugins-official` | Git commit/push/clean_gone skills |
| security-guidance | `claude-plugins-official` | 安全性指引（背景生效） |
| pr-review-toolkit | `claude-plugins-official` | PR review agents（code-reviewer、silent-failure-hunter 等） |
| pyright-lsp | `claude-plugins-official` | Python type checking LSP |
| jdtls-lsp | `claude-plugins-official` | Java LSP（Eclipse JDT.LS），需 JDK 21+，透過 wrapper 自動選擇 JDK |
| learning-output-style | `claude-plugins-official` | 互動式學習 + 教育性解說輸出模式 |
| claude-code-setup | `claude-plugins-official` | 分析 codebase 推薦 automations |
| episodic-memory | `superpowers-marketplace` | 跨 session 對話記憶 |
| elements-of-style | `superpowers-marketplace` | Strunk 寫作風格改善 |

### On-demand 工具

| 名稱 | 觸發方式 | 說明 |
|------|----------|------|
| OpenSpec | `/ensure-openspec` skill | 結構化變更管理，按需安裝 CLI 並初始化專案 |
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
| [jdtls](https://github.com/eclipse-jdtls/eclipse.jdt.ls) | Java LSP server | Windows: `scoop install jdtls`；Linux: 同步腳本自動下載 |
| JDK 21+ | jdtls 執行環境 | wrapper (`~/.local/bin/jdtls`) 自動從 scoop/系統 JDK 中選擇 |

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

## /ensure-openspec Skill

全域 user-invocable skill，用於按需安裝 OpenSpec CLI 並初始化當前專案。

### 依賴

| 依賴 | 用途 | 備註 |
|------|------|------|
| [Node.js](https://nodejs.org/) / npm | 安裝 OpenSpec CLI (`npm install -g`) | 支援透過 [nvm](https://github.com/nvm-sh/nvm) 載入 |

### 功能

1. 檢查 OpenSpec CLI 是否已安裝，沒有則透過 npm 安裝
2. 檢查當前專案是否已 `openspec init`，沒有則執行初始化
3. 已初始化的專案會執行 `openspec update`

### 使用方式

在 Claude Code 中輸入 `/ensure-openspec`，Claude 會自動執行腳本並回報結果。

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
# 複製 statusline.go 到 ~/.claude/
cp statusline/statusline.go ~/.claude/

# 編譯
cd ~/.claude
go build -o statusline.exe statusline.go   # Windows
go build -o statusline statusline.go       # macOS/Linux
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

### 緩存機制

為避免頻繁執行外部命令，使用以下緩存策略：

| 資料 | 緩存時間 | 說明 |
|------|----------|------|
| ccusage 費用 | 60 秒 | 每日花費 |
| Block 資訊 | 30 秒 | Burn rate 與 reset 時間 |
| MCP 狀態 | 120 秒 | 伺服器連線狀態 |

緩存檔案位於 `~/.claude/statusline-cache/`

### Session 追蹤

**使用時間計算**（基於心跳機制）：
- 每次 statusline 執行時更新心跳
- 只計算連續活動時間（心跳間隔 ≤ 60 秒）
- Session 檔案位於 `~/.claude/statusline-sessions/`

**活躍 Session 數量**（直接計算進程）：
- Windows: 使用 PowerShell 計算 `claude` 進程數
- macOS/Linux: 使用 `pgrep` 計算 `claude` 進程數
- 精準反映當前開啟的 Claude Code 數量

### 參考

樣式參考自 [Claude Code Status Line](https://jackle.pro/articles/claude-code-status-line)
