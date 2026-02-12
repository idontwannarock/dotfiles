# Dotfiles

個人設定檔案集合。主要為 Windows 設計，但盡量保持跨平台相容性（Windows、macOS、Linux/WSL）。

## 目錄結構

```
dotfiles/
├── bash/          # Bash 設定 (WSL)
├── claude/        # Claude Code 設定
├── fastfetch/     # Fastfetch 系統資訊顯示設定
├── git/           # Git 憑證管理設定
├── neovim/        # NeoVim 設定 (已棄用)
├── powershell/    # PowerShell 設定 (Windows)
├── scoop/         # Scoop 套件管理器設定 (Windows)
├── ssh/           # SSH key 設定
├── starship/      # Starship prompt 設定
├── usr/           # 自訂腳本與工具
└── vim/           # Vim 設定
```

## Linux/WSL 快速開始

如果你使用 Linux 或 WSL，以下是最常用的設定：

### Vim
```bash
cp vim/.ideavimrc ~/.ideavimrc
cp vim/.vimrc ~/.vimrc
cp -r vim/.vim ~/.vim
```

### Fastfetch
```bash
# 安裝 fastfetch (Ubuntu)
sudo add-apt-repository ppa:zhangsongcui3371/fastfetch
sudo apt update && sudo apt install fastfetch

# 套用設定
cp -r fastfetch ~/.config/fastfetch
```

### Starship
```bash
cp starship/starship.toml ~/.config/starship.toml
```

### Claude Code
```bash
mkdir -p ~/.claude
cp claude/settings.json ~/.claude/settings.json
```

## 各設定詳細說明

| 目錄 | 說明 | 平台 |
|------|------|------|
| [bash](./bash/) | WSL Bash 與 Windows Terminal 整合 | Linux/WSL |
| [claude](./claude/) | Claude Code AI 助手設定 | 跨平台 |
| [fastfetch](./fastfetch/) | 終端機系統資訊顯示 | 跨平台 |
| [git](./git/) | Git 憑證管理（access token） | 跨平台 |
| [neovim](./neovim/) | NeoVim 設定 (已棄用) | 跨平台 |
| [powershell](./powershell/) | PowerShell 設定 | Windows |
| [scoop](./scoop/) | Scoop 套件管理器 | Windows |
| [ssh](./ssh/) | SSH key 設定 | 跨平台 |
| [starship](./starship/) | Starship 終端機 prompt 設定 | 跨平台 |
| [usr](./usr/) | 自訂腳本與工具 | 跨平台 |
| [vim](./vim/) | Vim 編輯器設定 | 跨平台 |

## TODO

- [ ] 自動化安裝腳本
