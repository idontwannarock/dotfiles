## MODIFIED Requirements

### Requirement: kubelogin 在 Windows 上由 chezmoi-external 安裝
Windows 上 kubelogin SHALL 由 `.chezmoiexternal.toml` 下載 GitHub Release `int128/kubelogin` 的 `kubelogin_windows_amd64.zip`，抽出 zip **根目錄**的 `kubelogin.exe` 至 `~/.local/bin/kubelogin.exe`。版本以 `$kubeloginVersion` 變數 pinned。kubelogin SHALL NOT 使用 `Azure/kubelogin`（該專案為 Azure AD 專用且不含 kubectl plugin）。

`.chezmoiexternal.toml` SHALL 額外從**同一個** `kubelogin_windows_amd64.zip` 抽出同一個 `kubelogin.exe` 至 `~/.local/bin/kubectl-oidc_login.exe`，以 kubectl plugin 命名慣例提供 `kubectl oidc-login`。

#### Scenario: Windows 上下載 kubelogin binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 從 `https://github.com/int128/kubelogin/releases/download/v<version>/kubelogin_windows_amd64.zip` 抽出根目錄 `kubelogin.exe` 至 `~/.local/bin/kubelogin.exe`，設為 executable

#### Scenario: Windows 上提供 kubectl-oidc_login plugin
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 從同一個 `kubelogin_windows_amd64.zip` 抽出 `kubelogin.exe` 至 `~/.local/bin/kubectl-oidc_login.exe`，設為 executable
- **AND** `kubectl plugin list` SHALL 列出 `kubectl-oidc_login`

#### Scenario: Windows 上 kubelogin 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-containers.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "kubelogin"`
