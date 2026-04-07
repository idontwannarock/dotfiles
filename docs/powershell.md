# PowerShell Profile

Windows PowerShell 設定檔（PS5 與 PS7 分開管理）。

## 管理方式

設定由 chezmoi 管理，部署到：

| 路徑 | 用途 |
|------|------|
| `~/Documents/PowerShell/` | PowerShell 7 profile |
| `~/Documents/WindowsPowerShell/` | Windows PowerShell 5 profile |
| `~/Documents/_shared-profile.d/` | PS5 + PS7 共用 fragments |

## 依賴

| 依賴 | 用途 | 備註 |
|------|------|------|
| [PowerShell](https://github.com/PowerShell/PowerShell) 5.1+ | Shell 環境 | Windows 內建 5.1；建議安裝 7+ |
| [Starship](https://starship.rs/) | Prompt 美化 | `90-prompt.ps1` |
| [Fastfetch](https://github.com/fastfetch-cli/fastfetch) | 開啟終端機時顯示系統資訊 | 選用，`25-fastfetch.ps1` |
| [PowerToys](https://github.com/microsoft/PowerToys) | PS7 CommandNotFound 模組 | 選用 |
| [winget](https://github.com/microsoft/winget-cli) | PS5 CommandNotFound 搜尋 | Windows 10/11 內建 |

## Worklog workflow trigger

`Documents/_shared-profile.d/10-aliases.ps1` 內建 `createnewlog` 函式，行為與 Bash 版完全一致：觸發遠端 `create-daily.yml` GitHub Actions workflow 並等待完成，不讀任何環境變數、不依賴 CWD、不做本地 git 操作。

詳見 [Bash 設定](bash.md#worklog-workflow-trigger)。

前置條件：本機已安裝並登入 [`gh` CLI](https://cli.github.com/)。
