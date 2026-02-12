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
[git:sync] → ensure-openspec → sp:brainstorm → opsx:ff → opsx:apply → opsx:verify → opsx:archive → [git:commit → git:push]
```

**大型：**
```
[git:sync] → ensure-openspec → sp:brainstorm → opsx:new → opsx:continue（重複）→ sp:plan → opsx:apply → sp:verify → opsx:verify → opsx:archive → [git:commit → git:push]
```

**使用 worktree 時：**
```
[git:sync] → sp:worktree → ensure-openspec → ... → opsx:archive → git:commit → sp:finish → [git:clean-gone]
```

#### Git 整合行為

| 時機 | 操作 | 行為 |
|------|------|------|
| 流程開始前 | `git:sync` | 自動執行，確保在最新 main 上工作（feature branch 上除外） |
| `opsx:archive` 之後 | `git:commit` | 提議 commit，使用者確認後執行 |
| commit 之後 | `git:push` | 詢問是否 push（使用者可能想批次 commit） |
| `sp:finish` 之後 | `git:clean-gone` | 使用 worktree 時，自動建議清理已合併的本地分支 |

### 可選擴充

以下技能視情況自動引入，不需要使用者手動觸發：

| 技能 | 簡寫 | 觸發時機 |
|------|------|----------|
| `using-git-worktrees` | `sp:worktree` | 需要隔離工作區時（大型任務、避免影響主分支） |
| `subagent-driven-development` | `sp:subagent` | 任務間互相獨立、可平行處理時 |
| `dispatching-parallel-agents` | `sp:parallel` | 多個不相關任務需同時進行時 |
| `test-driven-development` | `sp:tdd` | 實作功能或修 bug 時，強制 RED→GREEN→REFACTOR |
| `systematic-debugging` | `sp:debug` | 遇到 bug、測試失敗、非預期行為時 |
| `requesting-code-review` | `sp:review` | 完成實作後、merge 前 |
| `receiving-code-review` | `sp:recv-review` | 收到 code review 回饋時 |
| `finishing-a-development-branch` | `sp:finish` | 實作完成、測試通過，決定 merge/PR/保留/丟棄 |
