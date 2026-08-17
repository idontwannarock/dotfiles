## MODIFIED Requirements

### Requirement: grill 訪談紀律
`grill` SHALL 以一次一題的訪談把模糊想法收斂成共識:每題附建議答案;能從環境查到的事實自己查、決策問使用者;解法有分岔時提出 2-3 個方案與推薦;每一題都必須可能改變後續行為。訪談開場,grill SHALL 讀取 `context/`(若存在)作為 domain grounding,併入其「事實自己查」紀律,避免重問已記載的背景。grill SHALL NOT 寫入 `context/`;凡發現疑似長青的 domain 詞彙或反覆適用原則,SHALL 以候選標記(如 `<!-- evergreen-candidate -->`)記入 `design.md` 的 `## Decisions`,待 sync/archive 階段對照實作再決定晉升。

選題順序 SHALL 由依賴決定:當一題的答案取決於另一題時,grill SHALL 標記其 `blocked by`,並優先問沒有被擋住的問題。

訪談中浮現、但尚無法收斂成精確問題的不確定性,grill SHALL 記錄為「尚未釐清」項而非丟棄,並於共識確認時一併呈給使用者裁決;確認後其去向為 `design.md` 的 `## Open Questions`。未釐清項 SHALL NOT 構成 gate——本 skill 的唯一 gate 仍是使用者明確確認共識達成。

#### Scenario: 單一 stop-gate
- **WHEN** 使用者尚未明確確認「共識達成」
- **THEN** Claude SHALL NOT 開始撰寫 openspec artifacts 或實作

#### Scenario: 產出分流
- **WHEN** 使用者確認共識達成
- **THEN** 結論 SHALL 直接分流至 openspec artifacts(決策→design.md Decisions;動機範圍→proposal.md;行為要求→spec delta),grill SHALL NOT 產生獨立的 design 文件

#### Scenario: 開場讀 context 當 grounding
- **WHEN** grill 訪談開始且 `context/` 存在
- **THEN** grill SHALL 先讀取它作為 domain 背景,SHALL NOT 重問其中已記載的事實

#### Scenario: 長青候選標記而非寫入
- **WHEN** 訪談中出現疑似長青的 domain 詞彙或反覆適用原則
- **THEN** grill SHALL 將其以候選標記記入 `design.md`,SHALL NOT 直接寫入 `context/`

#### Scenario: 未決問題的依賴決定提問順序
- **WHEN** 一個未決問題的答案取決於另一個未決問題
- **THEN** grill SHALL 標記其 `blocked by`,並先問沒有被擋住的問題

#### Scenario: 未釐清項於共識確認時裁決
- **WHEN** 使用者確認共識達成,且存在已記錄的未釐清項
- **THEN** grill SHALL 一併呈出並請使用者就每項擇一:接受風險往下走 / 現在再問 / 移出這次範圍;經裁決後仍保留的項 SHALL 記入 `design.md` 的 `## Open Questions`

#### Scenario: 未釐清項不構成第二個 gate
- **WHEN** 存在尚未釐清的項目,而使用者已明確確認共識達成
- **THEN** grill SHALL NOT 因此阻擋後續 artifacts 撰寫或實作

#### Scenario: 無未釐清項時不製造噪音
- **WHEN** 訪談過程未浮現任何無法收斂成精確問題的不確定性
- **THEN** grill SHALL NOT 提及「尚未釐清」,SHALL NOT 為了填欄位而硬擠條目
