# PowerShell Profile

Windows PowerShell 設定檔。

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

## Functions & Aliases

| Command | Description |
|---------|-------------|
| `which <command>` | 顯示指令的完整路徑（類似 Linux 的 which） |
| `wtsettings` | 用 vim 開啟 Windows Terminal 的 settings.json |
| `scoopupdate` | 互動式更新 scoop 套件 |
