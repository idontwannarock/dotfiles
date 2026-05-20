## ADDED Requirements

### Requirement: kubectl 在 Windows 上由 chezmoi-external 安裝
Windows 上 kubectl SHALL 由 `.chezmoiexternal.toml` 直接從 Kubernetes 官方 CDN（`dl.k8s.io`）下載對應版本的 `kubectl.exe` 至 `~/.local/bin/kubectl.exe`。版本以 `$kubectlVersion` 變數 pinned。

#### Scenario: Windows 上下載 kubectl binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 從 `https://dl.k8s.io/release/v<version>/bin/windows/amd64/kubectl.exe` 下載至 `~/.local/bin/kubectl.exe`，設為 executable

#### Scenario: Windows 上 kubectl 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-containers.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "kubectl"`

### Requirement: kubelogin 在 Windows 上由 chezmoi-external 安裝
Windows 上 kubelogin SHALL 由 `.chezmoiexternal.toml` 下載 GitHub Release `Azure/kubelogin` 的 `kubelogin-win-amd64.zip`，抽出 `bin/windows_amd64/kubelogin.exe` 至 `~/.local/bin/kubelogin.exe`。

#### Scenario: Windows 上下載 kubelogin binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 下載 `kubelogin-win-amd64.zip`，抽出內部 `bin/windows_amd64/kubelogin.exe` 至 `~/.local/bin/`，設為 executable

#### Scenario: Windows 上 kubelogin 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-containers.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "kubelogin"`

### Requirement: yt-dlp 在 Windows 上由 chezmoi-external 安裝
Windows 上 yt-dlp SHALL 由 `.chezmoiexternal.toml` 直接下載 GitHub Release `yt-dlp/yt-dlp` 的裸 `yt-dlp.exe` 至 `~/.local/bin/yt-dlp.exe`。版本使用 CalVer `YYYY.MM.DD` 格式（無 `v` prefix）。

#### Scenario: Windows 上下載 yt-dlp binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 從 `https://github.com/yt-dlp/yt-dlp/releases/download/<version>/yt-dlp.exe` 下載至 `~/.local/bin/yt-dlp.exe`，設為 executable

#### Scenario: Windows 上 yt-dlp 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "yt-dlp"`

### Requirement: hugo (extended) 在 Windows 上由 chezmoi-external 安裝
Windows 上 hugo SHALL 由 `.chezmoiexternal.toml` 下載 GitHub Release `gohugoio/hugo` 的 `hugo_extended_<version>_windows-amd64.zip`，抽出 `hugo.exe` 至 `~/.local/bin/hugo.exe`。一律使用 extended variant（含 SASS/SCSS 支援），不另裝 vanilla hugo。

#### Scenario: Windows 上下載 hugo extended binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 下載 `hugo_extended_<version>_windows-amd64.zip`，抽出 root 的 `hugo.exe` 至 `~/.local/bin/`，設為 executable

#### Scenario: Windows 上 hugo 與 hugo-extended 都不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "hugo"` 或 `Install-ScoopPackage "hugo-extended"`

### Requirement: nexttrace 在 Windows 上由 chezmoi-external 安裝
Windows 上 nexttrace SHALL 由 `.chezmoiexternal.toml` 直接下載 GitHub Release `nxtrace/NTrace-V1` 的裸 `nexttrace_windows_amd64.exe` 至 `~/.local/bin/nexttrace.exe`。

#### Scenario: Windows 上下載 nexttrace binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 從 `https://github.com/nxtrace/NTrace-V1/releases/download/v<version>/nexttrace_windows_amd64.exe` 下載至 `~/.local/bin/nexttrace.exe`，設為 executable

#### Scenario: Windows 上 nexttrace 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "nexttrace"`

### Requirement: golangci-lint 在 Windows 上由 chezmoi-external 安裝
Windows 上 golangci-lint SHALL 由 `.chezmoiexternal.toml` 下載 GitHub Release `golangci/golangci-lint` 的 `golangci-lint-<version>-windows-amd64.zip`，抽出 `golangci-lint-<version>-windows-amd64/golangci-lint.exe` 至 `~/.local/bin/golangci-lint.exe`。archive 內部路徑含版本字串，須與 url 用同一個 `$ver` 變數 inject。

#### Scenario: Windows 上下載 golangci-lint binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 下載 `golangci-lint-<version>-windows-amd64.zip`，抽出 `golangci-lint-<version>-windows-amd64/golangci-lint.exe` 至 `~/.local/bin/`，設為 executable

#### Scenario: Windows 上 golangci-lint 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "golangci-lint"`

### Requirement: Wave 2 一次性遷移腳本
`run_once_after_migrate-scoop-wave2.ps1.tmpl` SHALL 在 Windows 上執行一次性遷移：卸載已存在的 scoop kubectl/kubelogin/yt-dlp/hugo/hugo-extended/nexttrace/golangci-lint。腳本 SHALL 為冪等：scoop 未安裝對應套件時視為 no-op。

腳本 SHALL NOT 動 User PATH（Wave 1 的 `run_once_after_migrate-scoop-to-external.ps1.tmpl` 已把 `~/.local/bin` 排在 `~/scoop/shims` 之前）。

#### Scenario: 已安裝 scoop 套件被卸載
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list <pkg>` 回報已安裝
- **THEN** 腳本執行 `scoop uninstall <pkg>`，scoop apps 目錄該套件被移除

#### Scenario: scoop 套件未安裝時 no-op
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list <pkg>` 回報未安裝
- **THEN** 腳本不執行 `scoop uninstall`，繼續處理下一個

#### Scenario: User PATH 不被本腳本修改
- **WHEN** Wave 2 migration 腳本執行
- **THEN** User PATH 環境變數值維持不變（PATH 排序為 Wave 1 migration 腳本的責任）
