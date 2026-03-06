## ADDED Requirements

### Requirement: Calculate block timer from JSONL timestamps
The statusline SHALL calculate the current 5-hour block's elapsed and remaining time by scanning JSONL files for timestamps with token usage, identifying the block start as the point after a gap exceeding 5 hours.

#### Scenario: Active block found
- **WHEN** JSONL timestamps show continuous activity within the last 5 hours
- **THEN** the statusline displays remaining time as `⏱ Block: Xh Ym left`

#### Scenario: No recent activity
- **WHEN** the most recent JSONL timestamp is older than 5 hours
- **THEN** the block timer section is omitted

#### Scenario: Block start at first activity
- **WHEN** there is no gap exceeding 5 hours in the lookback window
- **THEN** the block start is the earliest timestamp found, floored to the hour

### Requirement: Approximate burn rate from today cost and block elapsed
The statusline SHALL calculate an approximate burn rate as `today_cost / block_elapsed_hours` when both values are available.

#### Scenario: Both today cost and block elapsed available
- **WHEN** today cost > 0 and block elapsed > 0
- **THEN** burn rate is displayed as `🔥 $X.XX/hr`

#### Scenario: Missing data
- **WHEN** today cost is unavailable or block elapsed is 0
- **THEN** burn rate section is omitted
