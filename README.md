# Dotfiles

個人設定檔案集合，透過 [chezmoi](https://www.chezmoi.io/) 跨平台管理（Windows 11、macOS、Linux/WSL）。

---

## Bootstrap：各平台前置安裝

在使用 chezmoi 前，需先安裝 **git** 與 **chezmoi**。

### macOS

```bash
# 安裝 git（若尚未安裝）
xcode-select --install
# 或
brew install git

# 安裝 chezmoi
brew install chezmoi
# 或使用官方腳本
sh -c "$(curl -fsLS get.chezmoi.io)"
```

### Windows（PowerShell）

```powershell
# 安裝 git（若尚未安裝）
winget install git.git
# 或（若已有 scoop）
scoop install git

# 安裝 chezmoi
winget install twpayne.chezmoi
# 或
scoop install chezmoi
```

### WSL Ubuntu

```bash
# 安裝 git
sudo apt update && sudo apt install -y git

# 安裝 chezmoi
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

> **⚠️ 首次 apply 前**：建議先執行 `chezmoi diff` 確認哪些現有設定會被覆蓋。

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

## 管理範圍

### 由 chezmoi 管理（chezmoi apply 時自動部署）

| 設定 | 部署目標 | 平台 |
|------|----------|------|
| Shell prompt（Starship） | `~/.config/starship/starship.toml` | 跨平台 |
| Fastfetch | `~/.config/fastfetch/` | 跨平台 |
| Vim / IdeaVim | `~/.vimrc`, `~/.ideavimrc`, `~/.vim/` | 跨平台 |
| Bash（WSL） | `~/.bashrc`, `~/.shell_common` | Linux/WSL |
| Zsh | `~/.zshrc`, `~/.shell_common` | macOS |
| PowerShell 7 | `~/Documents/PowerShell/` | Windows |
| PowerShell 5 | `~/Documents/WindowsPowerShell/` | Windows |
| PS shared fragments | `~/Documents/_shared-profile.d/` | Windows |
| Claude Code 全域設定 | `~/.claude/CLAUDE.md` | 跨平台 |
| Claude Code commands | `~/.claude/commands/` | 跨平台 |
| Claude Code agents | `~/.claude/agents/` | 跨平台 |
| Statusline binary | `~/.local/bin/statusline` | 跨平台（自動下載） |

### 不納入 chezmoi（手動管理）

| 項目 | 原因 |
|------|------|
| SSH keys（`ssh/`） | 每台機器獨立，不應同步 |
| Scoop 套件清單（`scoop/`） | 尚未整理必要 vs 選用套件 |
| Git 憑證（`git/`） | 包含機器專屬 access token |
| NeoVim（`neovim/`） | 已棄用 |

---

## 目錄結構

```
dotfiles/
├── .chezmoi.toml.tmpl        # chezmoi 環境偵測設定（WSL detection 等）
├── .chezmoiignore.tmpl       # 依 OS 排除不適用的檔案
├── .chezmoiexternal.toml     # 外部資源（statusline binary）
├── .github/workflows/        # GitHub Actions（statusline 自動編譯發佈）
├── Documents/                # Windows PowerShell profiles（chezmoi 管理）
│   ├── _shared-profile.d/    # PS5 + PS7 共用 fragments
│   ├── PowerShell/           # PS7 專屬 profile
│   └── WindowsPowerShell/    # PS5 專屬 profile
├── dot_config/               # ~/.config/ 設定
│   ├── fastfetch/
│   └── starship/
├── dot_claude/               # ~/.claude/ 設定
│   ├── exact_commands/       # Commands（exact_：自動清理移除的檔案）
│   └── exact_agents/         # Agents（exact_：自動清理移除的檔案）
├── dot_local/bin/            # ~/.local/bin/ 腳本
├── dot_shell_common          # ~/.shell_common（bash/zsh 共用）
├── dot_bashrc.tmpl           # ~/.bashrc（WSL only）
├── dot_zshrc                 # ~/.zshrc（macOS only）
├── dot_vimrc                 # ~/.vimrc
├── dot_ideavimrc             # ~/.ideavimrc
├── dot_vim/                  # ~/.vim/
├── run_once_install-*.tmpl   # 工具安裝腳本（只跑一次）
├── run_onchange_*.tmpl       # 設定更新腳本（變更時重跑）
├── bash/                     # Bash 輔助腳本（非 chezmoi 管理）
├── claude/statusline/        # statusline 原始碼（GitHub Actions 編譯）
├── git/                      # Git 憑證說明
├── scoop/                    # Scoop 套件清單（手動管理）
├── ssh/                      # SSH key 說明
└── usr/                      # 其他自訂腳本
```
