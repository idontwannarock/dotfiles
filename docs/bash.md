# Bash 設定

## 管理方式

`.bashrc` 和 `.shell_common` 由 chezmoi 管理，透過 `.chezmoitemplates/` 依平台載入不同的 template 片段：

| 平台 | `.bashrc` 來源 | `.shell_common` 來源 |
|------|---------------|---------------------|
| Windows (Git Bash) | `bashrc/windows` | `shell-common/windows` → `shell-common/base` |
| Linux/WSL | `bashrc/linux` | `shell-common/linux` → `shell-common/base` |
| macOS | 不部署（使用 zsh） | `shell-common/darwin` → `shell-common/base` |

## Worklogs 設定

### 依賴

| 依賴 | 用途 | 備註 |
|------|------|------|
| [worklogs](https://github.com/idontwannarock/worklogs) repo | `createnewlog` / `gitpushlog` alias | 選用，需先執行 worklogs 設定腳本 |

### 設定方式

```bash
./scripts/set-worklogs-path.sh
source ~/.bashrc
```

此腳本會依序搜尋以下位置尋找 `worklogs` git repo：
1. `$HOME`（深度 4）
2. `/home`（深度 5）
3. `/opt`、`/usr/local`、`/var`（深度 4）
4. `/`（深度 6，排除系統目錄）

設定 `WORKLOGS_PATH` 後，可使用以下 alias（定義在 `~/.shell_common`）：

| Alias | 說明 |
|-------|------|
| `createnewlog` | 建立新的 worklog |
| `gitpushlog` | Push worklog 到遠端 |

## Windows Terminal 整合（WSL）

WSL 的 `.bashrc` 透過 `PROMPT_COMMAND` 發送 OSC 9;9 escape sequence，讓 Windows Terminal 知道當前工作目錄。

- Split pane (`Alt+Shift+D`) 時自動繼承當前目錄
- 只在 Windows Terminal 環境下啟用（偵測 `$WT_SESSION`）
- 使用 `wslpath -w` 將 Linux 路徑轉換為 Windows 路徑
