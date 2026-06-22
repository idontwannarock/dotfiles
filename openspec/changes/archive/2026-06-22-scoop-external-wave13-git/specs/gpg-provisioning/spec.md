## ADDED Requirements

### Requirement: gpg-agent pinentry-w32 由偵測到的 git root 解析（不再硬依賴 scoop）
`run_onchange_install-gnupg.ps1.tmpl` 設定 gpg-agent.conf 的 `pinentry-program` 時，SHALL 由「已知 Git-for-Windows 安裝 root 的有序候選清單」（同 chezmoi-structure 的偵測：`~/.local/opt/git` → `C:\Program Files\Git` → scoop，並含 `HKLM/HKCU\SOFTWARE\GitForWindows\InstallPath` registry probe）解析 `<git root>\usr\bin\pinentry-w32.exe`，而非硬指 `~/scoop/apps/git/current/usr/bin/pinentry-w32.exe`。若偵測不到任何 git（無 pinentry-w32），SHALL 維持既有 fallback 至 GnuPG 自帶的 `pinentry-basic.exe`。

#### Scenario: 有非-scoop git 時用其 pinentry-w32
- **WHEN** 機器上有 `C:\Program Files\Git`（winget）
- **THEN** gpg-agent.conf 的 `pinentry-program` 指向 `C:\Program Files\Git\usr\bin\pinentry-w32.exe`

#### Scenario: 無任何 git 時 fallback
- **WHEN** 偵測不到任何候選 git root 的 `usr\bin\pinentry-w32.exe`
- **THEN** `pinentry-program` fallback 至 `~/.local/opt/gnupg/.../pinentry-basic.exe`（既有行為）
