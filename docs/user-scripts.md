# User Scripts

輔助腳本，集中放在 `scripts/` 目錄。

## 腳本清單

| 腳本 | 平台 | 說明 |
|------|------|------|
| `set-worklogs-path.sh` | Linux/macOS | 搜尋並設定 `WORKLOGS_PATH` 環境變數 |
| `set-worklogs-path.ps1` | Windows | 同上（PowerShell 版） |
| `scoop-interactive-update.ps1` | Windows | 互動式更新 scoop 套件 |

## 依賴

| 依賴 | 用途 | 備註 |
|------|------|------|
| [Scoop](https://scoop.sh/) | `scoop-interactive-update.ps1` | 僅 Windows |
| [worklogs](https://github.com/idontwannarock/worklogs) repo | `set-worklogs-path.*` | 選用 |
