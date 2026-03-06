## 1. Multi-layer Cache Refactor

- [x] 1.1 Refactor cache system: add TTL field to cache structs, add `loadCacheWithTTL` that returns (value, fresh bool)
- [x] 1.2 Remove hardcoded TTL checks from main(), move TTL constants to cache source definitions

## 2. JSONL Reading Infrastructure

- [x] 2.1 Add `findSessionJSONL(sessionID)` function (extract from getSessionDisplayName's logic)
- [x] 2.2 Add `readJSONLTail(path, maxLines)` function to read last N lines efficiently
- [x] 2.3 Add JSONL line parsing for timestamps and token usage

## 3. Token Speed

- [x] 3.1 Add `calculateTokenSpeed(sessionID)` — parse recent assistant responses from JSONL, return output tokens/sec
- [x] 3.2 Add token speed to line 1 display: `⚡ XX.X t/s`
- [x] 3.3 Add file cache for token speed (15s TTL)

## 4. Block Timer from JSONL

- [x] 4.1 Add `calculateBlockTimer()` — scan recent JSONL files for timestamps, find 5hr block boundary
- [x] 4.2 Replace `fetchBlockInfo()` ccusage call with JSONL-based block timer
- [x] 4.3 Calculate approximate burn rate: `session_cost / block_elapsed_hours` (changed from today_cost)
- [x] 4.4 Update line 2 display format

## 5. Git Diff Stats

- [x] 5.1 Extend `getGitInfo()` to also return insertions/deletions from `git diff --shortstat`
- [x] 5.2 Update line 1 display: `⚡ branch* +N -M`

## 6. Cleanup

- [x] 6.1 Remove `fetchBlockInfo()` and `BlockCache` struct (no longer needed)
- [x] 6.2 Remove ccusage block-related goroutine from main()

## 7. Verification

- [x] 7.1 Build and test with sample JSON input
- [x] 7.2 Verify block timer calculation with real JSONL data
- [x] 7.3 Verify token speed calculation
- [x] 7.4 Verify git diff stats display
