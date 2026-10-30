## 1. 架構檢查

- [x] 1.1 `home/.chezmoiexternal.toml`：Linux starship entry 外加 `{{- if $starshipArch }}`（驗證：linux/386 與 linux/arm render 出合法 TOML 且無 starship entry；linux/amd64、linux/arm64、windows/amd64 各有一個 starship entry）
