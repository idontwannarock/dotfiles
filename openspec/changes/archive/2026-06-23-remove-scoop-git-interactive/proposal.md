## Why

Wave 13 移除了 chezmoi 對 scoop git 的依賴（`.sh` interpreter 改為偵測 Git-for-Windows 安裝 root，scoop 殿後）。但**互動環境**仍剩一條對 scoop git 的硬依賴：Windows Terminal 的「Git Bash」profile 把 `commandline` 寫死成 `~\scoop\apps\git\current\bin\bash.exe`。只要這條還在，`scoop uninstall git` 就會讓 Git Bash 分頁啟動失敗。移除這最後一條依賴後，scoop git 即可安全卸載。

## What Changes

- **本機改 Windows Terminal「Git Bash」profile**：`commandline` 由 scoop 路徑改為 `C:\Program Files\Git\bin\bash.exe`（絕對路徑）。WT settings.json 目前不在 chezmoi 管理範圍，故為本機手動變更。
- **卸載 scoop git**：`scoop uninstall git`。
- **接受失去互動式 `sh`**：`sh` 目前僅由 scoop shims 提供，卸載後消失。不補救 —— chezmoi 執行 `.sh` 用的是偵測到的 `bin\bash.exe` **絕對路徑**，不靠互動 PATH；PowerShell 互動幾乎不手打 `sh`。
- **不新增 PATH 腳本**：`git` 已由 Machine PATH 的 `C:\Program Files\Git\cmd` 勝出；`gpg`（standalone external `~\.local\opt\gnupg`）與 `ssh`（Windows System32 OpenSSH）早已脫離 scoop。互動 `bash` 維持解析到 WSL（既有行為，與 scoop 無關）。
- **記錄 future TODO**：將 WT「Git Bash」profile 納入 chezmoi 管理（跨機器一致），留待後續變更處理。

## Capabilities

### New Capabilities
<!-- 無 -->

### Modified Capabilities
- `windows-toolchain-provisioning`: 新增需求——Windows 互動環境的 `git` 與 git-bash SHALL 解析到 Program Files（winget）git 而非 scoop git，使 scoop git 可被卸載且不破壞互動 shell 與 Git Bash 終端機 profile。

## Impact

- **本機（非 repo）**：Windows Terminal `settings.json` 的 Git Bash profile；移除 scoop `git` 套件。
- **repo**：僅 `windows-toolchain-provisioning` spec delta（終態需求）；無 chezmoi source 變更（偵測清單已 scoop 殿後，卸載後自然解析到 Program Files）。
- **memory**：`scoop-git-path-migration-todo` 標記完成；新增「chezmoi 管理 WT Git Bash profile」future TODO。
