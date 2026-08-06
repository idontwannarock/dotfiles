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

## `~/.ssh/config` 的三層結構

`~/.ssh/config` 本身**永遠是機器本地的、不進這個 repo**：它含有內網 IP、公司 FQDN、主機別名，這些都算內部資訊。
結構分三層，用兩個 `Include` 夾住中間的主機區塊：

```
Include ~/.ssh/config.d/*      ← 覆寫層（chezmoi 部署）

Host github.com                ← 常用、各自獨立的主機
Host dev157
...

Host *                         ← 預設層（機器本地）
  Include ~/.ssh/hosts.d/*
```

| 層 | 目錄 | 位置 | 語意 | 誰維護 |
|---|---|---|---|---|
| 覆寫層 | `~/.ssh/config.d/` | 檔首 | 蓋過下方所有 host 區塊 | chezmoi（來源 `home/private_dot_ssh/private_config.d/`）|
| 主體 | `~/.ssh/config` | 中間 | 常用、不成組的主機 | 手動，機器本地 |
| 預設層 | `~/.ssh/hosts.d/` | 檔尾 | 被上方所有區塊覆寫 | 手動，機器本地 |

### 為什麼位置就是語意

ssh 對每個關鍵字取**第一個看到的值**（first-match-wins），不是後蓋前。同一個 `Host devkws*` 區塊放在具體主機**之前**是覆寫、放在**之後**是預設——語法完全相同，只有位置不同。

因此 `config.d/`（檔首）只能放兩種東西：

1. 值本來就在所有 host 之間一致的通用設定（覆寫等於沒覆寫，安全）；
2. 刻意要覆寫特定 host pattern 的政策。

反過來說，`IdentityFile` / `IdentitiesOnly` 這類**各 host 不同**的設定不可放進 `Host *`——它會讓沒有自行宣告金鑰的 host（例如只吃密碼+OTP 的公司主機）被強迫送出金鑰，觸發 `MaxAuthTries`。

### 覆寫層目前的 drop-in

| 檔案 | 內容 | 平台 |
|------|------|------|
| `config.d/00-common` | `Host *` 的 `ServerAliveInterval 30` | 全平台 |
| `config.d/corp-multiplex` | 公司主機的 `ControlMaster` + `PubkeyAuthentication no` | WSL/Linux/macOS（Win32-OpenSSH 無 ControlMaster，見 [corp-ssh-setup.md](corp-ssh-setup.md)） |

### 預設層：成組的主機抽成獨立檔案

同一組主機（例如公司的 `devkws*` 叢集，13 台）整組搬進 `~/.ssh/hosts.d/` 下的一個檔案，主 config 只留一行 Include。組內只寫各主機獨有的 `HostName`，共用的 `User` / `ProxyJump` 收成該檔**最後**一個 pattern 區塊：

```
# ~/.ssh/hosts.d/devkws
Host devkwsxcm01
  HostName dev-zone-x-keywordsearch-clustermanager01.devstg.cti.hk

... （其餘 devkws* 主機）

Host devkwsmongo
  HostName hktv-keyword-search-mongodb-dev.nat.hkmpcl.com.hk
  User root              # 例外：覆寫下方群組預設（先出現先贏）

# ── 群組預設（必須是本檔最後一個區塊）──
Host devkws*
  User howard.wang@shoalter.com
  ProxyJump dev157
```

兩個陷阱，兩者都**不會報錯**：

**一、`hosts.d/` 的檔案不可放進 `config.d/`。** 那個目錄被檔首的 `Include ~/.ssh/config.d/*` 匹配，整組會從「預設」變成「覆寫」——上例中 `devkwsmongo` 的 `User root` 會被靜默蓋成一般帳號。若兩處都 Include，同一批區塊被解析兩次而第一次獲勝，症狀是「改了檔尾卻沒反應」。

**二、檔尾 Include 前面的 `Host *` 不可省略。** OpenSSH 的 `Include` 和 `HostName`、`User` 一樣，屬於它前面最近的 `Host` 區塊：

```
Host dev-livekit
  HostName zoom-live-dev01.devstg.cti.hk

Include ~/.ssh/hosts.d/*       # ← 錯：這行屬於 Host dev-livekit
```

寫成這樣，只有連 `dev-livekit` 時才會展開該目錄，連 `devkwsxcm01` 時整組設定形同不存在，而 `ssh -G` 不會印任何警告。加一行 `Host *` 重置 context 即可：

```
Host *
  Include ~/.ssh/hosts.d/*
```

（檔首的 `Include config.d/*` 沒有這個問題，因為它出現在第一個 `Host` 之前，處於全域 context。）

副作用：`Host devkws*` 會匹配到打錯的別名（`ssh devkwsxyz` 也會拿到 `ProxyJump`），失敗訊息會變成跳板連線錯誤而非「找不到主機」。這是萬用字元的固有代價。

### 主機別名命名

別名以該伺服器的實際名稱為準（`twsvr-gpu01`、`fa00572`），只有在實際名稱難以辨識時才另取好記的短名。同一台機器不要維護兩個別名——Windows 與 WSL 是兩份獨立的本地 config，重複別名只會加速兩邊漂移。

### 驗證改動

改完 `~/.ssh/config` 後，用 `ssh -G` 比對前後：它會印出 ssh 實際套用的完整設定，是唯一能證明「重構沒有改變行為」的方式。

```bash
for h in <alias1> <alias2> ...; do echo "## $h"; ssh -G "$h"; done > after.txt
diff before.txt after.txt
```

Windows 上請用 `C:\Windows\System32\OpenSSH\ssh.exe`——Git Bash 自帶的 msys ssh 是不同版本，輸出欄位會有差異。

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
