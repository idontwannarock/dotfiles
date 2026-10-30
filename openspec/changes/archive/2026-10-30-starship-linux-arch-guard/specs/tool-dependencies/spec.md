## MODIFIED Requirements

### Requirement: Starship 安裝腳本支援 macOS 與 Linux
macOS 上 starship SHALL 由 `run_once_install-01-runtimes.sh.tmpl` 以 Homebrew 安裝。Linux 與 Windows 上 starship SHALL 由 `.chezmoiexternal.toml` 從 GitHub Release 下載 pinned 版本：Linux 抽出 `starship-<arch>-unknown-linux-musl.tar.gz` 的 `starship` 至 `~/.local/bin/starship`；Windows 抽出 `starship-x86_64-pc-windows-msvc.zip` 的 `starship.exe` 至 `~/.local/bin/starship.exe`，不再經由 Scoop。Linux 與 Windows SHALL 共用同一個 `$starshipVersion` 變數。

#### Scenario: macOS 上安裝 starship
- **WHEN** chezmoi apply 在 macOS 執行，且 starship 未安裝
- **THEN** 使用 `brew install starship` 安裝

#### Scenario: Linux 上安裝 starship
- **WHEN** chezmoi apply 在 Linux（WSL）執行
- **THEN** `.chezmoiexternal.toml` 從 GitHub Release 下載 pinned 版本的 `starship-<arch>-unknown-linux-musl.tar.gz`（`amd64` → `x86_64`、`arm64` → `aarch64`），抽出 `starship` 至 `~/.local/bin/`，設為 executable

#### Scenario: 不支援的 Linux 架構不下載
- **WHEN** chezmoi apply 在 Linux 執行，且 `.chezmoi.arch` 不是 `amd64` 或 `arm64`
- **THEN** `.chezmoiexternal.toml` SHALL NOT 產生 starship entry，`chezmoi apply` 不因 starship 下載失敗而中斷

#### Scenario: Linux 上不再呼叫官方 installer
- **WHEN** 在 Linux 上的 `run_once_install-01-runtimes.sh.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `https://starship.rs/install.sh`

#### Scenario: Linux 與 Windows 共用版本號
- **WHEN** Renovate 更新 `$starshipVersion`
- **THEN** Linux 與 Windows 的 starship external URL 都改用新版本，且該變數只有一個 `# renovate:` 註記

#### Scenario: Windows 上下載 starship binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 從 GitHub Release 下載 pinned 版本的 `starship-x86_64-pc-windows-msvc.zip`，抽出 `starship.exe` 至 `~/.local/bin/`，設為 executable

#### Scenario: Windows 上 starship 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-01-runtimes.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "starship"`
