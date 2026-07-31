# workflow-instructions Specification

## Purpose
規範 dev-workflow 核心流程指令:確認流程、worktree 要求、大小型流程、code review、git 整合、文件語言、bug 進入點與 tasks.md 切片慣例。
## Requirements
### Requirement: 確認流程
收到實作任務時，Claude SHALL 詢問流程選擇：OpenSpec 小型（Small）/ OpenSpec 大型（Large）/ 不使用（Skip）。

#### Scenario: 一次確認
- **WHEN** 收到非瑣碎的實作任務
- **THEN** Claude SHALL 在一個回合中詢問流程選擇

#### Scenario: 瑣碎任務自動跳過
- **WHEN** 任務為改 typo、一行修改、簡單問答等瑣碎任務
- **THEN** Claude SHALL 跳過詢問，直接進行

### Requirement: OpenSpec 流程必須使用 worktree
OpenSpec 流程需要隔離時 SHALL 使用自家 `worktree` skill 建立獨立工作區;無其他 active workflow 時得直接在主 repo 開 branch。

#### Scenario: 開始 OpenSpec 流程
- **WHEN** 使用者確認要使用 OpenSpec 流程且存在其他 active/paused workflow
- **THEN** Claude SHALL 先執行 `git:sync`,再用 `worktree` skill 建立工作區,然後才開始後續步驟

### Requirement: 小型核心流程
小型流程 SHALL 跳過 grill，由 openspec 直接處理設計。在 sync-specs/archive 階段,若 `design.md` 有標記的長青候選,SHALL 逐條對照實際 shipped 內容,將符合晉升閘門者晉升進 `context/`。

#### Scenario: 小型流程步驟
- **WHEN** 選擇小型流程
- **THEN** 執行順序 SHALL 為：ensure-openspec → openspec-new-change → openspec-continue-change（loop）→ openspec-apply-change → openspec validate → [openspec-sync-specs;此時晉升 design.md 的長青候選進 context/] → openspec-archive-change → git:commit → code:review-surgical → 如需修正走新一輪 → 如不需修正 → finish-branch → [git:clean-gone]

#### Scenario: 晉升長青候選
- **WHEN** 小型流程進行 sync-specs/archive 且 `design.md` 含 evergreen 候選標記
- **THEN** Claude SHALL 逐條對照實際實作,將反覆適用的原則/新 domain 詞彙晉升進 `context/` 下性質相符的 concept 檔,其餘 SHALL 留在 archived `design.md`

### Requirement: 大型核心流程
大型流程 SHALL 以 grill 開場收斂共識,並在實作與收尾套用紀律 skills。在 sync-specs/archive 階段,若 `design.md` 有標記的長青候選,SHALL 逐條對照實際 shipped 內容,將符合晉升閘門者晉升進 `context/`。

#### Scenario: 大型流程步驟
- **WHEN** 選擇大型流程
- **THEN** 執行順序 SHALL 為:ensure-openspec → grill → openspec-new-change → openspec-continue-change → openspec-apply-change(可測 seam 套 tdd)→ verify-done → openspec-verify-change → openspec validate → openspec-sync-specs（此時晉升 design.md 的長青候選進 context/）→ openspec-archive-change → git:commit → code:review-comprehensive → 如需修正走新一輪 → 如不需修正 → finish-branch → [git:clean-gone]

#### Scenario: 晉升長青候選
- **WHEN** 大型流程進行 sync-specs/archive 且 `design.md` 含 evergreen 候選標記
- **THEN** Claude SHALL 逐條對照實際實作,將反覆適用的原則/新 domain 詞彙晉升進 `context/` 下性質相符的 concept 檔,其餘 SHALL 留在 archived `design.md`

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
OpenSpec 流程中的 Git 操作 SHALL 遵循定義的整合行為，包含同步、merge、清理等時機。

#### Scenario: 流程開始前同步
- **WHEN** OpenSpec 流程開始
- **THEN** Claude SHALL 執行 `git:sync` 確保 main 是最新的（已在 worktree 上的 session 除外）

#### Scenario: Merge 前 rebase
- **WHEN** 執行 `finish-branch`
- **THEN** Claude SHALL 在 merge 前先 rebase main，有 conflict 暫停問使用者

#### Scenario: 清理分支
- **WHEN** merge 完成後
- **THEN** Claude SHALL 自動建議執行 `git:clean-gone` 清理已合併的本地分支與 worktree

### Requirement: 文件語言為中文
全域 CLAUDE.md 的內容 SHALL 以中文撰寫。

#### Scenario: 語言一致性
- **WHEN** 安裝腳本將 CLAUDE.md 部署到 ~/.claude/
- **THEN** 使用者看到的全域指令 SHALL 為中文

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
