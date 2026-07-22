## MODIFIED Requirements

### Requirement: Workflow Registry
Claude SHALL 維護 `~/.agent/workflow-registry.md`，記錄各 repo 的主 repo 路徑與對應的 project memory 路徑。此檔案各機器獨立，不透過 dotfiles 同步。格式為：

| Repo | Main Repo Path | Project Memory Path |
|------|----------------|---------------------|

#### Scenario: 首次在 repo 開啟 OpenSpec 流程
- **WHEN** Claude 在某 repo 開始 OpenSpec 流程，且 registry 中無該 repo 紀錄
- **THEN** Claude SHALL 用 `git rev-parse --git-common-dir` 推導主 repo 路徑，算出 project memory 路徑，自動新增到 registry

#### Scenario: 在 worktree 中查詢 registry
- **WHEN** Claude 當前在某 worktree 中
- **THEN** Claude SHALL 透過 `git rev-parse --git-common-dir` 找到主 repo，查 registry 取得正確的 project memory 路徑

### Requirement: Active Workflows Index
每個 repo 的 active-workflows 索引 SHALL 位於 `~/.agent/workflows/<repo-slug>/active_workflows.md`（`<repo-slug>` 由 `git rev-parse --git-common-dir` slugify 而得），記錄該 repo 所有進行中的 OpenSpec 流程。此檔案各機器獨立，不透過 dotfiles 同步。Current Step 欄位 SHALL 使用 tool-neutral 的語義標籤（如 `apply-change done`、`review`），SHALL NOT 寫入任何工具專屬的 sigil'd skill token —— 此檔案跨工具共用，恢復工作的工具依自身 name-map 重新推導 token。

#### Scenario: 新流程開始
- **WHEN** 工作區（主 repo branch 或 worktree）建立後
- **THEN** Claude SHALL 在 `active_workflows.md` 新增一行，包含 change 名稱、branch、路徑、type、current step、status、last updated

#### Scenario: 流程步驟推進
- **WHEN** 每個 skill 完成時
- **THEN** Claude SHALL 更新該流程的 current step（tool-neutral 標籤）和 last updated

#### Scenario: 流程暫停
- **WHEN** 使用者要求暫停當前流程切換到另一個任務
- **THEN** Claude SHALL 將該流程 status 標註為 paused

#### Scenario: 流程完成
- **WHEN** `finish-branch` 完成後
- **THEN** Claude SHALL 從 `active_workflows.md` 移除該流程紀錄
