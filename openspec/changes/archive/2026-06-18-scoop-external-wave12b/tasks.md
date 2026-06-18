# Tasks — Wave 12b: 7z（MSI + COM shell ext）+ 兩個 Nerd Font（soft-unmanage）

> 先在本機驗證再改 source（spike 已完成：`msiexec /a` 解到 `Files\7-Zip\`、`7z.exe` 可獨立執行、現行 CLSID 指向 scoop DLL）。

## 1. 7z external（MSI 下載）
- [x] 1.1 `.chezmoiexternal.toml` 新增 Wave 12b 區段：`$sevenZipVersion` + `[".local/share/7zip/7zip-x64.msi"]` type=file，URL ip7z GitHub release。
- [x] 1.2 本機驗證：`chezmoi apply` 後 MSI 落在 `~/.local/share/7zip/7zip-x64.msi`。

## 2. 7z migrate 腳本（解壓 + flatten + uninstall + reg）
- [x] 2.1 新增 `run_once_after_migrate-scoop-wave12b.ps1.tmpl`：(a) gate `~/.local/opt/7zip\7z.exe` 不存在才 `msiexec /a` 解 MSI 並 flatten `Files\7-Zip\*` → `~/.local/opt/7zip`；(b) `scoop uninstall 7zip`（冪等）；(c) native 寫 `HKCU\Software\Classes` context/dragdrop/CLSID keys 指向 `~/.local/opt/7zip\7-zip.dll`。順序：解壓 → uninstall → reg。
- [x] 2.2 本機驗證：`~/.local/opt/7zip\7z.exe` 存在可執行；CLSID InprocServer32 指向新 DLL；scoop 7zip 卸載。

## 3. 7z wrapper + 移除 scoop install
- [x] 3.1 新增 `dot_local/bin/7z.cmd`：`"%USERPROFILE%\.local\opt\7zip\7z.exe" %*`。
- [x] 3.2 `run_once_install-cli-tools.ps1.tmpl`：移除 `Install-ScoopPackage "7z" "7zip"`，改歷史註解。
- [x] 3.3 本機驗證：`7z` 經 `~/.local/bin/7z.cmd` 解析正常。

## 4. 字型 external（archive）
- [x] 4.1 `.chezmoiexternal.toml`：新增 `$cascadiaNfVersion`/`$jetbrainsMonoVersion` + 2 個 `type = "archive"` external（cascadia ttf 在根；jetbrains `extract_dir = "fonts/ttf"`）→ `~/.local/share/fonts/<name>`。
- [x] 4.2 本機驗證：`chezmoi apply` 後兩字型 zip 解到 `~/.local/share/fonts/*`。

## 5. 字型 register 腳本 + 移除 scoop install（soft-unmanage）
- [x] 5.1 新增 `run_once_register-fonts.ps1.tmpl`：複製 `.ttf` 到 `%LOCALAPPDATA%\...\Fonts` + AppContainer ACL + HKCU 註冊（`-Force` 冪等）。**不** scoop uninstall。
- [x] 5.2 `run_once_install-fonts.ps1.tmpl`：移除兩字型 scoop install，改歷史註解 + soft-unmanage 說明。
- [x] 5.3 本機驗證：register 腳本對既有安裝冪等（no-op 效果）；字型仍註冊於 HKCU。

## 6. 收尾
- [x] 6.1 `openspec validate scoop-external-wave12b --strict` 通過。
- [x] 6.2 commit 只 stage 本輪相關檔案。
