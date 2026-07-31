# User Scripts

供使用者手動執行的輔助腳本。原始碼位於 `home/dot_local/bin/`，經 chezmoi 部署到 `~/.local/bin/`。

> 新增腳本一律放 `home/dot_local/bin/`。為什麼這條分界是雙向的、放錯會怎樣，見 [`context/`](../context/index.md) 的詞彙表 `.chezmoiroot` 條目。

## 腳本清單

| 腳本 | 平台 | 說明 | 呼叫方式 |
|------|------|------|----------|
| `scoop-interactive-update.ps1` | Windows | 互動式更新 scoop 套件 | `scoopupdate` alias |
| `switch-pwsh-to-msi.ps1` | Windows | 將 Microsoft Store（MSIX）版 PowerShell 7 換成官方 MSI 版 | 手動執行，需系統管理員權限 |

## 依賴

| 依賴 | 用途 | 備註 |
|------|------|------|
| [Scoop](https://scoop.sh/) | `scoop-interactive-update.ps1` | 僅 Windows |
