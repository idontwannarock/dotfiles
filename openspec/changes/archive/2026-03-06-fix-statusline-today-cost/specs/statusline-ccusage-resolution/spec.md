## ADDED Requirements

### Requirement: Resolve ccusage binary path with fallback
The statusline SHALL resolve the `ccusage` binary path at startup using a multi-step lookup: first `exec.LookPath`, then platform-specific fallback paths (`~/.bun/bin/ccusage` or `~/.bun/bin/ccusage.exe`). The resolved path SHALL be cached in a package-level variable for reuse.

#### Scenario: ccusage found via LookPath
- **WHEN** `exec.LookPath("ccusage")` succeeds
- **THEN** the resolved absolute path is used for all ccusage invocations

#### Scenario: ccusage found via fallback path
- **WHEN** `exec.LookPath("ccusage")` fails but `~/.bun/bin/ccusage(.exe)` exists
- **THEN** the fallback path is used for all ccusage invocations

#### Scenario: ccusage not found anywhere
- **WHEN** neither LookPath nor fallback paths find ccusage
- **THEN** all ccusage-dependent features are skipped (no error, no zero-value cache)

### Requirement: Preserve stale cache on ccusage failure
When ccusage invocation fails or returns empty output, the statusline SHALL NOT overwrite existing cache files. Previous cached values SHALL be preserved.

#### Scenario: ccusage fails with existing cache
- **WHEN** ccusage returns empty output and a cached cost file exists with `today: 39.99`
- **THEN** the cache file retains `today: 39.99` and the display shows the cached value

#### Scenario: ccusage fails with no prior cache
- **WHEN** ccusage returns empty output and no cache file exists
- **THEN** no cache file is created and the today cost section is omitted from output
