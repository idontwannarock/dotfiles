# Git 設定

Git 遠端認證設定。

## 認證方式選擇

一般情況下建議使用 SSH key 認證（參考 [ssh/](../ssh/)），以下 access token 方式適用於無法使用 SSH 的情境，例如：

- 企業環境只開放 HTTPS
- GitLab 的 CI/CD 或 API 操作需要 personal access token
- 臨時在他人機器上操作

## Access Token 憑證管理

| 平台 | 方式 | 說明 |
|------|------|------|
| Windows | Git Credential Manager | Scoop 安裝的 Git 內建 GCM |
| WSL | Windows Git Credential Manager | 借用 Windows 端的 GCM，憑證統一管理 |
| Linux | `credential.helper store` | 明文存於 `~/.git-credentials` |

### Windows

透過 Scoop 安裝的 Git 已內建 Git Credential Manager (GCM)，通常預設已啟用：

```powershell
git config --global credential.helper manager
```

驗證：

```powershell
git config --global credential.helper
# 應顯示: manager
```

GCM 會將憑證安全地存於 Windows Credential Manager 中。

### WSL

WSL 透過呼叫 Windows 端的 GCM 來管理憑證，與 Windows 共用同一組已儲存的 token。

**前提：** Windows 端已透過 [Scoop](https://scoop.sh) 安裝 Git（含 GCM）。

1. 找到 Windows 端 GCM 的實際路徑：

```bash
find "/mnt/c/Users/$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')/scoop/apps/git" \
  -name "git-credential-manager.exe" -path "*/mingw64/bin/*" 2>/dev/null
```

2. 用找到的路徑設定 credential helper（以 Scoop 預設路徑為例）：

```bash
git config --global credential.helper \
  "/mnt/c/Users/<USERNAME>/scoop/apps/git/current/mingw64/bin/git-credential-manager.exe"
```

> 使用 `current` symlink 路徑，Scoop 更新 Git 版本後不需重新設定。

3. 驗證：

```bash
git config --global credential.helper
# 應顯示: /mnt/c/Users/<USERNAME>/scoop/apps/git/current/mingw64/bin/git-credential-manager.exe
```

首次對遠端操作時，GCM 會自動彈出視窗或在終端要求輸入 token，之後就會自動記住。

### Linux

```bash
git config --global credential.helper store
```

首次輸入帳密後，憑證會明文存於 `~/.git-credentials`，建議設定檔案權限：

```bash
chmod 600 ~/.git-credentials
```
