# Dotfiles

個人設定檔案集合，透過 [chezmoi](https://www.chezmoi.io/) 跨平台管理（Windows 11、macOS、Linux/WSL）。

---

## Bootstrap：各平台前置安裝

在使用 chezmoi 前，需先安裝 **git**、**chezmoi**，以及平台的套件管理器。

### macOS

```bash
# 1. 安裝 Xcode Command Line Tools（提供 git 和編譯工具）
xcode-select --install

# 2. 安裝 Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 3. 安裝 chezmoi
brew install chezmoi
```

### Windows（PowerShell）

> **前提**：Windows 上 git 一律透過 scoop 安裝。chezmoi 的 `.sh` script interpreter
> 硬指向 `~/scoop/apps/git/current/bin/bash.exe`，其他安裝方式會導致 script 執行失敗。

```powershell
# 1. 安裝 scoop（若尚未安裝）
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# 2. 安裝 git（scoop 本身首次安裝不需要 git，但後續 scoop update 需要）
scoop install git

# 3. 安裝 chezmoi
scoop install chezmoi
```

### Linux / WSL

```bash
# 1. 設定 passwordless sudo（chezmoi apply 的 install scripts 需要 sudo 安裝套件）
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$USER
sudo chmod 0440 /etc/sudoers.d/$USER

# 2. 安裝 git 和編譯工具
sudo apt update && sudo apt install -y git build-essential curl

# 3. 安裝 Homebrew（版本管理工具如 JDK、Python、Go 透過 brew 安裝）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# 依照 brew 的提示將 brew 加入 PATH

# 4. 安裝 chezmoi
brew install chezmoi
# 或使用官方腳本
sh -c "$(curl -fsLS get.chezmoi.io)"
```

---

## 初始化

依機器情況選擇以下其中一種方式：

### 情境 A：機器上已有此 repo（最常見）

```bash
# 告訴 chezmoi 使用現有 repo，不克隆新的
chezmoi init --source /path/to/your/dotfiles

# 查看會有哪些變更
chezmoi diff

# 套用設定
chezmoi apply
```

### 情境 B：全新機器，克隆到指定位置

```bash
# 克隆到你偏好的路徑，同時初始化
mkdir -p ~/github
chezmoi init --source ~/github/dotfiles git@github.com:idontwannarock/dotfiles.git

# 查看會有哪些變更
chezmoi diff

# 套用設定
chezmoi apply
```

### 情境 C：全新機器，使用 chezmoi 預設位置

```bash
# chezmoi 會克隆到 ~/.local/share/chezmoi（macOS/Linux）
# 或 %USERPROFILE%/AppData/Local/chezmoi（Windows）
chezmoi init --apply git@github.com:idontwannarock/dotfiles.git
```

> **首次 apply 前**：建議先執行 `chezmoi diff` 確認哪些現有設定會被覆蓋。

---

## 日常操作

```bash
# 拉取最新變更並套用（最常用）
chezmoi update

# 只看差異，不套用
chezmoi diff

# 套用全部
chezmoi apply

# 只套用特定檔案
chezmoi apply ~/.config/starship/starship.toml

# 進入 source 目錄（編輯設定、commit、push）
chezmoi cd
git add .
git commit -m "..."
git push
exit  # 回到原本的目錄
```

### 開機自動提示

每天開啟第一個 shell（bash/zsh/PowerShell）時，若 dotfiles 有新版本會自動提示：

```
dotfiles: 3 new commit(s). Run 'chezmoi update' to apply.
```

不會自動套用，保留你決定何時更新的控制權。

---

## Troubleshooting

### Windows：`chezmoi update` 報 `%1 is not a valid Win32 application`

症狀：

```
chezmoi: .claude/settings.json.sh: fork/exec ...\*.settings.json.sh: %1 is not a valid Win32 application.
```

原因：chezmoi 本機 config（`~/.config/chezmoi/chezmoi.toml`）缺少 `[interpreters.sh]`
區塊，Windows 無法直接執行 `.sh` script。這個區塊定義在 `.chezmoi.toml.tmpl`，
但該 template 只有 `chezmoi init` 時才會 render 進本機 config；`chezmoi update`
刻意不碰本機 config。所以在這個區塊加入 repo 之前就 init 過的環境會踩到。

自動修復：`run_onchange_before_patch-chezmoi-config.ps1.tmpl` 會在 `chezmoi apply`
早期偵測並補上 `[interpreters.sh]`，使用者只需要**再跑一次** `chezmoi update
--force` 即可（第一次 apply 會修好 config 但同一 run 的 `.sh` script 可能還在用
舊快取，第二次就會乾淨跑完）。

手動修復：如果上面的自動修復沒生效，可以直接 `chezmoi init`，這會重新 render
`.chezmoi.toml.tmpl` 成本機 config（不會動 source、也不會問問題）。

---

## 管理範圍

### 由 chezmoi 管理（chezmoi apply 時自動部署）

| 設定 | 部署目標 | 平台 |
|------|----------|------|
| Shell prompt（[Starship](docs/starship.md)） | `~/.config/starship/starship.toml` | 跨平台 |
| [Vim](docs/vim.md) / IdeaVim | `~/.vimrc`, `~/.ideavimrc`, `~/.vim/` | 跨平台 |
| Bash | `~/.bashrc`, `~/.shell_common` | Windows (Git Bash)、Linux/WSL |
| Zsh | `~/.zshrc`, `~/.shell_common` | macOS |
| PowerShell 7 | `~/Documents/PowerShell/` | Windows |
| PowerShell 5 | `~/Documents/WindowsPowerShell/` | Windows |
| PS shared fragments | `~/Documents/_shared-profile.d/` | Windows |
| Claude Code 全域設定 | `~/.claude/CLAUDE.md` | 跨平台 |
| Claude Code commands | `~/.claude/commands/` | 跨平台 |
| Claude Code agents | `~/.claude/agents/` | 跨平台 |
| Codex CLI 全域設定 | `~/.codex/config.toml` | 跨平台 |
| Codex CLI skills | `~/.codex/skills/` | 跨平台 |
| Statusline binary | `~/.local/bin/statusline` | 跨平台（自動下載） |

### 自動安裝的工具

`chezmoi apply` 時會自動安裝以下工具（若尚未安裝）。Windows 用 scoop，macOS 用 brew，Linux/WSL 一般工具用 apt、版本管理工具（JDK、Python）用 sdkman / uv，Go 在 Linux 用官方 tarball 裝到 `~/.local/go`（apt 版太舊不支援 GOTOOLCHAIN）。

**基礎設施（before phase）：**

| 工具 | 說明 |
|------|------|
| jq | modify_ scripts 的 JSON 處理 |

**開發語言 / Runtime（install-01-runtimes）：**

| 工具 | 說明 |
|------|------|
| NVM + Node.js | npm 的來源（Unix: curl installer, Windows: scoop） |
| Vim | 編輯器 |
| Go | Base version ≥ 1.24（支援 GOTOOLCHAIN 自動下載專案需求版本）。Linux 用官方 tarball 裝到 `~/.local/go`；macOS brew；Windows scoop `go124`。 |
| Python 3.11, 3.13 | |
| uv | Python 套件管理 |
| Rustup | Rust 工具鏈 |
| Maven 3 | Java 建置 |
| Temurin JDK 8, 11, 17, 21, 25 | Adoptium OpenJDK |
| Starship | Shell prompt |

**npm 全域工具（install-02-npm-tools）：**

| 工具 | 說明 |
|------|------|
| Claude Code | AI CLI |
| Codex CLI | AI CLI |
| OpenSpec | 結構化開發流程 |

**Claude Code 設定（install-03-claude-config）：**

| 工具 | 說明 |
|------|------|
| superpowers / code-review / slack plugins | Claude Code plugins |
| jdtls | Java LSP |
| agent-browser / chrome-devtools MCP | Claude Code MCP servers |

**容器 / 雲（install-containers）：**

| 工具 | 說明 |
|------|------|
| Docker, Docker Compose | 容器 |
| kubectl, kubelogin | Kubernetes CLI |
| Lens | K8s GUI（Windows/macOS） |

**CLI 工具（install-cli-tools）：**

| 工具 | 說明 |
|------|------|
| 7zip, curl, ffmpeg | 基礎工具 |
| Hugo | 靜態網站 |
| nexttrace | 路由追蹤 |
| yt-dlp | 影片下載 |
| clink, dark, vimtutor, winget, winget-ps | Windows 專屬 |

**字型（install-fonts）：**

| 工具 | 說明 |
|------|------|
| CaskaydiaCove Nerd Font Mono | Terminal 字型 |
| JetBrains Mono | 程式字型 |

### 不納入 chezmoi（手動管理）

| 項目 | 原因 |
|------|------|
| [SSH keys](docs/ssh.md) | 每台機器獨立，不應同步 |
| [Git 憑證](docs/git-credentials.md) | 包含機器專屬 access token |
| GUI 應用程式 | 各機器需求不同（參考 [`scoop/scoopfile.json`](scoop/scoopfile.json)） |
| NeoVim（`neovim/`） | 已棄用 |

---

## 目錄結構

```
dotfiles/
├── .chezmoi.toml.tmpl        # chezmoi 環境偵測設定（WSL detection 等）
├── .chezmoiignore.tmpl       # 依 OS 排除不適用的檔案
├── .chezmoiexternal.toml     # 外部資源（statusline binary）
├── .chezmoitemplates/        # 平台專用 template 片段
│   ├── bashrc/               #   bashrc/{windows,linux}
│   ├── scripts/              #   scripts/{load-nvm}（安裝腳本共用片段）
│   ├── shell-common/         #   shell-common/{base,windows,linux,darwin}
│   └── zshrc/                #   zshrc/{darwin}
├── .github/workflows/        # GitHub Actions（statusline 自動編譯發佈）
├── Documents/                # Windows PowerShell profiles（chezmoi 管理）
│   ├── _shared-profile.d/    # PS5 + PS7 共用 fragments
│   ├── PowerShell/           # PS7 專屬 profile
│   └── WindowsPowerShell/    # PS5 專屬 profile
├── docs/                     # 工具設定說明文件
├── dot_config/               # ~/.config/ 設定
│   └── starship/
├── dot_claude/               # ~/.claude/ 設定
│   ├── exact_commands/       # Commands（exact_：自動清理移除的檔案）
│   └── exact_agents/         # Agents（exact_：自動清理移除的檔案）
├── dot_codex/                # ~/.codex/ 設定
│   └── skills/               # Codex skills
├── dot_local/bin/            # ~/.local/bin/ 腳本
├── dot_shell_common.tmpl     # ~/.shell_common 入口（依 OS 載入 template 片段）
├── dot_bashrc.tmpl           # ~/.bashrc 入口（Windows Git Bash / Linux/WSL）
├── dot_zshrc.tmpl            # ~/.zshrc 入口（macOS）
├── dot_vimrc                 # ~/.vimrc
├── dot_ideavimrc             # ~/.ideavimrc
├── dot_vim/                  # ~/.vim/
├── run_onchange_before_*.tmpl # 前置腳本（jq 安裝、chezmoi config 修復）
├── run_once_install-*.tmpl   # 工具安裝腳本（依序：01-runtimes → 02-npm-tools → 03-claude-config, containers, cli-tools, fonts）
├── run_onchange_*.tmpl       # 設定更新腳本（變更時重跑）
├── run_after_*.tmpl          # 後置腳本（Windows codex config 合併）
├── claude/statusline/        # statusline 原始碼（CI 編譯）
├── neovim/                   # NeoVim 設定（已棄用）
├── scoop/                    # Scoop 套件參考清單（手動管理的 GUI 應用等）
└── scripts/                  # 輔助腳本（worklogs 設定等）
```

---

## 文件

| 文件 | 說明 |
|------|------|
| [Bash](docs/bash.md) | Bash 設定、worklogs、Windows Terminal 整合 |
| [Claude Code](docs/claude-code.md) | Claude Code 設定、statusline、plugins |
| [Codex CLI](docs/codex-cli.md) | Codex CLI 設定、skills、Claude workflow 對齊 |
| [Git 憑證管理](docs/git-credentials.md) | Git 遠端認證（GCM、SSH、WSL） |
| [PowerShell](docs/powershell.md) | PowerShell profile 設定與依賴 |
| [SSH](docs/ssh.md) | SSH key 設定教學 |
| [Starship](docs/starship.md) | Starship prompt 設定 |
| [User Scripts](docs/user-scripts.md) | 輔助腳本（worklogs、scoop 更新） |
| [Vim](docs/vim.md) | Vim / IdeaVim 設定與快捷鍵 |
