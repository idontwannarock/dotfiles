# Bash 設定

## 管理方式

`.bashrc` 和 `.shell_common` 由 chezmoi 管理，透過 `.chezmoitemplates/` 依平台載入不同的 template 片段：

| 平台 | `.bashrc` 來源 | `.shell_common` 來源 |
|------|---------------|---------------------|
| Windows (Git Bash) | `bashrc/windows` | `shell-common/windows` → `shell-common/base` |
| Linux/WSL | `bashrc/linux` | `shell-common/linux` → `shell-common/base` |
| macOS | 不部署（使用 zsh） | `shell-common/darwin` → `shell-common/base` |

## Linux/WSL 預設 editor

Linux/WSL 的 `shell-common/linux` 會設定：

```sh
export EDITOR=vim
export VISUAL=vim
```

用途：

- 終端工具在需要開啟外部 editor 編輯內容時，預設走 `vim`
- 目前主要是讓 WSL/Ubuntu 內的 `codex` / `claude` 這類 CLI 在叫出 prompt editor 時使用 `vim`
- 作用範圍只限 Linux/WSL，不影響 macOS 與 Windows Git Bash

## Worklog workflow trigger

`shell-common/base` 內建 `createnewlog` 函式，觸發遠端 GitHub Actions workflow `create-daily.yml` 並等待 run 完成。

| 命令 | 行為 |
|------|------|
| `createnewlog` | `gh -R idontwannarock/worklogs workflow run create-daily.yml` → 輪詢取得 run ID → `gh run watch <id> --exit-status` |

特性：

- **不依賴 CWD**：可從任意目錄呼叫，包含非 git repo 的位置
- **不依賴環境變數**：完全不讀 `WORKLOGS_PATH` 或其他自訂變數
- **不做本地 git 操作**：純粹觸發遠端 workflow，本地分支若需同步請自行 `cd` 到 worklogs repo 處理
- **repo hardcoded**：`idontwannarock/worklogs` 直接寫死在函式內，與 worklog skills 在 CLAUDE.md 的設定一致

前置條件：本機已安裝並登入 [`gh` CLI](https://cli.github.com/)（`gh auth login`）。

> 註：本地 commit/push 備援由 `worklogs` repo 自身的腳本提供，需手動 `cd` 進該 repo 執行，dotfiles 不再代為包裝。

## Windows Terminal 整合（WSL）

WSL 的 `.bashrc` 透過 `PROMPT_COMMAND` 發送 OSC 9;9 escape sequence，讓 Windows Terminal 知道當前工作目錄。

- Split pane (`Alt+Shift+D`) 時自動繼承當前目錄
- 只在 Windows Terminal 環境下啟用（偵測 `$WT_SESSION`）
- 使用 `wslpath -w` 將 Linux 路徑轉換為 Windows 路徑
