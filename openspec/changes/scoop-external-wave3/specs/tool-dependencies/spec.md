## ADDED Requirements

### Requirement: gopass 在 Windows 上由 chezmoi-external 安裝
Windows 上 gopass SHALL 由 `.chezmoiexternal.toml` 下載 GitHub Release `gopasspw/gopass` 的 `gopass-<version>-windows-amd64.zip`，抽出 archive 根目錄的 `gopass.exe` 至 `~/.local/bin/gopass.exe`。版本以 `$gopassVersion` 變數 pinned；URL 中的 tag 帶 `v` prefix，archive 內檔名版本字串不帶 `v`，須以同一變數雙重 inject。

#### Scenario: Windows 上下載 gopass binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 從 `https://github.com/gopasspw/gopass/releases/download/v<version>/gopass-<version>-windows-amd64.zip` 下載並抽出 `gopass.exe` 至 `~/.local/bin/gopass.exe`，設為 executable

#### Scenario: Windows 上 gopass 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "gopass"`

### Requirement: curl 不再由 dotfiles 安裝
Windows 上 dotfiles SHALL NOT 透過 scoop 安裝 curl。`curl.exe` 仰賴 Win10 build 17063+ 內建於 `C:\Windows\System32\curl.exe`，以及 Git for Windows 安裝時自帶於 `<git>\mingw64\bin\curl.exe`。dotfiles 不再保證 scoop 版本可用。

#### Scenario: Windows 上 curl 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "curl"`

#### Scenario: Linux/macOS curl 安裝不受影響
- **WHEN** 在 Linux 或 macOS 上的 `run_once_install-cli-tools.sh.tmpl` 執行
- **THEN** 該腳本仍可使用 apt/brew 安裝 curl（本 requirement 限定 Windows scope）

### Requirement: wget 不再由 dotfiles 在 Windows 上安裝
Windows 上 dotfiles SHALL NOT 透過 scoop 安裝 wget。Windows PowerShell / Git Bash 流程內部不呼叫 wget；`run_onchange_install-03-claude-config.sh.tmpl` 的 `curl || wget` fallback 為 `.sh.tmpl`（Linux/macOS only）。如使用者個人需要 wget 可手動安裝。

#### Scenario: Windows 上 wget 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "wget"`

#### Scenario: Linux/macOS wget 安裝不受影響
- **WHEN** 在 Linux 或 macOS 上的 `run_once_install-cli-tools.sh.tmpl` 執行
- **THEN** 該腳本仍可使用 apt/brew 安裝 wget（本 requirement 限定 Windows scope）

### Requirement: Wave 3 一次性遷移腳本
`run_once_after_migrate-scoop-wave3.ps1.tmpl` SHALL 在 Windows 上執行一次性遷移：卸載已存在的 scoop gopass / curl / wget。腳本 SHALL 為冪等：scoop 未安裝對應套件時視為 no-op；scoop 未安裝時整支 skip。

腳本 SHALL NOT 動 User PATH（Wave 1 的 `run_once_after_migrate-scoop-to-external.ps1.tmpl` 已把 `~/.local/bin` 排在 `~/scoop/shims` 之前）。

#### Scenario: 已安裝 scoop 套件被卸載
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list <pkg>` 回報已安裝
- **THEN** 腳本執行 `scoop uninstall <pkg>`，scoop apps 目錄該套件被移除

#### Scenario: scoop 套件未安裝時 no-op
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list <pkg>` 回報未安裝
- **THEN** 腳本不執行 `scoop uninstall`，繼續處理下一個

#### Scenario: scoop 未安裝時 no-op
- **WHEN** chezmoi apply 在 Windows 執行，且 `Get-Command scoop` 回 not found
- **THEN** 腳本印警告訊息並 return，不嘗試任何 scoop 命令

#### Scenario: User PATH 不被本腳本修改
- **WHEN** Wave 3 migration 腳本執行
- **THEN** User PATH 環境變數值維持不變（PATH 排序為 Wave 1 migration 腳本的責任）
