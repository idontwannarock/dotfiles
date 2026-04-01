## ADDED Requirements

### Requirement: team.md 包含 filter ID
team.md 的每位成員 SHALL 使用格式 `<!-- jira: {account_id} | filter: {filter_id} -->`。Display name 不再包含。

#### Scenario: Parse team.md 抽取 filter ID
- **WHEN** workflow 讀取 team.md
- **THEN** 每位成員 SHALL 抽取出 `name`、`jira_id`、`filter_id` 三個欄位

#### Scenario: 成員缺少 filter ID
- **WHEN** team.md 中某成員的 comment 不包含 `filter:` 欄位
- **THEN** workflow SHALL 對該成員輸出 warning 並跳過查詢（不中斷其他成員）

### Requirement: 用 Saved Filter 查詢 active tickets
Workflow SHALL 對每位成員使用 JQL `filter = {filterId}` 查詢 active tickets，取代 inline Dev PIC/assignee JQL。

#### Scenario: 正常查詢
- **WHEN** workflow 對成員執行 Jira 查詢
- **THEN** SHALL 使用 `filter = {filterId}` 作為唯一 JQL，不加額外 status 過濾

#### Scenario: Filter 查詢失敗
- **WHEN** Jira API 回傳 HTTP 4xx/5xx
- **THEN** workflow SHALL 對該成員輸出 warning，將空結果寫入（不覆蓋現有 Comment #1 的 jira-section），並繼續處理其他成員

### Requirement: 不再讀取 atlassian-config.md 的 custom field
Workflow SHALL 移除對 `atlassian-config.md` 中 Dev PIC / Test PIC field ID 的讀取。Cloud ID 仍需讀取（Jira API base URL 需要）。

#### Scenario: Workflow 不依賴 custom field
- **WHEN** workflow 執行
- **THEN** SHALL 不讀取 Dev PIC field 或 Test PIC field，也不在 JQL 中使用 `cf[...]` 語法
