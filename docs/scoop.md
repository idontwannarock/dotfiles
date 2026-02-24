# Scoop 設定

[Scoop](https://scoop.sh/) 套件管理器的匯出設定。

## 依賴

| 依賴 | 用途 | 備註 |
|------|------|------|
| [PowerShell](https://github.com/PowerShell/PowerShell) 5.1+ | 執行 Scoop 指令 | Windows 內建 |
| [Scoop](https://scoop.sh/) | 套件管理器 | 見下方安裝方式 |

## TL;DR

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
scoop import ./scoop/scoopfile.json
```
