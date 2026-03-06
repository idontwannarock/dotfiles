## Why

Statusline's "Today" cost always shows $0.00 because `ccusage` CLI fails silently when Claude Code spawns the statusline process (likely PATH issue). The `runCommand` function swallows errors and saves `today: 0` to cache, overwriting any previous valid data.

## What Changes

- Add robust `ccusage` path resolution with fallback to `~/.bun/bin/ccusage(.exe)`
- Stop saving zero-value cache when `ccusage` fails — preserve stale cache instead
- Show current session cost from Claude Code's JSON input (`cost.total_cost_usd`) as always-available supplement
- Display format: `Today: $X.XX (session: $Y.YY)` when ccusage works, `Session: $Y.YY` when it doesn't

## Capabilities

### New Capabilities

- `statusline-ccusage-resolution`: Robust ccusage binary path resolution with fallback locations and cached result
- `statusline-session-cost`: Display current session cost from Claude Code JSON data as fallback/supplement to today cost

### Modified Capabilities

- `statusline-release`: Changes to statusline.go output format and ccusage invocation logic

## Impact

- `claude/statusline/statusline.go` — main changes
- No new dependencies; reduces fragility of existing `ccusage` dependency
- Output format changes (line 2 cost section) — cosmetic, no breaking changes
