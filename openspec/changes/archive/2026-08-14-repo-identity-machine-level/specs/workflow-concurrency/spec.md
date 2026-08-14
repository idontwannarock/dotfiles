## MODIFIED Requirements

### Requirement: Workflow Registry
Claude SHALL 維護 `~/.agent/workflow-registry.md`，記錄各 repo 的主 repo 路徑、對應的 active-workflows 索引路徑，以及該 repo 的團隊文件目標。此檔案各機器獨立，不透過 dotfiles 同步。格式為：

| Repo | Main Repo Path | Active Workflows Path | Doc Target |
|------|----------------|-----------------------|------------|

`Repo` 欄 SHALL 為該 repo 的正典 slug——其唯一定義見 `~/.agent/reference/repo-identity.md`，此處 SHALL NOT 複述該定義。`Active Workflows Path` 欄 SHALL 指向該 repo 的 `active_workflows.md`，SHALL NOT 填入 project memory 路徑（memory 路徑由 memory-hook 自行推導，不由 registry 承載）。

registry 的列 SHALL 只增不減：既有列 SHALL NOT 因流程結束、分支合併或例行清理而被移除。（會隨流程結束而移除的是 `active_workflows.md` 的列，兩者不同檔。）

`Doc Target` 欄 SHALL 為三態，且空白與 `none` 語意不同：

| 值 | 語意 |
|---|---|
| 空白 | 尚未詢問過該 repo |
| Confluence hub 頁的 URL 或 page ID | 該 repo 的團隊文件寫入此處 |
| `none` | 該 repo 明確不需要團隊文件 |

#### Scenario: 首次在 repo 開啟 OpenSpec 流程
- **WHEN** Claude 在某 repo 開始 OpenSpec 流程，且 registry 中無該 repo 紀錄
- **THEN** Claude SHALL 依 `~/.agent/reference/repo-identity.md` 的定義推導該 repo 的正典 slug 作為 `Repo` 欄，並填入該 slug 對應的 active-workflows 路徑，自動新增到 registry
- **AND** `Doc Target` SHALL 留空

#### Scenario: 在 worktree 中查詢 registry
- **WHEN** Claude 當前在某 worktree 中
- **THEN** Claude SHALL 依同一個正典 slug 定位該 repo 在 registry 的列，取得正確的 active-workflows 路徑

#### Scenario: registry 列不因流程結束而移除
- **WHEN** 某 repo 的流程完成、分支已合併，或使用者要求清理工作流程狀態
- **THEN** Claude SHALL 保留該 repo 在 registry 的列
- **AND** SHALL NOT 以「該 repo 目前無進行中流程」為由刪除該列

#### Scenario: 補寫 Doc Target
- **WHEN** 使用者對該 repo 的團隊文件目標做出答覆
- **THEN** Claude SHALL 將答覆寫入該 repo 的 `Doc Target` 欄（hub 頁的 URL/page ID，或 `none`）

#### Scenario: 同一 repo 的產物必須落在同一處
- **WHEN** 同一個 repo 被以不同形式的 key 記錄（裸 repo 名、缺前導字元的 slug、或任何非正典 slug）
- **THEN** 此 SHALL 視為缺陷而非風格差異——同一 repo 的 agent 產物會落在互相看不見的目錄，且失敗為靜默（寫得出、讀得到，只是讀不到其他寫入者的那些）
- **AND** 發現時 SHALL 將產物合併回正典 slug 對應的目錄，並修正 registry 的 `Repo` 欄

#### Scenario: 推導算式不得出現在此 spec
- **WHEN** 任何 requirement 或 scenario 需要提及正典 slug 如何推導
- **THEN** 該處 SHALL 指向 `~/.agent/reference/repo-identity.md`
- **AND** SHALL NOT 寫出算式本身或其任何部分片段——片段化的複本會與正典分歧，而分歧的症狀是目錄分裂，不是文字不一致

> 何時讀取 `Doc Target`、何時詢問使用者，屬流程行為，見 `workflow-instructions` 的「團隊文件目標的 lazy 詢問」。此處只定義欄位語意與寫入結果。

### Requirement: Active Workflows Index
每個 repo 的 active-workflows 索引 SHALL 位於 `~/.agent/workflows/<repo-slug>/active_workflows.md`，其中 `<repo-slug>` 為該 repo 的正典 slug（定義見 `~/.agent/reference/repo-identity.md`，此處 SHALL NOT 複述），記錄該 repo 所有進行中的 OpenSpec 流程。此檔案各機器獨立，不透過 dotfiles 同步。Current Step 欄位 SHALL 使用 tool-neutral 的語義標籤（如 `apply-change done`、`review`），SHALL NOT 寫入任何工具專屬的 sigil'd skill token —— 此檔案跨工具共用，恢復工作的工具依自身 name-map 重新推導 token。

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
