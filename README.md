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

> **前提**：先裝好 **git**、**PowerShell 7（pwsh）** 與 **chezmoi**。
> - chezmoi 的 `.sh` interpreter 會自動偵測 Git for Windows（依序找
>   `~/.local/opt/git`、`C:\Program Files\Git`、scoop git），git 用 winget、官方安裝器
>   或 scoop 皆可，**不再硬依賴 scoop**。
> - chezmoi 對 `.ps1` run script 預設用 **pwsh** 執行（非 Windows 內建的 PowerShell 5.1），
>   且**無 fallback**：缺了 pwsh，第一個 `.ps1` 安裝腳本就會 `exec: "pwsh": not found` 而中止。
>   pwsh 之於 `.ps1` 等同 git 之於 `.sh`，故為手動前置條件。

```powershell
# 1. 安裝 git（winget 為 OS 內建，不需 scoop）
winget install Git.Git

# 2. 安裝 PowerShell 7（chezmoi 用它執行 .ps1 安裝腳本）
winget install Microsoft.PowerShell

# 3. 安裝 chezmoi
winget install twpayne.chezmoi
```

> **MSIX vs MSI**：`winget install Microsoft.PowerShell` 交付的是 **MSIX（Store）**版
> —— 它落在版本化的 `WindowsApps`、靠 App Execution Alias 上 PATH，且提權安裝會
> `0x80070005`。bootstrap 用它**完全堪用**（chezmoi 的 `.ps1` interpreter 靠 PATH 解析）。
> 若你偏好乾淨的 **MSI** 版（落 `C:\Program Files\PowerShell\7`、非 Store），winget 給不了，
> 需改用 [GitHub release](https://github.com/PowerShell/PowerShell/releases) 的
> `PowerShell-<ver>-win-x64.msi`（提權 `msiexec /i ... /qn`）。已是 MSIX 的機器可用部署到
> `~/.local/bin/switch-pwsh-to-msi.ps1` 的 helper（提權執行）一鍵切換；apply 期間也會偵測並提醒。

> scoop 為**選用**：僅在你要用它管理 GUI 應用程式時才需安裝
> （GUI app 清單維護於 [gist](https://gist.github.com/idontwannarock/cef42b856b878e718a2e402eb8e5d7e1)，不在本 repo）。chezmoi 本身不需要 scoop。

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
# 拉取最新變更並套用（最常用，已預設 --init --force --refresh-externals）
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
在本機 config 不存在或過舊時需要 `chezmoi init` 才會 render 進去。

自動修復：`run_onchange_before_patch-chezmoi-config.ps1.tmpl` 會在 `chezmoi apply`
早期偵測並補上 `[interpreters.sh]`，使用者只需要**再跑一次** `chezmoi update`
即可（第一次 apply 會修好 config 但同一 run 的 `.sh` script 可能還在用
舊快取，第二次就會乾淨跑完）。

手動修復：直接執行 `chezmoi init`，這會重新 render `.chezmoi.toml.tmpl`
成本機 config（不會動 source directory、也不會問問題）。

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
| Rustup | Rust 工具鏈（安裝後，每次 `chezmoi apply` 由 `run_update-rust-toolchain` 自動 `rustup update stable` 追蹤最新版） |
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
| GUI 應用程式 | 各機器需求不同（清單維護於 [gist](https://gist.github.com/idontwannarock/cef42b856b878e718a2e402eb8e5d7e1)） |
| NeoVim | 已棄用並自 repo 移除，改用 [Vim](docs/vim.md) 設定；舊設定可自 git history 取回 |

---

## 目錄結構

chezmoi 的 source state 全部收在 `home/` 底下，由 repo root 的 `.chezmoiroot`
（內容為 `home`）指向。repo root 只保留「不部署」的專案基礎建設（CI 原始碼、文件、
測試、OpenSpec），讓根目錄保持精簡。兩者互不干擾：root 的檔案 chezmoi 根本看不到，
因此不需要再用 `.chezmoiignore` 排除。

```
dotfiles/
├── .chezmoiroot              # 內容為 "home"：chezmoi 從 home/ 讀取 source state
├── home/                     # ← chezmoi source root（所有受管設定與安裝腳本）
│   ├── .chezmoi.toml.tmpl    # chezmoi 環境偵測設定（WSL detection 等）
│   ├── .chezmoiignore.tmpl   # 依 OS 排除不適用的檔案
│   ├── .chezmoiexternal.toml # 外部資源（statusline / passgen binary）
│   ├── .chezmoiremove        # 退役檔案清單（跨機器清除已部署的舊檔）
│   ├── .chezmoitemplates/    # 平台專用 template 片段
│   │   ├── bashrc/           #   bashrc/{windows,linux}
│   │   ├── scripts/          #   scripts/{load-nvm}（安裝腳本共用片段）
│   │   ├── shell-common/     #   shell-common/{base,windows,linux,darwin}
│   │   └── zshrc/            #   zshrc/{darwin}
│   ├── Documents/            # Windows PowerShell profiles（chezmoi 管理）
│   │   ├── _shared-profile.d/ #   PS5 + PS7 共用 fragments
│   │   ├── PowerShell/       #   PS7 專屬 profile
│   │   └── WindowsPowerShell/ #   PS5 專屬 profile
│   ├── dot_config/           # ~/.config/ 設定（starship 等）
│   ├── dot_claude/           # ~/.claude/ 設定（exact_commands / exact_agents）
│   ├── dot_codex/            # ~/.codex/ 設定（skills）
│   ├── dot_local/bin/        # ~/.local/bin/ 腳本（wrapper 與手動執行的輔助腳本）
│   ├── dot_shell_common.tmpl # ~/.shell_common 入口（依 OS 載入 template 片段）
│   ├── dot_bashrc.tmpl       # ~/.bashrc 入口（Windows Git Bash / Linux/WSL）
│   ├── dot_zshrc.tmpl        # ~/.zshrc 入口（macOS）
│   ├── dot_vimrc / dot_ideavimrc / dot_vim/  # Vim / IdeaVim
│   ├── run_onchange_before_*.tmpl # 前置腳本（jq 安裝、chezmoi config 修復）
│   ├── run_once_install-*.tmpl    # 工具安裝腳本（01-runtimes → 02-npm-tools → 03-claude-config, containers, cli-tools, fonts）
│   ├── run_onchange_*.tmpl        # 設定更新腳本（變更時重跑）
│   └── run_after_*.tmpl           # 後置腳本（Windows codex config 合併）
│
├── .github/workflows/        # GitHub Actions（statusline / passgen 自動編譯發佈）
├── tools/                    # 自建工具原始碼（CI 編譯為 release，經 external 拉回，不部署）
│   ├── statusline/           #   Go：Claude Code 狀態列
│   └── passgen/              #   Rust：密碼產生器
├── docs/                     # 工具設定說明文件
├── tests/                    # Pester 測試（CI 於 windows-latest 執行）
└── openspec/                 # OpenSpec 變更追蹤
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
| [User Scripts](docs/user-scripts.md) | 手動執行的輔助腳本（scoop 更新、pwsh 換裝） |
| [Vim](docs/vim.md) | Vim / IdeaVim 設定與快捷鍵 |
