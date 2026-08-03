## ADDED Requirements

### Requirement: shell_common 與 PowerShell profile 各提供一個 glab wrapper

`shell_common` SHALL 定義一個名為 `glab` 的 shell function,Windows 的 profile fragment SHALL 定義其 PowerShell 對應版本。兩者行為一致:解析權杖與 host,設定僅作用於單次呼叫的環境,再轉呼叫真正的 `glab` binary。

wrapper 以 `glab` 為名遮蔽 binary(與另取新名的 `claude-zai` 不同),因為每次 corp 呼叫都需要權杖,不存在「要呼叫未包裝版本」的情境。為避免無窮遞迴,轉呼叫 SHALL 明確指向 binary 而非函式名:bash 用 `command glab`,PowerShell 用 `Get-Command -CommandType Application`。

#### Scenario: bash 環境下 wrapper 生效且不遞迴
- **WHEN** WSL bash 啟動並 source `shell_common`,接著呼叫 `glab api version`
- **THEN** 呼叫抵達 `~/.local/bin/glab` 並成功回傳,過程中不發生函式自我遞迴

#### Scenario: PowerShell 環境下行為一致
- **WHEN** Windows PowerShell profile 載入後呼叫 `glab api version`
- **THEN** 得到與 bash 端相同的結果,錯誤訊息文字亦一致

#### Scenario: 環境設定不外洩到後續呼叫
- **WHEN** wrapper 呼叫結束
- **THEN** 呼叫端 shell 的 `GITLAB_TOKEN` 維持呼叫前的狀態(未設定就仍未設定)
