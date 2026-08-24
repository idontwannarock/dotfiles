## ADDED Requirements

### Requirement: 一個情境只對應一個退化理由

退化理由的集合 SHALL 為互斥:任一實際情境 SHALL 恰好對應一個理由。當某步驟以「比照前一步驟」承接另一步驟的程序時,SHALL 明述承接的範圍,並 SHALL 釘死該情境自身的退化理由。

理由:理由的唯一用途是讓人知道要去修什麼。三個理由競逐同一個條件時,報告寫哪一個變成任意的,而「跨模型 review 失敗」這種收斂寫法丟掉的正是唯一能讓人修好它的資訊。

#### Scenario: rebuttal 檔缺失

- **WHEN** 一輪反駁後 `counterpart-rebuttal.md` 不存在
- **THEN** 退化理由 SHALL 為 `rebuttal exchange incomplete`
- **AND** SHALL NOT 沿用 findings 檔缺失時的分類程序所產生的理由 —— 該程序的兩個出口皆針對 findings 檔

#### Scenario: 步驟間的「比照前一步驟」

- **WHEN** 某步驟以「confirm as in <前一步驟>」承接程序
- **THEN** SHALL 明述承接的是等待與存活確認,SHALL NOT 連同該步驟專屬的退化理由一併承接
