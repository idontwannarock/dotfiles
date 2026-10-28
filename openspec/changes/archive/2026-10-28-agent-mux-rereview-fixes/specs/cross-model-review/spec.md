## MODIFIED Requirements

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
- **AND** herdr 後端的狀態檔 SHALL 只記錄 `backend=herdr` 與 terminal id,SHALL NOT 記錄 pane id;`close` 時以 terminal id 在 `herdr api snapshot` 中找出目前的 pane —— pane id 在 pane move 後可能改變,存下來會過期,而 `start` 之後沒有任何動詞需要它
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
- **AND** `unknown`(已收斂、未能分類)SHALL 與 `idle` 同樣使等待結束;只有查詢失敗 SHALL 被跳過而繼續等待
- **AND** 兩者 SHALL 在腳本內以不同的字表示 —— 共用同一個字時,已收斂而未分類的 agent 會被當成查詢失敗,一路等到 timeout

#### Scenario: ghostex state 查詢失敗
- **WHEN** `start` 呼叫 `ghostex state` 失敗
- **THEN** 錯誤訊息 SHALL 只說 `ghostex state failed` 與其原因,SHALL NOT 另外宣稱 repo 不在任何 Ghostex project 中
