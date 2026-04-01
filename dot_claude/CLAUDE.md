# 全域指令

## 預設工作流程：OpenSpec + Superpowers

收到實作任務（新功能、bug 修復、重構、程式碼修改）時，**開始工作前**依序確認三件事：

### 第一步：確認流程

> 要使用 **OpenSpec + Superpowers** 流程嗎？

- **是**：進入第二步
- **否**：直接以標準方式進行
- **瑣碎任務**（改 typo、一行修改、簡單問答）：跳過詢問，直接進行

### 第二步：確認規模

根據任務複雜度建議並等使用者確認：

- **小型流程**（`opsx:ff`）：一次產生所有 artifact 後直接實作。適合範圍明確、改動不大的任務
- **大型流程**（`opsx:new` → `opsx:continue`）：逐步產生 artifact，每步可調整。適合複雜、需要多輪討論的任務

### 第三步：確認推進模式

- **逐步確認**：每個 skill 結束後等使用者說「繼續」再推進
- **自動推進**：做完一步直接下一步，只在關鍵點暫停

### 核心流程

三步確認完成後執行（`[ ]` 為可選步驟）：

**小型：**
```
[git:sync] → ensure-openspec → superpowers:brainstorming → opsx:ff → opsx:apply → [code:review-spec] → opsx:verify → opsx:archive → [git:commit → git:push]
```

**大型：**
```
[git:sync] → ensure-openspec → superpowers:brainstorming → opsx:new → opsx:continue（重複）→ superpowers:writing-plans → opsx:apply → [code:review-spec] → superpowers:verification-before-completion → opsx:verify → opsx:archive → [git:commit → git:push]
```

**使用 worktree 時：**
```
[git:sync] → superpowers:using-git-worktrees → ensure-openspec → ... → opsx:archive → git:commit → superpowers:finishing-a-development-branch → [git:clean-gone]
```

#### Git 整合行為

| 時機 | 操作 | 行為 |
|------|------|------|
| 流程開始前 | `git:sync` | 自動執行，確保在最新 main 上工作（feature branch 上除外） |
| `opsx:archive` 之後 | `git:commit` | 提議 commit，使用者確認後執行 |
| commit 之後 | `git:push` | 詢問是否 push（使用者可能想批次 commit） |
| `superpowers:finishing-a-development-branch` 之後 | `git:clean-gone` | 使用 worktree 時，自動建議清理已合併的本地分支 |

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
