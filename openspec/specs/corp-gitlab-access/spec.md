# corp-gitlab-access Specification

## Purpose

規範 `glab` 對公司 GitLab 實例的存取如何跨平台重現:權杖於呼叫當下自本地 vault 取得(env 為 fallback)、host 由機器本地狀態提供,以及一條硬性邊界 —— corp 主機名不得進入本 repo(本 repo 為公開 repo)。並要求每台機器的一次性設定步驟、兩個會導致誤診的已知陷阱、以及 native MCP 的探測結論都有文件可查。
## Requirements
### Requirement: glab 的憑證採 vault 優先、env fallback 的惰性解析

`glab` 的存取權杖 SHALL 於**呼叫當下**取得,SHALL NOT 於 shell 啟動時取得。來源順序 SHALL 為:先讀本地 vault(Unix 用 `pass`、Windows 用 `gopass`,entry 名稱 `gitlab/corp-token`),讀不到時 fallback 到 `$GITLAB_TOKEN` 環境變數。

`glab` 自己的 config store SHALL NOT 作為權杖來源。這不只是一條慣例:wrapper SHALL 在每次呼叫前檢查 config store,發現權杖時 SHALL 拒絕呼叫。

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

#### Scenario: env 傳入的權杖不落地
- **WHEN** wrapper 以 `GITLAB_TOKEN` 呼叫 `glab` 完成一次操作
- **THEN** config store 內不含該權杖字串 —— glab 不將 env 來源寫回設定檔

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

### Requirement: wrapper SHALL 原封不動轉交所有參數給被包的 CLI

wrapper SHALL 把使用者給的每一個參數原封不動轉交給 `glab`,SHALL NOT 依賴任何會先行解讀參數的繫結機制。

PowerShell 的 `[CmdletBinding()]` 加 `ValueFromRemainingArguments` 會先做具名參數繫結,而 common parameter 支援前綴比對,於是被包 CLI 的短旗標會被吃掉或造成繫結失敗。裸 function 的 `$args` 不做繫結。

#### Scenario: 與 common parameter 撞名的短旗標仍然送達

- **WHEN** 使用者執行 `glab mr create -d "描述"`(`-d` 是 glab 的 `--description`,同時是 PowerShell `-Debug` 的前綴)
- **THEN** `glab` 收到的參數序列包含 `-d` 與其值,順序與使用者輸入相同

#### Scenario: 不與 common parameter 撞名的短旗標不因繫結而失敗

- **WHEN** 使用者執行 `glab mr list -R owner/repo`
- **THEN** 命令送達 `glab`,不出現 PowerShell 的參數繫結錯誤

### Requirement: 兩個平台的 wrapper 在錯誤路徑上 SHALL 產出相同的訊息文字與退出碼

同一支 wrapper 的兩個平台實作 SHALL 在錯誤路徑上輸出逐字相同的訊息文字、寫到 process 的 stderr、並以相同的非零碼結束(拒絕呼叫為 1,找不到執行檔為 127)。

`Write-Error` 會再前綴一次 function 名,且兩個版本的 PowerShell 都把 ErrorRecord 渲染成引用原始碼行的多行區塊,與 bash 的單行 `printf >&2` 相去甚遠。改用 `[Console]::Error` 的代價要一併寫進註解:PowerShell 的 `2>` 只重導自己的錯誤串流,攔不到 process stderr。行尾字元(CRLF vs LF)與非 ASCII 的編碼(仰賴 `00-encoding.ps1` 先設好 UTF-8)不在保證範圍內 —— 宣稱一致而實際不一致,比一開始就不宣稱更糟。

#### Scenario: 錯誤訊息不被重複前綴

- **WHEN** 在 `GITLAB_HOST` 未設定的 Windows shell 呼叫 `glab`
- **THEN** stderr 上的訊息以單一個 `glab: ` 開頭,與 bash 版逐字相同

#### Scenario: 守衛路徑回報非零退出碼

- **WHEN** wrapper 因 host 未設定或取不到 token 而拒絕呼叫 `glab`
- **THEN** 後續讀取退出碼者看到 1,而非上一個命令留下的舊值

#### Scenario: 找不到執行檔時回報 command-not-found

- **WHEN** PATH 上沒有 `glab` 執行檔
- **THEN** 退出碼為 127,與同 repo 其他 wrapper 對同一情境的取值一致

### Requirement: config store 內存有權杖時 wrapper SHALL 拒絕呼叫

`glab auth login` 與不帶 `--global` 的 `glab config set token …` 會繞過 wrapper,把權杖以**明文**寫進 config store 並永久保留。wrapper SHALL 在每次呼叫前檢查 config store;發現權杖時 SHALL NOT 呼叫 `glab`,SHALL 於 stderr 印出訊息並以 1 結束。

檢查範圍 SHALL 同時涵蓋 global store(`${GLAB_CONFIG_DIR:-~/.config/glab-cli}/config.yml`)與 repo-local store(`<git-dir>/glab-cli/config.yml`)。只涵蓋其一的守衛,其宣稱在另一半為假。

wrapper SHALL NOT 自動清除該權杖。清除會讓「權杖曾經明文落地、必須輪替」這個唯一重要的後果無聲消失。訊息 SHALL 載明輪替的要求,並 SHALL 指出清除必須繞過 wrapper —— 守衛擋下的是**每一次**呼叫,包含清除用的那一次。清除指令本身 SHALL 留在 `docs/gitlab-corp-access.md`,不寫進訊息:兩個平台的繞過語法不同,而訊息又被要求逐字相同,兩者無法同時成立。

#### Scenario: global store 有權杖
- **WHEN** `${GLAB_CONFIG_DIR:-~/.config/glab-cli}/config.yml` 內有非空的 `token:` 或 `job_token:`
- **THEN** wrapper 印出含該檔案路徑、輪替要求,以及「清除要繞過 wrapper、指令見文件」的訊息,以 1 結束
- **AND** SHALL NOT 呼叫 `glab`,SHALL NOT 讀取 vault(因此不觸發 gpg pinentry)

#### Scenario: repo-local store 有權杖
- **WHEN** 於某個 git repo 內呼叫,且 `<git-dir>/glab-cli/config.yml` 內有非空的 `token:`
- **THEN** wrapper 以同樣方式拒絕,訊息內的路徑指向該 repo-local 檔案

#### Scenario: 空值與註解不誤判
- **WHEN** config store 內的 `token:` 冒號後沒有值(glab 對未設定的 host 即為此形),或該行是 glab 自帶的說明註解(如 `# Your GitLab access token…`、`#   value: Bearer token123`)
- **THEN** 守衛放行,wrapper 照常呼叫 `glab`

#### Scenario: config store 不存在時放行
- **WHEN** config store 的檔案不存在
- **THEN** 守衛放行 —— 沒有檔案就沒有落地的權杖

#### Scenario: 守衛的訊息兩平台逐字相同
- **WHEN** 在 bash 與 PowerShell 上分別觸發此守衛
- **THEN** 兩者於 process stderr 輸出逐字相同的訊息文字,並以 1 結束

