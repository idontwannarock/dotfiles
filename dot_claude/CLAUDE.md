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
