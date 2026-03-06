## 1. ccusage Path Resolution

- [x] 1.1 Add `resolveCcusagePath()` function: try `exec.LookPath("ccusage")`, fallback to `~/.bun/bin/ccusage(.exe)`, cache result in package-level `ccusagePath` variable
- [x] 1.2 Update `fetchCcusageCosts()` and `fetchBlockInfo()` to use resolved path; skip calls when path is empty

## 2. Cache Preservation

- [x] 2.1 Modify `fetchCcusageCosts()`: only call `saveCache` when ccusage returns valid data (non-empty output with parsed cost)
- [x] 2.2 Modify `fetchBlockInfo()`: same treatment (already partially correct — returns nil on failure, but verify no zero-value save)

## 3. Session Cost Display

- [x] 3.1 Add session cost formatting to line 2: `Today: $X.XX (session: $Y.YY)` when both available, `Session: $Y.YY` when only session cost
- [x] 3.2 Use `data.Cost.TotalCostUSD` from Claude Code JSON input

## 4. Verification

- [x] 4.1 Build locally and test with `echo '<json>' | statusline.exe`
- [x] 4.2 Verify cache file is NOT overwritten when ccusage is unavailable
