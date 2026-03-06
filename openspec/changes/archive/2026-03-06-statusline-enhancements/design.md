## Context

statusline.go 是一個 Go binary，由 Claude Code 每次需要更新 statusline 時 spawn 並透過 stdin 傳入 JSON。目前依賴 ccusage CLI 取得 today cost 和 block info，但 ccusage 慢且不穩定。

參考 ccstatusline（TypeScript）的做法，block timer 和 token speed 可以直接從 Claude Code 的 session JSONL 檔案計算。

## Goals / Non-Goals

**Goals:**
- 從 JSONL 計算 token speed 和 block timer
- 減少 ccusage 依賴（block info 不再需要）
- 加入 git diff stats
- 改進 cache 架構

**Non-Goals:**
- 呼叫 Anthropic OAuth API（目前回傳 authentication error）
- 完全移除 ccusage（today cost 仍需要）
- 加入 TUI 設定介面

## Decisions

### 1. JSONL 讀取策略

Session JSONL 檔案可能很大（數 MB）。採用「從尾部往回讀」策略：
- Token speed：找最後幾筆 assistant response 的 timestamps + output_tokens
- Block timer：需要掃描更多 JSONL 檔案找 timestamps，但只需 timestamp 欄位

具體做法：
- 重用 `getSessionDisplayName` 的 JSONL 定位邏輯（掃描 projects 目錄）
- Token speed 只讀當前 session 的 JSONL，從尾部取最近 10 筆 assistant message
- Block timer 掃描所有最近修改過的 JSONL，收集 timestamps 後找 5hr gap

### 2. Block Timer 計算

仿 ccstatusline 的 `jsonl-blocks.ts`：
1. 收集近 10 小時內所有 JSONL 的 timestamps（只看有 token usage 的行）
2. 從最新 timestamp 往回找，直到 gap > 5hr
3. 該 gap 之後的最早 timestamp 就是 block start
4. Block elapsed = now - block start
5. Block remaining = 5hr - elapsed

### 3. Burn Rate 近似計算

原本從 ccusage blocks API 取得。現在改為：
- `burn_rate = today_cost / block_elapsed_hours`
- 只在 today_cost > 0 且 block_elapsed > 0 時計算
- 精確度比 ccusage 低，但免費且快速

### 4. 多層 Cache

```
┌─────────────────────────────────────────────┐
│ memory cache (package-level vars)            │
│ - 每次 process invocation 內有效             │
│ - 避免同一次呼叫內重複計算                    │
├─────────────────────────────────────────────┤
│ file cache (~/.claude/statusline-cache/)      │
│ - 跨 process 持久化                          │
│ - 各 cache 有獨立 TTL                        │
│ - ccusage costs: 60s                         │
│ - block timer: 30s                           │
│ - token speed: 15s                           │
├─────────────────────────────────────────────┤
│ actual data source                           │
│ - ccusage CLI (today cost)                   │
│ - JSONL files (block timer, token speed)     │
│ - git commands (branch, dirty, diff stats)   │
└─────────────────────────────────────────────┘
```

statusline 每次被呼叫都是新 process，memory cache 只在同一次呼叫中避免重複計算。File cache 是主要的跨呼叫快取機制。

### 5. Git Diff Stats

`git diff --shortstat` 一個命令取得 insertions/deletions。在 `getGitInfo` 中一起做。

### 6. 輸出格式

```
Line 1: [💛 Opus 4.6] 📂 dir ⚡ branch* +23 -5 | ██████░░░░ 62.3% 124.6k | ⚡ 42.1 t/s | #session │ 1h30m
Line 2: 💰 Today: $39.99 (session: $2.45) │ 🔥 $17.70/hr │ ⏱ Block: 2h15m left
```

## Risks / Trade-offs

- [JSONL 解析可能慢] → 只從尾部讀最後 N 行，加 file cache 15-30s
- [Block timer 精確度] → 只看有 token usage 的行，跳過 sidechain，與 ccstatusline 做法一致
- [Burn rate 近似] → today_cost / elapsed 比 ccusage 的精確計算粗糙，但對使用者足夠有用
