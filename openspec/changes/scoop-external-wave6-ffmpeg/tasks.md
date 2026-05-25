## 1. Version 確認（前置）

- [x] 1.1 確認 BtbN/FFmpeg-Builds 當前最新 dated tag 名稱（`gh release list --repo BtbN/FFmpeg-Builds --limit 5` 或 `gh api repos/BtbN/FFmpeg-Builds/releases`）
- [x] 1.2 取得該 dated tag 對應的 `n8.1` static GPL asset filename（`gh release view <tag> --repo BtbN/FFmpeg-Builds --json assets --jq '[.assets[] | select(.name | test("n8.1") and test("win64-gpl") and (test("shared") | not)) | .name]'`），預期格式 `ffmpeg-n8.1.X-Y-g<hash>-win64-gpl-8.1.zip`
- [x] 1.3 將 tag 與 asset filename 兩個字串記下，準備 inject 進 `.chezmoiexternal.toml`

## 2. chezmoi-external entries

- [x] 2.1 在 `.chezmoiexternal.toml` 的 Windows-only 區塊（`{{- if eq .chezmoi.os "windows" }}`）的尾端、`{{- end }}` 之前新增 Wave 6 區段註解，說明來源、static GPL 選擇、dated tag pinning 策略
- [x] 2.2 新增 `$ffmpegTag` 與 `$ffmpegAsset` 兩個變數
- [x] 2.3 確認 archive 內部路徑前綴：dated tag 的 asset 解壓後 root dir 名稱通常等於 asset filename 去掉 `.zip` 後綴（例：`ffmpeg-n8.1.1-8-gb21e00eda5-win64-gpl-8.1/bin/ffmpeg.exe`）；用 `gh release download` + `7z l` 或 `unzip -l` 確認實際結構
- [x] 2.4 新增 `[".local/bin/ffmpeg.exe"]` entry：`type = "archive-file"`、`url = "https://github.com/BtbN/FFmpeg-Builds/releases/download/{{ $ffmpegTag }}/{{ $ffmpegAsset }}"`、`path = "<archive-root>/bin/ffmpeg.exe"`（用 chezmoi template 的字串 trim 工具或顯式串接 asset filename without `.zip` 來算 archive-root；若 chezmoi template 不便處理，可直接展開為硬編碼 `path`，並於註解明示「bump tag 時要同步改 path」）、`executable = true`
- [x] 2.5 新增 `[".local/bin/ffprobe.exe"]` entry（同 2.4 模式，僅 path 結尾改為 `ffprobe.exe`）
- [x] 2.6 新增 `[".local/bin/ffplay.exe"]` entry（同 2.4 模式，僅 path 結尾改為 `ffplay.exe`）

## 3. Install script 清理

- [x] 3.1 編輯 `run_once_install-cli-tools.ps1.tmpl`，於 `# ── Media ──────` 區段移除第 39 行的 `Install-ScoopPackage "ffmpeg"`
- [x] 3.2 留下解釋註解，沿用 Wave 4/5 的標準措辭：說明 ffmpeg 在 Wave 6 (2026-05-25) 已遷至 `.chezmoiexternal.toml`，並指引讀者去看 `run_once_after_migrate-scoop-wave6.ps1.tmpl`

## 4. Wave 6 一次性遷移腳本

- [x] 4.1 建立 `run_once_after_migrate-scoop-wave6.ps1.tmpl`，沿用 Wave 5 模式（`{{- if eq .chezmoi.os "windows" -}}` 守衛、`$ErrorActionPreference = "Continue"`、`Get-Command scoop` 早退、`scoop list <pkg>` regex 偵測、`scoop uninstall <pkg>` 冪等）
- [x] 4.2 套件清單：`@("ffmpeg")`
- [x] 4.3 註解明示「**不**動 User PATH」
- [x] 4.4 結尾印 `=== Wave 6 migration complete. ===`

## 5. 本機驗證（在 dotfiles repo 內 chezmoi diff/apply 前先測試）

- [x] 5.1 `chezmoi diff` 檢查新檔顯示為 add、`run_once_install-cli-tools.ps1.tmpl` 顯示為 modify（無預期外的變更）
- [x] 5.2 `chezmoi apply -v`：確認 external 下載 zip、抽出 3 隻 binary、`run_once_after_migrate-scoop-wave6` 卸載 scoop ffmpeg
- [x] 5.3 `where.exe ffmpeg` → 應回 `~/.local/bin/ffmpeg.exe` 單一條目（無 scoop shim 殘留）
- [x] 5.4 `ffmpeg -version` → version 字串為 BtbN n8.1 stable + git-describe；無 DLL not found 錯誤（驗證 static build）
- [x] 5.5 `ffprobe -version` → 同 5.4
- [x] 5.6 `ffplay -version` → 同 5.4
- [x] 5.7 `scoop list ffmpeg` → 回 not installed
- [x] 5.8 觀察 `chezmoi apply -v` 是否 3 條 entry 共用同一 cache（用同一 URL 應只下載 1 次；若實際 3 次也記下，未來 wave 評估是否改用 `archive` 模式）

## 6. 文件 / memory 更新（archive step 處理）

- [ ] 6.1 更新 `C:\Users\user\.claude\projects\D--ws-github-dotfiles\memory\reference_chezmoi_external_cli_tools.md`：新增 Wave 6 區塊，記錄 ffmpeg 3 條 entry、BtbN dated tag 與 asset filename 雙變數模式、archive-file 共用 URL 的 cache 行為觀察結果
- [ ] 6.2 更新 `C:\Users\user\.claude\projects\D--ws-github-dotfiles\memory\project_scoop_external_wave4_candidates.md`：Category A 表格將 ffmpeg 劃掉、標記 Wave 6 完成，並補一段「archive-pattern 第一個遷的設計選擇：archive-file × N 而非 archive × 1，PATH 不變」結論供後續 vim/nvm/gpg 參考
- [ ] 6.3 視需要更新 `MEMORY.md` 索引（若主要連結文字或描述需要改）
- [ ] 6.4 `openspec validate scoop-external-wave6-ffmpeg --strict`：確認無紅字
- [ ] 6.5 `openspec archive scoop-external-wave6-ffmpeg`：完成歸檔（含 spec sync 進 `openspec/specs/tool-dependencies/spec.md`）
- [ ] 6.6 `openspec spec validate tool-dependencies`：確保 spec 同步無誤
