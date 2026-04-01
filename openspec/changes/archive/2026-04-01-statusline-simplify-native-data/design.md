## Context

`claude/statusline/statusline.go` (~760 行) 是一個 Go 程式，由 CI 編譯後透過 chezmoi 部署為 `~/.local/bin/statusline.exe`。它從 Claude Code 的 JSON stdin 讀取 session 資料並輸出兩行彩色狀態列。

目前有大量迂迴邏輯：掃描 JSONL 檔案計算 block timer 和 token speed、呼叫外部 ccusage CLI 取得 today cost、維護多層 cache 系統（TTL + stale fallback）。Claude Code 已原生提供 `rate_limits`、`cost.total_cost_usd`、`cost.total_duration_ms`、`context_window.used_percentage` 等欄位，可直接取代這些做法。

## Goals / Non-Goals

**Goals:**
- 使用 Claude Code JSON stdin 原生欄位取代所有迂迴取得方式
- 移除 ccusage CLI 依賴
- 移除 JSONL 掃描基礎設施和 cache 系統
- 移除 session display name（Claude Code 原生顯示）
- 新增 rate limits（5h + 7d）、session cost、worktree 顯示
- 程式碼從 ~760 行降到 ~350 行

**Non-Goals:**
- 不改變第一行的佈局（model、context bar、dir、git、effort）
- 不改變 git info 取得方式（JSON stdin 不提供）
- 不改變 active session count 取得方式（JSON stdin 不提供）
- 不改變 effort level 取得方式（JSON stdin 不提供）
- 不新增 MCP 狀態、output style 等額外資訊

## Decisions

### D1: 直接使用 `used_percentage` 而非手動計算
現有程式手動算 `(input + cache_creation + cache_read) / window_size * 100`。JSON stdin 已提供預算好的 `used_percentage`，直接使用。仍保留 `current_usage` token 數字用於顯示（如 `156k`）。

### D2: `rate_limits` 取代 block timer
`rate_limits.five_hour.used_percentage` + `resets_at` 直接取代整個 JSONL 掃描 + block 計算邏輯。注意 `rate_limits` 只在 Claude.ai 訂閱用戶且第一個 API response 後才出現，需 graceful handling。

### D3: 高用量時顯示重置時間
rate limit ≥ 80% 時，在百分比後附加重置時間（如 `⟳14:30`）。`resets_at` 是 Unix epoch seconds，轉換為本地時間顯示。

### D4: `cost.total_duration_ms` 取代 session start time 解析
不再需要 `session.start_time` 和 `formatSessionDuration` 函式，直接用毫秒數除以 60000 得到分鐘數。

### D5: 移除整個 cache 系統
Cache 系統存在是為了 ccusage（60s TTL）和 block timer（30s TTL）。兩者都移除後，cache 系統無用武之地。`countClaudeProcesses` 和 git 操作每次都是即時執行，不需要 cache。

### D6: 保留 goroutine 平行但簡化
只剩 `countClaudeProcesses` 和 `getGitInfo` 需要並行。移除 mutex（兩者寫不同變數），保留 WaitGroup + timeout。timeout 可縮短到 1 秒（不再等 ccusage）。

### D7: Worktree 顯示在第一行 dir 區域
worktree 資訊在第一行 dir 後面顯示，格式：`📁 dotfiles 🌿wt-name`。只在 `worktree` 欄位存在時顯示。

### D8: 第二行佈局
`#abc12345 ⏱ 12m [2] │ 💰 $0.15 │ ⏳ 5h: 23% │ 7d: 41%`

各部分都是 optional：
- session ID + duration + process count：永遠顯示（session_id 來自 JSON）
- session cost：`cost.total_cost_usd > 0` 時顯示
- rate limits：`rate_limits` 存在時顯示

## Risks / Trade-offs

- **`rate_limits` 可能不存在** → 只在存在時顯示，不影響其他部分。非訂閱用戶或 session 初期看不到此區塊。
- **`used_percentage` 可能為 null** → 初始時 fallback 到 0，與現有行為一致。
- **移除 token speed** → 依賴 JSONL 掃描，一併清除。JSON stdin 沒有對應欄位。如果未來需要可重新加回。
- **移除 today cost** → 使用者明確要求移除。`cost.total_cost_usd` 是 session cost 不是 today total，語義不同但使用者接受。
