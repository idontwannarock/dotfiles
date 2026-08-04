## ADDED Requirements

### Requirement: wrapper SHALL 原封不動轉交所有參數給被包的 CLI

wrapper SHALL 把使用者給的每一個參數原封不動轉交給 `glab`,SHALL NOT 依賴任何會先行解讀參數的繫結機制。

PowerShell 的 `[CmdletBinding()]` 加 `ValueFromRemainingArguments` 會先做具名參數繫結,而 common parameter 支援前綴比對,於是被包 CLI 的短旗標會被吃掉或造成繫結失敗。裸 function 的 `$args` 不做繫結。

#### Scenario: 與 common parameter 撞名的短旗標仍然送達

- **WHEN** 使用者執行 `glab mr create -d "描述"`(`-d` 是 glab 的 `--description`,同時是 PowerShell `-Debug` 的前綴)
- **THEN** `glab` 收到的參數序列包含 `-d` 與其值,順序與使用者輸入相同

#### Scenario: 不與 common parameter 撞名的短旗標不因繫結而失敗

- **WHEN** 使用者執行 `glab mr list -R owner/repo`
- **THEN** 命令送達 `glab`,不出現 PowerShell 的參數繫結錯誤

### Requirement: 兩個平台的 wrapper 在錯誤路徑上 SHALL 產出相同的字串、串流與退出碼

同一支 wrapper 的兩個平台實作 SHALL 在錯誤路徑上輸出逐字相同的訊息、寫到同一種串流(stderr)、並以相同的非零碼結束。

`Write-Error` 會再前綴一次 function 名並走 error stream,兩者都與 bash 的 `printf >&2` 不同;宣稱一致而實際不一致,比一開始就不宣稱更糟。

#### Scenario: 錯誤訊息不被重複前綴

- **WHEN** 在 `GITLAB_HOST` 未設定的 Windows shell 呼叫 `glab`
- **THEN** stderr 上的訊息以單一個 `glab: ` 開頭,與 bash 版逐字相同

#### Scenario: 守衛路徑回報非零退出碼

- **WHEN** wrapper 因 host 未設定或取不到 token 而拒絕呼叫 `glab`
- **THEN** 後續讀取退出碼者看到非零值,而非上一個命令留下的舊值

### Requirement: 含非 ASCII 的 profile 片段 SHALL 帶 UTF-8 BOM

`Documents/_shared-profile.d/` 底下含非 ASCII 的 `.ps1` SHALL 以 UTF-8 BOM(`EF BB BF`)開頭。

這些片段同時被 PS 5.1 與 PS 7 的 profile loader dot-source,而 PS 5.1 的 parser 對無 BOM 檔案退回系統 ANSI codepage,中文序列 mojibake 後可能吃掉引號,並在無關的行報出 parser 錯誤。

#### Scenario: 片段的前三個位元組

- **WHEN** 檢查 `Documents/_shared-profile.d/` 下任一含非 ASCII 的 `.ps1`
- **THEN** 檔案前三個位元組為 `EF BB BF`
