## REMOVED Requirements

### Requirement: Generic cache with TTL
**Reason**: Cache system existed for ccusage (60s TTL) and block timer (30s TTL). Both are removed. Remaining operations (git, process count) execute fast enough without caching.
**Migration**: No replacement. Remove `loadCache`, `saveCache`, `cacheDir`, and all cache-related types.

### Requirement: Stale cache fallback on timeout
**Reason**: No longer needed without ccusage and JSONL scanning.
**Migration**: No replacement.

### Requirement: Parallel async cache refresh with timeout
**Reason**: Simplified to basic goroutine parallelism for git and process count only. No cache refresh needed.
**Migration**: Retain goroutine pattern for `countClaudeProcesses` and `getGitInfo` but remove cache layer.
