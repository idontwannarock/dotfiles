# workflow-concurrency

## MODIFIED Requirements

### Requirement: Active Workflows Index
每個 repo 的 project memory 下 SHALL 有 `active_workflows.md`,記錄該 repo 所有進行中的 OpenSpec 流程。

#### Scenario: 新流程開始
- **WHEN** 工作區(主 repo branch 或 worktree)建立後
- **THEN** Claude SHALL 在 `active_workflows.md` 新增一行,包含 change 名稱、branch、路徑、type、current step、status、last updated

#### Scenario: 流程步驟推進
- **WHEN** 每個 skill 完成時
- **THEN** Claude SHALL 更新該流程的 current step 和 last updated

#### Scenario: 流程暫停
- **WHEN** 使用者要求暫停當前流程切換到另一個任務
- **THEN** Claude SHALL 將該流程 status 標註為 paused

#### Scenario: 流程完成
- **WHEN** `finish-branch` 完成後
- **THEN** Claude SHALL 從 `active_workflows.md` 移除該流程紀錄
