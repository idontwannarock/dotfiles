## MODIFIED Requirements

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

## ADDED Requirements

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
