## ADDED Requirements

### Requirement: 偵測 Store/MSIX pwsh 並警告（不自動修復）

系統 SHALL 在 Windows 的 `chezmoi apply` 期間，以一支 Windows-only run script 偵測當前 pwsh 是否為 Store/MSIX build —— 判斷依據為「執行中的 pwsh `$PSHOME` 路徑含 `WindowsApps`」或「`Get-AppxPackage Microsoft.PowerShell` 存在」。偵測為 MSIX 時 SHALL 以 `Write-Warning` 印出切換到 MSI 的修復指引（指向 helper），且 MUST NOT 自動執行任何 Appx 移除或 MSI 安裝。偵測非 MSIX 時 SHALL 靜默通過。非 Windows SHALL 不執行此偵測。

#### Scenario: MSIX 機器在 apply 時收到警告

- **WHEN** 機器上的 pwsh 為 Store/MSIX build，執行 `chezmoi apply`
- **THEN** 出現指向 `switch-pwsh-to-msi.ps1` 的 `Write-Warning`，且未移除或安裝任何套件

#### Scenario: MSI 機器 apply 時無警告

- **WHEN** 機器上的 pwsh 已是 `Program Files\PowerShell\7` 的 MSI 版且無殘留 MSIX，執行 `chezmoi apply`
- **THEN** 偵測靜默通過，無 warning、無任何動作

#### Scenario: 非 Windows 不觸發

- **WHEN** 在 macOS / Linux 執行 `chezmoi apply`
- **THEN** 此偵測不執行（no-op）

### Requirement: 提供使用者手動提權執行的 MSI 切換 helper

系統 SHALL 透過 chezmoi 部署一支 helper 到 `~/.local/bin/switch-pwsh-to-msi.ps1`（Windows-only），供使用者以系統管理員手動執行。該 helper SHALL：(1) 未提權時中止並提示需以 admin 執行；(2) 移除 per-user 與 provisioned 的 `Microsoft.PowerShell` MSIX；(3) 從 GitHub PowerShell releases 取得最新穩定版的 `PowerShell-<ver>-win-x64.msi`；(4) 驗證下載 MSI 的 Authenticode 簽章為有效且簽署者為 Microsoft；(5) 以 `msiexec /i ... /qn` 安裝；(6) 驗證 `C:\Program Files\PowerShell\7\pwsh.exe` 存在。任一關鍵步驟失敗 SHALL 明確報錯而非靜默繼續。

#### Scenario: 提權執行完成切換

- **WHEN** 使用者以 admin 在有 MSIX pwsh 的機器執行 helper
- **THEN** MSIX 被移除、MSI 安裝到 `C:\Program Files\PowerShell\7`、`pwsh` 回報 7.x

#### Scenario: 非提權拒絕執行

- **WHEN** 在未提權的 session 執行 helper
- **THEN** helper 中止並提示需 admin，未做任何移除或安裝

#### Scenario: 簽章不符時拒裝

- **WHEN** 下載的 MSI Authenticode 簽章無效或簽署者非 Microsoft
- **THEN** helper 中止、不執行 `msiexec` 安裝

### Requirement: 切換流程不納入 chezmoi apply 自動執行

MSIX→MSI 的切換 MUST NOT 由 `chezmoi apply` 自動執行。apply 期間僅允許「偵測-警告」（不提權、不破壞）；實際的 Appx 移除與 MSI 安裝 MUST 由使用者手動觸發 helper。理由：MSI 安裝需 elevation（互動 UAC，破壞無人值守）、流程具破壞性（中途失敗會讓 pwsh 缺席），且 pwsh 之於 `.ps1` 有 chicken-and-egg（chezmoi 用 pwsh 跑 `.ps1`）。

#### Scenario: apply 不自動切換

- **WHEN** `chezmoi apply` 在 MSIX 機器上執行
- **THEN** 不發生任何 Appx 移除或 `msiexec` pwsh 安裝（僅 warning）

#### Scenario: run script 不呼叫切換動作

- **WHEN** 檢視所有 run script
- **THEN** 無任何 run script 呼叫 switch helper、`Remove-AppxPackage` 或以 `msiexec` 安裝 pwsh
