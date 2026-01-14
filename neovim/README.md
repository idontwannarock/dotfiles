# NeoVim Config files

This NeoVim settings repo is for personal use, but you are welcome to use and free to ask any questions about it!

## Pre-requisite

- git
- neovim

## TL;DR

### Unix

```bash
git clone git@github.com:idontwannarock/neovim-config.git ~/.config/nvim
```

#### Pre-requisite

- nodejs
- cc
- rg

```bash
sudo apt install nodejs clang ripgrep
npm install -g neovim
```

#### Reference

**IMPORTANT** Ubuntu environment requires additional setup in advance.

Please reference following docs to setup properly.

- [sudo apt-get install libstdc++](https://askubuntu.com/a/726789)
- [Neovim Installation on Ubuntu](https://github.com/neovim/neovim/wiki/Installing-Neovim#ubuntu)
- [Neovim Unstable](https://launchpad.net/~neovim-ppa/+archive/ubuntu/unstable)

> You need to explicitly install Neovim 0.7.0+ version as current stable version for Ubuntu is 0.6.0.

### Windows

```bat
git clone git@github.com:idontwannarock/neovim-config.git ~\AppData\Local\nvim
```

#### Pre-requisite

- llvm
- nodejs / npm
- wget
- gzip
- rg

```powershell
choco install llvm nodejs-lts wget gzip ripgrep -y
clang --version
```

#### Reference

**IMPORTANT** Windows environment requires additional setup in advance.

Please reference following docs to setup properly.

- [Treesitter Windows support](https://github.com/nvim-treesitter/nvim-treesitter/wiki/Windows-support)
- [How run clang from command line on Windows?](https://stackoverflow.com/a/42540457/7605040)

