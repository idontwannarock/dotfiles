## ADDED Requirements

### Requirement: vim 套件本體在 Windows 上由 chezmoi-external 整包安裝
Windows 上 vim 套件（vim distribution + 4 個依賴 DLL + 完整 runtime/ 子目錄）SHALL 由 `.chezmoiexternal.toml` 從 `vim/vim-win32-installer` GitHub Release 下載 `gvim_<version>_x64.zip`（unsigned 變體），以 `type = "archive"` + `stripComponents = 1` 整包解壓至 `~/.local/share/vim/`，產生 `~/.local/share/vim/vim92/` 子樹（含 `vim.exe`、`gvim.exe`、`xxd.exe`、`vim64.dll`、`libiconv-2.dll`、`libintl-8.dll`、`libsodium.dll` 與 `autoload/`、`syntax/`、`doc/`、`tutor/` 等 runtime 子目錄）。

版本以 chezmoi template 變數 `$vimVersion` pinning（如 `9.2.0530`），URL 形式：`https://github.com/vim/vim-win32-installer/releases/download/v{{ $vimVersion }}/gvim_{{ $vimVersion }}_x64.zip`。

#### Scenario: Windows 上下載並整包解壓 vim distribution
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 自 `https://github.com/vim/vim-win32-installer/releases/download/v<version>/gvim_<version>_x64.zip` 下載並解壓至 `~/.local/share/vim/`，最終 `~/.local/share/vim/vim92/vim.exe` 存在且可執行

#### Scenario: 版本 pinning 確保跨機器 reproducible
- **WHEN** 同一 commit 在不同機器、不同時間執行 chezmoi apply
- **THEN** `~/.local/share/vim/vim92/vim.exe --version` 輸出的版本字串一致——pinning 採 `$vimVersion` 變數，**不**使用 rolling `latest` tag

#### Scenario: runtime 資源完整可用
- **WHEN** 使用者執行 `vim foo.py`
- **THEN** vim 能正確載入 Python syntax highlighting（驗證 `~/.local/share/vim/vim92/syntax/python.vim` 存在且 vim runtime path 解析成功）

### Requirement: 15 個 .cmd wrapper 鏡像 scoop bin 介面
`~/.local/bin/` SHALL 包含 15 個純 ASCII `.cmd` wrapper 檔，每個 wrapper 對應 scoop `vim.json` manifest 的 `bin[]` 陣列中對應 alias，呼叫對應的 underlying `.exe` 並傳入正確 flag。Wrapper 全部以靜態文字（非 chezmoi template）寫成，內嵌路徑為 `%USERPROFILE%\.local\share\vim\vim92\<binary>.exe`。

Flag 對應表：
- `vim.cmd` / `vi.cmd` → `vim.exe`（無 flag）
- `ex.cmd` → `vim.exe -e`
- `view.cmd` → `vim.exe -R`
- `rvim.cmd` → `vim.exe -Z`
- `rview.cmd` → `vim.exe -RZ`
- `vimdiff.cmd` → `vim.exe -d`
- `gvim.cmd` → `gvim.exe`（無 flag）
- `gview.cmd` → `gvim.exe -R`
- `evim.cmd` → `gvim.exe -y`
- `eview.cmd` → `gvim.exe -Ry`
- `rgvim.cmd` → `gvim.exe -Z`
- `rgview.cmd` → `gvim.exe -RZ`
- `gvimdiff.cmd` → `gvim.exe -d`
- `xxd.cmd` → `xxd.exe`（無 flag）

#### Scenario: 直接呼叫 vim/gvim/xxd 走 wrapper
- **WHEN** 使用者在 PowerShell / cmd.exe / Git Bash 執行 `vim foo.txt`
- **THEN** `where.exe vim` 解析到 `~/.local/bin/vim.cmd`，wrapper 轉發到 `~/.local/share/vim/vim92/vim.exe`，foo.txt 被開啟

#### Scenario: alias mode wrapper 傳遞正確 flag
- **WHEN** 使用者執行 `vimdiff a.txt b.txt`
- **THEN** `~/.local/bin/vimdiff.cmd` 被呼叫，wrapper 執行 `vim.exe -d a.txt b.txt`，vim 進入 diff 模式

#### Scenario: gvim alias mode wrapper 傳遞正確 flag
- **WHEN** 使用者執行 `evim foo.txt`
- **THEN** `~/.local/bin/evim.cmd` 被呼叫，wrapper 執行 `gvim.exe -y foo.txt`，gvim 進入 easy mode

### Requirement: Windows 上 vim 不再經由 Scoop
`run_once_install-cli-tools.ps1.tmpl`（或其他 install 腳本）SHALL NOT 呼叫 `Install-ScoopPackage "vim"`。腳本可保留註解標明 vim 已遷至 `.chezmoiexternal.toml`，指引讀者去看 `run_once_after_migrate-scoop-wave7.ps1.tmpl`。

#### Scenario: install script 不主動安裝 scoop vim
- **WHEN** 在乾淨 Windows 上首次 `chezmoi apply`
- **THEN** `run_once_install-cli-tools.ps1.tmpl` 不執行 `scoop install vim`；vim 由 `.chezmoiexternal.toml` 提供

### Requirement: Wave 7 一次性遷移腳本
`run_once_after_migrate-scoop-wave7.ps1.tmpl` SHALL 在 Windows 上執行一次性遷移：卸載 1 個 scoop 套件 `vim`。腳本 SHALL 為冪等：scoop 未安裝 vim 時視為 no-op；scoop 未安裝時整支 skip。

腳本 SHALL NOT 動 User PATH（Wave 1 的 `run_once_after_migrate-scoop-to-external.ps1.tmpl` 已把 `~/.local/bin` 排在 `~/scoop/shims` 之前）。

腳本 SHALL NOT 主動清理 gvim 右鍵選單 registry 項目（屬於 Windows shell 整合層而非本 wave 範圍；使用者需要時可手動）。

#### Scenario: 已安裝 scoop vim 被卸載
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list vim` 回報已安裝
- **THEN** 腳本執行 `scoop uninstall vim`，scoop apps 目錄該套件被移除

#### Scenario: scoop vim 未安裝時 no-op
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list vim` 回報未安裝
- **THEN** 腳本不執行 `scoop uninstall`，繼續結束

#### Scenario: scoop 未安裝時整支 skip
- **WHEN** chezmoi apply 在 Windows 執行，且 `Get-Command scoop` 回 not found
- **THEN** 腳本印警告訊息並 return，不嘗試任何 scoop 命令

#### Scenario: User PATH 不被本腳本修改
- **WHEN** Wave 7 migration 腳本執行
- **THEN** User PATH 環境變數值維持不變（PATH 排序為 Wave 1 migration 腳本的責任）
