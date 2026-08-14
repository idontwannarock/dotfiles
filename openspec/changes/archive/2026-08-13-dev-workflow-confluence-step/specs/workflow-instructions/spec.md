## ADDED Requirements

### Requirement: 團隊文件記錄步驟

兩個核心流程 SHALL 在 review 迴圈收斂之後、`finish-branch` 之前，套用一條判準決定本次 change 是否應寫入團隊文件；判定為是時 SHALL 交由 `confluence-team-doc` 執行。此步驟 SHALL NOT 阻斷流程。

判準為單一問句：**repo 外的人若要回答這次產出的那個問題（怎麼操作 / 為什麼這樣設計），除了讀這份 diff 之外有沒有別的地方可讀？沒有 → 值得寫。** 判準 SHALL 綁「repo 外是否有讀者」，SHALL NOT 綁 diff 大小或流程規模。

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

### Requirement: 團隊文件目標的 lazy 詢問

流程 SHALL 於既有的 registry 讀取步驟一併讀取該 repo 的 `Doc Target`，但 SHALL NOT 於該時點詢問使用者。詢問 SHALL 延遲到判準判定值得寫的那一刻。

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

### Requirement: 團隊文件步驟的顯性退化

當執行前提不滿足時，此步驟 SHALL 明說原因並停下，SHALL NOT 靜默消失。

#### Scenario: 工具端無 Atlassian MCP

- **WHEN** 當前工具端沒有可用的 Atlassian MCP（例如 Codex 端）
- **THEN** 流程說明 SHALL 仍呈現此步驟的存在，並明說本端無對應能力、需於具備該能力的工具端執行
- **AND** SHALL NOT 以條件式渲染讓此步驟在該端整段消失

#### Scenario: 目標為尚未支援的 space

- **WHEN** `Doc Target` 指向 `confluence-team-doc` 尚未支援的 Confluence space
- **THEN** Claude SHALL 明說該 space 尚未支援、需先泛化 `confluence-team-doc` 的座標，然後停下
- **AND** SHALL NOT 嘗試以團隊 space 的座標寫入其他 space

## MODIFIED Requirements

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

#### Scenario: Review 通過
- **WHEN** code review 通過不需修正
- **THEN** Claude SHALL 先套用團隊文件記錄步驟的判準,再繼續執行 `finish-branch`
