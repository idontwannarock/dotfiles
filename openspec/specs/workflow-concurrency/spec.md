# workflow-concurrency Specification

## Purpose
定義 dev-workflow 的 per-repo 狀態載體:Workflow Registry(含各 repo 的路徑對應與團隊文件目標)、Active Workflows Index、以及 session 開始時的讀取行為。
## Requirements
### Requirement: Workflow Registry
Claude SHALL 維護 `~/.agent/workflow-registry.md`，記錄各 repo 的主 repo 路徑、對應的 project memory 路徑，以及該 repo 的團隊文件目標。此檔案各機器獨立，不透過 dotfiles 同步。格式為：

| Repo | Main Repo Path | Project Memory Path | Doc Target |
|------|----------------|---------------------|------------|

registry 的列 SHALL 只增不減：既有列 SHALL NOT 因流程結束、分支合併或例行清理而被移除。（會隨流程結束而移除的是 `active_workflows.md` 的列，兩者不同檔。）

`Doc Target` 欄 SHALL 為三態，且空白與 `none` 語意不同：

| 值 | 語意 |
|---|---|
| 空白 | 尚未詢問過該 repo |
| Confluence hub 頁的 URL 或 page ID | 該 repo 的團隊文件寫入此處 |
| `none` | 該 repo 明確不需要團隊文件 |

#### Scenario: 首次在 repo 開啟 OpenSpec 流程
- **WHEN** Claude 在某 repo 開始 OpenSpec 流程，且 registry 中無該 repo 紀錄
- **THEN** Claude SHALL 用 `git rev-parse --git-common-dir` 推導主 repo 路徑，算出 project memory 路徑，自動新增到 registry
- **AND** `Doc Target` SHALL 留空

#### Scenario: 在 worktree 中查詢 registry
- **WHEN** Claude 當前在某 worktree 中
- **THEN** Claude SHALL 透過 `git rev-parse --git-common-dir` 找到主 repo，查 registry 取得正確的 project memory 路徑

#### Scenario: registry 列不因流程結束而移除
- **WHEN** 某 repo 的流程完成、分支已合併，或使用者要求清理工作流程狀態
- **THEN** Claude SHALL 保留該 repo 在 registry 的列
- **AND** SHALL NOT 以「該 repo 目前無進行中流程」為由刪除該列

#### Scenario: 補寫 Doc Target
- **WHEN** 使用者對該 repo 的團隊文件目標做出答覆
- **THEN** Claude SHALL 將答覆寫入該 repo 的 `Doc Target` 欄（hub 頁的 URL/page ID，或 `none`）

> 何時讀取此欄、何時詢問使用者，屬流程行為，見 `workflow-instructions` 的「團隊文件目標的 lazy 詢問」。此處只定義欄位語意與寫入結果。

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

### Requirement: Session 開始時讀取 Active Workflows
每個 session 收到任務時，Claude SHALL 先讀取 `active_workflows.md`。

#### Scenario: Session 開始處理順序
- **WHEN** `active_workflows.md` 存在且有紀錄
- **THEN** Claude SHALL 先清理過期紀錄（worktree 路徑已不存在的），再將剩餘的進行中流程告知使用者，詢問要接手既有的還是開新的

#### Scenario: 沒有進行中的流程
- **WHEN** `active_workflows.md` 為空、不存在、或清理過期紀錄後無剩餘
- **THEN** Claude SHALL 正常進入確認流程

