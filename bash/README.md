# Bash Profile (WSL/Linux)

Bash 設定檔，適用於 WSL 和 Linux 環境。

> **注意**：`.bashrc` 是片段設定，應該 **附加** 到現有的 `~/.bashrc`，而非覆蓋。

## 依賴

| 依賴 | 用途 | 備註 |
|------|------|------|
| Bash | Shell 環境 | 通常已預裝 |
| wslpath | Windows Terminal 整合（路徑轉換） | WSL 內建，僅 WSL 環境需要 |
| [worklogs](https://github.com/idontwannarock/worklogs) repo | `createnewlog` / `gitpushlog` alias | 選用，需先執行 `set-worklogs-path.sh` |

## 檔案說明

| 檔案 | 說明 |
|------|------|
| `.bashrc` | Windows Terminal 整合設定（附加用） |
| `.bash_aliases` | Alias 設定（複製到 `~/.bash_aliases`） |
| `set-worklogs-path.sh` | 搜尋並設定 `WORKLOGS_PATH` 環境變數 |

## 安裝

### 1. 附加 `.bashrc` 設定

```bash
cat .bashrc >> ~/.bashrc
```

⚠️ **請勿使用 `cp` 覆蓋**，這會導致系統預設的 bashrc 設定遺失。

### 2. 安裝 `.bash_aliases`

```bash
cp .bash_aliases ~/.bash_aliases
```

> Ubuntu/Debian 的預設 `.bashrc` 會自動載入 `~/.bash_aliases`。

### 3. 設定 Worklogs 路徑（可選）

```bash
./set-worklogs-path.sh
source ~/.bashrc
```

此腳本會依序搜尋以下位置尋找 `worklogs` git repo：
1. `$HOME`（深度 4）
2. `/home`（深度 5）
3. `/opt`、`/usr/local`、`/var`（深度 4）
4. `/`（深度 6，排除系統目錄）

## Worklogs Aliases

設定 `WORKLOGS_PATH` 後，可使用以下 alias：

| Alias | 說明 |
|-------|------|
| `createnewlog` | 建立新的 worklog |
| `gitpushlog` | Push worklog 到遠端 |

## Windows Terminal 整合

透過 `PROMPT_COMMAND` 發送 OSC 9;9 escape sequence，讓 Windows Terminal 知道當前工作目錄。

**功能：**
- Split pane (`Alt+Shift+D`) 時自動繼承當前目錄
- 只在 Windows Terminal 環境下啟用（偵測 `$WT_SESSION`）
- 使用 `wslpath -w` 將 Linux 路徑轉換為 Windows 路徑

**Windows Terminal 設定範例：**
```json
{
    "actions": [
        {
            "command": {
                "action": "splitPane",
                "split": "auto",
                "splitMode": "duplicate"
            },
            "keys": "alt+shift+d"
        }
    ]
}
```

**參考：** [Opening a tab/pane in the same directory - Microsoft Learn](https://learn.microsoft.com/en-us/windows/terminal/tutorials/new-tab-same-directory)
