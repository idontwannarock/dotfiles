# statusline-native-data Specification

## Purpose
規範 statusline 改用原生資料來源呈現 context 百分比、5 小時/7 天 rate limit、session 成本與時長、worktree 資訊與第二行佈局。

## Requirements

### Requirement: Use native context window percentage
The statusline SHALL use `context_window.used_percentage` from JSON stdin instead of manually calculating from token counts. When `used_percentage` is null, the statusline SHALL fall back to 0.

#### Scenario: Normal context display
- **WHEN** JSON stdin contains `context_window.used_percentage` of 42
- **THEN** the statusline displays `42%` with the corresponding progress bar

#### Scenario: Null percentage early in session
- **WHEN** `context_window.used_percentage` is null
- **THEN** the statusline displays `0%` with an empty progress bar

### Requirement: Display 5-hour rate limit from native data
The statusline SHALL display `rate_limits.five_hour.used_percentage` as `5h: X%`. When usage ≥ 80%, the statusline SHALL append the reset time formatted as local HH:MM (from `resets_at` Unix epoch).

#### Scenario: Normal 5-hour rate limit
- **WHEN** `rate_limits.five_hour.used_percentage` is 23.5
- **THEN** the statusline displays `5h: 24%`

#### Scenario: High 5-hour usage with reset time
- **WHEN** `rate_limits.five_hour.used_percentage` is 85 and `resets_at` corresponds to 14:30 local time
- **THEN** the statusline displays `5h: 85% ⟳14:30`

#### Scenario: Rate limits absent
- **WHEN** `rate_limits` field is not present in JSON stdin
- **THEN** the rate limit section is omitted from the statusline

### Requirement: Display 7-day rate limit from native data
The statusline SHALL display `rate_limits.seven_day.used_percentage` as `7d: X%`. When usage ≥ 80%, the statusline SHALL append the reset time. If reset is within today, format as HH:MM; otherwise format as abbreviated weekday (e.g., `Mon`).

#### Scenario: Normal 7-day rate limit
- **WHEN** `rate_limits.seven_day.used_percentage` is 41.2
- **THEN** the statusline displays `7d: 41%`

#### Scenario: High 7-day usage with reset on another day
- **WHEN** `rate_limits.seven_day.used_percentage` is 92 and `resets_at` corresponds to next Monday
- **THEN** the statusline displays `7d: 92% ⟳Mon`

### Requirement: Display session cost from native data
The statusline SHALL display `cost.total_cost_usd` from JSON stdin as `💰 $X.XX` on the second line when the value is greater than 0.

#### Scenario: Session with cost
- **WHEN** `cost.total_cost_usd` is 0.15
- **THEN** the statusline displays `💰 $0.15`

#### Scenario: Zero cost
- **WHEN** `cost.total_cost_usd` is 0
- **THEN** the cost section is omitted

### Requirement: Use native session duration
The statusline SHALL use `cost.total_duration_ms` from JSON stdin to display session duration instead of parsing `session.start_time`.

#### Scenario: Duration under one hour
- **WHEN** `cost.total_duration_ms` is 720000 (12 minutes)
- **THEN** the statusline displays `⏱ 12m`

#### Scenario: Duration over one hour
- **WHEN** `cost.total_duration_ms` is 5520000 (1 hour 32 minutes)
- **THEN** the statusline displays `⏱ 1h32m`

### Requirement: Display worktree information
The statusline SHALL display worktree name on the first line after the directory name when the `worktree` field is present in JSON stdin.

#### Scenario: Active worktree
- **WHEN** `worktree.name` is "my-feature"
- **THEN** the statusline displays `🌿my-feature` after the directory name

#### Scenario: No worktree
- **WHEN** `worktree` field is absent
- **THEN** no worktree indicator is shown

### Requirement: Second line layout
The second line SHALL display sections in this order, separated by ` │ `: session info, session cost, rate limits. Each section is optional and omitted when data is unavailable.

#### Scenario: Full second line
- **WHEN** all data is available with session ID `abc12345`, duration 12m, 2 active sessions, cost $0.15, 5h at 23%, 7d at 41%
- **THEN** the statusline displays `#abc12345 ⏱ 12m [2] │ 💰 $0.15 │ ⏳ 5h: 23% │ 7d: 41%`

#### Scenario: Minimal second line
- **WHEN** only session ID and duration are available, single session, no cost, no rate limits
- **THEN** the statusline displays `#abc12345 ⏱ 0m`
