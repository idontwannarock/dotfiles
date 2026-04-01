## REMOVED Requirements

### Requirement: Display today's total cost from ccusage
**Reason**: User no longer wants today total cost. Session cost from JSON stdin replaces this.
**Migration**: Use `cost.total_cost_usd` from JSON stdin for per-session cost display (defined in statusline-native-data spec).
