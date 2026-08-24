## ADDED Requirements

### Requirement: 空的 findings 檔等同於沒有檔案

findings 檔存在但內容為空 SHALL 與檔案不存在等同處置。判定表與逐步程序 SHALL 各自涵蓋此情形,SHALL NOT 僅於散文中提及。

理由:讀者照著表格與編號程序執行。一個只寫在收尾散文裡的規則,對停在表格第一列的讀者不生效——而該列若只判「檔案存在」,零位元組的檔案就會被讀成「沒有發現問題」,正是檔案通道要防的那個混同。

#### Scenario: 收斂但檔案為空

- **WHEN** 最終狀態為 `idle` 或 `done`,findings 檔存在但為空
- **THEN** SHALL 走與「檔案不存在」相同的路徑:重送一次,仍為空則以一次分類讀取決定退化理由
- **AND** SHALL NOT 將其讀為「沒有發現問題」
