## Why

chezmoi 的 `.sh` interpreter 硬釘在 `~/scoop/apps/git/current/bin/bash.exe`（`.chezmoi.toml.tmpl` `[interpreters.sh]`），加上另外 3 處 git-bash 引用，使得**沒有 scoop 的機器無法 `chezmoi apply`**。scoop→chezmoi-external 系列已把所有工具移出 scoop，唯獨 git 仍是硬依賴。本輪（Wave 13）移除 chezmoi 對 scoop 的依賴（**scope A**：不卸載 scoop，scoop 仍可選用於 GUI app）。

git-bash 是**循環 bootstrap 依賴**（chezmoi 用它跑所有 `.sh`），故 git 無法改成 chezmoi-external——它必須維持「手動 prerequisite」，只是改用非-scoop 方式（建議 winget）。解法不是 hardcode 單一路徑，而是**偵測**已知的 Git-for-Windows 安裝位置。

## What Changes

**(1) git-bash 偵測（候選清單，非 hardcode 單路徑、非 `where bash`）**：
- 依序檢查已知 Git-for-Windows 安裝 root 的 `bin\bash.exe`（MSYSTEM wrapper），第一個存在者勝出。順序＝偏好，非-scoop 優先、scoop 殿後做 backward-compat：
  - (a) `~/.local/opt/git/bin/bash.exe`（PortableGit）
  - (b) `C:\Program Files\Git\bin\bash.exe`（winget / 官方安裝器）
  - (c) `~/scoop/apps/git/current/bin/bash.exe`（scoop — 相容舊機器）
- `.chezmoi.toml.tmpl` `[interpreters.sh]`：以 `stat`-based first-existing 掃描取代 hardcode 的 scoop 路徑（init 時 render）。
- `run_onchange_before_patch-chezmoi-config.ps1.tmpl`：同候選清單（PowerShell），外加可選的 `HKLM/HKCU\SOFTWARE\GitForWindows\InstallPath` registry probe（補捉非預設目錄的 winget/官方安裝；PortableGit/scoop 不寫此 key）。解析 git-bash、self-heal chezmoi config 的 interpreter；既有的 scoop-path guard 改檢查偵測到的路徑。

**(2) 重新指向另外 2 處 functional refs 到偵測到的 git root**：
- `dot_claude/modify_settings.json.sh.tmpl`：`git_bash` arg（現為 scoop 路徑）→ 偵測到的 bash 路徑。
- `run_onchange_install-gnupg.ps1.tmpl`：`pinentry-w32.exe`（現為 `~/scoop/apps/git/current/usr/bin/pinentry-w32.exe`）→ `<偵測 git root>/usr/bin/pinentry-w32.exe`。

**(3) README bootstrap（Windows）**：移除「git 一律透過 scoop」前提與 `scoop install git`/`scoop install chezmoi`，改 `winget install Git.Git` + `winget install twpayne.chezmoi`；scoop 僅保留為「選用於 GUI app」。**註**：`bootstrap-docs` spec 已要求 `winget install git.git`（line 8），現行 README 違反該 spec，本變更是 compliance 修正。

**(4) 瑣事**：修 `run_onchange_install-03-claude-config.ps1.tmpl:98` 過時提示——「Install with: scoop install dos2unix」改為提示重跑 `chezmoi apply`（external 已提供 dos2unix）。

**(5) 本機遷移**：`winget install Git.Git`，驗證偵測優先 Program Files git over scoop git，驗證 `chezmoi apply` 走新 bash；scoop git 留著但不再被引用。

## Capabilities

### New Capabilities
（無）

### Modified Capabilities
- `chezmoi-structure`：新增 requirement——`[interpreters.sh]` 的 git-bash 由候選清單偵測（非-scoop 優先、scoop backward-compat），不再 hardcode scoop 路徑；`patch-chezmoi-config` 以同清單 + registry probe self-heal。
- `bootstrap-docs`：README Windows bootstrap 改 winget 裝 git + chezmoi、移除 scoop git 前提（與既有 spec 對齊）。
- `gpg-provisioning`：pinentry-w32 路徑改由偵測到的 git root 解析，不再硬指 scoop。

## Impact

- `.chezmoi.toml.tmpl`：`[interpreters.sh]` 改 stat-based 偵測。
- `run_onchange_before_patch-chezmoi-config.ps1.tmpl`：候選清單 + registry probe + self-heal + guard 更新。
- `dot_claude/modify_settings.json.sh.tmpl`：git_bash arg 改偵測路徑。
- `run_onchange_install-gnupg.ps1.tmpl`：pinentry-w32 改偵測 git root。
- `run_onchange_install-03-claude-config.ps1.tmpl`：dos2unix 提示改 `chezmoi apply`。
- `README.md`：Windows bootstrap 改 winget。
- 既有 scoop 機器：偵測仍找到 scoop git（清單殿後），不破壞；本機 winget 裝 git 後改走 Program Files git。

## Out of Scope
- 卸載 scoop（`scoop uninstall scoop`）／移除 `~/scoop`。
- 遷移 GUI app。
- macOS/Linux 的 git（系統 / brew / apt 提供）。
