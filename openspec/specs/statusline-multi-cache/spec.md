## ADDED Requirements

### Requirement: Multi-layer cache with TTL
The statusline SHALL use a two-layer cache: in-process memory cache and persistent file cache with per-source TTL.

#### Scenario: File cache hit within TTL
- **WHEN** cached data exists and is within its TTL
- **THEN** the cached value is used without fetching from the data source

#### Scenario: File cache expired
- **WHEN** cached data exists but is beyond its TTL
- **THEN** a background fetch is initiated and the stale cached value is used for display

#### Scenario: Cache TTL per source
- **WHEN** different data sources have different update frequencies
- **THEN** ccusage costs use 60s TTL, block timer uses 30s TTL, token speed uses 15s TTL
