## MODIFIED Requirements

### Requirement: 判準來源分層且降級可見
模組邊界的判準 SHALL 依可用資訊分層:存在 `context/` bundle 時 SHALL 以其詞彙 concept 檔為權威判準;不存在時 SHALL 從 codebase 推斷 domain 語言(目錄結構、型別/類別名、導出介面)。使用推斷判準時,報告 SHALL 明示該判準為推斷而非權威。`arch-review` SHALL NOT 寫入 `context/`。

#### Scenario: 有 context bundle
- **WHEN** 執行體檢且 `context/` bundle 存在
- **THEN** SHALL 讀取其詞彙 concept 檔作為模組邊界判準,並於報告標示判準來源為 `context/`

#### Scenario: 無 context bundle 時降級並標示
- **WHEN** 執行體檢且 `context/` bundle 不存在
- **THEN** SHALL 從 codebase 推斷 domain 語言,且報告 SHALL 明確標示判準為推斷而非權威

#### Scenario: 不寫入 context
- **WHEN** 體檢過程中發現疑似長青的 domain 詞彙
- **THEN** SHALL NOT 寫入 `context/`(該 bundle 僅於 sync/archive 階段寫入)
