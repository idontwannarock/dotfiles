## ADDED Requirements

### Requirement: coordinate 派線時關閉線的直接發問管道
`coordinate` SHALL 規定派線時關閉線在自己 session 直接詢問真人的能力,且 SHALL 要求同一次派工附上升級契約——兩者 SHALL NOT 分開使用。

關閉的範圍 SHALL 是**單一 session**（啟動參數）,SHALL NOT 寫入任何層級的設定檔——協調者本身必須保留該能力,它是唯一該升級到真人的角色。

skill SHALL 標明此機制在哪些 agent 有機械保障:Claude 端以 `--disallowedTools AskUserQuestion` 達成,其他 agent kind 若無等價機制 SHALL 明說只有 prompt 約束。

#### Scenario: 旗標與契約必須同時給
- **WHEN** 協調者派出一條線並關閉其發問管道
- **THEN** 同一次派工 SHALL 附上升級契約(撞到做不了的決策 → 具名回報協調者並停下、不要挑預設值)
- **AND** SHALL NOT 只關閉管道而不給契約——僅移除工具不會產生停下來的行為,只會讓線在命名風險之後仍以預設值繼續

#### Scenario: 不得寫入設定檔
- **WHEN** 要讓被協調的線失去直接發問能力
- **THEN** SHALL 以啟動參數限定於該 session,SHALL NOT 寫入 user 層、repo 層或 repo-local 層的設定檔——那會一併關閉協調者自己的發問能力,使升級鏈斷在最上面

#### Scenario: 標明機械保障的範圍
- **WHEN** skill 描述這個做法
- **THEN** SHALL 標明哪些 agent kind 有機械保障、哪些只有 prompt 約束,SHALL NOT 讓讀者以為所有 kind 一致

#### Scenario: 真人失去繞過通道的代價要寫明
- **WHEN** skill 描述這個做法
- **THEN** SHALL 一併寫明代價:協調者因此成為沒有 bypass 的單點,而線推翻錯誤前提的管道改為文字回報而非選單
