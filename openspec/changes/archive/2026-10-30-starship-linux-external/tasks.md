## 1. Linux starship 改用 external

- [x] 1.1 `home/.chezmoiexternal.toml`：把 `$starshipVersion` 與 Renovate 註記移到 Windows 區塊之前，新增 Linux `.local/bin/starship` archive-file entry（驗證：在 Linux 與 Windows 兩種 OS 下 render，各自只出現自己的 starship URL，且 URL 回 200）
- [x] 1.2 `home/run_once_install-01-runtimes.sh.tmpl`：starship 段落只在 macOS 安裝（驗證：Linux render 結果不含 `starship.rs/install.sh`，darwin render 仍含 `brew install starship`）
- [x] 1.3 本機 `chezmoi apply` 後 `starship --version` 為 pinned 版本，`starship prompt` 不再印出 `Unknown key`（blocked by 1.1）

## 2. 文件

- [x] 2.1 `docs/starship.md`：更新安裝方式，並註明舊 `/usr/local/bin/starship` 可手動刪除
