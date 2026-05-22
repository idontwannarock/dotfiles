## ADDED Requirements

### Requirement: clink 不再由 dotfiles 安裝
Windows 上 dotfiles SHALL NOT 透過 scoop 安裝 `clink`。dotfiles 內無任何流程呼叫 `clink autorun install`，且 starship 已透過 PowerShell/Git Bash/zsh init 取代 cmd.exe 命令列增強需求。

#### Scenario: Windows 上 clink 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "clink"`

### Requirement: dark 不再由 dotfiles 安裝（軟脫管）
Windows 上 dotfiles SHALL NOT 透過 scoop 主動安裝 `dark`（WiX Toolset Decompiler）。`dark.exe` 在 dotfiles 全 repo 無任何引用，已安裝的 scoop manifest 亦無宣告為 dependency。**現有已安裝的 dark 不主動卸載**（軟脫管）。

#### Scenario: Windows 上 dark 不再經由 Scoop 安裝
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "dark"`

#### Scenario: 既有 dark 安裝不被本變更卸載
- **WHEN** chezmoi apply 在 Windows 執行且 `scoop list dark` 回報已安裝
- **THEN** Wave 4 migration 腳本 SHALL NOT 執行 `scoop uninstall dark`

### Requirement: vimtutor 不再由 dotfiles 安裝（軟脫管）
Windows 上 dotfiles SHALL NOT 透過 scoop 主動安裝 `vimtutor`。它為互動式教學程式，無腳本依賴。**現有已安裝的 vimtutor 不主動卸載**（軟脫管）。

#### Scenario: Windows 上 vimtutor 不再經由 Scoop 安裝
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 包含 vimtutor 安裝區塊

#### Scenario: 既有 vimtutor 安裝不被本變更卸載
- **WHEN** chezmoi apply 在 Windows 執行且 `scoop list vimtutor` 回報已安裝
- **THEN** Wave 4 migration 腳本 SHALL NOT 執行 `scoop uninstall vimtutor`

### Requirement: winget 不再由 dotfiles 安裝
Windows 上 dotfiles SHALL NOT 透過 scoop 安裝 `winget`。Win10 build 1809+ 與 Win11 已 OS-bundled `winget.exe` 於 `%LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe`（透過 Microsoft.DesktopAppInstaller Store package），scoop shim 為冗餘來源。

#### Scenario: Windows 上 winget 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "winget"`

#### Scenario: OS-bundled winget 接手
- **WHEN** 使用者於 PowerShell 執行 `winget --version`
- **THEN** PATH lookup 命中 `%LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe`，命令正常執行

### Requirement: winget-ps 不再由 dotfiles 安裝
Windows 上 dotfiles SHALL NOT 透過 scoop 安裝 `winget-ps`（`Microsoft.WinGet.Client` PowerShell 模組）。dotfiles 內無任何 PowerShell script 載入此模組或呼叫其 cmdlet（`Find-WinGetPackage` / `Install-WinGetPackage` 等）。

#### Scenario: Windows 上 winget-ps 不再經由 Scoop 安裝
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 包含 winget-ps 安裝區塊

#### Scenario: PowerToys CommandNotFound 模組不受影響
- **WHEN** 使用者啟動 PowerShell 且已安裝 PowerToys CommandNotFound 模組
- **THEN** `Microsoft.WinGet.CommandNotFound` 仍可正常載入（該模組獨立於 `Microsoft.WinGet.Client`/winget-ps）並透過 OS-bundled winget 提供建議

### Requirement: Wave 4 一次性遷移腳本
`run_once_after_migrate-scoop-wave4.ps1.tmpl` SHALL 在 Windows 上執行一次性遷移：卸載 3 個 scoop 套件 `clink`、`winget`、`winget-ps`。腳本 SHALL 為冪等：scoop 未安裝對應套件時視為 no-op；scoop 未安裝時整支 skip。

腳本 SHALL NOT 卸載 `dark` 與 `vimtutor`（軟脫管項目）。

腳本 SHALL NOT 動 User PATH（Wave 1 的 `run_once_after_migrate-scoop-to-external.ps1.tmpl` 已把 `~/.local/bin` 排在 `~/scoop/shims` 之前）。

#### Scenario: 已安裝 scoop 硬清套件被卸載
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list <pkg>` 回報已安裝（pkg ∈ {clink, winget, winget-ps}）
- **THEN** 腳本執行 `scoop uninstall <pkg>`，scoop apps 目錄該套件被移除

#### Scenario: 軟脫管套件不被卸載
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** 腳本 SHALL NOT 嘗試 `scoop uninstall dark` 或 `scoop uninstall vimtutor`，無論其安裝狀態

#### Scenario: scoop 硬清套件未安裝時 no-op
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list <pkg>` 回報未安裝
- **THEN** 腳本不執行 `scoop uninstall`，繼續處理下一個

#### Scenario: scoop 未安裝時 no-op
- **WHEN** chezmoi apply 在 Windows 執行，且 `Get-Command scoop` 回 not found
- **THEN** 腳本印警告訊息並 return，不嘗試任何 scoop 命令

#### Scenario: User PATH 不被本腳本修改
- **WHEN** Wave 4 migration 腳本執行
- **THEN** User PATH 環境變數值維持不變（PATH 排序為 Wave 1 migration 腳本的責任）

### Requirement: PowerShell command-not-found 前置條件明示
所有 `Documents/{Windows,}PowerShell/profile.d/99-command-not-found.ps1` 檔案 SHALL 在檔案頂部包含 header comment 明示前置條件。實際命令邏輯不變。

兩個版本對應不同 PowerShell：
- `Documents/PowerShell/profile.d/99-command-not-found.ps1`（PowerShell 7+）依賴 PowerToys 安裝並啟用 `Microsoft.WinGet.CommandNotFound` 模組，以及 OS-bundled `winget.exe`（Win10 1809+/Win11）。仍以 `-ErrorAction SilentlyContinue` 確保 silent no-op。
- `Documents/WindowsPowerShell/profile.d/99-command-not-found.ps1`（Windows PowerShell 5.x）直接呼叫 `winget search`，依賴 OS-bundled `winget.exe`。

#### Scenario: PS7 檔案 header 註明前置條件
- **WHEN** 開啟 `Documents/PowerShell/profile.d/99-command-not-found.ps1`
- **THEN** 檔案前段包含 comment 提及 PowerToys CommandNotFound 模組與 OS-bundled winget 兩項前置條件

#### Scenario: PS5 檔案 header 註明前置條件
- **WHEN** 開啟 `Documents/WindowsPowerShell/profile.d/99-command-not-found.ps1`
- **THEN** 檔案前段包含 comment 提及 OS-bundled winget 前置條件

#### Scenario: Import-Module 與 CommandNotFoundAction 邏輯保持不變
- **WHEN** PowerShell session 啟動載入對應 .ps1
- **THEN** PS7 仍執行 `Import-Module -Name Microsoft.WinGet.CommandNotFound -ErrorAction SilentlyContinue`；PS5 仍註冊 `$ExecutionContext.InvokeCommand.CommandNotFoundAction`，無其他副作用
