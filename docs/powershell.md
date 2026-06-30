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
| [PowerShell 7](https://github.com/PowerShell/PowerShell) | Shell 環境 + chezmoi `.ps1` interpreter | Windows 內建僅 5.1；chezmoi 預設用 **pwsh 7** 執行 `.ps1` 安裝腳本（無 fallback），屬 bootstrap 前置條件，見 [README](../README.md) Bootstrap |
| [Starship](https://starship.rs/) | Prompt 美化 | `90-prompt.ps1` |
| [Fastfetch](https://github.com/fastfetch-cli/fastfetch) | 開啟終端機時顯示系統資訊 | 選用，`25-fastfetch.ps1` |
| [PowerToys](https://github.com/microsoft/PowerToys) | PS7 CommandNotFound 模組 | 選用 |
| [winget](https://github.com/microsoft/winget-cli) | PS5 CommandNotFound 搜尋 | Windows 10/11 內建 |

## pwsh 7：MSIX（Store）vs MSI

`winget install Microsoft.PowerShell` 交付的是 **MSIX（Store）**版（`winget show` → `Installer Type: msix`）：落在版本化的 `WindowsApps`、靠可被關閉的 App Execution Alias 上 PATH，提權安裝會 `0x80070005`，winget 永遠裝不出 `C:\Program Files\PowerShell\7`。MSIX 版當 chezmoi 的 `.ps1` interpreter **完全堪用**。

若偏好乾淨的 **MSI** 版（標準路徑、非 Store、實體 exe 直接上 Machine PATH），真正的 MSI 只在 [GitHub Releases](https://github.com/PowerShell/PowerShell/releases) 提供（`PowerShell-<ver>-win-x64.msi`）。

- **一鍵切換**：已是 MSIX 的機器，提權執行部署到 `~/.local/bin/switch-pwsh-to-msi.ps1` 的 helper（移除 MSIX → 抓 GitHub 最新穩定版 MSI → 驗簽 → `msiexec` 安裝 → 驗證）。
- **apply 提醒**：`run_warn-pwsh-msix.ps1.tmpl` 會在每次 `chezmoi apply` 偵測到 MSIX pwsh 時 `Write-Warning` 提示（不自動切換 —— 需 admin、具破壞性、且 pwsh 是 `.ps1` interpreter 的 chicken-and-egg）。
- **後續更新**：winget 仍把它視為 MSIX，`winget upgrade` 可能想換回 Store；改用 GitHub MSI 覆蓋安裝，或 `winget pin add --id Microsoft.PowerShell`。

## Worklog workflow trigger

`Documents/_shared-profile.d/10-aliases.ps1` 內建 `createnewlog` 函式，行為與 Bash 版完全一致：觸發遠端 `create-daily.yml` GitHub Actions workflow 並等待完成，不讀任何環境變數、不依賴 CWD、不做本地 git 操作。

詳見 [Bash 設定](bash.md#worklog-workflow-trigger)。

前置條件：本機已安裝並登入 [`gh` CLI](https://cli.github.com/)。
