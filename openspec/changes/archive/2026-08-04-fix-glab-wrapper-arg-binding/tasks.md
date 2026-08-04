## 1. 修 wrapper

- [x] 1.1 `26-glab.ps1`:移除 `[CmdletBinding()]` + `param(ValueFromRemainingArguments)`,
      改用 `$args`;`& $exe.Source @args`
      → 順帶補上 `Select-Object -First 1`(`Get-Command` 會回傳 PATH 上每一個同名執行檔)
- [x] 1.2 兩個守衛路徑改用 `[Console]::Error.WriteLine` 並設 `$global:LASTEXITCODE = 1`;
      錯誤字串維持與 bash 版逐字相同
      → 實際是三個守衛(host、token、binary not on PATH),三個都改
- [x] 1.3 更正檔頭的 token 來源敘述:兩個平台各有獨立的 store
      → 實測 WSL `/home/howardwang/.password-store` vs Windows `C:\Users\user\.password-store`
- [x] 1.4 補 UTF-8 BOM → `head -c 3 | xxd -p` = `efbbbf`

## 2. 釘住 regression

- [x] 2.1 `tests/glab-wrapper.Tests.ps1`:mock glab 逐行印出收到的 argv,斷言 `-d`、`-R`
      原樣送達且順序不變
- [x] 2.2 斷言守衛路徑訊息只有單一個 `glab: ` 前綴、走 stderr、退出碼 1
- [x] 2.3 `Invoke-Pester -Path tests -CI` → **24 passed / 0 failed**(3 個檔案)

## 3. 上機驗證

- [x] 3.1 用真實 `glab.exe`(`C:\Users\user\.local\bin\glab.exe`)透過 wrapper 跑
      `mr list -R owner/repo --help` 與 `mr create -d desc --help`:兩者都由 glab 自己
      解析並印出對應子命令的 help,無 PowerShell 繫結錯誤。以假 host + 假 token + `--help`
      執行,不送出任何網路請求、不碰真實 vault(mock 一支必定失敗的 gopass 走 env fallback)
