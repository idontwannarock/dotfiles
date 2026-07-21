# workflow-instructions

## MODIFIED Requirements

### Requirement: OpenSpec 流程必須使用 worktree
OpenSpec 流程需要隔離時 SHALL 使用自家 `worktree` skill 建立獨立工作區;無其他 active workflow 時得直接在主 repo 開 branch。

#### Scenario: 開始 OpenSpec 流程
- **WHEN** 使用者確認要使用 OpenSpec 流程且存在其他 active/paused workflow
- **THEN** Claude SHALL 先執行 `git:sync`,再用 `worktree` skill 建立工作區,然後才開始後續步驟

### Requirement: 小型核心流程
小型流程 SHALL 跳過 grill,由 opsx 直接處理設計。

#### Scenario: 小型流程步驟
- **WHEN** 選擇小型流程
- **THEN** 執行順序 SHALL 為:ensure-openspec → openspec-new-change → openspec-continue-change(loop)→ openspec-apply-change → openspec validate → [openspec-sync-specs] → openspec-archive-change → git:commit → code:review-surgical → 如需修正走新一輪 → 如不需修正 → finish-branch → [git:clean-gone]

### Requirement: 大型核心流程
大型流程 SHALL 以 grill 開場收斂共識,並在實作與收尾套用紀律 skills。

#### Scenario: 大型流程步驟
- **WHEN** 選擇大型流程
- **THEN** 執行順序 SHALL 為:ensure-openspec → grill → openspec-new-change → openspec-continue-change → openspec-apply-change(可測 seam 套 tdd)→ verify-done → openspec-verify-change → openspec validate → openspec-sync-specs → openspec-archive-change → git:commit → code:review-comprehensive → 如需修正走新一輪 → 如不需修正 → finish-branch → [git:clean-gone]

### Requirement: Code review 必做
所有 OpenSpec 流程 SHALL 在 archive 後執行 code review。

#### Scenario: 小型流程 review
- **WHEN** 小型流程 archive 完成
- **THEN** Claude SHALL 執行 `code:review-surgical`

#### Scenario: 大型流程 review
- **WHEN** 大型流程 archive 完成
- **THEN** Claude SHALL 執行 `code:review-comprehensive`

#### Scenario: Review 發現需要修正
- **WHEN** code review 結果需要修正
- **THEN** Claude SHALL 根據問題複雜度建議流程規模(小型或大型),使用者確認後在同一工作區從 openspec-new-change 開始新一輪 change

#### Scenario: Review 通過
- **WHEN** code review 通過不需修正
- **THEN** Claude SHALL 繼續執行 `finish-branch`

### Requirement: Git 整合行為
OpenSpec 流程中的 Git 操作 SHALL 遵循定義的整合行為,包含同步、merge、清理等時機。

#### Scenario: 流程開始前同步
- **WHEN** OpenSpec 流程開始
- **THEN** Claude SHALL 執行 `git:sync` 確保 main 是最新的(已在 worktree 上的 session 除外)

#### Scenario: Merge 前 rebase
- **WHEN** 執行 `finish-branch`
- **THEN** Claude SHALL 在 merge 前先 rebase main,有 conflict 暫停問使用者

#### Scenario: 清理分支
- **WHEN** merge 完成後
- **THEN** Claude SHALL 自動建議執行 `git:clean-gone` 清理已合併的本地分支與 worktree

## ADDED Requirements

### Requirement: Bug 任務進入點
收到修 bug 或效能退化任務時,Claude SHALL 先以 `diagnose` 完成根因診斷,再進入流程選擇;診斷出的根因 SHALL 成為該 change proposal.md 的 `## Why` 依據。

#### Scenario: bug 任務先診斷
- **WHEN** 收到修 bug 任務
- **THEN** Claude SHALL 先執行 `diagnose` 取得根因,才詢問 Small / Large / Skip

### Requirement: tasks.md 切片慣例
撰寫 tasks.md 時,Claude SHALL 遵循切片慣例:每個 task 為 tracer-bullet 垂直切片(窄但完整穿過所有層)、每片大小以一個 fresh context window 能完成為度、依賴以 blocked by 標明、大範圍 refactor 以 expand–contract 排序。

#### Scenario: 產出 tasks.md
- **WHEN** openspec-continue-change 產出 tasks.md
- **THEN** task 切分 SHALL 符合上述慣例,SHALL NOT 按層橫切
