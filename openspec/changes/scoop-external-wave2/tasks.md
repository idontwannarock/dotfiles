## 1. chezmoi-external entries

- [x] 1.1 編輯 `.chezmoiexternal.toml`，在 Wave 1 區塊後加入 6 個 entries（kubectl/kubelogin/yt-dlp/hugo/nexttrace/golangci-lint），版本變數 pinned 在 entry 區塊起頭
- [x] 1.2 `chezmoi execute-template < .chezmoiexternal.toml` 渲染驗證 6 個 URL 都正確（kubectl `dl.k8s.io/release/v1.36.1/...`、kubelogin `Azure/kubelogin v0.2.17`、yt-dlp CalVer `2026.03.17`、hugo extended `v0.161.1`、nexttrace `NTrace-V1 v1.6.5`、golangci-lint `v2.12.2`）

## 2. 清理 scoop install 呼叫

- [x] 2.1 `run_once_install-cli-tools.ps1.tmpl`：5 行 `Install-ScoopPackage` 已移除，留下說明註解
- [x] 2.2 `run_once_install-containers.ps1.tmpl`：2 行 `Install-ScoopPackage` 已移除，留下說明註解；`scoop bucket add extras` 保留給 Lens
- [x] 2.3 grep 確認無殘留：`grep -rn "scoop install|Install-ScoopPackage" --include="*.ps1.tmpl"` 過濾後 7 套件全乾淨

## 3. Wave 2 migration 腳本

- [x] 3.1 新增 `run_once_after_migrate-scoop-wave2.ps1.tmpl`：Windows-only、`{{- if eq .chezmoi.os "windows" -}}` 包整支
- [x] 3.2 `$pkgs` 含 7 套件；仿 Wave 1 idempotent 模式
- [x] 3.3 不寫 PATH 邏輯

## 4. 驗證

- [x] 4.1 `openspec validate scoop-external-wave2 --strict` 通過
- [x] 4.2 `chezmoi apply -v` 跑過：6 個 .exe 已下載至 `~/.local/bin/`、7 個 scoop 套件已 uninstall
- [x] 4.3 6 個工具版本實測：kubectl 1.36.1（clientVersion 開頭）、kubelogin 0.2.17、yt-dlp 2026.03.17、hugo extended 0.161.1、NextTrace 1.6.5、golangci-lint 2.12.2
- [x] 4.4 `Get-Command` 全部解析到 `C:\Users\user\.local\bin\<tool>.exe`，PATH ordering 正確
- [x] 4.5 git diff scope：`.chezmoiexternal.toml` + 2 install scripts modified + 1 新檔 migration + openspec 目錄（共 5 處）

## 5. Archive 與 Commit

- [ ] 5.1 Commit 實作 + openspec proposal（一個 commit）
- [ ] 5.2 code-reviewer subagent review，採納可採納的建議
- [ ] 5.3 `openspec archive scoop-external-wave2` 並 sync spec deltas 進 `openspec/specs/tool-dependencies/spec.md`
- [ ] 5.4 第二個 commit：archive 移動 + spec sync
- [ ] 5.5 merge 回 main，刪除 feature branch，清 active_workflows
- [ ] 5.6 更新 `reference_chezmoi_external_cli_tools.md` 加入 Wave 2 條目；視情況更新 `MEMORY.md` 的 SSH gotchas scope
