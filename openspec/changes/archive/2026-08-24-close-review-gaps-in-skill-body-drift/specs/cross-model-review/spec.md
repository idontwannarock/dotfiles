## MODIFIED Requirements

### Requirement: 收斂判定區分 blocked

僅 `idle` 與 `done` SHALL 視為對造完成工作。`blocked`、timeout、以及 herdr 回報的 stalled 狀態 SHALL 視為未完成並走退化路徑。

理由:`blocked` 意為對造停在等待輸入(權限提示或澄清問題),其工作並未完成;而 herdr 的預設等待條件把 `blocked` 也算作收斂。

herdr 回報的是 **pane 的狀態**,不是工作的狀態。因此任何收斂狀態 SHALL NOT 單獨作為工作已完成的證據,findings 檔的存在與內容 SHALL 為唯一證據。

「對造停在自身的信任／授權提示」與「對造什麼都沒做」在外顯訊號上完全相同——皆為收斂狀態加上沒有 findings 檔。因此退化理由 SHALL 由一次明確的分類讀取決定,SHALL NOT 由讀者無從觀測的事實決定:重送一次後仍無檔案時,SHALL 以 `herdr agent read` **僅為分類**讀取一次。此用途屬既有的診斷例外,與「SHALL NOT 以 `agent read` 收割結果」不衝突——分界在於讀來當結果或讀來分類失敗。

#### Scenario: 對造停在等待輸入
- **WHEN** 對造的最終狀態為 `blocked`
- **THEN** SHALL 視為未完成,SHALL NOT 讀取並採信其 findings

#### Scenario: 收斂狀態但沒有 findings 檔
- **WHEN** 最終狀態為 `idle` 或 `done`,而 findings 檔不存在
- **THEN** SHALL 先重送該 prompt 一次(見〈收斂狀態不等於 prompt 已送達〉)
- **AND** 仍無檔案時 SHALL 以 `herdr agent read` 分類一次:pane 上可見對造自身的信任／授權／目錄確認提示 → 退化理由 SHALL 為 `counterpart blocked on input`;否則 → SHALL 為 `counterpart produced no findings file`
- **AND** SHALL NOT 在未分類的情況下任選其一 —— 兩者的可修復性不同,收斂成單一理由會丟掉唯一能讓人修好它的資訊

#### Scenario: 對造停在自身的信任或授權提示
- **WHEN** 對造 CLI 停在它自己的信任／授權／目錄確認提示上,而 herdr 回報的狀態為 `done`
- **THEN** SHALL 視為未完成並走 blocked 處置,退化原因 SHALL 為 `counterpart blocked on input`
- **AND** SHALL NOT 因狀態為 `done` 而採信其結果 —— 該提示屬對造自身的啟動流程,herdr 無從分辨它與工作結束後的閒置

#### Scenario: agent 已退出但狀態仍回報 idle
- **WHEN** 對造 agent 已從 pane 退出
- **THEN** `herdr agent get` SHALL NOT 被當作存活或完成的判準 —— 實測其於 agent 退出後仍回報 `idle`

#### Scenario: 步驟開頭的敘述不得與其判定表相斥
- **WHEN** 本步驟同時以散文與表格陳述收斂判定
- **THEN** 兩者 SHALL 一致 —— 由上而下閱讀者可能停在散文而未讀到表格,故散文 SHALL NOT 宣稱任何收斂狀態本身即為成功

#### Scenario: 送出前確認 pane 仍由 agent 佔用
- **WHEN** 準備送出任一 prompt(含重送)
- **THEN** SHALL 先確認該 pane 仍由預期的 agent 佔用
- **AND** 若 agent 已不存在,SHALL 走退化路徑,SHALL NOT 送出 —— agent 退出後 pane 回到 shell,送出的 prompt 文字會被 shell 逐行當指令執行,而 review prompt 是任意文字且 cwd 就是 repo
- **AND** agent 自我更新等啟動期行為可造成此情形,`interactive_ready` 為真不構成後續仍存活的保證

#### Scenario: 收斂狀態不等於 prompt 已送達
- **WHEN** 對造回報收斂狀態但 findings 檔不存在
- **THEN** SHALL 重送該 prompt **一次**後才退化 —— 啟動後的首個 prompt 可能被 agent 自身的啟動通知吞掉,而 herdr 仍回報收斂狀態(兩個受測 kind 皆再現)
