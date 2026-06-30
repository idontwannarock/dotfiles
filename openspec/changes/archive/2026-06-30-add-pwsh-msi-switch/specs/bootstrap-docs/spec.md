## ADDED Requirements

### Requirement: Windows bootstrap 文件化 pwsh 7 前置條件與 MSI 取得方式

README 的 Windows bootstrap 章節 SHALL 將 PowerShell 7（pwsh）列為與 git 同級的前置條件（chezmoi 用它執行 `.ps1` run script，無 fallback；缺了 pwsh，第一個 `.ps1` 安裝腳本即 `exec: "pwsh": not found` 而中止）。文件 SHALL 說明 `winget install Microsoft.PowerShell` 交付的是 **MSIX** 版，並 SHALL 指出若要 MSI 版（落 `C:\Program Files\PowerShell\7`、非 Store）需改用 GitHub release 的 `PowerShell-<ver>-win-x64.msi`，可參照 `~/.local/bin/switch-pwsh-to-msi.ps1`。`docs/powershell.md` SHALL 與此一致。

#### Scenario: pwsh 列為 Windows 前置條件

- **WHEN** 使用者查閱 README 的 Windows bootstrap 章節
- **THEN** 可找到 pwsh 7 被列為前置條件，且有 `winget install Microsoft.PowerShell` 安裝指令

#### Scenario: 文件指出 MSI 取得方式

- **WHEN** 使用者想要非 Store 的 MSI 版 pwsh
- **THEN** README / `docs/powershell.md` 指出 winget 交付的是 MSIX、MSI 在 GitHub release，並指向 switch helper
