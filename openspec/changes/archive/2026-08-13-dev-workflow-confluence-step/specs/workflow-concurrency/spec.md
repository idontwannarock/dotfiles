## MODIFIED Requirements

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
- **AND** `Doc Target` SHALL 留空——此時不得詢問使用者

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
