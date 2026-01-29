# Claude Code 設定

Claude Code 相關的個人設定檔案。

## 目錄結構

```
claude/
├── agents/           # 自訂 Agent 提示詞
├── statusline/       # 自訂狀態列程式
│   └── statusline.go
└── README.md
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
- [ccusage](https://github.com/ryoppippi/ccusage)（費用統計，透過 `bunx ccusage` 執行）
- Claude CLI（MCP 狀態檢查）

### 安裝

#### 1. 複製並編譯

```bash
# 複製 statusline.go 到 ~/.claude/
cp statusline/statusline.go ~/.claude/

# 編譯
cd ~/.claude
go build -o statusline.exe statusline.go   # Windows
go build -o statusline statusline.go       # macOS/Linux
```

#### 2. 設定 Claude Code

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

#### 3. 重啟 Claude Code

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
