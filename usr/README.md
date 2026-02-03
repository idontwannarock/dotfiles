# User Scripts

跨平台的個人腳本，放在 `~/.local/bin`。

## 安裝

**Windows (PowerShell):**
```powershell
Copy-Item -Path ".local/bin/*" -Destination "~/.local/bin" -Recurse -Force
```

**Linux / macOS:**
```bash
cp -r .local/bin/* ~/.local/bin/
```

> 確保 `~/.local/bin` 已加入 `$PATH`。

## Scripts

| Script | Description |
|--------|-------------|
| `scoop-interactive-update.ps1` | 互動式更新 scoop 套件（Windows only） |
