## Why

承 scoop→chezmoi-external 系列，本輪（Wave 12a）處理三個低風險項：補修 Wave 11 漏網的 `scoop install jdtls`、把 GUI 工具 lens 移出 chezmoi 管理、把單檔 CLI `dos2unix` 改成 chezmoi-external（同 Wave 1 jq/rg）。7z 與字型（需 app-bundle / 字型註冊）留待 Wave 12b。

## What Changes

**(0) 補修 Wave 11 漏網**：
- `run_onchange_install-03-claude-config.ps1.tmpl` 移除 `scoop install jdtls` 區段（Wave 11 已由 `.chezmoiexternal.toml` 提供 jdtls；此 leftover 會在腳本 hash 變動時把 jdtls 裝回 scoop，部分回退遷移）。

**(1) lens 移出 chezmoi 管理（soft-unmanage）**：
- `run_once_install-containers.ps1.tmpl` 移除 `Install-ScoopPackage "lens"` 與其 `scoop bucket add extras` / 不再被使用的 `Install-ScoopPackage` 函式與 scoop 前置檢查，保留歷史註解並標明 lens 改為手動管理。**不**主動 `scoop uninstall lens`（既有安裝保留，比照 clink/vimtutor/dark 的 soft-unmanage 前例）。

**(2) dos2unix → chezmoi-external（Windows-only）**：
- `.chezmoiexternal.toml` 新增 Wave 12a 區段：`[".local/bin/dos2unix.exe"]` type=archive-file，自 `https://waterlander.net/dos2unix/files/dos2unix-<version>-win64.zip` 取 `bin/dos2unix.exe`（單檔 standalone，無 DLL 依賴；spike 已驗證 `dos2unix.exe --version` 可獨立執行）。版本以 template 變數 pinning。
- `run_onchange_before_install-prereqs.ps1.tmpl` 移除 `Ensure-ScoopTool "dos2unix"`，改註解標明 dos2unix 由 `.chezmoiexternal.toml` 提供（比照既有 jq 的處理）。
- Wave 12a migrate 腳本：`scoop uninstall dos2unix`（冪等）。

**不動**：
- macOS / Linux（dos2unix 由 apt/brew 提供）。
- 既有 Wave 1~11 entries、migration 腳本、PATH 設定。

## Capabilities

### New Capabilities
（無）

### Modified Capabilities
- `tool-dependencies`：新增 requirement——dos2unix 由 chezmoi-external 單檔提供（Windows）；install-prereqs 不再經 scoop 裝 dos2unix；jdtls 不再由 install-03 經 scoop 安裝（補修 Wave 11）；lens soft-unmanage；Wave 12a 一次性遷移腳本（dos2unix uninstall）。

## Impact

- `.chezmoiexternal.toml`：+1 archive-file entry（dos2unix）+ pinned 版本變數。
- `run_onchange_install-03-claude-config.ps1.tmpl`：移除 jdtls scoop 安裝區段。
- `run_once_install-containers.ps1.tmpl`：移除 lens 安裝（含 dead function/guard），保留歷史註解。
- `run_onchange_before_install-prereqs.ps1.tmpl`：移除 dos2unix 的 scoop 安裝，改註解。
- `run_once_after_migrate-scoop-wave12a.ps1.tmpl`（新檔）：冪等 `scoop uninstall dos2unix`。
- 既有機器：scoop 卸載 dos2unix；jdtls 不再被 install-03 重裝；lens 維持現狀（手動）。

## Out of Scope（Wave 12b）
- 7z（MSI + COM shell extension context menu → app-bundle）。
- 兩個 Nerd Font（需複製 .ttf + 註冊 HKCU 的 font-install script）。
