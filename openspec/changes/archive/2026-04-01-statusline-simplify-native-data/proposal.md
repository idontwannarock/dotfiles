## Why

Claude Code 的 statusline JSON stdin 已原生提供 rate limits、session cost、context percentage、session duration 等資料。現有 statusline.go 透過掃描 JSONL 檔案算 block timer、呼叫 ccusage CLI 算 today cost，這些迂迴做法可以全部移除，改用原生資料。同時移除使用者不再需要的 today cost 顯示和 session display name（Claude Code 已原生顯示）。

## What Changes

- **移除** ccusage 整合：`resolveCcusagePath`、`fetchCcusageCosts`、`CostCache`、相關 cache 邏輯
- **移除** JSONL 掃描基礎設施：`findSessionJSONL`、`readJSONLTail`、`parseJSONLEntry`、`jsonlEntry`、`calculateBlockTimer`、`extractTimestamps`、`sortTimestamps`、`BlockTimerCache`
- **移除** session display name 功能：`getSessionDisplayName`（Claude Code 原生顯示在輸入框右上角）
- **移除** 手動 context percentage 計算，改用 `context_window.used_percentage`
- **移除** `session.start_time` 解析，改用 `cost.total_duration_ms`
- **移除** 整個 cache 系統（`loadCache`、`saveCache`、`cacheDir`），不再需要
- **新增** `rate_limits.five_hour` 顯示（取代 block timer）
- **新增** `rate_limits.seven_day` 顯示
- **新增** `cost.total_cost_usd` session cost 顯示
- **新增** `worktree.*` 資訊顯示

## Capabilities

### New Capabilities
- `statusline-native-data`: 使用 Claude Code JSON stdin 原生欄位（rate limits、session cost、duration、context percentage、worktree）取代所有迂迴取得方式

### Modified Capabilities
- `statusline-block-timer`: 整個移除，被 `rate_limits.five_hour` 取代
- `statusline-ccusage-resolution`: 整個移除，不再需要 ccusage
- `statusline-session-cost`: 移除 today cost，改為 session cost（來自 JSON stdin）
- `statusline-token-speed`: 移除（依賴 JSONL 掃描，一併清除）
- `statusline-multi-cache`: 整個移除，不再需要 cache 系統

## Impact

- `claude/statusline/statusline.go`：主要修改對象，預計從 ~760 行降到 ~350 行
- `ClaudeData` struct：擴充 `RateLimits`、`Worktree`、`Cost.TotalDurationMs`；移除 `Session`
- 外部依賴 `ccusage` CLI：不再需要
- CI/CD：無影響（同一個 Go 檔案，同樣的編譯流程）
- 第二行顯示佈局重新設計：`#id ⏱ Xm [N] │ 💰 $X.XX │ ⏳ 5h: X% │ 7d: X%`
