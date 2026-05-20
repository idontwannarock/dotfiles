## 1. chezmoi-external entry

- [x] 1.1 編輯 `.chezmoiexternal.toml`，在 Wave 2 區塊後加入 Wave 3 區塊與 `$gopassVersion` 變數（pin v1.16.1），新增 gopass entry：archive-file 模式，path 為 `gopass.exe`，URL 雙重 inject `$gopassVersion`（tag 帶 `v` prefix、檔名版本字串不帶）
- [x] 1.2 `chezmoi execute-template < .chezmoiexternal.toml` 渲染驗證 URL 與 path 正確

## 2. 清理 scoop install 呼叫

- [x] 2.1 `run_once_install-cli-tools.ps1.tmpl`：移除 `Install-ScoopPackage "curl"`、`Install-ScoopPackage "wget"`、`Install-ScoopPackage "gopass"`（3 行），各自留下說明註解（curl: Win10+ 內建；wget: Windows 流程未使用；gopass: 已遷 chezmoi-external Wave 3）
- [x] 2.2 grep 確認無殘留：`run_once_install-*.ps1.tmpl` 內無命中（docs/superpowers/ 內歷史 plan/spec 不動）

## 3. Wave 3 migration 腳本

- [x] 3.1 新增 `run_once_after_migrate-scoop-wave3.ps1.tmpl`：Windows-only `{{- if eq .chezmoi.os "windows" -}}` 包整支
- [x] 3.2 `$pkgs = @("gopass", "curl", "wget")`；仿 Wave 2 idempotent 模式（`scoop list` regex 判定後才 uninstall；scoop 不存在時 skip 整支）
- [x] 3.3 不寫 PATH 邏輯

## 4. 驗證

- [x] 4.1 `openspec validate scoop-external-wave3 --strict` 通過
- [x] 4.2 `chezmoi apply -v` 跑過：`~/.local/bin/gopass.exe` 已下載、3 個 scoop 套件已 uninstall（或本來就未裝）
- [x] 4.3 `gopass --version` 顯示 1.16.1 (`b2fb8ba9`) go1.25.5
- [x] 4.4 `Get-Command gopass` 解析到 `C:\Users\user\.local\bin\gopass.exe`，不是 scoop shim
- [x] 4.5 `gpg --version` 顯示 2.5.20，libgcrypt 1.12.2（gpg suite 維持 scoop 安裝）
- [x] 4.6 corp-ssh-askpass 驗證：`gopass ls` 列出 corp/password、corp/totp（gpg-agent 解密成功）
- [x] 4.7 `where.exe curl` 顯示 `C:\Windows\System32\curl.exe` 作為 fallback
- [x] 4.8 git diff scope：`.chezmoiexternal.toml` + `run_once_install-cli-tools.ps1.tmpl` + 新檔 migration + openspec 目錄（共 4 處）

## 5. Archive 與 Commit

- [x] 5.1 Commit 實作 + openspec proposal（commit `601b683`）
- [x] 5.2 code-reviewer subagent review，採納 2 個 doc clarity 建議（commit `7d97aae`）
- [ ] 5.3 `openspec archive scoop-external-wave3` 並 sync spec deltas 進 `openspec/specs/tool-dependencies/spec.md`
- [ ] 5.4 第三個 commit：archive 移動 + spec sync
- [ ] 5.5 merge 回 main，刪除 feature branch，清 active_workflows
- [ ] 5.6 更新 `reference_chezmoi_external_cli_tools.md` 加入 Wave 3 條目；新增 memory note 記錄 Wave 4 候選清單待後續討論
