# discipline-skills

## MODIFIED Requirements

### Requirement: worktree 與 finish-branch 雙架構支援
`worktree` 與 `finish-branch` SHALL 原生支援 normal 與 bare-worktree 兩種 repo 架構,依 ARCH 偵測自動選擇對應機制,不依賴外部 override 說明。

#### Scenario: normal 架構下建立工作區
- **WHEN** ARCH=normal 且需要新工作區
- **THEN** `worktree` SHALL 以最新的 `main` 為明確起點建立 worktree(命令含 `main` start-point),SHALL NOT 從當前 HEAD 分支

#### Scenario: bare-worktree 下建立工作區
- **WHEN** ARCH=bare-worktree 且需要新工作區
- **THEN** `worktree` SHALL 以 `git --git-dir=.bare worktree add -b <branch> <branch> main` 建立(目錄與 branch 同名,無強制前綴),並依 bare-worktree 的手動規則(autoMemoryDirectory key)解析 registry 後登記 active_workflows

#### Scenario: finish-branch 選項行為
- **WHEN** 使用者選擇 Keep 或 Push + PR(PR 尚未 merge)
- **THEN** `finish-branch` SHALL 保留 worktree 與 branch,SHALL NOT 移除 active_workflows row(僅更新 status/step)

#### Scenario: finish-branch 失敗中止
- **WHEN** merge/rebase 序列中任一命令失敗(含 `--ff-only` 失敗)
- **THEN** `finish-branch` SHALL 立即停止,SHALL NOT 執行後續 dispose 或 row 移除,並回報狀態

#### Scenario: bare-worktree 下收尾
- **WHEN** ARCH=bare-worktree 且執行 `finish-branch` 的本地 merge
- **THEN** SHALL rebase 後從 `main/` worktree 以 `--ff-only` merge;merge 確認完成後才處置 worktree 與 branch,全程不需查閱額外 override 文件

#### Scenario: Discard 確認 gate
- **WHEN** 使用者選擇 Discard(捨棄未 merge 的工作)
- **THEN** `finish-branch` SHALL 在執行 `git branch -D` 前再次向使用者確認
