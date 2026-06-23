## ADDED Requirements

### Requirement: Windows 互動環境的 git 與 git-bash 不依賴 Scoop

系統 SHALL 確保 Windows 互動環境（PowerShell / cmd / Windows Terminal）的 `git` 與 git-bash 解析到 Program Files（winget / 官方安裝）git，而非 scoop git，使 scoop git 可被卸載而不破壞互動 shell 與終端機 profile。git 為手動 bootstrap 前置（非 chezmoi 安裝），故此需求以「終態解析結果」與「終端機 profile 指向」表達，不要求新增安裝/遷移腳本。

互動 `bash` 解析到 WSL（`C:\Windows\System32\bash.exe`）為既有行為、與 scoop 無關，不在本需求範圍；互動 `sh`（先前僅由 scoop shims 提供）於卸載後消失為可接受結果——chezmoi 執行 `.sh` 用偵測到的 `bin\bash.exe` 絕對路徑，不依賴互動 PATH。

#### Scenario: 互動 git 解析到 Program Files git
- **WHEN** 全新登入 shell 執行 `where.exe git`
- **THEN** 第一個結果為 `C:\Program Files\Git\cmd\git.exe`（由 Machine PATH 提供，排在所有 scoop 的 User PATH 條目之前），非 `~\scoop\apps\git\...`

#### Scenario: Windows Terminal Git Bash profile 指向 Program Files git
- **WHEN** 開啟 Windows Terminal「Git Bash」分頁
- **THEN** 啟動的 `commandline` 為 `C:\Program Files\Git\bin\bash.exe`，分頁正常開啟且不依賴 scoop git

#### Scenario: 卸載 scoop git 後互動環境不破壞
- **WHEN** 執行 `scoop uninstall git` 後，於全新登入 shell 檢查
- **THEN** `scoop list` 不含 `git`；`git`、`gpg`、`ssh` 仍正常解析（`git` → `C:\Program Files\Git\cmd`、`gpg` → `~\.local\opt\gnupg\bin`、`ssh` → `C:\Windows\System32\OpenSSH`），且 Windows Terminal「Git Bash」分頁仍可開啟
