These are all custom scripts for personal use.

If it is in Windows, the scripts in `local/bin` should go to `~/.local/bin` folder, `/usr/local/bin` in Linux or MacOS.

# Windows

```powershell
Copy-Item -Path ".local/bin" -Destination "~/.local/bin" -Recurse -Force
Copy-Item -Path Microsoft.PowerShell_profile.ps1 -Destination $PROFILE
```

> `profile.d` folder and `Microsoft.PowerShell_profile.ps1` should be placed in the same directory, either in `~/Documents/PowerShell` for PowerShell 7 or `~/Documents/WindowsPowerShell` for PowerShell 5.1.

## Profile 模組化結構

PowerShell profile 採用模組化設計，將設定拆分到 `profile.d/` 目錄下：

| 檔案 | 說明 |
|------|------|
| `00-encoding.ps1` | UTF-8 編碼設定、Clear-Host |
| `10-aliases.ps1` | 常用別名定義 |
| `20-functions.ps1` | 自訂函數（which, wtsettings 等） |
| `30-git-greeter.ps1` | 進入 Git 專案時顯示 onefetch |
| `99-prompt.ps1` | Starship prompt、CommandNotFound 功能 |

## CommandNotFound 功能

當輸入不存在的命令時，會自動搜尋 winget 並建議可安裝的套件：

- **PowerShell 7+**: 使用 PowerToys 的 `Microsoft.WinGet.CommandNotFound` 模組
- **Windows PowerShell 5.x**: 使用 `CommandNotFoundAction` 替代方案

## PowerShell Functions & Aliases

| Command | Description |
|---------|-------------|
| `which <command>` | 顯示指令的完整路徑（類似 Linux 的 which） |
| `wtsettings` | 用 vim 開啟 Windows Terminal 的 settings.json |
