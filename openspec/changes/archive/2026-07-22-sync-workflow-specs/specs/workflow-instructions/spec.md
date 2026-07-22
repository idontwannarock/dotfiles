## MODIFIED Requirements

### Requirement: 確認流程
收到實作任務時，Claude SHALL 詢問流程選擇：OpenSpec 小型（Small）/ OpenSpec 大型（Large）/ 不使用（Skip）。

#### Scenario: 一次確認
- **WHEN** 收到非瑣碎的實作任務
- **THEN** Claude SHALL 在一個回合中詢問流程選擇

#### Scenario: 瑣碎任務自動跳過
- **WHEN** 任務為改 typo、一行修改、簡單問答等瑣碎任務
- **THEN** Claude SHALL 跳過詢問，直接進行

### Requirement: 小型核心流程
小型流程 SHALL 跳過 grill，由 openspec 直接處理設計。

#### Scenario: 小型流程步驟
- **WHEN** 選擇小型流程
- **THEN** 執行順序 SHALL 為：ensure-openspec → openspec-new-change → openspec-continue-change（loop）→ openspec-apply-change → openspec validate → [openspec-sync-specs] → openspec-archive-change → git:commit → code:review-surgical → 如需修正走新一輪 → 如不需修正 → finish-branch → [git:clean-gone]

## REMOVED Requirements

### Requirement: 推進模式決定 opsx 指令
**Reason**: dev-workflow rework（2026-07-21）移除了「推進模式（逐步確認 / 自動推進）」概念，且 `opsx:propose` / `opsx:new` / `opsx:continue` 指令已被 openspec-* skills 取代。artifact 產出改由 `openspec-continue-change` loop 逐一產出，不再由使用者預先選推進模式控制。
**Migration**: 逐步產出走 `openspec-new-change` → `openspec-continue-change`（loop）；需要一次快進所有 artifacts 時走 `openspec-ff-change`。流程確認時不再詢問推進模式，只問 Small / Large / Skip。
