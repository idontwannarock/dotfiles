## ADDED Requirements

### Requirement: glab 的憑證採 vault 優先、env fallback 的惰性解析

`glab` 的存取權杖 SHALL 於**呼叫當下**取得,SHALL NOT 於 shell 啟動時取得。來源順序 SHALL 為:先讀本地 vault(Unix 用 `pass`、Windows 用 `gopass`,entry 名稱 `gitlab/corp-token`),讀不到時 fallback 到 `$GITLAB_TOKEN` 環境變數。

此形狀 SHALL 與 `claude-zai` wrapper 一致 —— 同一個 repo 只維持一種憑證慣例。

#### Scenario: vault 可用時使用 vault 的權杖
- **WHEN** `pass`(或 Windows 的 `gopass`)可執行且 `gitlab/corp-token` 存在
- **THEN** wrapper 以該值設定 `GITLAB_TOKEN` 後呼叫 `glab`,且該設定僅作用於這一次呼叫

#### Scenario: vault 不可用時 fallback 到環境變數
- **WHEN** vault 指令不存在、或 entry 讀取失敗
- **AND** `$GITLAB_TOKEN` 已設定
- **THEN** wrapper 使用該環境變數的值,不視為錯誤

#### Scenario: 兩個來源都沒有時給出可行動的錯誤
- **WHEN** vault 讀不到且 `$GITLAB_TOKEN` 未設定
- **THEN** wrapper 於 stderr 印出明指兩個來源的訊息並以非零狀態結束
- **AND** SHALL NOT 呼叫 `glab` —— 否則使用者看到的會是遠端回傳的 401,而非真正的原因

#### Scenario: shell 啟動不觸發 vault 解密
- **WHEN** 開啟一個新的 shell
- **THEN** 不執行任何 vault 讀取,因此不出現 gpg pinentry 提示

### Requirement: 缺少 GITLAB_HOST 時明確拒絕而非誤打 gitlab.com

`glab` 在 `GITLAB_HOST` 未設定時預設連向 `gitlab.com`,用 corp 權杖會得到 `401 Unauthorized` —— 一個指向權杖、實際成因卻是 host 的錯誤訊息。wrapper SHALL 於呼叫前檢查 `GITLAB_HOST`,未設定時 SHALL 直接失敗並說明成因。

#### Scenario: GITLAB_HOST 未設定
- **WHEN** 在 `GITLAB_HOST` 未設定的環境下呼叫 `glab`
- **THEN** wrapper 印出說明「host 未設定,參見 `docs/gitlab-corp-access.md`」的訊息並以非零狀態結束
- **AND** SHALL NOT 送出任何網路請求

### Requirement: repo 不得含有 corp FQDN

corp GitLab 的實際主機名 SHALL NOT 出現在本 repo 的任何檔案中 —— 本 repo 為公開 repo,且此慣例已由 `private_corp-multiplex`(「FQDN/IP host blocks stay machine-local」)與 `context/principles.md` 的刻意不重現機器狀態清單所確立。

`GITLAB_HOST` 的值 SHALL 由機器本地狀態提供(Windows registry `HKCU\Environment` 加上 `WSLENV` 傳遞進 WSL),SHALL NOT 由 chezmoi 管理。

#### Scenario: 機械驗證 repo 無 corp 主機名
- **WHEN** 對 repo 全文搜尋 corp 網域字串
- **THEN** 命中數為零

#### Scenario: 文件用 placeholder 說明設定步驟
- **WHEN** 閱讀 `docs/gitlab-corp-access.md` 的 `GITLAB_HOST` 設定段落
- **THEN** 該段以 placeholder(如 `gitlab.example.com`)呈現指令,並明說真實 FQDN 是刻意不寫在 repo 裡的

### Requirement: 每台機器的設定步驟與已知陷阱有文件

`docs/gitlab-corp-access.md` SHALL 記載:vault entry 的建立、`GITLAB_HOST` 的設定、`WSLENV` 的調整,以及兩個會導致誤診的已知陷阱 —— `glab auth status` 只看自己的 config store 因而謊報未認證(REST 操作其實正常),以及 `WSLENV` 的變更需要 `wsl --shutdown` 加上 Windows Terminal 完整重啟才生效。

文件 SHALL 一併記錄 native MCP 的探測結論,使下一個人不必盲目重測。

#### Scenario: 文件涵蓋兩個陷阱
- **WHEN** 閱讀該文件
- **THEN** 兩個陷阱各有一段說明,且緊鄰對應的操作步驟而非集中在文末

#### Scenario: 文件記錄 MCP 探測結論
- **WHEN** 閱讀該文件的 MCP 段落
- **THEN** 其載明探測日期、當時的 instance 版本、探測過的路徑,以及「未採用」的結論
