## Context

The statusline binary (`claude/statusline/statusline.go`) is spawned by Claude Code as a child process. It calls `ccusage` CLI via `exec.Command("ccusage", ...)` for today's cost and block info. When Claude Code spawns the process, `.bun/bin` may not be in PATH, causing `ccusage` to silently fail. The `fetchCcusageCosts` function then saves `today: 0` to cache, overwriting any previous valid data.

Claude Code's JSON input already includes `cost.total_cost_usd` for the current session, but the statusline ignores it.

## Goals / Non-Goals

**Goals:**
- Make ccusage work reliably from the statusline process
- Show session cost from Claude Code JSON (always works)
- Never overwrite valid cache with zero-value data on failure

**Non-Goals:**
- Replacing ccusage entirely (still needed for cross-session "today" aggregation)
- Calling Anthropic API directly (like ccstatusline does — future work)
- Adding new widgets or TUI configuration

## Decisions

### 1. Resolve ccusage path at startup with fallback

Try `exec.LookPath("ccusage")` first. If it fails, check `~/.bun/bin/ccusage` (+ `.exe` on Windows). Cache the resolved path in a package-level variable. If neither works, set path to empty string and skip all ccusage calls.

**Why not hardcode the path?** Users may install ccusage via npm, bun, or other package managers. LookPath-first respects their setup.

### 2. Preserve stale cache on failure

When ccusage fails (returns empty or error), do NOT save `{today: 0}`. Keep the previous cache file. The display will show the last-known value, which is more useful than $0.00.

### 3. Show session cost from JSON input

Add `data.Cost.TotalCostUSD` to line 2. When today cost is available: `Today: $X.XX (session: $Y.YY)`. When unavailable: `Session: $Y.YY`.

## Risks / Trade-offs

- [Stale cache shows outdated value] → Acceptable; stale data > wrong zero. Cache TTL (60s) limits staleness once ccusage starts working.
- [Session cost resets on restart] → Expected behavior; it's per-session by design. Today cost from ccusage covers the aggregate.
