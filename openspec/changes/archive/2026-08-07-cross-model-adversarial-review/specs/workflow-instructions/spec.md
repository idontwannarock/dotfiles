## MODIFIED Requirements

### Requirement: 大型核心流程
大型流程 SHALL 以 grill 開場收斂共識,並在實作與收尾套用紀律 skills。在 sync-specs/archive 階段,若 `design.md` 有標記的長青候選,SHALL 逐條對照實際 shipped 內容,將符合晉升閘門者晉升進 `context/`。review 關卡 SHALL 在 `code:review-comprehensive` 之後接續跨模型 adversarial review。

#### Scenario: 大型流程步驟
- **WHEN** 選擇大型流程
- **THEN** 執行順序 SHALL 為:ensure-openspec → grill → openspec-new-change → openspec-continue-change → openspec-apply-change(可測 seam 套 tdd)→ verify-done → openspec-verify-change → openspec validate → openspec-sync-specs（此時晉升 design.md 的長青候選進 context/）→ openspec-archive-change → git:commit → code:review-comprehensive → code:review-cross-model → 如需修正走新一輪 → 如不需修正 → finish-branch → [git:clean-gone]

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
- **THEN** Claude SHALL 繼續執行 `finish-branch`
