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
小型流程 SHALL 跳過 grill，由 openspec 直接處理設計。在 sync-specs/archive 階段,若 `design.md` 有標記的長青候選,SHALL 逐條對照實際 shipped 內容,將符合晉升閘門者晉升進 `context/`。在 `finish-branch` 之前 SHALL 套用團隊文件記錄步驟的判準。

#### Scenario: 小型流程步驟
- **WHEN** 選擇小型流程
- **THEN** 執行順序 SHALL 為：ensure-openspec → openspec-new-change → openspec-continue-change（loop）→ openspec-apply-change → openspec validate → [openspec-sync-specs;此時晉升 design.md 的長青候選進 context/] → openspec-archive-change → git:commit → code:review-surgical → 如需修正走新一輪 → 如不需修正 → [團隊文件記錄步驟] → finish-branch → [git:clean-gone]

#### Scenario: 晉升長青候選
- **WHEN** 小型流程進行 sync-specs/archive 且 `design.md` 含 evergreen 候選標記
- **THEN** Claude SHALL 逐條對照實際實作,將反覆適用的原則/新 domain 詞彙晉升進 `context/` 下性質相符的 concept 檔,其餘 SHALL 留在 archived `design.md`

### Requirement: 大型核心流程
大型流程 SHALL 以 grill 開場收斂共識,並在實作與收尾套用紀律 skills。在 sync-specs/archive 階段,若 `design.md` 有標記的長青候選,SHALL 逐條對照實際 shipped 內容,將符合晉升閘門者晉升進 `context/`。review 關卡 SHALL 在 `code:review-comprehensive` 之後接續跨模型 adversarial review。在 `finish-branch` 之前 SHALL 套用團隊文件記錄步驟的判準。

#### Scenario: 大型流程步驟
- **WHEN** 選擇大型流程
- **THEN** 執行順序 SHALL 為:ensure-openspec → grill → openspec-new-change → openspec-continue-change → openspec-apply-change(可測 seam 套 tdd)→ verify-done → openspec-verify-change → openspec validate → openspec-sync-specs（此時晉升 design.md 的長青候選進 context/）→ openspec-archive-change → git:commit → code:review-comprehensive → code:review-cross-model → 如需修正走新一輪 → 如不需修正 → [團隊文件記錄步驟] → finish-branch → [git:clean-gone]

#### Scenario: 晉升長青候選
- **WHEN** 大型流程進行 sync-specs/archive 且 `design.md` 含 evergreen 候選標記
- **THEN** Claude SHALL 逐條對照實際實作,將反覆適用的原則/新 domain 詞彙晉升進 `context/` 下性質相符的 concept 檔,其餘 SHALL 留在 archived `design.md`

#### Scenario: 跨模型段不阻斷流程
- **WHEN** `code:review-cross-model` 因前置條件不滿足而未執行
- **THEN** 大型流程 SHALL 依既有 review 結果繼續,SHALL NOT 停在該步驟

### Requirement: Code review 必做
所有 OpenSpec 流程 SHALL 在 archive 後執行 code review。大型流程 SHALL 額外執行跨模型 adversarial review;小型流程 SHALL NOT 執行。

#### Scenario: 小型流程 review
- **WHEN** 小型流程 archive 完成
- **THEN** Claude SHALL 執行 `code:review-surgical`

#### Scenario: 小型流程不做跨模型 review
- **WHEN** 小型流程 archive 完成
- **THEN** Claude SHALL NOT 自動執行 `code:review-cross-model` —— 小型 change 的訊號密度不足以支撐該關卡,例行化會使其被學會忽略

#### Scenario: 大型流程 review
- **WHEN** 大型流程 archive 完成
- **THEN** Claude SHALL 執行 `code:review-comprehensive`,並接續執行 `code:review-cross-model`

#### Scenario: Review 發現需要修正
- **WHEN** code review 結果需要修正
- **THEN** Claude SHALL 根據問題複雜度建議流程規模(小型或大型),使用者確認後在同一工作區從 openspec-new-change 開始新一輪 change

#### Scenario: 跨模型分歧項的處置
- **WHEN** 跨模型 review 產出分歧項(僅單造提出且對造未表態)
- **THEN** Claude SHALL 將分歧項連同兩造理由呈給使用者裁決,SHALL NOT 逕自決定是否納入修正範圍

#### Scenario: Review 通過
- **WHEN** code review 通過不需修正
- **THEN** Claude SHALL 先套用團隊文件記錄步驟的判準,再繼續執行 `finish-branch`

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

### Requirement: 團隊文件記錄步驟
兩個核心流程 SHALL 在 review 迴圈收斂之後、`finish-branch` 之前，套用一條判準決定本次 change 是否應寫入團隊文件；判定為是時 SHALL 交由 `confluence-team-doc` 執行。此步驟 SHALL NOT 阻斷流程——任何退化、跳過或使用者否決，SHALL 一律以繼續執行 `finish-branch` 收場。

判準為單一問句：**repo 外的人若要回答這次產出的那個問題（怎麼操作 / 為什麼這樣設計），除了讀這份 diff 之外有沒有別的地方可讀？沒有 → 值得寫。** 判準 SHALL 綁「repo 外是否有讀者」，SHALL NOT 綁 diff 大小或流程規模。

當該 repo 的 `Doc Target` 為 `none` 時，此步驟 SHALL 為 no-op。引用此步驟的流程敘述 SHALL NOT 各自複製這項例外——例外由本 requirement 單處持有。

文件型別（ARCH / RUNBOOK / KB）的決定 SHALL 交由 `confluence-team-doc` 的 `doc-taxonomy` 規則，SHALL NOT 在流程說明中重述。

#### Scenario: 判定值得寫
- **WHEN** 本次 change 產出了 repo 外的人需要照著操作的程序，或會被 repo 外的人追問「為什麼這樣設計」的決策
- **THEN** Claude SHALL 提出寫入提案，包含判定理由與建議標題
- **AND** 是否寫入 SHALL 由使用者拍板

#### Scenario: 判定不值得寫
- **WHEN** 本次 change 的產出只有 repo 內的讀者（例如調整 skill 措辭、重構內部腳本）
- **THEN** Claude SHALL 直接進入 `finish-branch`
- **AND** SHALL NOT 輸出任何負面判定的說明——例行化的「本次不需要」提示會使此關卡被學會忽略

#### Scenario: 小型 change 仍可觸發
- **WHEN** 一個僅數行的 change 產出了別的團隊要照著操作的程序
- **THEN** Claude SHALL 判定值得寫
- **AND** SHALL NOT 以 change 規模小為由跳過

#### Scenario: 使用者否決
- **WHEN** Claude 提出寫入提案而使用者否決
- **THEN** Claude SHALL 直接進入 `finish-branch`，SHALL NOT 追問

#### Scenario: Doc Target 為 none 時此步驟為 no-op
- **WHEN** 流程抵達此步驟而該 repo 的 `Doc Target` 為 `none`
- **THEN** Claude SHALL 直接進入 `finish-branch`，SHALL NOT 套用判準、SHALL NOT 詢問、SHALL NOT 提案
- **AND** 流程敘述中「SHALL 套用判準」的措辭 SHALL 理解為受此例外限定，SHALL NOT 據以認定衝突

### Requirement: 團隊文件目標的 lazy 詢問
流程 SHALL 於既有的 registry 讀取步驟一併讀取該 repo 的 `Doc Target`，但 SHALL NOT 於該時點詢問使用者。詢問 SHALL 延遲到判準判定值得寫的那一刻。流程說明中執行 registry 讀取的那一步 SHALL 明列 `Doc Target` 為讀取項目之一，並 SHALL 於新增 registry 列時明示該欄留空——否則此 requirement 無可執行的依據。

#### Scenario: Doc Target 為空白且本次值得寫
- **WHEN** 判準判定值得寫，而該 repo 的 `Doc Target` 為空白
- **THEN** Claude SHALL 於此時詢問該 repo 的團隊文件目標（hub 頁，或明確不需要）
- **AND** SHALL 將答覆寫回 registry

#### Scenario: Doc Target 為 none
- **WHEN** 該 repo 的 `Doc Target` 為 `none`
- **THEN** Claude SHALL 跳過整個團隊文件步驟，SHALL NOT 詢問、SHALL NOT 提案

#### Scenario: 流程開始時不詢問
- **WHEN** 流程於 registry 讀取步驟發現 `Doc Target` 為空白
- **THEN** Claude SHALL 繼續流程，SHALL NOT 於此時詢問使用者

#### Scenario: 讀取步驟涵蓋 Doc Target
- **WHEN** 流程執行 registry 讀取步驟
- **THEN** 該步驟的說明 SHALL 將 `Doc Target` 列為讀取項目
- **AND** 該步驟新增 registry 列時 SHALL 產出 `Doc Target` 欄並留空

### Requirement: 團隊文件步驟的顯性退化
當執行前提不滿足時，此步驟 SHALL 明說原因並停下該步驟，SHALL NOT 靜默消失，亦 SHALL NOT 停下整條流程。各端能力與目標支援度的陳述 SHALL 出現在它所限制的執行指令**之前**，SHALL NOT 置於其後。

#### Scenario: 工具端無 Atlassian MCP
- **WHEN** 當前工具端沒有可用的 Atlassian MCP（例如 Codex 端）
- **THEN** 流程說明 SHALL 仍呈現此步驟的存在，並明說本端無對應能力、需於具備該能力的工具端執行
- **AND** SHALL NOT 以條件式渲染讓此步驟在該端整段消失

#### Scenario: 目標為尚未支援的 space
- **WHEN** `Doc Target` 指向 `confluence-team-doc` 尚未支援的 Confluence space
- **THEN** Claude SHALL 明說該 space 尚未支援、需先泛化 `confluence-team-doc` 的座標
- **AND** SHALL NOT 嘗試以團隊 space 的座標寫入其他 space
- **AND** SHALL 繼續執行 `finish-branch`，SHALL NOT 停在該步驟

#### Scenario: 能力陳述先於執行指令
- **WHEN** 流程說明同時包含「交給 `confluence-team-doc` 執行」與「本端是否具備該能力」兩項敘述
- **THEN** 能力敘述 SHALL 排在執行指令之前
- **AND** SHALL NOT 讓渲染後的順序變成先下達指令、後才否定其可行性

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

### Requirement: 協調模式下的線側契約
當一條線是由協調者派出的多條平行線之一時,`dev-workflow` 的核心流程 SHALL 不變,但 SHALL 附加三項義務。完整規則屬於 `coordinate`;`dev-workflow` 內文 SHALL 只放**線側**契約,並以 name-map 指向該 skill,SHALL NOT 寫死 skill 名。

#### Scenario: 以名字定址協調者
- **WHEN** 一條線要回報給協調者
- **THEN** SHALL 以名字定址(`coordinator`),SHALL NOT 以 pane id 定址——pane id 在換手時會變,名字不會

#### Scenario: 跨線事實即時回報
- **WHEN** 線撞到任何別條線也可能動到的東西(共用 fixture、兩條線都斷言的量測、migration 版本、編號區間、落在兩者影響半徑內的檔案)
- **THEN** SHALL 立即回報,SHALL NOT 等到收尾——自己量到的數字只對自己量測時的 base 成立,而合併那些數字的只有協調者

#### Scenario: 前提錯誤的裁決應被推翻
- **WHEN** 協調者給的裁決其問題框架本身不成立
- **THEN** 線 SHALL 指出框架不對,SHALL NOT 只在給定選項內作答——只在框內作答會把協調者的錯誤放大成決策;同理 SHALL 拒絕會汙染自身證據的指令(例如在自己 session 裡執行會打斷當前回合的實驗)

#### Scenario: finish-branch 回報四訊號
- **WHEN** 線走到 `finish-branch`
- **THEN** SHALL 回報四個獨立訊號(MR/PR 已合併、handoff 已歸檔、worktree/branch 已處置、`active_workflows.md` 該列已移除),且 SHALL 預期協調者自行查證而非採信回報

#### Scenario: 合併驗證不用 branch -d
- **WHEN** 要確認一條 branch 是否真的合併了
- **THEN** SHALL 以 scoped diff 驗證,SHALL NOT 以 `git branch -d` 判斷——squash 合併下該指令對「已合併」與「從未合併」給同一個答案
