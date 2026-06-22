## ADDED Requirements

### Requirement: git-bash interpreter 由偵測候選清單解析（不再硬依賴 scoop）
Windows 上 chezmoi 的 `[interpreters.sh]` command SHALL 由「已知 Git-for-Windows 安裝 root 的有序候選清單」偵測解析，取第一個其 `bin\bash.exe` 存在者，而非硬指 `~/scoop/apps/git/current/bin/bash.exe`。候選順序 SHALL 為非-scoop 優先、scoop 殿後（backward-compat）：
1. `~/.local/opt/git/bin/bash.exe`（PortableGit）
2. `C:\Program Files\Git\bin\bash.exe`（winget / 官方安裝器）
3. `~/scoop/apps/git/current/bin/bash.exe`（scoop）

偵測 SHALL NOT 使用 PATH 搜尋（`where bash` / `lookPath`）——該方式會錯選 WSL `C:\Windows\System32\bash.exe` 或裸 `usr\bin\bash.exe`。候選 SHALL 以 `bin\bash.exe`（MSYSTEM wrapper）為準。

`.chezmoi.toml.tmpl` SHALL 在 render 時以 `stat`-based first-existing 掃描 static 清單寫入 interpreter。`run_onchange_before_patch-chezmoi-config.ps1.tmpl` SHALL 以同清單（PowerShell）外加可選的 `HKLM/HKCU\SOFTWARE\GitForWindows\InstallPath` registry probe 解析、並在 config 的 interpreter 與偵測不符時 self-heal 改寫；其既有 guard SHALL 檢查偵測到的 git-bash 路徑（非硬指 scoop）。

#### Scenario: 偵測優先非-scoop git
- **WHEN** 機器上同時有 `C:\Program Files\Git\bin\bash.exe`（winget）與 scoop git
- **THEN** `[interpreters.sh]` 解析為 Program Files 的 `bin\bash.exe`（清單 (2) 在 (3) 之前）

#### Scenario: 僅有 scoop git 的舊機器不破壞
- **WHEN** 機器上只有 scoop git
- **THEN** 偵測命中清單 (3)，interpreter 為 `~/scoop/apps/git/current/bin/bash.exe`，chezmoi apply 正常

#### Scenario: 非預設目錄的官方/winget 安裝由 registry probe 補捉
- **WHEN** git 由官方安裝器裝在非預設目錄（static 清單未命中），但 `HKLM\SOFTWARE\GitForWindows\InstallPath` 指向它
- **THEN** `patch-chezmoi-config` 經 registry probe 解析到該 git，self-heal 改寫 interpreter

#### Scenario: 不使用 PATH 搜尋
- **WHEN** 偵測 git-bash
- **THEN** 不呼叫 `where bash` / `lookPath`；不選用 `C:\Windows\System32\bash.exe` 或任何 `usr\bin\bash.exe`
