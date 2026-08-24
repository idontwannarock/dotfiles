## MODIFIED Requirements

### Requirement: 收斂判定區分 blocked

僅 `idle` 與 `done` SHALL 視為對造完成工作。`blocked`、timeout、以及 herdr 回報的 stalled 狀態 SHALL 視為未完成並走退化路徑。

理由:`blocked` 意為對造停在等待輸入(權限提示或澄清問題),其工作並未完成;而 herdr 的預設等待條件把 `blocked` 也算作收斂。

herdr 回報的是 **pane 的狀態**,不是工作的狀態。因此任何收斂狀態 SHALL NOT 單獨作為工作已完成的證據,findings 檔的存在與內容 SHALL 為唯一證據。

#### Scenario: 對造停在等待輸入
- **WHEN** 對造的最終狀態為 `blocked`
- **THEN** SHALL 視為未完成,SHALL NOT 讀取並採信其 findings

#### Scenario: 對造停在自身的信任或授權提示
- **WHEN** 對造 CLI 停在它自己的信任／授權／目錄確認提示上,而 herdr 回報的狀態為 `done`
- **THEN** SHALL 視為未完成並走 blocked 處置,退化原因 SHALL 為 `counterpart blocked on input`
- **AND** SHALL NOT 因狀態為 `done` 而讀取 findings —— 該提示屬對造自身的啟動流程,herdr 無從分辨它與工作結束後的閒置

#### Scenario: agent 已退出但狀態仍回報 idle
- **WHEN** 對造 agent 已從 pane 退出
- **THEN** `herdr agent get` SHALL NOT 被當作存活或完成的判準 —— 實測其於 agent 退出後仍回報 `idle`
- **AND** 完成與否 SHALL 僅由 findings 檔判定

#### Scenario: 送出前確認 pane 仍由 agent 佔用
- **WHEN** 準備送出任一 prompt(含重送)
- **THEN** SHALL 先確認該 pane 仍由預期的 agent 佔用
- **AND** 若 agent 已不存在,SHALL 走退化路徑,SHALL NOT 送出 —— agent 退出後 pane 回到 shell,送出的 prompt 文字會被 shell 逐行當指令執行,而 review prompt 是任意文字且 cwd 就是 repo
- **AND** agent 自我更新等啟動期行為可造成此情形,`interactive_ready` 為真不構成後續仍存活的保證

#### Scenario: 收斂狀態不等於 prompt 已送達
- **WHEN** 對造回報收斂狀態但 findings 檔不存在
- **THEN** SHALL 重送該 prompt **一次**後才退化 —— 啟動後的首個 prompt 可能被 agent 自身的啟動通知吞掉,而 herdr 仍回報收斂狀態(兩個受測 kind 皆再現)
- **AND** SHALL NOT 將收斂狀態本身當作工作已執行的證據
