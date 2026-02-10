# SSH 設定

SSH key 設定，適用於 Git 遠端認證、遠端伺服器連線等各種 SSH 使用情境。

## 依賴

| 依賴 | 用途 | 備註 |
|------|------|------|
| [OpenSSH](https://www.openssh.com/) | `ssh-keygen`、`ssh-agent`、`ssh-add` | 大多數系統已預裝；Windows 需確認 OpenSSH 功能已啟用 |

## 產生 SSH Key

各平台指令相同：

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

> Ed25519 是目前推薦的演算法，比 RSA 更安全且金鑰更短。

## 啟動 SSH Agent 並加入金鑰

### Windows（PowerShell）

```powershell
# 確認 ssh-agent 服務已啟用（需以管理員執行一次）
Get-Service ssh-agent | Set-Service -StartupType Automatic
Start-Service ssh-agent

# 加入金鑰
ssh-add "$env:USERPROFILE\.ssh\id_ed25519"
```

### WSL / Linux

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

若希望登入時自動啟動 ssh-agent，可在 `~/.bashrc` 加入：

```bash
if [ -z "$SSH_AUTH_SOCK" ]; then
  eval "$(ssh-agent -s)" > /dev/null
  ssh-add ~/.ssh/id_ed25519 2>/dev/null
fi
```

## 將公鑰加入遠端服務

複製公鑰內容：

```bash
cat ~/.ssh/id_ed25519.pub
```

然後貼到對應服務的 SSH Keys 設定頁面：

- **GitHub**: Settings > SSH and GPG keys > New SSH key
- **GitLab**: Preferences > SSH Keys > Add new key

## SSH Config 設定

編輯 `~/.ssh/config` 可簡化連線設定：

```
# GitHub
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519

# GitLab（範例）
Host gitlab.example.com
    HostName gitlab.example.com
    User git
    IdentityFile ~/.ssh/id_ed25519

# 自訂主機
Host myserver
    HostName 192.168.1.100
    User deploy
    IdentityFile ~/.ssh/id_ed25519
    Port 22
```

設定後可直接用 `ssh myserver` 連線，或用 `git clone git@github.com:user/repo.git` 操作 Git。

## 驗證連線

```bash
# GitHub
ssh -T git@github.com

# GitLab
ssh -T git@gitlab.example.com
```

## 檔案權限

SSH 對檔案權限有嚴格要求，權限不正確會導致連線被拒：

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
chmod 600 ~/.ssh/config
```
