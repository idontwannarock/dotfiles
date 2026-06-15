## Context

Wave 2（2026-05-20）將 6 個 CLI 工具從 Scoop 遷移到 `.chezmoiexternal.toml`。kubelogin 這條被設成 `Azure/kubelogin`，但使用者的 Scoop 來源是 `extras` bucket 的 `int128/kubelogin`。兩者同名、用途不同：

- `int128/kubelogin`（使用者要的）：通用 OpenID Connect credential plugin，release zip 內含**根目錄**的 `kubelogin.exe`；Scoop manifest 另外以 plugin 命名慣例提供 `kubectl-oidc_login.exe`（同一個 binary 的別名）。
- `Azure/kubelogin`（誤裝的）：Azure AD 專用（`get AAD token`），zip 內路徑為 `bin/windows_amd64/kubelogin.exe`，不含任何 kubectl plugin。

macOS/Linux 走 `brew install kubelogin`（Homebrew core formula = `int128/kubelogin`），一直正確；只有 Windows 在 Wave 2 設錯。

## Goals / Non-Goals

**Goals:**
- Windows 改回 `int128/kubelogin` v1.36.2，與其他平台一致。
- 還原 `kubectl-oidc_login` plugin，使 `kubectl plugin list` 可掃出、`kubectl oidc-login` 可用。

**Non-Goals:**
- 不保留 `Azure/kubelogin`（使用者僅需 int128）。
- 不改動 Wave 2 遷移腳本的 Scoop 卸載邏輯（套件名同為 `kubelogin`，卸載仍正確）。
- 不改動 macOS/Linux 安裝路徑（已正確）。

## Decisions

**1. 以兩條 `archive-file` entry 從同一個 zip 取出同一個 binary。**
chezmoi-external 無法將單次下載複製成兩個目標檔，但可用兩條 entry 指向同一 URL（chezmoi 會快取下載），各自抽出 `kubelogin.exe` 到不同目標檔名。比起「下載一份再用 run script 複製」更宣告式、與既有 external 風格一致。
- 替代方案：`run_after` 腳本 `Copy-Item kubelogin.exe kubectl-oidc_login.exe` — 多一個指令式步驟、需處理冪等，捨棄。

**2. zip 內部 `path` 設為 `kubelogin.exe`（根目錄），非 `bin/windows_amd64/kubelogin.exe`。**
已實測 `kubelogin_windows_amd64.zip` 內容為根目錄的 `kubelogin.exe`(22581248 bytes)、`LICENSE`、`README.md`。沿用 Azure 的 `bin/windows_amd64/` 路徑會抽取失敗。

**3. `kubectl-oidc_login.exe` 直接用 int128 的 `kubelogin.exe` 改名。**
int128 binary 會依自身被呼叫的名稱切換行為（被 kubectl 當 plugin 呼叫時等同 `kubectl oidc-login`），與 Scoop manifest 的 alias 機制一致，無需另一個檔案來源。

## Risks / Trade-offs

- [兩條 entry 版本/URL 須同步] → 兩者都用同一個 `$kubeloginVersion` 模板變數，bump 版本時一致更新，避免漂移。
- [既有實機殘留 Azure 版 `kubelogin.exe`] → `chezmoi apply` 會以新來源覆寫同一目標檔；`kubectl-oidc_login.exe` 為新檔，apply 後自動出現。驗證步驟會確認 `kubelogin --version` 顯示 int128 v1.36.2 且 `kubectl plugin list` 掃出 `kubectl-oidc_login`。
