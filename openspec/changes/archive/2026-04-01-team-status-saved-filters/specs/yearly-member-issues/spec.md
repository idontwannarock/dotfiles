## ADDED Requirements

### Requirement: Member issue title 包含年份
Per-member issue 的 title SHALL 使用格式 `Team: {Name} ({Year})`，其中 Year 為台北時區的當前年份。

#### Scenario: 建立新 member issue
- **WHEN** workflow 為成員建立新 issue
- **THEN** title SHALL 為 `Team: {Name} ({Year})`（例如 `Team: Lily (2026)`）

#### Scenario: 查詢現有 member issue
- **WHEN** workflow 查詢成員的 per-member issue
- **THEN** SHALL 比對 `Team: {Name} ({Year})` 格式，只匹配當前年份的 issue

#### Scenario: 上一年度 issue 不被匹配
- **WHEN** 存在 `Team: Lily (2025)` 和 `Team: Lily (2026)` 兩個 open issues
- **THEN** SHALL 只匹配 `Team: Lily (2026)`

### Requirement: 清理重建現有 issues
部署前 SHALL close 現有不帶年份的 per-member issues (#23-#26)。新 workflow 首次執行時自動建立帶年份的新 issues。

#### Scenario: 首次執行無匹配 issue
- **WHEN** workflow 查詢 `Team: Lily (2026)` 找不到 open issue
- **THEN** SHALL 建立新 issue 並 seed Comment #1（Active Tasks）和 Comment #2（Completed）

#### Scenario: Seed comment 格式
- **WHEN** workflow 為新 issue seed comments
- **THEN** Comment #1 SHALL 包含 `## Active Tasks`、`<!-- jira-start/end -->` markers、`### Manual Tasks` section
- **AND** Comment #2 SHALL 包含 `## Completed`、`<!-- jira-start/end -->` markers、`### Manual Completed` section
