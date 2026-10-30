## Why

WSL 上的 starship 停在 2023 年裝的 1.16.0，不認得 `starship.toml` 的 `pwsh_indicator`，每開一次 shell 就印出 `[WARN] ... Unknown key`。原因是 Linux 由 `run_once_install-01-runtimes.sh.tmpl` 呼叫官方 installer，且「已安裝就跳過」，所以 chezmoi 只管第一次安裝、不管版本；Windows 則已由 `.chezmoiexternal.toml` 釘版本並由 Renovate 升版，兩邊版本因此漂移。

## What Changes

- Linux 改由 `home/.chezmoiexternal.toml` 從 GitHub Release 下載 pinned 版本的 starship 至 `~/.local/bin/starship`。
- `$starshipVersion` 與其 Renovate 註記移出 Windows 區塊，Windows 與 Linux 共用同一個版本號。
- `run_once_install-01-runtimes.sh.tmpl` 的 starship 段落只保留 macOS 的 `brew install`；Linux 不再呼叫官方 installer。
- macOS 維持 Homebrew，不在本次範圍。
- 舊的 `/usr/local/bin/starship` 不由 chezmoi 移除（需要 sudo）；`~/.local/bin` 在 PATH 中排在前面，因此新版會先被找到。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `tool-dependencies`: 「Starship 安裝腳本支援 macOS 與 Linux」改為 Linux 經由 `.chezmoiexternal.toml` 下載 pinned binary，與 Windows 共用版本號。

## Impact

- `home/.chezmoiexternal.toml`：新增 Linux starship entry，搬移版本變數。
- `home/run_once_install-01-runtimes.sh.tmpl`：內容變更會使該 run_once 在每台 Linux 機器重跑一次；各段落皆有冪等檢查。
- `docs/starship.md`：更新安裝方式說明。
- CI `validate-externals` 會在 ubuntu runner 上 HEAD 檢查新的 Linux URL。
