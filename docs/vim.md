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

## 管理方式

設定檔由 chezmoi 管理，部署到 `~/.vimrc`、`~/.ideavimrc`、`~/.vim/`。

首次啟動 Vim 時，會自動下載 [vim-plug](https://github.com/junegunn/vim-plug) 並安裝插件。

## 快捷鍵

Leader 鍵設為 `空白鍵`。

### 移動

| 快捷鍵 | 模式 | 功能 |
|--------|------|------|
| `<Leader>s` | Normal | EasyMotion 雙字元跳轉 |
| `<Leader>j` | Normal | EasyMotion 向下快速移動 |
| `<Leader>k` | Normal | EasyMotion 向上快速移動 |
| `hh` | Normal/Visual | 跳到行首 |
| `ll` | Normal/Visual | 跳到行尾 |
| `J` | Visual | 向下移動選中的行 |
| `K` | Visual | 向上移動選中的行 |

### Markdown 折疊

在 Markdown 檔案中可折疊 code block（需 mkdx 插件）：

| 快捷鍵 | 功能 |
|--------|------|
| `za` | 切換當前折疊 |
| `zo` | 展開當前折疊 |
| `zc` | 關閉當前折疊 |
| `zM` | 關閉所有折疊 |
| `zR` | 展開所有折疊 |

## 功能

### 輸入法自動切換

離開 Insert Mode 時自動切換到英文輸入法，進入 Insert Mode 時恢復上次的輸入法。

| 平台 | 工具 | 自動安裝 |
|------|------|----------|
| Windows | im-select.exe | 首次啟動自動下載 |
| macOS | im-select | 首次啟動自動下載 |
| Linux (fcitx5) | fcitx5-remote | 需先安裝 fcitx5 |
| Linux (fcitx) | fcitx-remote | 需先安裝 fcitx |
| Linux (ibus) | ibus | 需先安裝 ibus |

Windows/macOS 會自動下載 im-select 到 `~/.vim/bin/`，無需額外安裝。
