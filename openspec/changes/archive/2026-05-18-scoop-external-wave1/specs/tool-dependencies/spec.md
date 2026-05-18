## MODIFIED Requirements

### Requirement: Starship 安裝腳本支援 macOS 與 Linux
`run_once_install-starship.sh.tmpl` SHALL 在 macOS（使用 Homebrew）與 Linux（使用官方安裝腳本）上安裝 starship。Windows 上 starship SHALL 由 `.chezmoiexternal.toml` 下載 GitHub Release 的 `starship-x86_64-pc-windows-msvc.zip` 並抽出 `starship.exe` 至 `~/.local/bin/starship.exe`，不再經由 Scoop。

#### Scenario: macOS 上安裝 starship
- **WHEN** chezmoi apply 在 macOS 執行，且 starship 未安裝
- **THEN** 使用 `brew install starship` 安裝

#### Scenario: Linux 上安裝 starship
- **WHEN** chezmoi apply 在 Linux（WSL）執行，且 starship 未安裝
- **THEN** 使用官方 curl install script 安裝

#### Scenario: Windows 上下載 starship binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 從 GitHub Release 下載 pinned 版本的 `starship-x86_64-pc-windows-msvc.zip`，抽出 `starship.exe` 至 `~/.local/bin/`，設為 executable

#### Scenario: Windows 上 starship 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-01-runtimes.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "starship"`

## ADDED Requirements

### Requirement: Zellij 在 Windows 上由 chezmoi-external 安裝
Windows 上 zellij SHALL 由 `.chezmoiexternal.toml` 下載 GitHub Release 的 `zellij-x86_64-pc-windows-msvc.zip` 並抽出 `zellij.exe` 至 `~/.local/bin/zellij.exe`。Linux 與 macOS 上由各自 OS 套件管理器負責，不在本要求範圍。

#### Scenario: Windows 上下載 zellij binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 下載 pinned 版本的 `zellij-x86_64-pc-windows-msvc.zip`，抽出 `zellij.exe` 至 `~/.local/bin/`，設為 executable

#### Scenario: SSH session 下 zellij 可直接啟動
- **WHEN** 經由 Tailscale + Win32-OpenSSH 連入 Windows，於 PowerShell 執行 `zellij`
- **THEN** 解析到 `~/.local/bin/zellij.exe` 並正常啟動，無需 `35-scoop-ssh-shims.ps1` 的 PATH 重寫

### Requirement: uv 在 Windows 上由 chezmoi-external 安裝
Windows 上 uv SHALL 由 `.chezmoiexternal.toml` 下載 GitHub Release 的 `uv-x86_64-pc-windows-msvc.zip` 並抽出 `uv.exe` 至 `~/.local/bin/uv.exe`。

#### Scenario: Windows 上下載 uv binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 下載 pinned 版本的 `uv-x86_64-pc-windows-msvc.zip`，抽出 `uv.exe` 至 `~/.local/bin/`，設為 executable

#### Scenario: Windows 上 uv 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-01-runtimes.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "uv"`

### Requirement: jq 在 Windows 上由 chezmoi-external 安裝
Windows 上 jq SHALL 由 `.chezmoiexternal.toml` 直接下載 GitHub Release 的 `jq-windows-amd64.exe` 至 `~/.local/bin/jq.exe`（jq 是裸 `.exe`，非 archive）。

#### Scenario: Windows 上下載 jq binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 從 `https://github.com/jqlang/jq/releases/download/jq-<version>/jq-windows-amd64.exe` 下載至 `~/.local/bin/jq.exe`，設為 executable

#### Scenario: Windows 上 jq 不再經由 Scoop prereq 腳本
- **WHEN** 在 Windows 上的 `run_onchange_before_install-prereqs.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Ensure-ScoopTool "jq"`

#### Scenario: 後續 chezmoi 腳本仍能呼叫 jq
- **WHEN** `modify_settings.json.sh.tmpl` 等後續腳本執行
- **THEN** 透過 PATH 解析到 `~/.local/bin/jq.exe` 並正常運作

### Requirement: ripgrep 在 Windows 上由 chezmoi-external 安裝
Windows 上 ripgrep SHALL 由 `.chezmoiexternal.toml` 下載 GitHub Release 的 `ripgrep-<version>-x86_64-pc-windows-msvc.zip`，抽出子目錄 `ripgrep-<version>-x86_64-pc-windows-msvc/rg.exe` 至 `~/.local/bin/rg.exe`。

#### Scenario: Windows 上下載 ripgrep binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 下載 pinned 版本的 `ripgrep-<version>-x86_64-pc-windows-msvc.zip`，從 archive 內子目錄抽出 `rg.exe` 至 `~/.local/bin/`，設為 executable

### Requirement: Wave 1 一次性遷移腳本
`run_once_after_migrate-scoop-to-external.ps1.tmpl` SHALL 在 Windows 上執行一次性遷移：（1）卸載已存在的 scoop starship/zellij/uv/jq/ripgrep；（2）調整 User PATH 確保 `~/.local/bin` 早於 `~/scoop/shims`。腳本為冪等：若 scoop 未安裝對應套件、或 PATH 順序已正確，對應步驟視為 no-op。

#### Scenario: 已安裝 scoop 套件被卸載
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list starship`（或其他 4 個）回報已安裝
- **THEN** 腳本執行 `scoop uninstall <pkg>`，scoop apps 目錄該套件被移除

#### Scenario: scoop 套件未安裝時 no-op
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list <pkg>` 回報未安裝
- **THEN** 腳本不執行 `scoop uninstall`，繼續處理 PATH

#### Scenario: User PATH 重排
- **WHEN** User PATH 中 `~/.local/bin` 的索引位置晚於 `~/scoop/shims`，或 `~/.local/bin` 不在 PATH 中
- **THEN** 腳本將 `~/.local/bin` 移除（若已在）並重新插入到 `~/scoop/shims` 之前；其他 PATH 條目原樣保留

#### Scenario: User PATH 順序已正確時 no-op
- **WHEN** User PATH 中 `~/.local/bin` 已位於 `~/scoop/shims` 之前
- **THEN** 腳本不修改 PATH

#### Scenario: PATH 變更後提示重開 session
- **WHEN** 腳本修改了 User PATH
- **THEN** 印出 warning 提醒使用者重開 terminal/SSH session 以讓變更生效

### Requirement: SSH workaround 檔案於 Wave 1 後移除
`Documents/exact__shared-profile.d/35-scoop-ssh-shims.ps1` SHALL 在 Wave 1 完成後從 chezmoi source 移除；同時 `90-prompt.ps1` 中 starship 的 shim-bypass 邏輯 SHALL 簡化為標準的 `starship init powershell` 呼叫。

#### Scenario: 35-scoop-ssh-shims.ps1 不再存在於 source
- **WHEN** chezmoi apply 執行
- **THEN** target `~/Documents/PowerShell/_shared-profile.d/35-scoop-ssh-shims.ps1` 不存在（chezmoi 因 source 已移除而清理 target）

#### Scenario: 90-prompt.ps1 starship 啟動使用標準寫法
- **WHEN** PowerShell session 載入 `90-prompt.ps1`
- **THEN** 透過 `Get-Command starship` 解析（會走 PATH，命中 `~/.local/bin/starship.exe`），呼叫 `starship init powershell --print-full-init` 並 `Invoke-Expression`，不再有 shim 路徑字串替換邏輯

#### Scenario: 90-prompt.ps1 保留 OSC 9;9 directory tracking
- **WHEN** PowerShell session 載入 `90-prompt.ps1`
- **THEN** `Invoke-Starship-PreCommand` 函式仍被定義，OSC 9;12/9;9 escape sequence 仍輸出，Windows Terminal duplicate-pane 仍能繼承目錄
