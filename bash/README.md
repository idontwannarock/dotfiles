# Bash Profile (WSL)

WSL Bash 設定檔。

## 安裝

將 `.bashrc` 內容加到你的 `~/.bashrc`：

```bash
cat .bashrc >> ~/.bashrc
source ~/.bashrc
```

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
