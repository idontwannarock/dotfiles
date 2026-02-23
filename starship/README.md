# Starship

[Starship](https://starship.rs/) 跨平台終端機 prompt 設定。

## 管理方式

設定檔由 chezmoi 管理，部署到 `~/.config/starship/starship.toml`。Starship 本身也會在 `chezmoi apply` 時自動安裝。

詳見根目錄 [README](../README.md) 的操作說明。

## 設定說明

| 設定 | 值 | 說明 |
|------|-----|------|
| `command_timeout` | `1000` | 指令超時時間（毫秒），預設 500ms 在 Windows 上容易因 Defender 即時掃描導致 git 指令超時 |
