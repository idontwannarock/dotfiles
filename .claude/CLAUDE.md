# Claude Code 專案指令

## 專案說明

跨平台個人設定檔管理專案，透過 [chezmoi](https://www.chezmoi.io/) 同步到 Windows、macOS、Linux/WSL。
此 repo 是 source of truth，**不是**直接生效在當前電腦上的設定。

## 變更設定檔的工作流程

1. **先在當前電腦測試**：變更當前電腦的實際設定，確認功能正常運作
2. **確認生效後再更新專案**：確認沒問題後，才將變更同步到此專案的相關同步設定檔
3. **考慮平台通用性**：盡量讓設定能跨平台使用（Windows、macOS、Linux）
4. **更新文件**：將變更記錄在 README 或 `docs/` 下的對應文件中

## 檔案角色

- **`.chezmoiignore.tmpl`**：依 OS 排除不適用的檔案（如 Windows 排除 `.codex/config.toml` 改由 ps1 shim 處理、macOS 排除 `.bashrc`、非 macOS 排除 `.zshrc`）
- **`scoop/scoopfile.json`**：手動管理的 GUI 應用參考清單（非完整 scoop export），自動安裝的工具已移至 install scripts

## Chezmoi 執行階段

`chezmoi apply` 的腳本依以下順序執行，名稱的字母排序決定同階段內的先後：

```
1. run_*_before_*       ← install-jq, patch-chezmoi-config
2. 檔案寫入 + modify_*  ← settings.json (需要 jq), codex config
3. run_* (無 before)    ← install-01-runtimes → 02-npm-tools → 03-claude-config, containers, cli-tools, fonts
4. run_after_*          ← modify-codex-config (Windows)
```

## Install Script 慣例

- **有依賴順序**的用數字前綴：`01-runtimes` → `02-npm-tools` → `03-claude-config`
- **無依賴**的不編號：`containers`、`cli-tools`、`fonts`
- 每個工具在 script 內做**冪等檢查**（已安裝就跳過）
- **Windows** 用 `.ps1.tmpl`（scoop 安裝），**macOS** 用 `.sh.tmpl`（brew 安裝），**Linux/WSL** 用 `.sh.tmpl`（一般工具 apt、版本管理工具 brew）
- Unix 的 npm 相關 script 必須引入 `{{ template "scripts/load-nvm" }}`
- 新增工具安裝時，確認字母排序不會打亂依賴順序

## 跨平台注意事項

- **Windows sh interpreter** 硬指向 `~/scoop/apps/git/current/bin/bash.exe`（scoop 裝的 git）
- `modify_*` 腳本在 Windows 上依副檔名判斷 interpreter：`.sh.tmpl` 可透過 `[interpreters.sh]` 執行，但 `.toml` 等非腳本副檔名不行
- **Codex config 雙源**：`dot_codex/modify_config.toml`（Unix）和 `run_after_modify-codex-config.ps1.tmpl`（Windows）內容必須同步更新
- `.gitattributes` 強制 `.sh.tmpl` 為 LF、`.ps1` 為 CRLF

## Template 片段

| Template | 用途 |
|----------|------|
| `scripts/load-nvm` | 在 sh script 中 source nvm，確保 npm/npx 可用 |
| `bashrc/*` | bashrc 的平台片段（windows, linux） |
| `shell-common/*` | shell_common 的平台片段（base, windows, linux, darwin） |
| `zshrc/*` | zshrc 的平台片段（darwin） |
