## Why

Windows 上 chezmoi 以 `pwsh` 執行所有 `.ps1` run script，pwsh 因此是 bootstrap 前置條件。但 `winget install Microsoft.PowerShell` 交付的是 **MSIX**（`Installer Type: msix`）：它落在版本化的 `WindowsApps` 目錄、靠可被關閉的 App Execution Alias 上 PATH，且提權安裝會 `0x80070005 Access denied` —— winget 這條路永遠裝不出 `C:\Program Files\PowerShell\7` 的 MSI 版。真正的 MSI 只在 GitHub Releases 提供。使用者偏好乾淨、非 Store 的 MSI 版，但目前缺少把既有機器從 MSIX 切到 MSI 的可重複工具，每次都得重走一遍人工調查。

## What Changes

- 新增一支 **偵測-警告** run script：偵測當前 pwsh 為 Store/MSIX build 時，`Write-Warning` 印出修復指令，但 **不自動執行**（非破壞、非提權、idempotent）。
- 新增一支 **使用者手動提權執行** 的 helper 腳本 `~/.local/bin/switch-pwsh-to-msi.ps1`，由 chezmoi 部署：移除 MSIX（per-user + provisioned）→ 抓 GitHub 最新穩定版 MSI → 驗 Authenticode 簽章 → `msiexec /i /qn` 安裝 → 驗證落在 `Program Files\PowerShell\7`。
- README / `docs/powershell.md` bootstrap 補一段：要 MSI 版改用 GitHub release 的 `PowerShell-<ver>-win-x64.msi`（winget 給的是 MSIX）。
- **約束（非變更，但須明文）**：切換流程 MUST NOT 塞進 `chezmoi apply` 自動執行（elevation 互動、破壞性、pwsh 之於 .ps1 的 chicken-and-egg）。

## Capabilities

### New Capabilities
- `pwsh-msi-provisioning`: Windows 上把 pwsh 從 Store/MSIX 切換到官方 MSI 版的偵測與工具 —— 偵測-警告 run script、使用者手動提權執行的切換 helper，以及「不自動化進 apply」的約束。

### Modified Capabilities
- `bootstrap-docs`: Windows bootstrap 文件 SHALL 說明 pwsh 7 為前置條件，且 SHALL 指出要 MSI 版需用 GitHub release 的 MSI（winget 交付 MSIX）。

## Impact

- 新增：`home/run_onchange_warn-pwsh-msix.ps1.tmpl`（偵測-警告，Windows-only）、`home/dot_local/bin/switch-pwsh-to-msi.ps1`（部署到 `~/.local/bin`）。
- 修改：`README.md`、`docs/powershell.md`（bootstrap 章節）。
- 平台：全部 Windows-only；非 Windows 經 `{{ if eq .chezmoi.os "windows" }}` 或部署忽略而不受影響。
- 不影響 `chezmoi apply` 的非提權、無人值守特性（切換為人工觸發）。
- 相依：helper 執行期需網路（GitHub）、admin、msiexec；偵測腳本零相依。
