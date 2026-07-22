## MODIFIED Requirements

### Requirement: 小型核心流程
小型流程 SHALL 跳過 grill，由 openspec 直接處理設計。在 sync-specs/archive 階段,若 `design.md` 有標記的長青候選,SHALL 逐條對照實際 shipped 內容,將符合晉升閘門者晉升進 `openspec/project.md`。

#### Scenario: 小型流程步驟
- **WHEN** 選擇小型流程
- **THEN** 執行順序 SHALL 為：ensure-openspec → openspec-new-change → openspec-continue-change（loop）→ openspec-apply-change → openspec validate → [openspec-sync-specs;此時晉升 design.md 的長青候選進 openspec/project.md] → openspec-archive-change → git:commit → code:review-surgical → 如需修正走新一輪 → 如不需修正 → finish-branch → [git:clean-gone]

#### Scenario: 晉升長青候選
- **WHEN** 小型流程進行 sync-specs/archive 且 `design.md` 含 evergreen 候選標記
- **THEN** Claude SHALL 逐條對照實際實作,將反覆適用的原則/新 domain 詞彙晉升進 `openspec/project.md`,其餘 SHALL 留在 archived `design.md`

### Requirement: 大型核心流程
大型流程 SHALL 以 grill 開場收斂共識,並在實作與收尾套用紀律 skills。在 sync-specs/archive 階段,若 `design.md` 有標記的長青候選,SHALL 逐條對照實際 shipped 內容,將符合晉升閘門者晉升進 `openspec/project.md`。

#### Scenario: 大型流程步驟
- **WHEN** 選擇大型流程
- **THEN** 執行順序 SHALL 為:ensure-openspec → grill → openspec-new-change → openspec-continue-change → openspec-apply-change(可測 seam 套 tdd)→ verify-done → openspec-verify-change → openspec validate → openspec-sync-specs（此時晉升 design.md 的長青候選進 openspec/project.md）→ openspec-archive-change → git:commit → code:review-comprehensive → 如需修正走新一輪 → 如不需修正 → finish-branch → [git:clean-gone]

#### Scenario: 晉升長青候選
- **WHEN** 大型流程進行 sync-specs/archive 且 `design.md` 含 evergreen 候選標記
- **THEN** Claude SHALL 逐條對照實際實作,將反覆適用的原則/新 domain 詞彙晉升進 `openspec/project.md`,其餘 SHALL 留在 archived `design.md`
