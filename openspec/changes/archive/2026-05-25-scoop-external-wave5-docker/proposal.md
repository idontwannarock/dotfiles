## Why

承 Wave 1~4 的 scoop → chezmoi-external 系列，Category C「docker audit」轉為具體決策：本機既不需要 Windows-side docker engine（`dockerd.exe`），也不打算用 Docker Desktop——只要 docker / docker-compose 兩個 CLI 連到 WSL Ubuntu 內的 Docker daemon（TCP `127.0.0.1:2375`）。Scoop 的 `docker` 套件同時打包 `docker.exe` + `dockerd.exe`，後者對本場景純屬冗餘；且 scoop drift 嚴重——`docker`/`docker-compose`/`lazydocker` 三者都不在 `scoop/scoopfile.json` 內，等於 source-of-truth 缺漏。同時 `DOCKER_HOST=tcp://127.0.0.1:2375` 目前是手設的 Windows User env var，不在 dotfiles 管理，新機需要重設一次。Wave 5 一次解掉這三件事。

## What Changes

**chezmoi-external 新條目（Windows-only）**：
- `~/.local/bin/docker.exe`：從 Docker Inc. 官方靜態映像下載 `docker-<version>.zip`，僅抽出 `docker/docker.exe`（捨棄 `dockerd.exe`）。URL pattern 與 Wave 1~3 的 GitHub release 不同，是 Wave 5 首見的 `download.docker.com` 路徑。
- `~/.local/bin/docker-compose.exe`：從 GitHub Release `docker/compose` 直接下載 `docker-compose-windows-x86_64.exe`（裸 binary，無 archive）。

**DOCKER_HOST env var 拉進 dotfiles**：
- 新增 `run_onchange_before_set-docker-host.ps1.tmpl`（Windows-only）：若 User-scope `DOCKER_HOST` 不存在或值不等於 `tcp://127.0.0.1:2375`，呼叫 `[Environment]::SetEnvironmentVariable("DOCKER_HOST", ..., "User")` 持久化。冪等：值已正確時 no-op。

**Active migration on existing machines**：
- 新增 `run_once_after_migrate-scoop-wave5.ps1.tmpl`：`scoop uninstall docker`、`scoop uninstall docker-compose` 若已安裝。
- **不**動 `lazydocker`（依使用者指示，TUI 工具保留在 scoop 不受 chezmoi 控管）。
- **不**動 User PATH（Wave 1 已搞定 `~/.local/bin` ordering）。

**Source-of-truth 補洞**：
- `scoop/scoopfile.json` 目前完全沒列 docker 三套件，所以無 entry 需要刪除。Proposal 內陳述此事實，避免下游審閱者誤以為遺漏。

**不動**：
- WSL 那側的 Docker daemon 設定（`/etc/docker/daemon.json` 開 TCP 2375）：屬 WSL Ubuntu rootfs，非 dotfiles scope。
- `lazydocker`：使用者明確要求保持現狀（不進 chezmoi，也不卸載）。
- 既有 Wave 1+2+3+4 entries、migration 腳本、PATH 設定。

**Breaking changes**：
- 既有 Windows 機器執行 `chezmoi apply` 後，scoop `docker` + `docker-compose` 會被卸載。`~/.local/bin/docker.exe` + `docker-compose.exe` 接手；因 Wave 1 已把 `~/.local/bin` 排在 `~/scoop/shims` 之前，PATH lookup 自動命中新位置。
- `dockerd.exe`（Windows 容器 daemon）將不再存在於本機——但既然從未被使用，無實際影響。
- `DOCKER_HOST` env var 若使用者曾改成其他值（例如指向 remote host），`chezmoi apply` 會把它覆寫成 `tcp://127.0.0.1:2375`。Proposal 假設這是個人開發機唯一場景，**不**考慮跳板機 / CI runner 等情境。

## Capabilities

### New Capabilities
（無）

### Modified Capabilities
- `tool-dependencies`：新增 4 條 requirement——`docker` CLI / `docker-compose` 由 chezmoi-external 安裝；`DOCKER_HOST` env var 由 dotfiles 管理；Wave 5 一次性遷移腳本。

## Impact

**Code changes**：
- `.chezmoiexternal.toml`：新增 Wave 5 區塊，含 `docker.exe` 與 `docker-compose.exe` 兩條 external entry，並 pin 對應版本變數。
- `run_onchange_before_set-docker-host.ps1.tmpl`（新檔）：Windows-only，冪等設 User-scope `DOCKER_HOST`。
- `run_once_after_migrate-scoop-wave5.ps1.tmpl`（新檔）：scoop uninstall docker + docker-compose（不動 lazydocker）。

**Existing machine state changes**：
- Scoop 卸載 2 個套件（`docker` + `docker-compose`）；`lazydocker` 維持現狀。
- `~/.local/bin/docker.exe` + `docker-compose.exe` 出現；後續 `docker ps` 等命令解析到新位置。
- User env var `DOCKER_HOST` 被設定為 `tcp://127.0.0.1:2375`（若已是該值，no-op）。
- User PATH **不變**。

**Memory updates（在 archive step 處理）**：
- `reference_chezmoi_external_cli_tools.md`：新增 Wave 5 區塊，記錄 docker + docker-compose 兩條 entry 與 URL pattern 特異性（`download.docker.com` 非 GitHub）。
- `project_scoop_external_wave4_candidates.md`：Category C「docker audit」從候選清單劃掉，標記 Wave 5 完成。
- 視需要更新 `MEMORY.md` 索引。

**Out of scope（後續 Wave 候選）**：
- **archive-pattern**：Category A 仍有 ffmpeg/vim/nvm/gpg（gpg 因 corp-ssh-askpass 依賴需謹慎）。
- **多版本 toolchain**：Category D。
- **WSL Docker daemon 設定 dotfiles 化**：屬 WSL rootfs 範疇，未來若要可獨立 propose。
