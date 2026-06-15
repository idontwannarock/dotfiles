## Why

Wave 2 將 kubelogin 從 Scoop 遷移到 chezmoi-external 時，誤把來源設成 `Azure/kubelogin`（Azure AD 專用，僅 `kubelogin.exe`），但使用者原本透過 Scoop `extras` bucket 安裝的是 `int128/kubelogin`（通用 OpenID Connect，提供 `kubelogin.exe` + `kubectl-oidc_login.exe`）。這個錯誤同時換掉了工具本體、並完全弄丟了 `kubectl-oidc_login` 這個 kubectl plugin，導致通用 OIDC 登入失效、`kubectl plugin list` 變空。macOS/Linux 透過 `brew install kubelogin`（Homebrew core formula 即 `int128/kubelogin`）一直是正確的，Windows 是唯一不一致的平台。

## What Changes

- **BREAKING**（Windows 套件來源變更）：`.chezmoiexternal.toml` 的 kubelogin 來源由 `Azure/kubelogin` v0.2.17 改回 `int128/kubelogin` v1.36.2。
- `kubelogin.exe` 從 `int128/kubelogin` release 的 `kubelogin_windows_amd64.zip` 取出（內部路徑為 zip 根目錄的 `kubelogin.exe`，而非 Azure 的 `bin/windows_amd64/kubelogin.exe`）。
- 新增 `~/.local/bin/kubectl-oidc_login.exe`：從同一個 zip 取出同一個 `kubelogin.exe`，以 kubectl plugin 命名慣例提供，使 `kubectl plugin list` 能掃出並支援 `kubectl oidc-login`。
- 移除 Azure/kubelogin（使用者僅需 int128 版本）。

## Capabilities

### New Capabilities
<!-- 無新增 capability -->

### Modified Capabilities
- `tool-dependencies`: 修改「kubelogin 在 Windows 上由 chezmoi-external 安裝」需求——來源改為 `int128/kubelogin`、修正 zip 內部路徑、並新增 `kubectl-oidc_login.exe` plugin 別名需求。

## Impact

- 設定檔：`.chezmoiexternal.toml`（`$kubeloginVersion` 變數 + kubelogin entry + 新增 kubectl-oidc_login entry）。
- 規格：`openspec/specs/tool-dependencies/spec.md`（kubelogin 需求段）。
- 實機：`chezmoi apply` 後 `~/.local/bin/` 會多出 `kubectl-oidc_login.exe`、`kubelogin.exe` 內容改為 int128 v1.36.2。
- Wave 2 遷移腳本（`run_once_after_migrate-scoop-wave2.ps1.tmpl`）的 Scoop 卸載清單不需變動（Scoop 套件名同為 `kubelogin`）。
