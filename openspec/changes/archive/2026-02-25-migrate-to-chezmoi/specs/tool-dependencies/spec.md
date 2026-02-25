## ADDED Requirements

### Requirement: chezmoi apply 自動安裝缺少的工具
每個部署設定檔的 capability SHALL 附帶對應的 `run_once_` 安裝腳本，確保工具在設定被部署前已安裝。腳本採冪等設計（工具已存在則跳過），並依 OS 跳過不適用平台。

#### Scenario: 工具未安裝時自動安裝
- **WHEN** chezmoi apply 執行，且對應工具尚未安裝
- **THEN** `run_once_install-<tool>.sh.tmpl` 執行，完成工具安裝

#### Scenario: 工具已安裝時跳過
- **WHEN** chezmoi apply 執行，且對應工具已存在
- **THEN** 安裝腳本執行但無實際操作，不重複安裝

#### Scenario: 不適用平台跳過安裝腳本
- **WHEN** chezmoi apply 在與工具不相容的 OS 執行（如 Windows 執行 Linux-only 工具腳本）
- **THEN** 腳本透過 OS 判斷提前退出，不嘗試安裝

### Requirement: Starship 安裝腳本支援 macOS 與 Linux
`run_once_install-starship.sh.tmpl` SHALL 在 macOS（使用 Homebrew）與 Linux（使用官方安裝腳本）上安裝 starship，Windows 上跳過（由 Scoop 負責）。

#### Scenario: macOS 上安裝 starship
- **WHEN** chezmoi apply 在 macOS 執行，且 starship 未安裝
- **THEN** 使用 `brew install starship` 安裝

#### Scenario: Linux 上安裝 starship
- **WHEN** chezmoi apply 在 Linux（WSL）執行，且 starship 未安裝
- **THEN** 使用官方 curl install script 安裝

### Requirement: Fastfetch 安裝腳本支援 macOS 與 Linux
`run_once_install-fastfetch.sh.tmpl` SHALL 在 macOS（Homebrew）與 Ubuntu/Debian（PPA）上安裝 fastfetch，Windows 上跳過。

#### Scenario: macOS 上安裝 fastfetch
- **WHEN** chezmoi apply 在 macOS 執行，且 fastfetch 未安裝
- **THEN** 使用 `brew install fastfetch` 安裝

#### Scenario: Ubuntu 上安裝 fastfetch
- **WHEN** chezmoi apply 在 Ubuntu（WSL）執行，且 fastfetch 未安裝
- **THEN** 新增 PPA 並以 `apt install fastfetch` 安裝

### Requirement: Claude Code 安裝腳本支援全平台
`run_once_install-claude-code.sh.tmpl`（Unix）與 `run_once_install-claude-code.ps1.tmpl`（Windows）SHALL 在對應平台安裝 Claude Code CLI，若已安裝則跳過。

#### Scenario: macOS/Linux 上安裝 Claude Code
- **WHEN** chezmoi apply 在 macOS 或 Linux 執行，且 `claude` 指令不存在
- **THEN** 使用官方安裝方式安裝 Claude Code

#### Scenario: Windows 上安裝 Claude Code
- **WHEN** chezmoi apply 在 Windows 執行，且 `claude` 指令不存在
- **THEN** 使用 PowerShell 安裝腳本安裝 Claude Code
