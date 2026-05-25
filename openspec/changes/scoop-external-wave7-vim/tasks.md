## 1. Version 確認（前置）

- [x] 1.1 確認 `vim/vim-win32-installer` 當前最新 release tag（`gh release list --repo vim/vim-win32-installer --limit 1` 取 `v<X.Y.Z>`）
- [x] 1.2 確認對應的 x64 unsigned asset 存在（`gh release view <tag> --repo vim/vim-win32-installer --json assets --jq '.assets[].name'` 預期含 `gvim_<X.Y.Z>_x64.zip`）
- [x] 1.3 用 `unzip -l` 確認 zip 內頂層目錄為 `vim/vim92/`（stripComponents=1 的前提）；若上游改名（如 vim93）需同步調整 wrapper 中 `vim92` 路徑

## 2. chezmoi-external entry

- [x] 2.1 編輯 `.chezmoiexternal.toml`，於 Windows-only 區塊（`{{- if eq .chezmoi.os "windows" }}`）尾端、`{{- end }}` 之前新增 Wave 7 區段註解（vim 來源、archive 整包模式、版本 pinning 策略、stripComponents=1 解釋）
- [x] 2.2 新增 `$vimVersion` 變數（值為 1.1 確認的版本字串，例 `9.2.0530`）
- [x] 2.3 新增 `[".local/share/vim"]` entry：`type = "archive"`、`url = "https://github.com/vim/vim-win32-installer/releases/download/v{{ $vimVersion }}/gvim_{{ $vimVersion }}_x64.zip"`、`stripComponents = 1`
- [x] 2.4 於 entry 註解中標明：minor version bump（9.2 → 9.3）時需同步更新 15 個 `dot_local/bin/*.cmd` wrapper 中的 `vim92` 路徑

## 3. Wrappers（15 個 `.cmd`）

- [x] 3.1 建立 `dot_local/bin/vim.cmd`：`@echo off` + `"%USERPROFILE%\.local\share\vim\vim92\vim.exe" %*`
- [x] 3.2 建立 `dot_local/bin/vi.cmd`：同上模式（無 flag，與 vim.cmd 完全相同 underlying call；scoop manifest 即此設計）
- [x] 3.3 建立 `dot_local/bin/ex.cmd`：`"%USERPROFILE%\.local\share\vim\vim92\vim.exe" -e %*`
- [x] 3.4 建立 `dot_local/bin/view.cmd`：`"%USERPROFILE%\.local\share\vim\vim92\vim.exe" -R %*`
- [x] 3.5 建立 `dot_local/bin/rvim.cmd`：`"%USERPROFILE%\.local\share\vim\vim92\vim.exe" -Z %*`
- [x] 3.6 建立 `dot_local/bin/rview.cmd`：`"%USERPROFILE%\.local\share\vim\vim92\vim.exe" -RZ %*`
- [x] 3.7 建立 `dot_local/bin/vimdiff.cmd`：`"%USERPROFILE%\.local\share\vim\vim92\vim.exe" -d %*`
- [x] 3.8 建立 `dot_local/bin/gvim.cmd`：`"%USERPROFILE%\.local\share\vim\vim92\gvim.exe" %*`
- [x] 3.9 建立 `dot_local/bin/gview.cmd`：`"%USERPROFILE%\.local\share\vim\vim92\gvim.exe" -R %*`
- [x] 3.10 建立 `dot_local/bin/evim.cmd`：`"%USERPROFILE%\.local\share\vim\vim92\gvim.exe" -y %*`
- [x] 3.11 建立 `dot_local/bin/eview.cmd`：`"%USERPROFILE%\.local\share\vim\vim92\gvim.exe" -Ry %*`
- [x] 3.12 建立 `dot_local/bin/rgvim.cmd`：`"%USERPROFILE%\.local\share\vim\vim92\gvim.exe" -Z %*`
- [x] 3.13 建立 `dot_local/bin/rgview.cmd`：`"%USERPROFILE%\.local\share\vim\vim92\gvim.exe" -RZ %*`
- [x] 3.14 建立 `dot_local/bin/gvimdiff.cmd`：`"%USERPROFILE%\.local\share\vim\vim92\gvim.exe" -d %*`
- [x] 3.15 建立 `dot_local/bin/xxd.cmd`：`"%USERPROFILE%\.local\share\vim\vim92\xxd.exe" %*`
- [x] 3.16 確認所有 15 個 `.cmd` 為純 ASCII（`file` 命令或 `head -c 3 | xxd -p` 不應顯示 BOM）；CRLF/LF 由 `.gitattributes` 處理（`dot_local/bin/*` 規則強制 LF，與既有 `corp-ssh-askpass.cmd` 一致；cmd.exe 接受 LF）
- [x] 3.17 確認 `.chezmoiignore.tmpl` 不會排除 `dot_local/bin/*.cmd`（Windows 條件下需保留）；新增 `{{- if ne .chezmoi.os "windows" }}` 區塊排除 15 個 wrapper 於非 Windows 部署

## 4. Install script 註解

- [x] 4.1 編輯 `run_once_install-cli-tools.ps1.tmpl`，於 `# ── Vim tutor ──` 區段現有 vimtutor 註解之下追加一段說明：「vim 套件本身於 Wave 7 (2026-05-25) 由 .chezmoiexternal.toml 接手安裝，並由 dot_local/bin/ 下的 15 個 .cmd wrapper 鏡像 scoop bin 介面；遷移腳本見 run_once_after_migrate-scoop-wave7.ps1.tmpl」

## 5. Wave 7 一次性遷移腳本

- [x] 5.1 建立 `run_once_after_migrate-scoop-wave7.ps1.tmpl`，沿用 Wave 6 模式（`{{- if eq .chezmoi.os "windows" -}}` 守衛、`$ErrorActionPreference = "Continue"`、`Get-Command scoop` 早退、`scoop list <pkg>` regex 偵測、`scoop uninstall <pkg>` 冪等）
- [x] 5.2 套件清單：`@("vim")`
- [x] 5.3 註解明示「**不**動 User PATH」與「**不**清理 gvim 右鍵選單 registry」
- [x] 5.4 結尾印 `=== Wave 7 migration complete. ===`
- [x] 5.5 若檔含非 ASCII 中文，加 UTF-8 BOM（`printf '\xef\xbb\xbf' | cat - file > tmp && mv tmp file`）；本檔為純 ASCII（英文註解），無需 BOM

## 6. 本機驗證（在 dotfiles repo 內 chezmoi diff/apply）

- [x] 6.1 `chezmoi diff` 檢查新檔顯示為 add（15 wrappers + migration script + external entry）、`run_once_install-cli-tools.ps1.tmpl` 顯示為 modify（僅追加註解）
- [x] 6.2 `chezmoi apply -v`：external 下載 zip、解壓到 `~/.local/share/vim/vim92/`、15 wrappers 寫入 `~/.local/bin/`、`run_once_after_migrate-scoop-wave7` 卸載 scoop vim
- [x] 6.3 `Test-Path "$HOME\.local\share\vim\vim92\vim.exe"` → True（vim/gvim/xxd/vim64.dll 皆驗證）
- [x] 6.4 `where.exe vim` → 回 `~/.local/bin/vim.cmd` 單一條目（PowerShell scope；User PATH index 20 = .local/bin 在 21 = scoop/shims 之前，Wave 1 PATH 設定有效）
- [x] 6.5 `vim --version` → 版本字串為 9.2.0530（patches 1-530），無 DLL not found 錯誤
- [x] 6.6 `gvim --version` / `xxd --version` → 同 6.5
- [x] 6.7 `vimdiff -h` / `vim -h` → 皆能顯示 vim help 文字含 `-d Diff 模式`，wrapper -d flag 透過 `%*` 傳遞正常
- [x] 6.8 `scoop list vim` → 回 not installed（剩 vimtutor 是另一套件）
- [x] 6.9 注意：cmd.exe AutoRun 紅字「The system cannot find the path specified.」為 Wave 4 clink 移除後 registry 殘留產生，與 Wave 7 wrapper 無關（已驗證 `cmd /c echo hello` 也會出現相同紅字）

## 7. 文件 / memory 更新（archive step 處理）

- [ ] 7.1 `openspec validate scoop-external-wave7-vim --strict` 通過
- [ ] 7.2 `openspec archive scoop-external-wave7-vim` 完成歸檔（含 spec sync 進 `openspec/specs/tool-dependencies/spec.md`）
- [ ] 7.3 `openspec spec validate tool-dependencies` 通過
- [ ] 7.4 更新 `C:\Users\user\.claude\projects\D--ws-github-dotfiles\memory\reference_chezmoi_external_cli_tools.md`：新增 Wave 7 區塊，記錄 vim archive-mode 設計、15 wrapper 對應表、minor-version-bump invariant（同步改 `$vimVersion` 與 15 wrappers）
- [ ] 7.5 更新 `C:\Users\user\.claude\projects\D--ws-github-dotfiles\memory\project_scoop_external_wave4_candidates.md`：Category A 表格將 vim 劃掉、標記 Wave 7 完成；補一段「archive-pattern 第二案——`type = "archive"` 整包 + `.cmd` wrappers，PATH 不變」結論供 nvm/gpg 參考
- [ ] 7.6 視需要更新 `MEMORY.md` 索引（若主要連結文字或描述需要改）
