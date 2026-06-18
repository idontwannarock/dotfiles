# Design — Wave 12b: 7z（MSI + COM shell ext）+ 兩個 Nerd Font（soft-unmanage）

## Context

Wave 12 的第二輪，收尾 scoop→chezmoi-external 系列最高風險的兩項。Spike 已在本機驗證（見下方 D1/D4）：MSI 以 `msiexec /a` 解到 `Files\7-Zip\`、`7z.exe` 可獨立執行、現行 CLSID InprocServer32 指向 scoop 的 `7-zip.dll`。字型在本機已安裝+註冊、scoop app 已不在（soft-unmanage 前提成立）。

## Decisions

### D1 — 7z 來源是 MSI：external 只下載，migrate 腳本解壓
chezmoi-external 無法解 MSI。故拆兩段：
- `.chezmoiexternal.toml` 以 `type = "file"` 下載 pinned MSI 到 `~/.local/share/7zip/7zip-x64.msi`（穩定檔名，與 URL 版本字串解耦——版本 bump 不留 orphan）。
- migrate 腳本 `msiexec /a "<msi>" /qn TARGETDIR="<tmp>"` 做 administrative install（不註冊系統、純鋪檔），解出 `<tmp>\Files\7-Zip\` 整套。**Spike 驗證**：exit 0，`Files\7-Zip\` 含 `7z.exe`/`7z.dll`/`7-zip.dll`/`7zFM.exe`/`7zG.exe`/`Lang/` 等；TARGETDIR 根另有一份 admin MSI copy（忽略）。

### D2 — flatten 到 `~/.local/opt/7zip`（app-bundle 位置）
複製 `<tmp>\Files\7-Zip\*` → `~/.local/opt/7zip\`（比照 gnupg/jdtls/nvm/jdk 等 stateful app-bundle 落 `~/.local/opt/`，而非 `~/.local/bin` 的單檔）。**冪等 gate**：`~/.local/opt/7zip\7z.exe` 已存在則 skip 解壓（沿用 Wave 9 nvm run_once_after 的 desired-state gate）。

### D3 — 右鍵選單用 native PowerShell 寫 registry（不 reg import 模板化 .reg）
scoop 的 `install-context.reg` 用 `{{7zip_dir}}` placeholder 指 DLL。我們改在 migrate 腳本以 `New-Item`/`New-ItemProperty` 直接寫 `HKCU:\Software\Classes`，解析出的 DLL 路徑為 `~/.local/opt/7zip\7-zip.dll`。理由：(1) 避免 .reg 的 placeholder 替換 + 反斜線跳脫脆弱；(2) `-Force` 天然冪等；(3) 不需在 repo 裡塞一個帶 placeholder 的 .reg。寫入的 key 完整對應 scoop 的 install-context.reg：
- `HKCU\Software\7-Zip\Options`（CascadedMenu / MenuIcons = 1）
- `*` / `Directory` / `Folder` 的 `shellex\ContextMenuHandlers\7-Zip` = CLSID
- `Directory` / `Drive` 的 `shellex\DragDropHandlers\7-Zip` = CLSID
- `CLSID\{23170F69-40C1-278A-1000-000100020000}`（default = "7-Zip Shell Extension"）+ `InprocServer32`（default = DLL 路徑，ThreadingModel = Apartment）

### D4 — ORDERING GOTCHA：解壓 → scoop uninstall → 再寫 reg（順序載重）
`scoop uninstall 7zip` 會跑 scoop manifest 的 uninstaller（`reg import uninstall-context.reg`），**刪掉** `HKCU\Software\Classes` 下的 7-Zip context keys 與 CLSID。若先寫我們的 reg 再 scoop uninstall，會被 scoop 刪掉。故 migrate 腳本嚴格順序：
1. 解 MSI + flatten 到 `~/.local/opt/7zip`（先確保新 DLL 在位）
2. `scoop uninstall 7zip`（冪等；其 uninstaller 清掉舊 context keys 指向 scoop DLL）
3. **再** native 寫入指向 `~/.local/opt/7zip\7-zip.dll` 的 context keys

scoop 未安裝 7zip 時跳過 step 2，step 3 仍冪等寫入（首次安裝機器）。

### D5 — 7z.cmd wrapper（靜態，比照 vim/java）
`dot_local/bin/7z.cmd`：`@echo off` + `"%USERPROFILE%\.local\opt\7zip\7z.exe" %*`。`~/.local/bin` 已是 Wave 1 的 PATH 首位，不動 PATH。移除 install-cli-tools 的 `Install-ScoopPackage "7z" "7zip"`。

### D6 — 字型 soft-unmanage：external archive + register 腳本，不 scoop uninstall
- 2 個 `type = "archive"` external：
  - `cascadiacode-nf-mono` → `~/.local/share/fonts/cascadiacode-nf-mono`（CascadiaCode.zip v3.4.0，ttf 在 zip 根）
  - `jetbrains-mono` → `~/.local/share/fonts/jetbrains-mono`（JetBrainsMono-2.304.zip，`extract_dir = "fonts/ttf"`）
- `run_once_register-fonts.ps1.tmpl` 複製 scoop per-user install：對 cascadia 取 `*NerdFontMono-*`、對 jetbrains 取 `*.ttf`；複製到 `%LOCALAPPDATA%\Microsoft\Windows\Fonts`、設 AppContainer ACL（SID `S-1-15-2-1`/`S-1-15-2-2`，ReadAndExecute，ContainerInherit+ObjectInherit）、註冊 `HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts` name `"<basename> (TrueType)"` = 完整路徑。`-Force` + `Copy-Item` 冪等。
- **不 scoop uninstall**：scoop 字型 install 是**複製**（非 symlink），`scoop uninstall` 的 uninstaller.script 會刪掉 `%LOCALAPPDATA%` 下實際安裝的 `.ttf` + HKCU 註冊；且本機字型已安裝、scoop app 已不在。比照 clink/dark/vimtutor soft-unmanage 前例：只停 scoop install、改 external+register，既有安裝不動。移除 install-fonts 兩個 scoop install。

### D7 — 字型 register 的 phase 排序
external 在 file 階段（phase 2）解出 `~/.local/share/fonts/*`，`run_once_register-fonts`（phase 3 run_once）在其後執行，能讀到 ttf。腳本 gate 於來源 zip 解出的 ttf 存在；不存在則警告 skip（比照 nvm 的 external-not-deployed guard）。

## Risks

- **MSI 解壓需 msiexec**：Windows 內建，`/qn` 非互動 admin install 已驗證 exit 0。
- **7z 版本升級**：解壓在 run_once（hash-keyed），版本 bump 後 external 會重抓新 MSI，但 run_once 不會自動重解。升級程序：bump `$sevenZipVersion` + 刪 `~/.local/opt/7zip`（或改 migrate 腳本 hash）後 `chezmoi apply`。已於腳本註解標明（同 nvm/jdtls 的 run_once_after 限制）。
- **shell ext DLL 可能被 explorer 鎖住**：寫 registry 不需 DLL 解鎖；DLL 檔案複製在 scoop uninstall 之前、目標是新目錄 `~/.local/opt/7zip`，不與 scoop 舊路徑衝突。重啟 explorer 或登出後右鍵選單生效。
- **字型已安裝下的冪等**：register 腳本 `-Force` 對既有註冊為 no-op 改寫；ACL 重設 cheap。已安裝的 `.ttf` 會被使用中的 app memory-map 鎖住，無法覆寫，故 Copy-Item 以 `-not (Test-Path $dest)` gate（只在缺檔時複製）——既有安裝跳過複製、重寫註冊，re-apply 無雜訊（本機驗證：12/32 註冊不變、零錯誤）。fresh 機器無鎖、正常複製。
