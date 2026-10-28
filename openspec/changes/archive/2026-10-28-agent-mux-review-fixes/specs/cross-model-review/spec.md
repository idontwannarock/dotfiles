## MODIFIED Requirements

### Requirement: 禮貌退出為 best-effort,不得成為保證的前提

收尾 SHALL 先嘗試讓對造自行結束(送出該 agent 自身的結束指令),使其 SessionEnd hook、transcript flush 與自起的子行程有機會正常收尾。

該步驟 SHALL 有時限。逾時或失敗時 SHALL NOT 重試、SHALL NOT 阻斷後續步驟 —— 關閉與確認 SHALL 無條件執行。

`agent-mux exit` SHALL 在每個後端、每次都先送出取消鍵(Escape),等 1 秒,再送結束指令;若仍無效,直接進入強制關閉。SHALL NOT 以狀態為 `blocked` 作為送取消鍵的條件——啟動期的對話框(Codex 的更新提示、信任提示)在 herdr 回報為 `done` 或 `idle`,在 Ghostex 回報為 idle,而在 Codex 的更新提示上按 Enter 會選中「立即更新」(2026-10-28 實測)。

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

#### Scenario: 對話框回報為 idle 時退出
- **WHEN** 對造停在啟動期對話框上,而多工器回報 `idle` 或 `done`
- **THEN** `agent-mux exit` SHALL 先送 Escape,之後才送結束指令,兩個後端皆同

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
- **AND** SHALL 在 `idle`、`done` 與 `unknown` 時以 0 結束,其餘以 1 結束 —— 三者都表示「已收斂,去讀 findings 檔」,與 skill 的判定表一致

#### Scenario: close 只碰 start 開的終端
- **WHEN** 呼叫 `agent-mux close <name>`
- **THEN** SHALL 只關閉同名 `start` 記錄下來的終端,並以多工器自己的清單確認它已消失
- **AND** 清單本身讀取失敗時 SHALL 以非零結束,SHALL NOT 當作「已消失」
- **AND** herdr 後端 SHALL 在 `start` 時記錄 pane 的 terminal id,`close` 時以它在 `herdr api snapshot` 中找出目前的 pane —— pane id 在 pane move 後會變,terminal id 不會
- **AND** `herdr pane close` 失敗,或關閉後該 terminal 仍在 snapshot 中時,SHALL 以非零結束並保留狀態檔,使 skill 回報 `teardown not confirmed`

#### Scenario: 狀態檔的後端必須有效
- **WHEN** 狀態檔記載的後端不是 `herdr` 或 `ghostex`
- **THEN** 每個讀取狀態檔的動詞 SHALL 以可讀的錯誤結束,SHALL NOT 嘗試呼叫不存在的後端函式

### Requirement: Ghostex 後端的對應做法

Ghostex 沒有 split pane。`agent-mux` SHALL 以 repo 所屬 Ghostex project 中的一個新 session 作為對等物。

#### Scenario: linked worktree
- **WHEN** repo 是某個 Ghostex project 的 linked worktree
- **THEN** `start` SHALL 選用該 project —— 判準為路徑相同,或 `git rev-parse --path-format=absolute --git-common-dir` 相同
- **AND** session 的 cwd SHALL 為該 worktree(`create-session --cwd`),SHALL NOT 為 project 的路徑

#### Scenario: repo 不是 Ghostex project
- **WHEN** repo 既不等於任何 Ghostex project 的路徑,也不與任何 project 共用 git common directory
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

## ADDED Requirements

### Requirement: 查詢失敗不等於 agent 已消失

`agent-mux` 的存活判定 SHALL 區分三種結果:存活、已消失、查詢失敗。查詢失敗(命令失敗、輸出為空、或 Ghostex 回 `ok` 不為 true)SHALL NOT 被當作已消失。原因 SHALL 寫到 stderr。

理由:把一次 gxserver 的短暫失誤當成「已消失」,會讓 `prompt` 印 `gone`、`exit` 不送結束指令就印 `exited`、`start` 誤報「agent 在啟動時退出」。

#### Scenario: 存活查詢失敗
- **WHEN** 多工器的查詢失敗
- **THEN** `alive` SHALL 印 `unknown` 並以 2 結束;`state` SHALL 印 `unknown`;`prompt` SHALL 印 `failed`,SHALL NOT 送出文字;`exit` SHALL 印 `unknown` 並以 1 結束,SHALL NOT 送出按鍵

#### Scenario: session 不在清單中
- **WHEN** Ghostex 的查詢成功,而 session 不在清單中,或其 `providerSessionState` 不是 `exists`
- **THEN** SHALL 判定為已消失

#### Scenario: Ghostex 的 session 清單落後於終端
- **WHEN** Ghostex 的 `providerSessionState` 為 `exists`
- **THEN** SHALL 再以 `ghostex read-text <ref> --lines 1 --json` 詢問終端本身:成功 → 存活;錯誤含 `does not exist` → 已消失;其他錯誤 → 查詢失敗
- **AND** SHALL 只用其結束狀態與錯誤訊息,SHALL NOT 使用讀到的文字
- **AND** 理由:2026-10-28 實測,終端結束後 `providerSessionState` 仍讀作 `exists` 約 30 秒

#### Scenario: 啟動期間查詢失敗
- **WHEN** `start` 在等待 agent 就緒時遇到查詢失敗
- **THEN** SHALL 繼續等待到時限,SHALL NOT 判定 agent 已退出
