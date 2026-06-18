## Why

承 scoop→chezmoi-external 系列，本輪（Wave 12b）收尾兩個最高風險項：**7z**（來源是 MSI、含 COM shell extension 右鍵選單）與**兩個 Nerd Font**（需複製 `.ttf` + 設 AppContainer ACL + 註冊 HKCU）。目標是把 scoop 隱藏在 install-time 的行為，在 off-scoop 後完整複製出來。

## What Changes

**(1) 7z → chezmoi-external（app-bundle，full migration）**：
- 來源是 **MSI** 而非 binary（`https://github.com/ip7z/7zip/releases/download/26.01/7z2601-x64.msi`）。chezmoi-external 無法解 MSI，故 `.chezmoiexternal.toml` 以 `type = "file"` 只負責「下載 pinned MSI」到 `~/.local/share/7zip/7z2601-x64.msi`。
- migrate 腳本以 `msiexec /a <msi> /qn TARGETDIR=<tmp>` 做 administrative install 解出整套（落在 `Files\7-Zip\`），flatten 到 `~/.local/opt/7zip`（`7z.exe`、`7z.dll`、`7-zip.dll` shell-ext COM server、`7zFM.exe`、`7zG.exe`、`Lang/` 等）。
- 靜態 `dot_local/bin/7z.cmd` wrapper → `~/.local/opt/7zip/7z.exe`（比照 vim/java wrappers）。
- 右鍵選單 = COM shell extension：以 `reg import` 在 `HKCU\Software\Classes` 註冊 CLSID `{23170F69-40C1-278A-1000-000100020000}` 的 `InprocServer32` → `~/.local/opt/7zip\7-zip.dll`，加上 `*`/`Directory`/`Drive`/`Folder` 的 ContextMenuHandlers / DragDropHandlers。
- 移除 `run_once_install-cli-tools.ps1.tmpl` 的 `Install-ScoopPackage "7z" "7zip"`。
- **ORDERING GOTCHA**：`scoop uninstall 7zip` 會跑 scoop 的 uninstaller（`reg import uninstall-context.reg`），**刪掉**右鍵選單的 context keys。故 migrate 腳本順序必須：解 MSI → `scoop uninstall 7zip` **先** → **再** `reg import` 我們指向新 DLL 的 install-context.reg。

**(2) 兩個 Nerd Font → chezmoi-external（SOFT-UNMANAGE）**：
- `cascadiacode-nf-mono`（CascadiaCode.zip，nerd-fonts v3.4.0，filter `*NerdFontMono-*`，ttf 在 zip 根）與 `jetbrains-mono`（JetBrainsMono-2.304.zip v2.304，`extract_dir = fonts/ttf`，所有 `*.ttf`）。
- `.chezmoiexternal.toml` 新增 2 個 `type = "archive"` external 取兩 zip 到 `~/.local/share/fonts/<name>`。
- 新 `run_once` 字型註冊腳本複製 scoop 的 per-user install：複製 `.ttf` 到 `%LOCALAPPDATA%\Microsoft\Windows\Fonts`、設 AppContainer ACL（SID `S-1-15-2-1` / `S-1-15-2-2`，ReadAndExecute）、註冊 `HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts` name `"<basename> (TrueType)"` = 完整路徑（`-Force` 冪等）。
- 移除 `run_once_install-fonts.ps1.tmpl` 兩個 scoop install。
- **SOFT-UNMANAGE（不 scoop uninstall）**：scoop 字型 install 是**複製**（非 symlink），`scoop uninstall` 會刪掉實際安裝的字型；且本機字型已安裝+註冊、scoop app 已不在。故只停用 scoop install + 改由 external+register，**不**主動 scoop-uninstall 字型。

**不動**：
- macOS / Linux 字型（brew/手動）。
- git / scoop 基礎建設（sh interpreter 釘在 scoop git）。
- 既有 Wave 1~12a entries、migration 腳本、PATH 設定。

## Capabilities

### New Capabilities
（無）

### Modified Capabilities
- `tool-dependencies`：新增 requirement——7z 由 chezmoi-external 提供 pinned MSI、migrate 腳本解 MSI + flatten 到 `~/.local/opt/7zip` + 註冊 COM shell extension 右鍵選單（含 scoop-uninstall-before-reg-import 排序）+ `7z.cmd` wrapper；install-cli-tools 不再經 scoop 裝 7z；兩個 Nerd Font 由 chezmoi-external archive 提供 + per-user 字型註冊腳本（soft-unmanage，不 scoop-uninstall）；install-fonts 不再經 scoop 裝字型。

## Impact

- `.chezmoiexternal.toml`：+1 file entry（7z MSI）+ 2 archive entries（兩字型）+ pinned 版本變數。
- `dot_local/bin/7z.cmd`（新檔）：wrapper → `~/.local/opt/7zip/7z.exe`。
- `run_once_after_migrate-scoop-wave12b.ps1.tmpl`（新檔）：解 MSI + flatten + scoop uninstall 7zip + reg import context menu。
- `run_once_register-fonts.ps1.tmpl`（新檔）：per-user 字型複製 + ACL + HKCU 註冊（冪等）。
- `run_once_install-cli-tools.ps1.tmpl`：移除 7z scoop 安裝，改歷史註解。
- `run_once_install-fonts.ps1.tmpl`：移除兩字型 scoop 安裝，改歷史註解 + soft-unmanage 說明。
- 既有機器：scoop 卸載 7zip、右鍵選單改指向新 DLL；字型維持現狀（已安裝，external+register 變冪等 no-op）。
