# Tasks — Wave 12a: scoop CLI cleanup

> 先在本機驗證再改 source（spike 已完成：dos2unix 單檔可獨立執行）。

## 1. dos2unix → chezmoi-external
- [x] 1.1 `.chezmoiexternal.toml` 新增 Wave 12a 區段：`$dos2unixVersion` + `[".local/bin/dos2unix.exe"]` type=archive-file，path `bin/dos2unix.exe`，URL waterlander win64 zip。
- [x] 1.2 本機驗證：`chezmoi apply` 後 `~/.local/bin/dos2unix.exe --version` 正常。

## 2. 移除 scoop 安裝呼叫
- [x] 2.1 `run_onchange_install-03-claude-config.ps1.tmpl`：移除 `scoop install jdtls` 區段（Wave 11 leftover）。
- [x] 2.2 `run_once_install-containers.ps1.tmpl`：移除 lens 安裝（含 dead `Install-ScoopPackage` 函式 + scoop guard），保留歷史註解 + lens soft-unmanage 說明。
- [x] 2.3 `run_onchange_before_install-prereqs.ps1.tmpl`：移除 `Ensure-ScoopTool "dos2unix"`，改註解標明由 external 提供。

## 3. migrate 腳本
- [x] 3.1 新增 `run_once_after_migrate-scoop-wave12a.ps1.tmpl`：冪等 `scoop uninstall dos2unix`（沿用 wave 樣板）。

## 4. 本機驗證
- [x] 4.1 dos2unix external 部署後可用；確認 install-03 的 CRLF 修復仍能用 `~/.local/bin/dos2unix.exe`。
- [x] 4.2 跑 migrate：scoop dos2unix 卸載、冪等；移除後 dos2unix 仍可用（來自 external）。

## 5. 收尾
- [x] 5.1 `openspec validate scoop-external-wave12a --strict` 通過。
- [x] 5.2 commit 只 stage 本輪相關檔案。
