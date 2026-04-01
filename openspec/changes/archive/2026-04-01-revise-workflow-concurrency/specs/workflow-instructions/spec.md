## MODIFIED Requirements

### Requirement: 確認流程
收到實作任務時，Claude SHALL 一次詢問兩個項目：流程選擇（OpenSpec 小型 / OpenSpec 大型 / 不使用）與推進模式（逐步確認 / 自動推進）。推進模式適用於所有非瑣碎任務，不限於 OpenSpec 流程。

#### Scenario: 一次確認
- **WHEN** 收到非瑣碎的實作任務
- **THEN** Claude SHALL 在一個回合中同時詢問流程選擇和推進模式

#### Scenario: 瑣碎任務自動跳過
- **WHEN** 任務為改 typo、一行修改、簡單問答等瑣碎任務
- **THEN** Claude SHALL 跳過詢問，直接進行

### Requirement: 推進模式決定 opsx 指令
推進模式 SHALL 同時控制 skill 之間的暫停行為和 opsx artifact 產出方式。

#### Scenario: 自動推進
- **WHEN** 使用者選擇自動推進
- **THEN** Claude SHALL 使用 `opsx:propose` 一次產出所有 artifacts，且 skill 之間不暫停

#### Scenario: 逐步確認
- **WHEN** 使用者選擇逐步確認
- **THEN** Claude SHALL 使用 `opsx:new` + `opsx:continue` 逐步產出 artifacts，且每個 skill 結束後等使用者確認

### Requirement: OpenSpec 流程必須使用 worktree
所有 OpenSpec 流程（不分大小型）SHALL 在獨立 worktree 上進行。

#### Scenario: 開始 OpenSpec 流程
- **WHEN** 使用者確認要使用 OpenSpec 流程（小型或大型）
- **THEN** Claude SHALL 先執行 `git:sync`，再用 `superpowers:using-git-worktrees` 建立 worktree，然後才開始後續步驟

### Requirement: 小型核心流程
小型流程 SHALL 跳過 brainstorming 和 superpowers skills，由 opsx 直接處理設計。

#### Scenario: 小型流程步驟
- **WHEN** 選擇小型流程
- **THEN** 執行順序 SHALL 為：git:sync → superpowers:using-git-worktrees → ensure-openspec → opsx:propose 或 opsx:new+continue → opsx:apply → openspec validate → opsx:archive → git:commit → code:review-quick → 如需修正走新一輪 → 如不需修正 → superpowers:finishing-a-development-branch → git:clean-gone

### Requirement: 大型核心流程
大型流程 SHALL 包含完整的 superpowers skills。

#### Scenario: 大型流程步驟
- **WHEN** 選擇大型流程
- **THEN** 執行順序 SHALL 為：git:sync → superpowers:using-git-worktrees → ensure-openspec → superpowers:brainstorming → opsx:propose 或 opsx:new+continue → superpowers:writing-plans → opsx:apply → superpowers:verification-before-completion → openspec validate → opsx:archive → git:commit → code:review-full → 如需修正走新一輪 → 如不需修正 → superpowers:finishing-a-development-branch → git:clean-gone

### Requirement: Code review 必做
所有 OpenSpec 流程 SHALL 在 archive 後執行 code review。

#### Scenario: 小型流程 review
- **WHEN** 小型流程 archive 完成
- **THEN** Claude SHALL 執行 `code:review-quick`

#### Scenario: 大型流程 review
- **WHEN** 大型流程 archive 完成
- **THEN** Claude SHALL 執行 `code:review-full`

#### Scenario: Review 發現需要修正
- **WHEN** code review 結果需要修正
- **THEN** Claude SHALL 在同一 worktree 上從 opsx:propose 或 opsx:new 開始新一輪 change，產生完整的 proposal/design/specs/tasks

#### Scenario: Review 通過
- **WHEN** code review 通過不需修正
- **THEN** Claude SHALL 繼續執行 `superpowers:finishing-a-development-branch`

### Requirement: Git 整合行為
OpenSpec 流程中的 Git 操作 SHALL 遵循定義的整合行為，包含同步、merge、清理等時機。

#### Scenario: 流程開始前同步
- **WHEN** OpenSpec 流程開始
- **THEN** Claude SHALL 執行 `git:sync` 確保 main 是最新的（已在 worktree 上的 session 除外）

#### Scenario: Merge 前 rebase
- **WHEN** 執行 `superpowers:finishing-a-development-branch`
- **THEN** Claude SHALL 在 merge 前先 rebase main，有 conflict 暫停問使用者

#### Scenario: 清理分支
- **WHEN** merge 完成後
- **THEN** Claude SHALL 自動建議執行 `git:clean-gone` 清理已合併的本地分支與 worktree
