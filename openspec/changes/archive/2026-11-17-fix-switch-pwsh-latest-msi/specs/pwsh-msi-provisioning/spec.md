## MODIFIED Requirements

### Requirement: 提供使用者手動提權執行的 MSI 切換 helper

系統 SHALL 透過 chezmoi 部署一支 helper 到 `~/.local/bin/switch-pwsh-to-msi.ps1`（Windows-only），供使用者以系統管理員手動執行。該 helper SHALL：(1) 未提權時中止並提示需以 admin 執行；(2) 從 GitHub PowerShell releases 取得 MSI：在所有穩定版（非 prerelease、非 draft）中，選出「含 `PowerShell-<ver>-win-x64.msi` asset」且版本號最高的 release，並下載該 MSI；(3) 驗證下載 MSI 的 Authenticode 簽章為有效且簽署者為 Microsoft；(4) 以 `msiexec /i ... /qn` 安裝；(5) 移除 per-user 與 provisioned 的 `Microsoft.PowerShell` MSIX；(6) 驗證 `C:\Program Files\PowerShell\7\pwsh.exe` 存在。任一關鍵步驟失敗 SHALL 明確報錯而非靜默繼續。當選到的版本低於最新穩定版時，helper SHALL 印出說明：最新穩定版沒有 MSI，所以改裝所選版本。若沒有任何穩定版含 MSI，helper SHALL 在移除任何 MSIX 之前中止並報錯。

#### Scenario: 提權執行完成切換

- **WHEN** 使用者以 admin 在有 MSIX pwsh 的機器執行 helper
- **THEN** MSIX 被移除、MSI 安裝到 `C:\Program Files\PowerShell\7`、`pwsh` 回報 7.x

#### Scenario: 非提權拒絕執行

- **WHEN** 在未提權的 session 執行 helper
- **THEN** helper 中止並提示需 admin，未做任何移除或安裝

#### Scenario: 簽章不符時拒裝

- **WHEN** 下載的 MSI Authenticode 簽章無效或簽署者非 Microsoft
- **THEN** helper 中止、不執行 `msiexec` 安裝

#### Scenario: 最新穩定版沒有 MSI 時改選較舊的有 MSI 版本

- **WHEN** 最新穩定版 release（例如 v7.7.0）沒有 `win-x64.msi` asset，而 v7.6.10 有
- **THEN** helper 選擇 v7.6.10 的 MSI，並印出說明「最新穩定版沒有 MSI，改裝 7.6.10」

#### Scenario: 版本號以數字比較而非字串比較

- **WHEN** 含 MSI 的穩定版有 v7.6.9 與 v7.6.10
- **THEN** helper 選擇 v7.6.10

#### Scenario: 略過 prerelease 與 draft

- **WHEN** 版本號最高的含 MSI release 是 prerelease 或 draft
- **THEN** helper 不選它，改選版本號最高的穩定版含 MSI release

#### Scenario: 沒有任何含 MSI 的穩定版時不動現有安裝

- **WHEN** 所有穩定版 release 都沒有 `win-x64.msi` asset
- **THEN** helper 報錯中止，且未移除 MSIX、未執行 `msiexec`
