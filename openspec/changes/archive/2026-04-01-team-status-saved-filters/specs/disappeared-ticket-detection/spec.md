## ADDED Requirements

### Requirement: 偵測從 filter 結果消失的 tickets
Workflow SHALL 比對 filter 查詢結果與 Comment #1 `<!-- jira-start -->` 區塊中的現有 Jira ticket keys，找出消失的 tickets。

#### Scenario: Ticket 從 active 消失
- **WHEN** Comment #1 包含 ticket KEY-123，但 filter 查詢結果中不包含 KEY-123
- **THEN** KEY-123 SHALL 被標記為消失，準備移到 Comment #2

#### Scenario: Comment #1 為空或首次執行
- **WHEN** Comment #1 的 jira-section 無既有 ticket keys（新 seed 或空白）
- **THEN** SHALL 不觸發消失偵測，僅寫入 filter 查詢結果

#### Scenario: Filter 查詢失敗時不觸發消失偵測
- **WHEN** 某成員的 filter 查詢失敗（API error）
- **THEN** SHALL 不對該成員執行消失偵測（避免把所有 active tickets 誤判為消失）

### Requirement: 批次查詢消失 tickets 的最終 status
消失的 tickets SHALL 用 `key IN (KEY-1, KEY-2, ...)` 一次 JQL 查詢取得最終 Jira status。

#### Scenario: 有消失的 tickets
- **WHEN** 偵測到 1 個或多個消失的 ticket keys
- **THEN** SHALL 用 `key IN (...)` 批次查詢，取得每張 ticket 的 `status.name` 和 `summary`

#### Scenario: 無消失的 tickets
- **WHEN** 偵測結果為空
- **THEN** SHALL 跳過批次查詢

#### Scenario: 批次查詢失敗
- **WHEN** `key IN (...)` 查詢回傳 API error
- **THEN** SHALL 輸出 warning，消失的 tickets 移到 Comment #2 時 status 標記為 `Unknown`

### Requirement: 移動消失 tickets 到 Comment #2
消失的 tickets SHALL 從 Comment #1 移除，並 append 到 Comment #2 的 `<!-- jira-start -->` 區塊。

#### Scenario: 正常移動
- **WHEN** ticket KEY-123 消失且最終 status 為 "Done"
- **THEN** Comment #2 的 jira-section SHALL append `- [done] KEY-123: {summary} — Done — {today_date}`

#### Scenario: 非 Done status 的消失 ticket
- **WHEN** ticket KEY-456 消失且最終 status 為 "Cancelled"
- **THEN** Comment #2 的 jira-section SHALL append `- [done] KEY-456: {summary} — Cancelled — {today_date}`

#### Scenario: 移動後 Comment #2 不再顯示 placeholder
- **WHEN** Comment #2 原本包含 `_No completed items yet._` 且有新 ticket 被移入
- **THEN** SHALL 移除 placeholder 文字
