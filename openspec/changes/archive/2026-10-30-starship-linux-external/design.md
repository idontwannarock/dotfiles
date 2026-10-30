## Context

Windows 的 starship 已由 `.chezmoiexternal.toml` 釘版本（`$starshipVersion`，Renovate 自動升版）。Linux 仍走 `run_once_` 官方 installer，裝過就不再更新。設定檔 `starship.toml` 兩邊共用，只要 Windows 版本較新、設定用了新 key，Linux 就會出現 `Unknown key` 警告。

## Goals / Non-Goals

**Goals:**
- Linux 與 Windows 的 starship 版本由同一個 pin 決定。
- Renovate 升一次版本，兩個 OS 都跟著升。

**Non-Goals:**
- macOS 改用 external（brew 有自己的升級路徑）。
- 由 chezmoi 刪除舊的 `/usr/local/bin/starship`。

## Decisions

- **版本變數移到 OS 條件之外**：`$starshipVersion` 與 Renovate 註記放在 Windows `if` 區塊之前，讓 Windows 與 Linux entry 都能引用。只保留一個註記，符合「shared version variable is annotated once」。
- **Linux 用 musl tarball**：`starship-<arch>-unknown-linux-musl.tar.gz` 是靜態連結，不依賴發行版 glibc 版本；與官方 installer 在 Linux 的預設相同。tarball 根目錄只有 `starship`，用 `type = "archive-file"` + `path = "starship"`。
- **架構對應**：`.chezmoi.arch` 的 `amd64` → `x86_64`、`arm64` → `aarch64`。其他架構不在支援範圍。
- **不刪舊 binary**：刪 `/usr/local/bin/starship` 需要 sudo，apply 中途要密碼不友善。PATH 中 `~/.local/bin` 已排在 `/usr/local/bin` 之前，舊檔不會被執行。替代方案（run_once 腳本 `sudo rm`）被否決。

## Risks / Trade-offs

- [某台 Linux 的 PATH 把 `/usr/local/bin` 放在 `~/.local/bin` 之前] → 仍會跑舊版；docs 註明可手動 `sudo rm /usr/local/bin/starship`。
- [改動 run_once 腳本內容會讓它在每台 Linux 重跑一次] → 各段落都有冪等檢查，重跑只會印出 skip。
