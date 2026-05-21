## 1. 清理 scoop install 呼叫

- [x] 1.1 `run_once_install-cli-tools.ps1.tmpl`：移除 `Install-ScoopPackage "clink"`、`Install-ScoopPackage "dark"`、`Install-ScoopPackage "winget"`，並移除 vimtutor 與 winget-ps 兩個 bespoke path-check 安裝區塊
- [x] 1.2 各自留下說明註解：clink/winget/winget-ps 註明硬清原因（無人用 / OS-bundled 取代 / dotfiles 未 import）；dark/vimtutor 註明軟脫管（dotfiles 不再管理，現有安裝保留）
- [x] 1.3 grep 確認無殘留：`Install-ScoopPackage` 與 vimtutor/winget-ps 字串在 `run_once_install-*.ps1.tmpl` 內無命中（openspec 目錄不動）

## 2. PowerShell command-not-found header comment

- [x] 2.1 `Documents/PowerShell/profile.d/99-command-not-found.ps1`（PS7）：在原有 PowerToys marker 後加入 header comment，明示前置條件（PowerToys CommandNotFound 模組 + OS-bundled winget），不動 `Import-Module` 程式碼
- [x] 2.2 `Documents/WindowsPowerShell/profile.d/99-command-not-found.ps1`（PS5）：在第一行 comment 後加入 header comment，明示前置條件（OS-bundled winget），不動 `CommandNotFoundAction` 程式碼

## 3. Wave 4 migration 腳本

- [x] 3.1 新增 `run_once_after_migrate-scoop-wave4.ps1.tmpl`：Windows-only `{{- if eq .chezmoi.os "windows" -}}` 包整支
- [x] 3.2 `$pkgs = @("clink", "winget", "winget-ps")`；仿 Wave 2+3 idempotent 模式（`scoop list` regex 判定後才 uninstall；scoop 不存在時 skip 整支）
- [x] 3.3 不卸載 `dark` 或 `vimtutor`（軟脫管項目）
- [x] 3.4 不寫 PATH 邏輯

## 4. 驗證

- [x] 4.1 `openspec validate scoop-external-wave4 --strict` 通過
- [x] 4.2 `chezmoi apply -v` 跑過：3 個 scoop 套件已 uninstall（clink/winget/winget-ps，或本來就未裝）
- [x] 4.3 `scoop list dark` 與 `scoop list vimtutor` 仍回報已安裝（軟脫管驗證）
- [x] 4.4 `winget --version` 仍正常運作（OS-bundled 接手）
- [x] 4.5 `Get-Command winget` 解析到 `%LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe`，不是 scoop shim
- [x] 4.6 新開 PowerShell session 啟動無錯誤（99-command-not-found.ps1 正常載入 PowerToys 模組或 silent no-op）
- [x] 4.7 git diff scope：`run_once_install-cli-tools.ps1.tmpl` + 新檔 migration + 兩個 `99-command-not-found.ps1`（PS7 + PS5）+ openspec 目錄（共 4 處檔案 + spec）

## 5. Archive 與 Commit

- [ ] 5.1 Commit 實作 + openspec proposal/design/specs/tasks
- [ ] 5.2 code-reviewer subagent review，採納可行建議
- [ ] 5.3 `openspec archive scoop-external-wave4` 並 sync spec deltas 進 `openspec/specs/tool-dependencies/spec.md`
- [ ] 5.4 第三個 commit：archive 移動 + spec sync
- [ ] 5.5 merge 回 main，刪除 feature branch，清 active_workflows
- [ ] 5.6 更新 `project_scoop_external_wave4_candidates.md`：標記 Category B 完成（5 個工具）；剩餘 Category A/C/D/E 維持
