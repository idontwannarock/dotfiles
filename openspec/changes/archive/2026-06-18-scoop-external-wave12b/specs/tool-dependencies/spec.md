## ADDED Requirements

### Requirement: 7z 在 Windows 上由 chezmoi-external 提供 MSI 並由 migrate 腳本解壓
Windows 上 7z 的來源是 MSI（非單檔 binary），chezmoi-external 無法解 MSI。故 `.chezmoiexternal.toml` SHALL 以 `type = "file"` 自 `https://github.com/ip7z/7zip/releases/download/<version>/7z<v>-x64.msi` 下載 pinned MSI 至 `~/.local/share/7zip/7zip-x64.msi`（穩定檔名，與 URL 版本字串解耦）。版本以 chezmoi template 變數 pinning。

#### Scenario: Windows 上取得 7z MSI
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `~/.local/share/7zip/7zip-x64.msi` 存在

#### Scenario: 版本 pinning 跨機器 reproducible
- **WHEN** 同一 commit 在不同機器執行 chezmoi apply
- **THEN** 取得的 MSI 版本一致（採 pinned 版本變數，不使用 rolling URL）

### Requirement: 7z migrate 腳本解 MSI、flatten、並註冊 COM shell extension 右鍵選單
`run_once_after_migrate-scoop-wave12b.ps1.tmpl` SHALL 在 Windows 上：(1) 以 `msiexec /a "<msi>" /qn TARGETDIR="<tmp>"` 解出 7z 套件，並將 `<tmp>\Files\7-Zip\*` flatten 複製到 `~/.local/opt/7zip`；(2) 卸載 scoop 套件 `7zip`；(3) 在 `HKCU\Software\Classes` 註冊 CLSID `{23170F69-40C1-278A-1000-000100020000}` 的 `InprocServer32` 指向 `~/.local/opt/7zip\7-zip.dll`，加上 `*`/`Directory`/`Folder` ContextMenuHandlers 與 `Directory`/`Drive` DragDropHandlers。腳本 SHALL 為冪等：`~/.local/opt/7zip\7z.exe` 已存在則跳過解壓；scoop 未安裝 7zip 時跳過卸載；reg 寫入以 `-Force` 冪等。

#### Scenario: 解 MSI 並 flatten 到 ~/.local/opt/7zip
- **WHEN** chezmoi apply 在 Windows 執行，且 `~/.local/opt/7zip\7z.exe` 尚不存在
- **THEN** 腳本以 `msiexec /a` 解 MSI，並將 `7z.exe`/`7z.dll`/`7-zip.dll`/`7zFM.exe`/`7zG.exe`/`Lang/` 等複製到 `~/.local/opt/7zip`

#### Scenario: 卸載與註冊的順序正確（避免 scoop uninstaller 刪掉新 keys）
- **WHEN** 機器上 scoop 已安裝 7zip，腳本執行
- **THEN** 腳本先解壓 + flatten，再 `scoop uninstall 7zip`（其 uninstaller 會刪舊 context keys），最後才寫入指向 `~/.local/opt/7zip\7-zip.dll` 的 context keys

#### Scenario: 右鍵選單指向新 DLL
- **WHEN** 腳本完成
- **THEN** `HKCU\Software\Classes\CLSID\{23170F69-40C1-278A-1000-000100020000}\InprocServer32` 的預設值為 `~/.local/opt/7zip\7-zip.dll` 的完整路徑

#### Scenario: 已遷移機器上冪等 no-op
- **WHEN** `~/.local/opt/7zip\7z.exe` 已存在且 scoop 未安裝 7zip
- **THEN** 腳本跳過解壓與卸載，僅冪等重寫 context keys，不報錯

### Requirement: 7z.cmd wrapper 與 install-cli-tools 不再經 Scoop 安裝 7z
`dot_local/bin/7z.cmd` SHALL 將 `7z` 委派給 `~/.local/opt/7zip\7z.exe`（`%*` 傳遞參數），比照既有 vim/java wrappers。`run_once_install-cli-tools.ps1.tmpl` SHALL NOT 呼叫 `scoop install 7zip`（或經 `Install-ScoopPackage "7z" "7zip"`）。

#### Scenario: 7z 由 wrapper 解析
- **WHEN** 在 Windows 上執行 `7z`
- **THEN** 解析到 `~/.local/bin/7z.cmd`，委派 `~/.local/opt/7zip\7z.exe`（`7z` 正常輸出版本/用法）

#### Scenario: install-cli-tools 不主動裝 scoop 7z
- **WHEN** 在 Windows 上執行 install-cli-tools 腳本
- **THEN** 不執行 `scoop install 7zip`

### Requirement: 兩個 Nerd Font 由 chezmoi-external archive 提供並由 register 腳本 per-user 安裝（soft-unmanage）
`.chezmoiexternal.toml` SHALL 以 `type = "archive"` 取得 `cascadiacode-nf-mono`（CascadiaCode.zip，nerd-fonts pinned 版本）與 `jetbrains-mono`（JetBrainsMono pinned 版本，`extract_dir = "fonts/ttf"`）至 `~/.local/share/fonts/<name>`。`run_once_register-fonts.ps1.tmpl` SHALL 複製 scoop 的 per-user 字型安裝：對 cascadia 取 `*NerdFontMono-*`、對 jetbrains 取 `*.ttf`，複製到 `%LOCALAPPDATA%\Microsoft\Windows\Fonts`、設 AppContainer ACL（SID `S-1-15-2-1`/`S-1-15-2-2` ReadAndExecute）、註冊 `HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts` name `"<basename> (TrueType)"` = 完整路徑。腳本 SHALL 為冪等（`-Force`）。本變更採 soft-unmanage：SHALL NOT `scoop uninstall` 任一字型（scoop 字型 install 為複製，uninstall 會刪掉實際安裝的字型）。

#### Scenario: Windows 上取得字型 zip 並註冊
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `~/.local/share/fonts/cascadiacode-nf-mono` 與 `~/.local/share/fonts/jetbrains-mono` 存在；register 腳本將對應 `.ttf` 複製到 `%LOCALAPPDATA%\Microsoft\Windows\Fonts` 並註冊於 HKCU Fonts

#### Scenario: 既有字型安裝下冪等
- **WHEN** 字型已安裝+註冊（本機現況）
- **THEN** register 腳本以 `-Force` 重寫為 no-op 效果，不報錯，不重複堆疊

#### Scenario: 字型 soft-unmanage（不 scoop uninstall）
- **WHEN** 機器上曾由 scoop 安裝字型
- **THEN** 本變更 SHALL NOT 執行 `scoop uninstall cascadiacode-nf-mono` 或 `scoop uninstall jetbrains-mono`；既有安裝維持現狀

### Requirement: install-fonts 不再經 Scoop 安裝字型
`run_once_install-fonts.ps1.tmpl` SHALL NOT 呼叫 `scoop install cascadiacode-nf-mono` 或 `scoop install jetbrains-mono`。字型由 `.chezmoiexternal.toml` + `run_once_register-fonts.ps1.tmpl` 提供。腳本可保留註解標明此事。

#### Scenario: install-fonts 不主動裝 scoop 字型
- **WHEN** 在 Windows 上執行 install-fonts 腳本
- **THEN** 不執行 `scoop install cascadiacode-nf-mono` 或 `scoop install jetbrains-mono`
