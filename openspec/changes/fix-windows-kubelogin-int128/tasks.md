## 1. 修改 chezmoi-external 設定

- [x] 1.1 `.chezmoiexternal.toml`：將 `$kubeloginVersion` 由 `0.2.17` 改為 `1.36.2`
- [x] 1.2 `.chezmoiexternal.toml`：把 `.local/bin/kubelogin.exe` entry 的 `url` 改為 `https://github.com/int128/kubelogin/releases/download/v{{ $kubeloginVersion }}/kubelogin_windows_amd64.zip`，`path` 改為 `kubelogin.exe`（zip 根目錄）
- [x] 1.3 `.chezmoiexternal.toml`：新增 `.local/bin/kubectl-oidc_login.exe` entry，`type = archive-file`、同一個 zip url、`path = kubelogin.exe`、`executable = true`

## 2. 更新規格文件

- [x] 2.1 spec 變更以 change delta（`changes/fix-windows-kubelogin-int128/specs/tool-dependencies/spec.md`）表達；主 spec 由 `openspec archive` 步驟套用，不在 apply 階段手改

## 3. 驗證

- [x] 3.1 `chezmoi execute-template` 渲染 `.chezmoiexternal.toml`，確認 kubelogin 與 kubectl-oidc_login 兩條 entry 的 url 都指向 int128 v1.36.2、path 為根目錄 `kubelogin.exe`
- [x] 3.2 `openspec validate fix-windows-kubelogin-int128 --strict` 通過
- [x] 3.3 實機驗證（以 worktree 為 source 做 scoped `chezmoi apply`）：`~/.local/bin/kubelogin.exe` 與 `kubectl-oidc_login.exe` 皆為 int128 v1.36.2（22581248 bytes，「Log in to the OpenID Connect provider」+ `setup` 子命令），`kubectl plugin list` 列出 `C:\Users\user\.local\bin\kubectl-oidc_login.exe`
