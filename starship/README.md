# Starship

[Starship](https://starship.rs/) 跨平台終端機 prompt 設定。

## 安裝設定

```bash
# 複製設定檔
cp starship/starship.toml ~/.config/starship.toml
```

## 設定說明

| 設定 | 值 | 說明 |
|------|-----|------|
| `command_timeout` | `1000` | 指令超時時間（毫秒），預設 500ms 在 Windows 上容易因 Defender 即時掃描導致 git 指令超時 |
