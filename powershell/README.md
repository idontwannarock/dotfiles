# PowerShell Profile

Windows PowerShell 設定檔。

## 依賴

| 依賴 | 用途 | 備註 |
|------|------|------|
| [PowerShell](https://github.com/PowerShell/PowerShell) 5.1+ | Shell 環境 | Windows 內建 5.1；建議安裝 7+ |
| [Starship](https://starship.rs/) | Prompt 美化 | `99-prompt.ps1` |
| [Fastfetch](https://github.com/fastfetch-cli/fastfetch) | 開啟終端機時顯示系統資訊 | 選用，`25-fastfetch.ps1`，未安裝時靜默跳過 |
| [onefetch](https://github.com/o2sh/onefetch) | 進入 Git 專案時顯示 repo 資訊 | 選用，`30-git-greeter.ps1` |
| [Git](https://git-scm.com/) | `30-git-greeter.ps1` 偵測 Git 專案 | 選用，未安裝時 greeter 不生效 |
| [Vim](https://www.vim.org/) | `wtsettings` 函數編輯 WT 設定 | 選用，`20-functions.ps1` |
| [PowerToys](https://github.com/microsoft/PowerToys) | PS7 CommandNotFound 模組 | 選用，未安裝時靜默跳過 |
| [winget](https://github.com/microsoft/winget-cli) | PS5 CommandNotFound 搜尋套件 | 選用，Windows 10/11 內建 |

## 安裝

```powershell
Copy-Item -Path Microsoft.PowerShell_profile.ps1 -Destination $PROFILE
```

> `profile.d` 資料夾和 `Microsoft.PowerShell_profile.ps1` 必須放在相同目錄，PowerShell 7 是 `~/Documents/PowerShell`，PowerShell 5.1 是 `~/Documents/WindowsPowerShell`。

> **注意：** Windows PowerShell 5.x 的 profile 檔案必須使用 CRLF 換行符號，否則會出現語法錯誤。

## Profile 模組化結構

PowerShell profile 採用模組化設計，將設定拆分到 `profile.d/` 目錄下：

| 檔案 | 說明 |
|------|------|
| `00-encoding.ps1` | UTF-8 編碼設定、Clear-Host |
| `10-aliases.ps1` | 常用別名定義 |
| `20-functions.ps1` | 自訂函數（which, wtsettings 等） |
| `25-fastfetch.ps1` | 開啟終端機時顯示 fastfetch 系統資訊 |
| `30-git-greeter.ps1` | 進入 Git 專案時顯示 onefetch |
| `99-prompt.ps1` | Starship prompt、Windows Terminal 整合、CommandNotFound 功能 |

## Windows Terminal 整合

透過 `Invoke-Starship-PreCommand` 函數發送 OSC 9;9 escape sequence，讓 Windows Terminal 知道當前工作目錄。

**功能：**
- Split pane (`Alt+Shift+D`) 時自動繼承當前目錄
- 需要在 Windows Terminal 設定 `splitMode: duplicate`

**Windows Terminal 設定範例：**
```json
{
    "actions": [
        {
            "command": {
                "action": "splitPane",
                "split": "auto",
                "splitMode": "duplicate"
            },
            "keys": "alt+shift+d"
        }
    ]
}
```

**參考：** [Opening a tab/pane in the same directory - Microsoft Learn](https://learn.microsoft.com/en-us/windows/terminal/tutorials/new-tab-same-directory)

## CommandNotFound 功能

當輸入不存在的命令時，會自動搜尋 winget 並建議可安裝的套件：

- **PowerShell 7+**: 使用 PowerToys 的 `Microsoft.WinGet.CommandNotFound` 模組
- **Windows PowerShell 5.x**: 使用 `CommandNotFoundAction` 替代方案

### PowerShell 7+ 啟用方式

需要安裝 [PowerToys](https://github.com/microsoft/PowerToys) 並啟用 Command Not Found 功能：

```powershell
scoop install powertoys
```

安裝後開啟 PowerToys Settings → **Command Not Found** → 啟用功能

> 如果未安裝 PowerToys，PowerShell 7 會靜默跳過此功能，不會顯示錯誤。

## Functions & Aliases

| Command | Description |
|---------|-------------|
| `which <command>` | 顯示指令的完整路徑（類似 Linux 的 which） |
| `wtsettings` | 用 vim 開啟 Windows Terminal 的 settings.json |
| `scoopupdate` | 互動式更新 scoop 套件 |
| `createnewlog` | 建立新的 worklog（需設定 WORKLOGS_PATH） |
| `gitpushlog` | 推送 worklogs 變更（需設定 WORKLOGS_PATH） |

## 選用設定

### Worklogs 整合

如果你有使用 [worklogs](https://github.com/idontwannarock/worklogs) 專案，可執行設定腳本自動搜尋 repo 位置並設定環境變數：

```powershell
.\Set-WorklogsPath.ps1
```

此腳本會：
1. 優先使用 [Everything CLI](https://www.voidtools.com/) (`es.exe`) 快速搜尋
2. 若無 Everything，則從各磁碟根目錄遞迴搜尋
3. 找到後設定 `WORKLOGS_PATH` 環境變數（永久）

設定完成後重啟 shell，即可使用 `createnewlog` 和 `gitpushlog` 別名。

**推薦安裝 Everything 加速搜尋：**

> **注意：** 必須安裝完整版 `everything`，`everything-lite` 不支援 IPC。

```powershell
scoop install everything everything-cli
```

安裝後需啟用 Everything 服務：**工具** → **選項** → **一般** → 勾選 **「Everything 服務」**

**手動設定：**
```powershell
[Environment]::SetEnvironmentVariable("WORKLOGS_PATH", "D:\path\to\worklogs", "User")
```
