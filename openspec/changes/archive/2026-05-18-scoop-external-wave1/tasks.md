## 1. 新增 chezmoi-external entries

- [x] 1.1 在 `.chezmoiexternal.toml` 開頭宣告版本變數（`$starshipVersion`、`$zellijVersion`、`$uvVersion`、`$jqVersion`、`$ripgrepVersion`）
- [x] 1.2 新增 starship entry（`type = "archive-file"`、`path = "starship.exe"`、Windows-only `if eq .chezmoi.os "windows"`）
- [x] 1.3 新增 zellij entry（同上格式，`path = "zellij.exe"`）
- [x] 1.4 新增 uv entry（URL 注意 `$version` 不帶 `v` 前綴）
- [x] 1.5 新增 jq entry（`type = "file"`，URL 帶 `jq-$version` tag 前綴）
- [x] 1.6 新增 ripgrep entry（`path = "ripgrep-$version-x86_64-pc-windows-msvc/rg.exe"`，注意子目錄）
- [x] 1.7 `chezmoi apply --dry-run` 驗證 5 個 entries 解析正確

## 2. 清理現有 install 腳本

- [x] 2.1 `run_once_install-01-runtimes.ps1.tmpl` 移除 `Install-ScoopPackage "starship"` 與 `Install-ScoopPackage "uv"`
- [x] 2.2 `run_onchange_before_install-prereqs.ps1.tmpl` 移除 `Ensure-ScoopTool "jq"`（保留 `dos2unix`）
- [x] 2.3 確認上述腳本仍能在新機器執行（語法檢查 + dry-run）

## 3. 一次性遷移腳本

- [x] 3.1 新增 `run_once_after_migrate-scoop-to-external.ps1.tmpl`，外層 `{{- if eq .chezmoi.os "windows" -}}` 包住
- [x] 3.2 對 5 個套件迴圈 `scoop list <pkg>` 判斷後 `scoop uninstall <pkg>`
- [x] 3.3 讀取 User PATH，split `;`，找 `~/.local/bin` 與 `~/scoop/shims` 的位置
- [x] 3.4 若 `~/.local/bin` 不在 PATH 或晚於 `~/scoop/shims`，重排為 prepend 到 `~/scoop/shims` 之前
- [x] 3.5 寫回 User PATH（`[Environment]::SetEnvironmentVariable('Path', $newPath, 'User')`）
- [x] 3.6 PATH 真有變動時 `Write-Warning` 提示重開 session
- [x] 3.7 全段 dry-run：腳本在每個破壞性動作前以 verbose log 印出將要執行的內容（uninstall pkg / PATH idx before）

## 4. SSH workaround 清理

- [x] 4.1 刪除 `Documents/exact__shared-profile.d/35-scoop-ssh-shims.ps1`
- [x] 4.2 修改 `Documents/exact__shared-profile.d/90-prompt.ps1`：保留 `Invoke-Starship-PreCommand`，替換 starship 初始化區塊為標準 `starship init powershell --print-full-init` 呼叫
- [x] 4.3 驗證新 session 中 `(Get-Command starship).Source` 指向 `~/.local/bin/starship.exe`

## 5. 跨平台驗證

- [x] 5.1 Windows: `chezmoi apply` → 5 個 `.exe` 出現在 `~/.local/bin/`，PATH 順序正確；4/5 scoop 套件被卸載（zellij 因 in-use lock 跳過，腳本正確 warn 並繼續）
- [x] 5.2 Windows: fresh PowerShell PATH 下 `starship --version` 1.25.1、`zellij --version` 0.44.3、`uv --version` 0.11.14、`jq --version` 1.8.1、`rg --version` 15.1.0 全部運作
- [ ] 5.3 Windows: SSH（從 phone/Tailscale）連入確認 starship prompt + zellij 啟動正常 — **使用者手動驗證**
- [x] 5.4 Linux/macOS: 透過 chezmoi template guard `{{ if eq .chezmoi.os "windows" }}` 確認新 entries 在非 Windows OS 下不渲染

## 6. 文件與記憶更新

- [x] 6.1 更新 `MEMORY.md`「Win32-OpenSSH × Scoop SSH gotchas」條目 + `reference_win32_openssh_scoop_ssh_gotchas.md` 加上 2026-05-18 update 區塊
- [x] 6.2 新增 `reference_chezmoi_external_cli_tools.md`，列出 Wave 1 後 `.chezmoiexternal.toml` 管理的所有 binaries + bump 流程 + 適合遷的判斷準則
- [x] 6.3 README/docs 檢查：`docs/starship.md` 與 `docs/powershell.md` 描述為「自動安裝」與「依賴」，與底層機制無關，無需更新；其他 docs 未提及 SSH shim workaround
