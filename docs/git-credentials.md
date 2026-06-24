# Git 憑證管理

Git 遠端認證設定。

## 依賴

| 依賴 | 用途 | 備註 |
|------|------|------|
| [Git](https://git-scm.com/) | Git 指令 | 各平台皆需安裝 |
| Windows 端 Git（含 GCM） | WSL 借用 Windows 端 Git Credential Manager | 僅 WSL 環境需要 |

## 認證方式選擇

一般情況下建議使用 SSH key 認證（參考 [SSH 設定](ssh.md)），以下 access token 方式適用於無法使用 SSH 的情境，例如：

- 企業環境只開放 HTTPS
- GitLab 的 CI/CD 或 API 操作需要 personal access token
- 臨時在他人機器上操作

## Access Token 憑證管理

| 平台 | 方式 | 說明 |
|------|------|------|
| Windows | Git Credential Manager | Windows 安裝的 Git 內建 GCM |
| WSL | Windows Git Credential Manager | 借用 Windows 端的 GCM，憑證統一管理 |
| Linux | `credential.helper store` | 明文存於 `~/.git-credentials` |

### Windows

Windows 安裝的 Git 已內建 Git Credential Manager (GCM)，通常預設已啟用：

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

**前提：** Windows 端已安裝 Git（含 GCM）。預設安裝路徑為 `C:\Program Files\Git`。

設定 credential helper 直接指向 Windows GCM。用 `PROGRA~1` 8.3 短名避開 `Program Files` 的空白（路徑含空白會讓 git 執行 helper 時解析失敗）：

```bash
git config --global credential.helper /mnt/c/PROGRA~1/Git/mingw64/bin/git-credential-manager.exe
```

驗證：

```bash
git config --global credential.helper
# 應顯示: /mnt/c/PROGRA~1/Git/mingw64/bin/git-credential-manager.exe
```

首次對遠端操作時，GCM 會自動彈出視窗或在終端要求輸入 token，之後就會自動記住。

> 不需要 `GIT_EXEC_PATH=...` 前綴或 `!` shell 形式 —— 只要 git.exe 在 Windows PATH 上，GCM 自己會找到。

**常見問題（踩過的雷）：**

- `Failed to locate 'git.exe' executable on the path`：GCM 是在 **Windows PATH** 找 `git.exe`（不是 `GIT_EXEC_PATH`）。確認 Git 目錄（`C:\Program Files\Git\cmd`）在 Windows PATH 上，且 PATH 上沒有殘留已移除的舊 Git（例如卸載後的 Scoop git）佔著位置卻沒有 `git.exe`。
- 改完 Windows PATH 後仍然報錯：WSL 在 **session 啟動時快取** Windows PATH，舊 session（與其啟動的 Windows 子行程）看不到新值。從 Windows 執行 `wsl --shutdown` 後重開 WSL 終端再試。

### Linux

```bash
git config --global credential.helper store
```

首次輸入帳密後，憑證會明文存於 `~/.git-credentials`，建議設定檔案權限：

```bash
chmod 600 ~/.git-credentials
```
