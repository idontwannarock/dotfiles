# Vim 設定

## 依賴

| 依賴 | 用途 | 安裝方式 |
|------|------|----------|
| vim | Vim 編輯器 | 見下方 |
| curl | 自動下載 vim-plug | 通常已預裝 |
| git | vim-plug 下載插件 | 通常已預裝 |

### Linux 安裝 Vim

```bash
# Ubuntu/Debian
sudo apt install vim

# Fedora
sudo dnf install vim

# Arch
sudo pacman -S vim
```

### macOS 安裝 Vim

```bash
brew install vim
```

## TL;DR

For Linux and macOS:

```bash
cp .ideavimrc ~/.ideavimrc
cp .vimrc ~/.vimrc
cp -r .vim ~/.vim
```

For Windows (PowerShell):

```powershell
Copy-Item .ideavimrc ~/.ideavimrc
Copy-Item .vimrc ~/.vimrc
Copy-Item -Recurse .vim ~/.vim
```

首次啟動 Vim 時，會自動下載 [vim-plug](https://github.com/junegunn/vim-plug) 並安裝插件。

## 功能

### 輸入法自動切換

離開 Insert Mode 時自動切換到英文輸入法，進入 Insert Mode 時恢復上次的輸入法。

| 平台 | 工具 | 自動安裝 |
|------|------|----------|
| Windows | im-select.exe | ✅ 首次啟動自動下載 |
| macOS | im-select | ✅ 首次啟動自動下載 |
| Linux (fcitx5) | fcitx5-remote | ❌ 需先安裝 fcitx5 |
| Linux (fcitx) | fcitx-remote | ❌ 需先安裝 fcitx |
| Linux (ibus) | ibus | ❌ 需先安裝 ibus |

Windows/macOS 會自動下載 im-select 到 `~/.vim/bin/`，無需額外安裝。
