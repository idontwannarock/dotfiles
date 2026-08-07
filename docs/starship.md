# Starship

[Starship](https://starship.rs/) 跨平台終端機 prompt 設定。

## 管理方式

設定檔由 chezmoi 管理，部署到 `~/.config/starship.toml`。Starship 本身也會在 `chezmoi apply` 時自動安裝。

**路徑不可更動。** `~/.config/starship.toml` 是 starship 唯一的預設搜尋路徑，`~/.config/starship/` 子目錄不會被讀取。設定檔找不到時 starship 不報錯，會套用內建預設值照常畫出 prompt——換言之放錯路徑跟正常運作長得一模一樣。設定曾經一度放在子目錄，`command_timeout` 因此靜默失效（見 `home/.chezmoiremove` 的說明）。若真要換路徑，必須同時在每個 shell 的 rc 匯出 `STARSHIP_CONFIG`。

## 設定說明

| 設定 | 值 | 說明 |
|------|-----|------|
| `command_timeout` | `1000` | 指令超時時間（毫秒），預設 500ms 在 Windows 上容易因 Defender 即時掃描導致 git 指令超時 |
| `shell.disabled` | `false` | 啟用 shell indicator（預設關閉），顯示當前 prompt 屬於哪個 shell |

### Shell indicator

所有 shell 共用同一份設定，畫面完全相同，靠這個模組區分。Indicator 顯示在 `❯` 正前方。

| Shell | 顯示 |
|-------|------|
| Bash（Git Bash / Linux / WSL） | `bash` |
| Zsh（macOS） | `zsh` |
| Windows PowerShell 5.1 | `ps5` |
| PowerShell 7+ | `pwsh` |
| cmd | `cmd` |
| 其他 | `?sh` |

兩個容易踩到的預設值：

- `pwsh_indicator` 預設未設定，會退回 `powershell_indicator`，因此**不明確指定就無法區分 PowerShell 5.1 與 7+**。兩者的判別來自 starship 自己的 init script，它依 `$PSVersionTable.PSVersion.Major` 把 `STARSHIP_SHELL` 設為 `powershell` 或 `pwsh`；`~/Documents/shared-profile.d/90-prompt.ps1` 一份 profile 兩邊共用即可，版本判斷在執行期發生。
- `unknown_indicator` 預設是空字串，未知 shell 會靜默不顯示。這裡設為 `?sh`，讓異常看得見。

模組判斷依據是 init script 寫入的 `STARSHIP_SHELL` 環境變數，不是 parent process，因此顯示的是「執行過 starship init 的那個 shell」。
