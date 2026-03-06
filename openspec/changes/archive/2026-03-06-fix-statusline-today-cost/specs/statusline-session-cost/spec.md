## ADDED Requirements

### Requirement: Display session cost from Claude Code JSON
The statusline SHALL display the current session's cost from the `cost.total_cost_usd` field in Claude Code's JSON input.

#### Scenario: Session cost with today cost available
- **WHEN** both session cost and today cost (from ccusage) are available
- **THEN** display format is `Today: $X.XX (session: $Y.YY)`

#### Scenario: Session cost without today cost
- **WHEN** session cost is available but ccusage today cost is not
- **THEN** display format is `Session: $Y.YY`

#### Scenario: Zero session cost
- **WHEN** session cost is 0.00
- **THEN** session cost is still displayed as `$0.00`
