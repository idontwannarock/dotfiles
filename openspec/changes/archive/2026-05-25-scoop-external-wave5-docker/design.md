## Context

承 Wave 1~4 將 scoop-managed CLI 遷至 `.chezmoiexternal.toml` 的工程脈絡（避開 Win32-OpenSSH SSH session 下 scoop shim/`current` junction 失效、把 source-of-truth 集中於 dotfiles repo）。Wave 5 範圍由 user 決定，聚焦於：

- **Docker CLI 場景特殊性**：本機 Windows 端不跑 docker engine（既不裝 Docker Desktop，也不啟 `dockerd.exe`）。docker daemon 在 WSL Ubuntu 內，透過 `/etc/docker/daemon.json` 監聽 `tcp://0.0.0.0:2375`，由 WSL2 的 localhost forwarding 讓 Windows side 直接以 `tcp://127.0.0.1:2375` 連入。Windows 端只需要 docker CLI client。
- **既有 drift**：`scoop list` 顯示 docker / docker-compose / lazydocker 三套件，但 `scoop/scoopfile.json` 一個都沒記。屬於 source-of-truth 缺漏，Wave 5 順手收尾（lazydocker 依 user 指示不動）。
- **DOCKER_HOST env var 目前外於 chezmoi**：手設的 User-scope env var，新機需要重設一次才能 docker CLI 正常工作。

## Goals / Non-Goals

**Goals:**
- `~/.local/bin/docker.exe`（CLI 單一 binary）由 `.chezmoiexternal.toml` 自 Docker Inc. 官方靜態映像下載，丟棄同 archive 中的 `dockerd.exe`。
- `~/.local/bin/docker-compose.exe` 由 `.chezmoiexternal.toml` 自 GitHub Release 下載裸 binary。
- `DOCKER_HOST=tcp://127.0.0.1:2375` 由 `run_onchange_before_set-docker-host.ps1.tmpl` 冪等寫進 Windows User env var。
- 既有 scoop `docker` + `docker-compose` 被 `run_once_after_migrate-scoop-wave5.ps1.tmpl` 卸載。
- 變更後 `docker ps`、`docker compose ps`、`docker run`、`docker exec` 等命令行為與 Wave 5 之前一致（端點仍是 WSL daemon）。

**Non-Goals:**
- **不**管理 lazydocker：user 明確要求保持 scoop 安裝，dotfiles 不介入。
- **不**動 WSL 內的 Docker daemon 設定（`/etc/docker/daemon.json` 的 TCP 監聽屬 WSL rootfs scope）。
- **不**支援 Docker Desktop / Windows-side `dockerd.exe`：本提案明確假設「WSL daemon + Windows CLI」單一架構。
- **不**支援跳板機 / CI runner / 多開發者場景：`DOCKER_HOST` 值寫死 `tcp://127.0.0.1:2375`，per user 明確要求僅針對個人開發機。
- **不**處理 Category A archive-pattern（ffmpeg/vim/nvm/gpg）與 Category D 多版本 toolchain，留給後續 Wave。

## Decisions

### D1: Docker CLI 來源使用 Docker Inc. 官方靜態映像，而非 GitHub Release

**選**：`https://download.docker.com/win/static/stable/x86_64/docker-<version>.zip`，內含 `docker/docker.exe` + `docker/dockerd.exe`。

**捨**：moby/moby GitHub Release（純 source release，無 Windows binary asset）；Docker Desktop（含 GUI、Linux 子系統、WSL backend，過度肥大）。

**理由**：Docker 官方明確將 Windows static CLI binary 發佈於 `download.docker.com/win/static/`，這是「只要 CLI、不要 daemon」官方支援路徑（Linux 端也提供同 schema 的 `/linux/static/`）。雖然 URL pattern 與 Wave 1~3 的 GitHub release 不同，但屬 Docker Inc. 第一方域名、穩定維護、CDN 加速，可靠度與 GitHub 等同。

### D2: chezmoi-external 的 `path =` 抽 `docker/docker.exe`，主動捨棄 `dockerd.exe`

**選**：`type = "archive-file"` + `path = "docker/docker.exe"`，archive 中其他檔案（`dockerd.exe`、`LICENSE` 等）不抽出。

**捨**：用 `type = "archive"` 抽整個 archive 後手動刪掉 `dockerd.exe`（多一步驟、增加冪等性負擔）。

**理由**：`archive-file` 模式精準輸出單一 binary 到目標路徑，自動處理 idempotency。`dockerd.exe`（Windows containers daemon）在本場景永遠用不到，沒理由佔磁碟空間。

### D3: docker-compose 使用 GitHub Release 的裸 `.exe`，非 `pip install`

**選**：`https://github.com/docker/compose/releases/download/v<version>/docker-compose-windows-x86_64.exe`（裸 binary，無 archive，可 `type = "file"`）。

**捨**：`pip install docker-compose`（v1 已 deprecated）；Scoop（即將卸載）；Docker Compose v2 plugin（隨 Docker Desktop 安裝；本場景不用 Desktop）。

**理由**：Docker Compose 自 v2.0 起以 Go 重寫為單一 binary，並於 2025-12 躍升至 v5 系列（v5.0.0 "Mont Blanc"，本提案 pin 至 v5.1.4）。GitHub Release 直供 `docker-compose-windows-x86_64.exe`。雖然 modern docker CLI 已內建 `docker compose` 子命令（plugin 形式），但其安裝需要 `docker-compose` 放在 plugin 目錄（`~/.docker/cli-plugins/`）才能被 `docker` 識別為子命令；本提案先把 binary 放在 `~/.local/bin/`，讓 `docker-compose` 作為獨立命令可用，同時保留未來 symlink 到 `~/.docker/cli-plugins/docker-compose.exe` 的選項（如有需求再另 propose）。

### D4: DOCKER_HOST 用 `run_onchange_before_` 而非 `run_once_`

**選**：`run_onchange_before_set-docker-host.ps1.tmpl`——每次 chezmoi apply 都檢查當前 User env var，若值不等於 `tcp://127.0.0.1:2375` 則重設。

**捨**：
- `run_once_`：使用者若不慎 / 不知情手動改了 `DOCKER_HOST`，dotfiles 無法回正。
- `dot_chezmoidata.toml`：chezmoidata 是 template var 來源，不是 env var 設定機制。
- Windows registry 直接 patch：太 low-level，且 `[Environment]::SetEnvironmentVariable` 等價且帶廣播。

**理由**：
- `before_`：早於 chezmoi step 4（update entries）執行，與 `run_onchange_before_setup-paths.ps1.tmpl` 同階段，模式一致。
- `onchange_`：每次 apply 都檢查當前狀態，自我修復 drift。腳本本身冪等（值已對則 no-op）。

### D5: 不動 lazydocker，依 user 指示

**選**：lazydocker 留在 scoop，dotfiles 不介入；Wave 5 migration 腳本明確跳過 `scoop uninstall lazydocker`。

**捨**：（無，user 已明確）

**理由**：依 user 指示，lazydocker 為 TUI 工具，個人開發機偶爾用、非 dotfiles 同步焦點；保持「不受 chezmoi 控管」狀態。

### D6: scoopfile.json 不動

**選**：因 docker / docker-compose / lazydocker 從一開始就不在 scoopfile.json 內，無 entry 需要刪除。

**捨**：（不適用）

**理由**：此事實反映 scoop drift 既存——這三套件是「local install 沒 sync 回 scoopfile.json」。Wave 5 不修補此歷史 drift（會擴大範圍），僅在 proposal/design 文件留下記錄供 future reviewer 參考。

## Risks / Trade-offs

- **R1: download.docker.com 服務中斷或 URL schema 變更** → Mitigation: Docker Inc. 第一方域名、有 CDN，歷史變動率低；變更時透過 GitHub Actions 監控 docker.com news 或被動等下次 apply 失敗即可。若擔心 supply-chain，未來 `project_dotfiles_release_mirror` 上線後可改抓自家 mirror（已是規劃中項目）。
- **R2: WSL daemon 不在線時 docker CLI 卡死或 hang** → Mitigation: 與 Wave 5 範圍無關（Wave 1~4 之前也是同樣狀況），但 design 註明：本提案不改變此行為。若需要 timeout 友善的客戶端，後續可加 `DOCKER_CLIENT_TIMEOUT` 或 `dot_zshrc.tmpl` alias。
- **R3: User 之後改 `DOCKER_HOST` 連別的 host（例如 Docker Cloud）** → Mitigation: `run_onchange_before_set-docker-host.ps1.tmpl` 會把它覆寫回 `tcp://127.0.0.1:2375`。Proposal 已明示「不考慮跳板機 / CI / 多 host」場景。若未來需要，可改用 `chezmoidata` 的 host-specific override（per-host config）。
- **R4: 既有機器若有舊版 docker CLI 殘留於 PATH 早於 `~/.local/bin`（極不可能，Wave 1 已修 PATH ordering）** → Mitigation: Wave 5 migration script 卸載 scoop `docker` 後，scoop shim `~/scoop/shims/docker.exe` 自動消失。`where docker` 預期回單一 `~/.local/bin/docker.exe`。
- **R5: `docker compose` (v2 plugin form) 不可用** → Mitigation: 本提案僅保證 `docker-compose` 獨立命令可用。`docker compose` 子命令形式需 binary 在 `~/.docker/cli-plugins/` 或被 Docker Desktop 註冊；本提案範圍內不處理。若需要可後續 propose（symlink 或 copy 到 plugin 目錄）。

## Migration Plan

1. PR merge 並推到 main 後，使用者下次 `chezmoi apply` 自動執行：
   - `run_onchange_before_set-docker-host.ps1.tmpl`：設 `DOCKER_HOST` User env var（若已對則 no-op）。
   - step 4 update entries：下載 `docker.exe` + `docker-compose.exe` 到 `~/.local/bin/`。
   - `run_once_after_migrate-scoop-wave5.ps1.tmpl`：卸載 scoop `docker` + `docker-compose`。
2. 開新的 PowerShell session（或登出登入）讓 `DOCKER_HOST` env var 變更生效。
3. 驗證：
   - `where.exe docker` → 應回 `C:\Users\<user>\.local\bin\docker.exe`（單一條目）。
   - `docker version` → client 版本應為新 pinned；server 應顯示 WSL daemon。
   - `docker ps` → 應列出 WSL 內既有容器（若有）。
   - `docker-compose version` → 顯示 pinned v5 版本（5.1.4）。
4. 回滾：`git revert` PR + `scoop install docker docker-compose` + 手動 `setx DOCKER_HOST tcp://127.0.0.1:2375`。

## Open Questions

無。所有範圍決策已於 propose 階段與 user 確認。
