# 全域指令

## 預設工作流程：OpenSpec + Superpowers

收到實作任務（新功能、bug 修復、重構、程式碼修改）時，**開始工作前一次確認**：

> 1. 流程：**OpenSpec 小型** / **OpenSpec 大型** / **不使用**（瑣碎任務自動跳過）
> 2. 推進模式：**逐步確認** / **自動推進**（僅 OpenSpec 流程適用）

- **OpenSpec 小型**：範圍明確、改動不大的任務
- **OpenSpec 大型**：複雜、需要多輪討論的任務
- **不使用**：直接以標準方式進行
- **瑣碎任務**（改 typo、一行修改、簡單問答）：跳過詢問，直接進行
- **逐步確認**：每個 skill 結束後等使用者說「繼續」再推進
- **自動推進**：做完一步直接下一步，只在關鍵點暫停

### 核心流程

所有 OpenSpec 流程一律在獨立 worktree 上進行。推進模式決定 opsx 指令：**自動推進**用 `opsx:propose`，**逐步確認**用 `opsx:new` + `opsx:continue`。

**小型流程：**
```
git:sync → superpowers:using-git-worktrees → ensure-openspec
→ opsx:propose 或 opsx:new+continue
→ opsx:apply → openspec validate → opsx:archive
→ git:commit → code:review-quick
→ 如需修正 → 根據問題複雜度確認規模，新一輪 change（同 worktree，從 opsx 開始）
→ 如不需修正 → superpowers:finishing-a-development-branch → [git:clean-gone]
```

**大型流程：**
```
git:sync → superpowers:using-git-worktrees → ensure-openspec
→ superpowers:brainstorming
→ opsx:propose 或 opsx:new+continue
→ superpowers:writing-plans → opsx:apply
→ superpowers:verification-before-completion → openspec validate → opsx:archive
→ git:commit → code:review-full
→ 如需修正 → 根據問題複雜度確認規模，新一輪 change（同 worktree，從 opsx 開始）
→ 如不需修正 → superpowers:finishing-a-development-branch → [git:clean-gone]
```

#### Git 整合行為

| 時機 | 操作 | 行為 |
|------|------|------|
| 流程開始前 | `git:sync` | 自動執行，確保 main 是最新的（已在 worktree 上的 session 除外） |
| worktree 建立後 | 更新 registry + active workflows | 自動執行（見多流程並行管理） |
| `opsx:archive` 之後 | `git:commit` | 提議 commit，使用者確認後執行 |
| code review 通過後 | `superpowers:finishing-a-development-branch` | merge 前先 rebase main，有 conflict 暫停問使用者 |
| merge 完成後 | `git:clean-gone` | 自動建議清理已合併的本地分支與 worktree |
| 流程完成後 | 更新 active workflows | 移除該流程紀錄 |

### 多流程並行管理

所有 OpenSpec 流程在獨立 worktree 上進行，支援同一 repo 同時推進多個流程。

#### Workflow Registry

`~/.claude/workflow-registry.md` 記錄各 repo 的主 repo 路徑與對應的 project memory 路徑。各機器獨立維護，不同步。

| Repo Name | Main Repo Path | Project Memory Path |
|-----------|---------------|---------------------|

流程開始時，Claude 讀取 registry 找到對應的 project memory 路徑。如果沒有紀錄，用 `git rev-parse --git-common-dir` 推導主 repo 路徑，算出 project memory 路徑，自動新增到 registry。

#### Active Workflows Index

每個 repo 的 project memory 下維護 `active_workflows.md`（`type: project`），記錄所有進行中的流程：

| Change | Branch | Worktree Path | Current Step | Status | Last Updated |
|--------|--------|---------------|--------------|--------|--------------|

**更新時機：**

| 事件 | 動作 |
|------|------|
| worktree 建立後 | 新增一行 |
| 每個 skill 完成時 | 更新 Current Step + Last Updated |
| 暫停切換到另一個流程時 | Status 標註 paused |
| 流程完成（finishing-a-development-branch 後） | 移除該行 |

**Session 開始行為：**

每個 session 收到任務時，先讀 `active_workflows.md`：
1. 先清理過期紀錄（worktree 路徑已不存在的）
2. 有剩餘進行中的流程 → 告知使用者，詢問要接手既有的還是開新的
3. 沒有 → 正常進入確認流程

### Spec 文件位置

Superpowers brainstorming 產生的 design spec **不要**寫到 `docs/superpowers/specs/`。Design 在對話中確認即可，正式 spec 交由 opsx（`opsx:propose` 或 `opsx:new`）產生到 `openspec/` 目錄下。

### 可選擴充

以下 skills 視情況自動引入：`superpowers:test-driven-development`、`superpowers:systematic-debugging`、`superpowers:using-git-worktrees`、`superpowers:requesting-code-review` 等。

Code review 指令：`code:review-quick`（快速）、`code:review-full`（完整 4 agent）、`code:review-spec`（需求對齊）、`code:review-linus`（架構）、`code:review-security`（安全）、`code:review-types`（型別）。

> 完整清單與使用情境：讀取 `~/.claude/reference.md`

## Worklog 記錄

Worklog repo: `idontwannarock/worklogs`（所有 worklog skill 共用此值，不需額外設定檔）

當以下情況發生時，主動問使用者是否要記到 worklog：
- 完成有意義的任務且已 commit
- 對話中累積多個 commit 後（批次提議一次，不在連續 commit 過程中打斷）
- 技術探索、設計討論得出明確結論或決策
- 使用者發出結束信號（「差不多了」「先這樣」等）且本次有實質成果

不要在以下情況觸發：
- 瑣碎修改（typo、格式調整）
- 使用者已經在 worklog repo 裡工作（避免重複）
- 連續 commit 過程中（等收尾再問）
- 純粹問答、查資料，沒有實質產出

記錄方式：呼叫 `/worklog:record` skill（寫到 GitHub Issue Comment）。

可用的 worklog skills：
- `/worklog:record` — 記錄工作項目到 Issue Comment（涵蓋筆記、行政、OKR 等）
- `/worklog:daily` — 管理今日待辦（寫 `[daily-todo]`/`[daily-done]` 到 daily Issue）
- `/worklog:team-status` — 觸發 workflow 更新 per-member issues 並呈現團隊狀態

已移除的 skills（功能由 GitHub Actions workflow 或 record 取代）：
`worklog:start`、`worklog:end`、`worklog:plan`、`worklog:notes`、`worklog:team`、`worklog:okr`、`worklog:admin`、`worklog:tidy`、`worklog:move`

## Episodic Memory 使用規則

- 探索性搜尋（「有沒有討論過 X」）→ 用 `search-conversations` agent（subagent 處理，保護主 context）
- 精確提取（已知要找什麼）→ 可直接呼叫 `search`，但 `show`/`read` 必須用 pagination（`startLine`/`endLine`），單次不超過 50 行
- 禁止無 pagination 的 `show`/`read` 呼叫
