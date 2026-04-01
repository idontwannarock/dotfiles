## REMOVED Requirements

### Requirement: Calculate block timer from JSONL timestamps
**Reason**: Replaced by `rate_limits.five_hour` from Claude Code JSON stdin, which provides the same information natively.
**Migration**: Use `rate_limits.five_hour.used_percentage` and `resets_at` fields from JSON stdin.

### Requirement: Approximate burn rate from today cost and block elapsed
**Reason**: Today cost display removed by user request; block timer replaced by native rate limits.
**Migration**: No replacement needed.
