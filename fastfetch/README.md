# Fastfetch 設定

[Fastfetch](https://github.com/fastfetch-cli/fastfetch) 是一個快速的系統資訊顯示工具。

## 安裝 Fastfetch

### Linux (Ubuntu)

```bash
sudo add-apt-repository ppa:zhangsongcui3371/fastfetch
sudo apt update
sudo apt install fastfetch
```

或從 [GitHub Releases](https://github.com/fastfetch-cli/fastfetch/releases) 下載 `.deb` 安裝：

```bash
# 下載最新版本 (請替換版本號)
wget https://github.com/fastfetch-cli/fastfetch/releases/download/2.x.x/fastfetch-linux-amd64.deb
sudo dpkg -i fastfetch-linux-amd64.deb
```

### macOS

```bash
brew install fastfetch
```

### Windows

```powershell
scoop install fastfetch
# 或
winget install fastfetch
```

## 套用設定

將整個 fastfetch 資料夾放到 `~/.config` 資料夾底下：

```bash
cp -r fastfetch ~/.config/fastfetch
```

重開終端機或執行 `fastfetch` 即可看到生效的成果。
