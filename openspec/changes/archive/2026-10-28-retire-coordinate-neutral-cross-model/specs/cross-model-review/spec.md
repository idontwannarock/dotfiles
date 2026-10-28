## MODIFIED Requirements

### Requirement: 資料通道為檔案,pane 僅為 trigger

對造的 findings SHALL 以檔案傳遞:派工時指定輸出路徑,主 agent 讀該檔取得結果。SHALL NOT 以終端讀取(`agent-mux classify-read`)的輸出作為 findings 的資料來源。

理由:終端讀取的失敗模式是靜默空字串(來源選錯時無錯誤、exit code 為 0),而空 findings 與「無發現」在下游無法區分。終端讀取僅得用於診斷與錯誤回報。

#### Scenario: 取得 findings
- **WHEN** 對造回報完成
- **THEN** 主 agent SHALL 自約定路徑讀取 findings 檔

#### Scenario: findings 檔不存在或為空
- **WHEN** 對造收斂但約定路徑無檔案或內容為空
- **THEN** SHALL 視為失敗並走退化路徑,SHALL NOT 解讀為「無發現」

#### Scenario: 反駁同樣走檔案通道
- **WHEN** 請對造反駁主 agent 的 findings
- **THEN** SHALL 指定獨立的反駁輸出檔並自該檔讀取,SHALL NOT 以終端讀取取得反駁內容
- **AND** 反駁檔缺失時 SHALL 在報告中記為「該向交換未完成」,SHALL NOT 逕自套用分級規則

#### Scenario: 輸出路徑必須檔名安全
- **WHEN** 組出 findings 與反駁檔的路徑
- **THEN** 路徑中的 scope 標籤 SHALL 經過消毒(`[A-Za-z0-9._-]` 以外一律替換)—— branch 名常含 `/`,原樣內插會產生未建立的巢狀目錄,導致寫入失敗而退化理由指向錯誤的原因

### Requirement: 收斂判定區分 blocked

`agent-mux prompt` 印出的 `idle`、`done` 與 `unknown` SHALL 僅視為「已收斂」,是否完成工作由 findings 檔決定。`blocked`、`timeout`、`gone`、`failed` SHALL 視為未完成並走退化路徑。

理由:`blocked` 意為對造停在等待輸入(權限提示或澄清問題),其工作並未完成;而多工器的等待條件把 `blocked` 也算作收斂。

多工器回報的是**終端的狀態**,不是工作的狀態。因此任何收斂狀態 SHALL NOT 單獨作為工作已完成的證據,findings 檔的存在與內容 SHALL 為唯一證據。

「對造停在自身的信任／授權提示」與「對造什麼都沒做」在外顯訊號上完全相同——皆為收斂狀態加上沒有 findings 檔。因此退化理由 SHALL 由一次明確的分類讀取決定,SHALL NOT 由讀者無從觀測的事實決定:重送一次後仍無檔案時,SHALL 以 `agent-mux classify-read` **僅為分類**讀取一次。此用途屬既有的診斷例外,與「SHALL NOT 以終端讀取收割結果」不衝突——分界在於讀來當結果或讀來分類失敗。

#### Scenario: 對造停在等待輸入
- **WHEN** 對造的最終狀態為 `blocked`
- **THEN** SHALL 視為未完成,SHALL NOT 讀取並採信其 findings

#### Scenario: 收斂狀態但沒有 findings 檔
- **WHEN** 最終狀態為 `idle`、`done` 或 `unknown`,而 findings 檔不存在
- **THEN** SHALL 先重送該 prompt 一次(見〈收斂狀態不等於 prompt 已送達〉)
- **AND** 仍無檔案時 SHALL 以 `agent-mux classify-read` 分類一次:pane 上可見對造自身的信任／授權／目錄確認提示 → 退化理由 SHALL 為 `counterpart blocked on input`;否則 → SHALL 為 `counterpart produced no findings file`
- **AND** SHALL NOT 在未分類的情況下任選其一 —— 兩者的可修復性不同,收斂成單一理由會丟掉唯一能讓人修好它的資訊

#### Scenario: 對造停在自身的信任或授權提示
- **WHEN** 對造 CLI 停在它自己的信任／授權／目錄確認提示上,而多工器回報的狀態為 `done` 或 `idle`(herdr 報 `done`;Ghostex 對 Codex 的更新提示報 idle)
- **THEN** SHALL 視為未完成並走 blocked 處置,退化原因 SHALL 為 `counterpart blocked on input`
- **AND** SHALL NOT 因收斂狀態而採信其結果 —— 該提示屬對造自身的啟動流程,多工器無從分辨它與工作結束後的閒置

#### Scenario: agent 已退出但狀態仍回報 idle
- **WHEN** 對造 agent 已從終端退出
- **THEN** 多工器的活動狀態 SHALL NOT 被當作存活的判準 —— 實測 Ghostex 的 activity 於 agent 退出後仍回報 `idle`
- **AND** 存活 SHALL 由 `agent-mux alive` 判定:herdr 以 `agent get` 能否解析出該名字的 agent;Ghostex 以該 session 的終端是否仍存在(agent 以 `exec` 啟動,agent 結束即終端結束)

#### Scenario: 步驟開頭的敘述不得與其判定表相斥
- **WHEN** 本步驟同時以散文與表格陳述收斂判定
- **THEN** 兩者 SHALL 一致 —— 由上而下閱讀者可能停在散文而未讀到表格,故散文 SHALL NOT 宣稱任何收斂狀態本身即為成功

#### Scenario: 送出前確認終端仍由 agent 佔用
- **WHEN** 準備送出任一 prompt(含重送)
- **THEN** `agent-mux prompt` SHALL 先確認該終端仍由預期的 agent 佔用;此檢查 SHALL 在腳本內,SHALL NOT 依賴呼叫端記得先呼叫
- **AND** 若 agent 已不存在,SHALL 印出 `gone` 並以 `counterpart no longer present` 退化,SHALL NOT 送出 —— agent 退出後 herdr pane 回到 shell,送出的 prompt 文字會被 shell 逐行當指令執行,而 review prompt 是任意文字且 cwd 就是 repo
- **AND** agent 自我更新等啟動期行為可造成此情形,`interactive_ready` 為真不構成後續仍存活的保證

#### Scenario: 收斂狀態不等於 prompt 已送達
- **WHEN** 對造回報收斂狀態但 findings 檔不存在
- **THEN** SHALL 重送該 prompt **一次**後才退化 —— 啟動後的首個 prompt 可能被 agent 自身的啟動通知吞掉,而多工器仍回報收斂狀態(兩個受測 kind 皆再現)

### Requirement: 退化必須顯式可見

前置條件不滿足時(沒有可用的 agent 多工器、對造 CLI 未安裝或未登入、啟動或等待逾時、對造 blocked、findings 檔缺失),本能力 SHALL 軟退化 —— 既有 review 照常產出,SHALL NOT 阻斷流程。但報告 SHALL 於顯著位置標註跨模型反駁未執行及其原因。

理由:靜默跳過會使報告看起來像已經過跨模型驗證,構成不可驗證的宣稱。

#### Scenario: 沒有可用的 agent 多工器
- **WHEN** `agent-mux detect` 失敗
- **THEN** SHALL 跳過跨模型段並照常產出 review,且報告 SHALL 標註「跨模型反駁:未執行 —— `no agent multiplexer available — <detect 印出的細節>`」
- **AND** 細節 SHALL 逐一列出每個後端與它失敗的原因(不在其中、找不到 binary、或環境變數在但命令失敗),因為三者的修法不同

#### Scenario: 任一失敗原因
- **WHEN** 跨模型段因任何原因未完成
- **THEN** 報告 SHALL 標註未執行並指明實際原因,SHALL NOT 省略該標註

### Requirement: 生命週期收尾涵蓋失敗路徑

本能力 SHALL 在結束前關閉自己建立的終端並確認無殘留:等待收斂 → 讀取 findings → 有時限的 best-effort 禮貌退出(`agent-mux exit`)→ 關閉並確認(`agent-mux close`:關閉 `start` 記下的終端,再以多工器自己的清單確認該 agent 已不在)。後兩步 SHALL 於成功與失敗路徑皆執行。`agent-mux close` 無法確認時,報告 SHALL 記載 `teardown not confirmed`。

終端識別碼(herdr 的 pane id、Ghostex 的 session globalRef)SHALL 取自建立時的回應並由 `agent-mux` 記錄,SHALL NOT 自行推導。SHALL NOT 關閉非自己建立的終端,SHALL NOT 停止多工器的 server。

#### Scenario: 成功路徑收尾
- **WHEN** 跨模型段正常完成
- **THEN** SHALL 先嘗試禮貌退出,再關閉自己建立的終端,並確認該 agent 已不在多工器的清單中

#### Scenario: 失敗路徑收尾
- **WHEN** 跨模型段因逾時、blocked、啟動失敗或任何錯誤而中止
- **THEN** SHALL 仍執行關閉與確認,SHALL NOT 留下終端或 agent 殘留

### Requirement: 禮貌退出為 best-effort,不得成為保證的前提

收尾 SHALL 先嘗試讓對造自行結束(送出該 agent 自身的結束指令),使其 SessionEnd hook、transcript flush 與自起的子行程有機會正常收尾。

該步驟 SHALL 有時限。逾時或失敗時 SHALL NOT 重試、SHALL NOT 阻斷後續步驟 —— 關閉與確認 SHALL 無條件執行。

對造為 `blocked` 時,SHALL 先送出取消鍵再嘗試結束指令;若仍無效,直接進入強制關閉。Ghostex 後端 SHALL 一律先送取消鍵——啟動期的對話框在 Ghostex 回報為 idle 而非 blocked,而在 Codex 的更新提示上按 Enter 會選中「立即更新」(2026-10-28 實測)。

#### Scenario: 禮貌退出成功
- **WHEN** 對造收到結束指令並自行退出
- **THEN** SHALL 接續執行關閉與確認 —— agent 已退出不豁免關閉終端

#### Scenario: 禮貌退出逾時或無效
- **WHEN** 結束指令送出後於時限內未觀察到對造退出
- **THEN** SHALL 直接執行關閉,SHALL NOT 重試結束指令,SHALL NOT 因此中止收尾

#### Scenario: 結束指令因 kind 而異
- **WHEN** 對造的 kind 無已知的結束指令
- **THEN** SHALL 跳過禮貌退出直接強制關閉,SHALL NOT 猜測指令字串,SHALL NOT 因缺少該指令而放棄收尾

#### Scenario: 不碰他人資源
- **WHEN** 執行收尾
- **THEN** SHALL 僅關閉自己建立的終端,SHALL NOT 關閉使用者或其他 client 的終端,SHALL NOT 停止多工器的 server

## ADDED Requirements

### Requirement: 多工器操作集中於 agent-mux

skill body SHALL NOT 含任何多工器專屬的指令。所有終端操作 SHALL 經由 `~/.local/bin/agent-mux`(source:`home/dot_local/bin/executable_agent-mux`)。該腳本 SHALL 提供下列動詞:`detect`、`start <name> <kind> <repo> [-- <launch args>]`、`alive <name>`、`state <name>`、`prompt <name> <file> [--timeout <seconds>]`、`classify-read <name>`、`exit <name> <exit command>`、`close <name>`。

後端 SHALL 為 herdr 與 Ghostex。兩者的差異 SHALL 只存在於腳本內。

#### Scenario: 選擇後端
- **WHEN** 呼叫 `agent-mux detect`
- **THEN** SHALL 先試 herdr,再試 Ghostex,印出第一個可用的後端名稱
- **AND** 兩者皆不可用時 SHALL 以非零結束,並在 stderr 逐一列出每個後端失敗的原因

#### Scenario: prompt 的結果字
- **WHEN** `agent-mux prompt` 結束
- **THEN** SHALL 在 stdout 印出恰好一個字:`idle`、`done`、`unknown`、`blocked`、`timeout`、`gone` 或 `failed`
- **AND** SHALL 僅在 `idle` 與 `done` 時以 0 結束

#### Scenario: close 只碰 start 開的終端
- **WHEN** 呼叫 `agent-mux close <name>`
- **THEN** SHALL 只關閉同名 `start` 記錄下來的終端,並以多工器自己的清單確認它已消失
- **AND** 清單本身讀取失敗時 SHALL 以非零結束,SHALL NOT 當作「已消失」

### Requirement: 偵測多工器必須執行真實命令

`agent-mux detect` SHALL NOT 僅憑環境變數判定後端可用。每個後端 SHALL 同時滿足:表示「正在其中」的環境變數存在(herdr:`HERDR_ENV=1`;Ghostex:`GHOSTEX_SESSION_ID`),且一個唯讀命令成功(herdr:`herdr agent list` 回傳 `.result`;Ghostex:`ghostex agents list --json` 回傳 `ok: true`)。

理由:在 Codex 的 sandbox 內 `HERDR_ENV=1` 仍被設定,但 unix socket 被當成網路,所以每個 herdr 命令都以 PermissionDenied 失敗;Ghostex 的 gxserver 在 127.0.0.1,同樣連不上。只信環境變數會在派工之後才失敗。

#### Scenario: 環境變數在但命令失敗
- **WHEN** `HERDR_ENV=1` 已設定,但 `herdr agent list` 失敗
- **THEN** `detect` SHALL NOT 回報 herdr,且失敗原因 SHALL 含該命令的錯誤訊息

#### Scenario: 只有 binary
- **WHEN** `ghostex` 在 PATH 上,但 `GHOSTEX_SESSION_ID` 未設定
- **THEN** `detect` SHALL NOT 回報 Ghostex —— 在 Ghostex 之外的終端開 session 會在使用者沒預期的地方出現

### Requirement: Ghostex 後端的對應做法

Ghostex 沒有 split pane。`agent-mux` SHALL 以 repo 所屬 Ghostex project 中的一個新 session 作為對等物。

#### Scenario: repo 不是 Ghostex project
- **WHEN** repo 路徑不等於任何 Ghostex project 的路徑
- **THEN** `start` SHALL 以 `counterpart failed to start` 失敗,SHALL NOT 呼叫 `add-project` —— 那會改變使用者的 sidebar

#### Scenario: 啟動參數
- **WHEN** 以 Ghostex 啟動對造
- **THEN** SHALL 以 `exec <Ghostex agent type 的 command> <launch args>` 作為 session 的輸入,command SHALL 取自 `ghostex agents types`,SHALL NOT 猜測
- **AND** 理由:`exec` 讓 agent 結束時終端隨之結束,所以沒有 shell 會收到後續打入的文字,而終端是否存在就是存活訊號

#### Scenario: attention 狀態的歧義
- **WHEN** Ghostex 的 activity 為 `attention`
- **THEN** SHALL 以 agent 自報的 program status 區分:`blocked` → `blocked`,`done` → `done`;沒有 program status 時 SHALL 印 `unknown`
- **AND** 理由:`attention` 同時代表「等待權限或回答」與「已完成但尚未被查看」

#### Scenario: 送出被拒
- **WHEN** `ghostex agents send` 因輸入框被對話框佔用而失敗,而 agent 仍存活
- **THEN** `prompt` SHALL 印出 `blocked`

#### Scenario: 等待收斂
- **WHEN** 訊息已送達
- **THEN** SHALL 輪詢狀態,直到觀察到 `working` 之後的第一個非 `working` 狀態;送出 10 秒後仍未觀察到 `working` 時,第一個非 `working` 狀態亦視為收斂 —— 短於輪詢間隔的回合可能整段被錯過,而是否完成由 findings 檔決定
