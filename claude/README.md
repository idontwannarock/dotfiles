# Claude Code 設定

Claude Code 相關的個人設定檔案。

## 目錄結構

```
claude/
├── agents/              # 自訂 Agent 提示詞
├── statusline/          # 自訂狀態列程式
│   └── statusline.go
├── CLAUDE.md            # 全域指令 (~/.claude/CLAUDE.md)
├── setup-plugins.ps1    # Plugin 安裝腳本 (Windows)
├── setup-plugins.sh     # Plugin 安裝腳本 (Linux/macOS)
└── README.md
```

## Global Instructions (CLAUDE.md)

全域指令檔，設定 Claude Code 的預設行為。

### 預設工作流程

安裝後，Claude Code 在收到實作需求時會先詢問是否要使用 **OpenSpec + Superpowers** 流程：

- **OpenSpec** — 結構化的變更管理流程（artifact-driven workflow）
- **Superpowers** — 進階技能集（brainstorming、TDD、systematic debugging 等）

瑣碎任務（改 typo、一行修改）會自動跳過詢問。

### 安裝

透過安裝腳本自動完成（見下方安裝段落），或手動複製：

```bash
cp claude/CLAUDE.md ~/.claude/CLAUDE.md
```

### 前置需求

- **superpowers** plugin — 提供 brainstorming 等技能
- **OpenSpec CLI** (`@fission-ai/openspec`) — 提供 `opsx:new` 等結構化流程

## Plugins

已安裝的 Claude Code Plugin。

### Plugin 清單

| 名稱 | 來源 | 說明 |
|------|------|------|
| superpowers | `claude-plugins-official` marketplace | 提供多種進階技能（brainstorming、TDD、debugging 等） |
| subtask | `zippoxer/subtask`（手動 clone） | 平行任務分派，將工作委派給多個 AI worker |
| OpenSpec | `@fission-ai/openspec`（npm CLI） | 結構化變更管理，自動產生 skills 及 commands |

### Marketplace

| 名稱 | 來源 | 說明 |
|------|------|------|
| claude-plugins-official | `anthropics/claude-plugins-official` | 內建預設 marketplace |
| superpowers-marketplace | `obra/superpowers-marketplace` | superpowers 系列插件 |

### 安裝

**使用腳本（推薦）：**

```powershell
# Windows
.\claude\setup-plugins.ps1
```

```bash
# Linux/macOS
chmod +x claude/setup-plugins.sh
./claude/setup-plugins.sh
```

**手動安裝：**

```bash
# 新增 marketplace
claude plugin marketplace add obra/superpowers-marketplace

# 安裝 superpowers plugin
claude plugin install superpowers

# Clone subtask plugin
git clone https://github.com/zippoxer/subtask.git ~/.claude/plugins/subtask/

# 安裝 OpenSpec CLI
npm install -g @fission-ai/openspec

# 複製全域 CLAUDE.md
cp claude/CLAUDE.md ~/.claude/CLAUDE.md
```

安裝完成後重啟 Claude Code 即可使用。

**在各專案啟用 OpenSpec：**

```bash
cd <project-dir>
openspec init --tools claude
```

## Status Line

自訂的 Claude Code 狀態列，使用 Go 編寫以獲得更好的效能。

### 顯示效果

```
[💛 Opus 4.5] 📂 project ⚡ main* | ██████░░░░ 52.8% 105.6k | 1h30m [2 sessions]
🔥 $4.00/hr │ 💰 Today: $6.83 │ ⏱ Reset: 2h 25m
MCP: ✓ playwright, chrome-devtools │ ✗ failed-server
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

### 依賴

- Go 1.18+（編譯用）
- [Bun](https://bun.sh/)（執行 ccusage 用）
- [ccusage](https://github.com/ryoppippi/ccusage)（費用統計，透過 `bunx ccusage` 執行）
- Claude CLI（MCP 狀態檢查）

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
    "command": "C:\\Users\\<username>\\.claude\\statusline.exe",
    "padding": 0
  }
}
```

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
