## REMOVED Requirements

### Requirement: Resolve ccusage binary path
**Reason**: ccusage CLI is no longer needed. Today cost display removed; session cost comes from JSON stdin `cost.total_cost_usd`.
**Migration**: No replacement needed. Remove `resolveCcusagePath`, `ccusagePath` global, and `fetchCcusageCosts`.

### Requirement: Fallback ccusage path resolution
**Reason**: ccusage CLI dependency entirely removed.
**Migration**: No replacement needed.
