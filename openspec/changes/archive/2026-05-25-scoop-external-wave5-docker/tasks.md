## 1. Version 確認（前置）

- [x] 1.1 確認 Docker CLI 最新 stable Windows static binary 版本（瀏覽 `https://download.docker.com/win/static/stable/x86_64/` 或 Docker docs）→ 29.5.2
- [x] 1.2 確認 Docker Compose v2 最新 stable Windows binary 版本（GitHub Releases `docker/compose`）→ 5.1.4（v5 系列，非 v2）
- [x] 1.3 將兩個版本字串記下，準備 inject 進 `.chezmoiexternal.toml`

## 2. chezmoi-external entries

- [x] 2.1 在 `.chezmoiexternal.toml` 的 Windows-only 區塊（`{{- if eq .chezmoi.os "windows" }}`）新增 Wave 5 區段註解
- [x] 2.2 新增 `$dockerVersion` 與 `$dockerComposeVersion` 變數
- [x] 2.3 新增 `[".local/bin/docker.exe"]` entry：`type = "archive-file"`、`url = "https://download.docker.com/win/static/stable/x86_64/docker-{{ $dockerVersion }}.zip"`、`path = "docker/docker.exe"`、`executable = true`
- [x] 2.4 新增 `[".local/bin/docker-compose.exe"]` entry：`type = "file"`、`url = "https://github.com/docker/compose/releases/download/v{{ $dockerComposeVersion }}/docker-compose-windows-x86_64.exe"`、`executable = true`

## 3. DOCKER_HOST env var 管理腳本

- [x] 3.1 建立 `run_onchange_before_set-docker-host.ps1.tmpl`：以 `{{- if eq .chezmoi.os "windows" -}}` ... `{{ end -}}` 包住整支腳本（全 ASCII，無需 BOM；設 `$ErrorActionPreference = "Stop"`）
- [x] 3.2 腳本主體：讀取 `[Environment]::GetEnvironmentVariable("DOCKER_HOST", "User")`、與 `tcp://127.0.0.1:2375` 比對、不等時 `SetEnvironmentVariable` 並提示重開 session
- [x] 3.3 已正確時印灰色 "already set" 訊息（不重寫）
- [x] 3.4 被使用者改成其他值時印 warning 註明值被回正

## 4. Wave 5 一次性遷移腳本

- [x] 4.1 建立 `run_once_after_migrate-scoop-wave5.ps1.tmpl`，沿用 Wave 4 模式（`{{- if eq .chezmoi.os "windows" -}}` 守衛、`$ErrorActionPreference = "Continue"`、`Get-Command scoop` 早退、`scoop list <pkg>` regex 偵測、`scoop uninstall <pkg>` 冪等）
- [x] 4.2 套件清單：`@("docker", "docker-compose")`
- [x] 4.3 註解明示「**不**動 lazydocker」與「**不**動 User PATH」
- [x] 4.4 結尾印 `=== Migration complete. ===`

## 5. 本機驗證（在 dotfiles repo 內 chezmoi diff/apply 前先測試）

- [x] 5.1 `chezmoi diff` 檢查新檔顯示為 add，無預期外的變更
- [x] 5.2 `chezmoi apply -v`：確認 `run_onchange_before_set-docker-host` 跑了、external 下載 docker.exe + docker-compose.exe、`run_once_after_migrate-scoop-wave5` 卸載 scoop 套件
- [x] 5.3 開新 PowerShell session（讓 env var 變更生效），執行 `where.exe docker` → 應回 `~/.local/bin/docker.exe` 單一條目
- [x] 5.4 `docker version` → client 為新 pinned 版；server 應顯示 WSL daemon engine
- [x] 5.5 `docker ps` → 應正常列出 WSL 內容器（若有；無也應不報錯）
- [x] 5.6 `docker-compose version` → 顯示 pinned v5 版本（5.1.4）
- [x] 5.7 確認 `~/.local/bin/dockerd.exe` **不存在**（archive 過濾正確）
- [x] 5.8 `scoop list docker` 與 `scoop list docker-compose` 都回 not installed
- [x] 5.9 `scoop list lazydocker` 仍回已安裝（未被誤卸）
- [x] 5.10 `[Environment]::GetEnvironmentVariable("DOCKER_HOST", "User")` 回 `tcp://127.0.0.1:2375`

## 6. 文件 / memory 更新（archive step 處理）

- [x] 6.1 更新 `C:\Users\user\.claude\projects\D--ws-github-dotfiles\memory\reference_chezmoi_external_cli_tools.md`：新增 Wave 5 區塊，記錄 docker + docker-compose 兩條 entry 與 URL pattern 特異性
- [x] 6.2 更新 `C:\Users\user\.claude\projects\D--ws-github-dotfiles\memory\project_scoop_external_wave4_candidates.md`：Category C「docker audit」從候選清單劃掉，標記 Wave 5 完成
- [x] 6.3 視需要更新 `MEMORY.md` 索引（若標題或描述需要改）
- [x] 6.4 `openspec validate scoop-external-wave5-docker --strict`：確認無紅字
- [x] 6.5 `openspec archive scoop-external-wave5-docker`：完成歸檔
- [x] 6.6 `openspec spec validate tool-dependencies`：確保 spec 同步無誤
