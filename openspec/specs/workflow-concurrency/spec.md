### Requirement: Workflow Registry
Claude SHALL 維護 `~/.claude/workflow-registry.md`，記錄各 repo 的主 repo 路徑與對應的 project memory 路徑。此檔案各機器獨立，不透過 dotfiles 同步。格式為：

| Repo Name | Main Repo Path | Project Memory Path |
|-----------|---------------|---------------------|

#### Scenario: 首次在 repo 開啟 OpenSpec 流程
- **WHEN** Claude 在某 repo 開始 OpenSpec 流程，且 registry 中無該 repo 紀錄
- **THEN** Claude SHALL 用 `git rev-parse --git-common-dir` 推導主 repo 路徑，算出 project memory 路徑，自動新增到 registry

#### Scenario: 在 worktree 中查詢 registry
- **WHEN** Claude 當前在某 worktree 中
- **THEN** Claude SHALL 透過 `git rev-parse --git-common-dir` 找到主 repo，查 registry 取得正確的 project memory 路徑

### Requirement: Active Workflows Index
每個 repo 的 project memory 下 SHALL 有 `active_workflows.md`，記錄該 repo 所有進行中的 OpenSpec 流程。

#### Scenario: 新流程開始
- **WHEN** worktree 建立後
- **THEN** Claude SHALL 在主 repo 的 `active_workflows.md` 新增一行，包含 change 名稱、branch、worktree 路徑、current step、status、last updated

#### Scenario: 流程步驟推進
- **WHEN** 每個 skill 完成時
- **THEN** Claude SHALL 更新該流程的 current step 和 last updated

#### Scenario: 流程暫停
- **WHEN** 使用者要求暫停當前流程切換到另一個任務
- **THEN** Claude SHALL 將該流程 status 標註為 paused

#### Scenario: 流程完成
- **WHEN** `superpowers:finishing-a-development-branch` 完成後
- **THEN** Claude SHALL 從 `active_workflows.md` 移除該流程紀錄

### Requirement: Session 開始時讀取 Active Workflows
每個 session 收到任務時，Claude SHALL 先讀取 `active_workflows.md`。

#### Scenario: Session 開始處理順序
- **WHEN** `active_workflows.md` 存在且有紀錄
- **THEN** Claude SHALL 先清理過期紀錄（worktree 路徑已不存在的），再將剩餘的進行中流程告知使用者，詢問要接手既有的還是開新的

#### Scenario: 沒有進行中的流程
- **WHEN** `active_workflows.md` 為空、不存在、或清理過期紀錄後無剩餘
- **THEN** Claude SHALL 正常進入確認流程
