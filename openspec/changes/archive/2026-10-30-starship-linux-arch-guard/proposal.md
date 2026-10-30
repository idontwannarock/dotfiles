## Why

Linux 的 starship external 用 `amd64`/`arm64` 對照表取得架構名稱。其他架構查不到時會得到空字串，網址變成 `starship--unknown-linux-musl.tar.gz` 並回 404，整個 `chezmoi apply` 會因此中斷。

## What Changes

- 架構不在對照表時，`.chezmoiexternal.toml` 不產生 Linux starship entry。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `tool-dependencies`: 「Starship 安裝腳本支援 macOS 與 Linux」新增「不支援的 Linux 架構不下載」情境。

## Impact

- `home/.chezmoiexternal.toml`：Linux starship entry 外加一層 `if`。
