## 1. Update ClaudeData struct

- [x] 1.1 Add `RateLimits` field with `FiveHour` and `SevenDay` sub-structs (pointer types for optional)
- [x] 1.2 Add `Worktree` field with `Name` and `Branch` (pointer type for optional)
- [x] 1.3 Add `Cost.TotalDurationMs` field (int64)
- [x] 1.4 Replace manual context % calculation with `ContextWindow.UsedPercentage` (*float64 for null handling)
- [x] 1.5 Remove `Session` struct (no longer need `start_time`)

## 2. Remove JSONL infrastructure

- [x] 2.1 Remove `findSessionJSONL`, `readJSONLTail`, `parseJSONLEntry`, `jsonlEntry` struct
- [x] 2.2 Remove `calculateBlockTimer`, `extractTimestamps`, `sortTimestamps`
- [x] 2.3 Remove `BlockTimerCache` type
- [x] 2.4 Remove `getSessionDisplayName` function

## 3. Remove ccusage and cache system

- [x] 3.1 Remove `resolveCcusagePath`, `ccusagePath` global, `fetchCcusageCosts`, `CostCache` type
- [x] 3.2 Remove `loadCache`, `saveCache`, `cacheDir` global, cache TTL constants
- [x] 3.3 Remove `projectsDir` global (only used by JSONL scanning)

## 4. Simplify main function

- [x] 4.1 Replace context % calculation with `data.ContextWindow.UsedPercentage` (fallback to 0 if nil)
- [x] 4.2 Replace session duration from `formatSessionDuration` with `cost.total_duration_ms` division
- [x] 4.3 Remove all cache loading and goroutine cache refresh logic
- [x] 4.4 Simplify goroutine parallelism: only `countClaudeProcesses` and `getGitInfo`, reduce timeout to 1s

## 5. Build new second line

- [x] 5.1 Add rate limit formatting: `5h: X%` / `7d: X%` with ≥80% reset time display
- [x] 5.2 Add `formatResetTime` helper: epoch → local HH:MM or weekday abbreviation
- [x] 5.3 Add session cost display from `cost.total_cost_usd`
- [x] 5.4 Add session duration display from `cost.total_duration_ms`
- [x] 5.5 Assemble second line: session info │ cost │ rate limits

## 6. Add worktree display

- [x] 6.1 Add worktree indicator on first line after dir: `🌿wt-name` when `worktree` present

## 7. Cleanup

- [x] 7.1 Remove `formatSessionDuration` function
- [x] 7.2 Remove unused imports (`bufio`, `regexp` if no longer needed)
- [x] 7.3 Update `init()`: remove `cacheDir`, `projectsDir`, `ccusagePath` setup
- [x] 7.4 Verify build: `go build -o /dev/null ./claude/statusline/`
