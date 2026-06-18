## ADDED Requirements

### Requirement: dos2unix 在 Windows 上由 chezmoi-external 單檔提供
Windows 上 `dos2unix.exe` SHALL 由 `.chezmoiexternal.toml` 以 `type = "archive-file"` 自 `https://waterlander.net/dos2unix/files/dos2unix-<version>-win64.zip` 取出 `bin/dos2unix.exe` 至 `~/.local/bin/dos2unix.exe`（單檔 standalone，無 DLL 依賴）。版本以 chezmoi template 變數 pinning。其他三個 binary（mac2unix/unix2dos/unix2mac）非本 repo 所需，不提取。

#### Scenario: Windows 上取得 dos2unix.exe
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `~/.local/bin/dos2unix.exe` 存在且可執行（`dos2unix.exe --version` 正常輸出）

#### Scenario: 版本 pinning 跨機器 reproducible
- **WHEN** 同一 commit 在不同機器執行 chezmoi apply
- **THEN** 取得的 dos2unix 版本一致（採 pinned 版本變數，不使用 rolling URL）

### Requirement: install-prereqs 不再經 Scoop 安裝 dos2unix
`run_onchange_before_install-prereqs.ps1.tmpl` SHALL NOT 呼叫 `scoop install dos2unix`（或經 `Ensure-ScoopTool "dos2unix"`）。dos2unix 由 `.chezmoiexternal.toml` 提供；腳本可保留註解標明此事（比照既有 jq 的處理）。

#### Scenario: prereqs 不主動裝 scoop dos2unix
- **WHEN** 在 Windows 上執行 prereqs 腳本
- **THEN** 不執行 `scoop install dos2unix`；後續 phase 仍能用到 `~/.local/bin/dos2unix.exe`（chezmoi-external 在 file 階段已部署）

### Requirement: jdtls 不再由 install-03 經 Scoop 安裝（補修 Wave 11）
`run_onchange_install-03-claude-config.ps1.tmpl` SHALL NOT 呼叫 `scoop install jdtls`。jdtls 已於 Wave 11 由 `.chezmoiexternal.toml` 提供（`~/.local/opt/jdtls`）；此 leftover 移除後，install-03 不會在 hash 變動時把 jdtls 重新裝回 scoop。

#### Scenario: install-03 不重裝 scoop jdtls
- **WHEN** `run_onchange_install-03-claude-config.ps1.tmpl` 在 Windows 執行
- **THEN** 不執行 `scoop install jdtls`；jdtls 由 Wave 11 的 external 提供

### Requirement: lens 移出 chezmoi 管理（soft-unmanage）
`run_once_install-containers.ps1.tmpl` SHALL NOT 呼叫 `scoop install lens`（或經 `Install-ScoopPackage "lens"`）。lens（K8s GUI）改為使用者手動管理。腳本 SHALL NOT 主動 `scoop uninstall lens`——既有安裝保留（soft-unmanage，比照 clink/vimtutor/dark 前例）。

#### Scenario: install-containers 不主動裝 lens
- **WHEN** 在 Windows 上執行 install-containers 腳本
- **THEN** 不執行 `scoop install lens`

#### Scenario: 既有 lens 安裝不被移除
- **WHEN** 機器上已由 scoop 安裝 lens
- **THEN** 本變更不執行 `scoop uninstall lens`；lens 維持現狀

### Requirement: Wave 12a 一次性遷移腳本
`run_once_after_migrate-scoop-wave12a.ps1.tmpl` SHALL 在 Windows 上卸載 scoop 套件 `dos2unix`。腳本 SHALL 為冪等：未安裝時 no-op；scoop 整個未安裝時印警告並 skip。腳本 SHALL NOT 動 User PATH，且 SHALL NOT 觸及 lens（soft-unmanage）。

#### Scenario: 已安裝 scoop dos2unix 被卸載
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list dos2unix` 回報已安裝
- **THEN** 腳本執行 `scoop uninstall dos2unix`

#### Scenario: scoop dos2unix 未安裝時 no-op
- **WHEN** `scoop list dos2unix` 回報未安裝
- **THEN** 腳本不執行 uninstall，繼續結束

#### Scenario: scoop 未安裝時整支 skip
- **WHEN** `Get-Command scoop` 回 not found
- **THEN** 腳本印警告並 return
