## ADDED Requirements

### Requirement: createnewlog 觸發 GitHub workflow 而非本地操作
`createnewlog` SHALL 在 PowerShell 與 POSIX shell（bash/zsh）下皆以**函式**形式定義（不是 alias），行為為觸發遠端 `create-daily.yml` GitHub Actions workflow 並等待其完成，不執行任何本地 git 操作。

#### Scenario: 從任意 CWD 觸發成功
- **WHEN** 使用者在任一目錄（包含非 git repo 的 `~` 或 `/tmp`）執行 `createnewlog`
- **THEN** 函式呼叫 `gh -R idontwannarock/worklogs workflow run create-daily.yml`，成功觸發 workflow 並繼續後續步驟，不會因為 CWD 不是 git repo 而失敗

#### Scenario: 等待 workflow run 完成
- **WHEN** workflow 已觸發
- **THEN** 函式透過 `gh -R idontwannarock/worklogs run list --workflow=create-daily.yml --limit=1 --json databaseId --jq '.[0].databaseId'` 取得剛觸發的 run ID，接著執行 `gh -R idontwannarock/worklogs run watch <id> --exit-status` 阻塞直到 run 完成

#### Scenario: 完成後不做本地 checkout
- **WHEN** workflow run 成功完成
- **THEN** 函式印出完成訊息後返回；**不執行** `git fetch` / `git checkout` / `git pull` 等本地 git 指令

### Requirement: createnewlog 不依賴環境變數或 CWD
`createnewlog` 的執行 SHALL 不讀取 `WORKLOGS_PATH` 環境變數，也不依賴 CWD 為 worklogs repo。

#### Scenario: 未設 WORKLOGS_PATH 仍可用
- **WHEN** shell session 完全沒有 `WORKLOGS_PATH` 環境變數
- **THEN** `createnewlog` 正常運作

#### Scenario: WORKLOGS_PATH 指向不存在路徑時不影響
- **WHEN** `WORKLOGS_PATH=/nonexistent/path` 已 export
- **THEN** `createnewlog` 仍正常運作，不讀取該變數也不檢查該路徑

### Requirement: repo 名稱 hardcode 於函式內
函式實作 SHALL 直接 hardcode `idontwannarock/worklogs` 為 `gh -R` 的值，不透過任何設定檔或環境變數間接指定。

#### Scenario: 變更 repo 需改 dotfiles 原始碼
- **WHEN** 使用者希望改用不同的 worklogs repo
- **THEN** 必須直接編輯 `Documents/exact__shared-profile.d/10-aliases.ps1` 與 `.chezmoitemplates/shell-common/base` 內的 hardcode 字串

### Requirement: 觸發失敗時報錯並退出
`createnewlog` SHALL 在 `gh workflow run`、`gh run list`、或 `gh run watch` 任一步驟失敗時，印出可辨識的錯誤訊息並以非零狀態碼退出（函式 return 非零；PowerShell 以 `Write-Error` + `return` 表達）。

#### Scenario: gh workflow run 失敗
- **WHEN** `gh workflow run` 返回非零 exit code（例如未登入、repo 不存在）
- **THEN** 函式印出錯誤訊息並立即退出，不繼續後續步驟

#### Scenario: 找不到 run ID
- **WHEN** `gh run list` 成功但 JSON 查詢結果為空
- **THEN** 函式印出「錯誤：找不到 workflow run」並退出非零

#### Scenario: run watch 失敗
- **WHEN** `gh run watch --exit-status` 返回非零（run 失敗或被取消）
- **THEN** 函式以同樣的非零 exit code 退出

### Requirement: gitpushlog 不存在於 dotfiles
Dotfiles SHALL NOT 提供任何名為 `gitpushlog` 的 alias、函式或 script 進入使用者的 shell。

#### Scenario: PowerShell session 無 gitpushlog
- **WHEN** 使用者在 PS5 或 PS7 session 執行 `Get-Command gitpushlog -ErrorAction SilentlyContinue`
- **THEN** 查無此命令（由 dotfiles 提供的話）

#### Scenario: bash/zsh session 無 gitpushlog
- **WHEN** 使用者在 bash/zsh session 執行 `type gitpushlog`
- **THEN** 查無此命令（由 dotfiles 提供的話）

### Requirement: 跨平台行為一致
PowerShell 版本與 POSIX shell 版本的 `createnewlog` SHALL 有等價的可觀測行為：相同的 gh 指令序列、相同的錯誤處理語意、相同的退出碼策略。

#### Scenario: PS 與 bash 行為對照
- **WHEN** 分別在 Windows PowerShell 7 與 Linux bash 執行 `createnewlog`
- **THEN** 兩者都 (a) 觸發 `gh -R idontwannarock/worklogs workflow run create-daily.yml`, (b) 取得 run ID, (c) 執行 `gh run watch`, (d) 全部成功則退出 0，任一步驟失敗則退出非零
