## ADDED Requirements

### Requirement: docker CLI 在 Windows 上由 chezmoi-external 安裝
Windows 上 docker CLI SHALL 由 `.chezmoiexternal.toml` 從 Docker Inc. 官方靜態映像 `https://download.docker.com/win/static/stable/x86_64/docker-<version>.zip` 下載，僅抽出 archive 內 `docker/docker.exe` 至 `~/.local/bin/docker.exe`，捨棄同 archive 的 `dockerd.exe`。版本以 `$dockerVersion` 變數 pinned。

URL pattern 與 Wave 1~3 的 GitHub release 不同，是 Wave 5 首見的 `download.docker.com` 路徑（Docker Inc. 官方 CDN）。

#### Scenario: Windows 上下載 docker.exe
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 從 `https://download.docker.com/win/static/stable/x86_64/docker-<version>.zip` 下載並抽出 `docker/docker.exe` 至 `~/.local/bin/docker.exe`，設為 executable

#### Scenario: dockerd.exe 不會出現在 ~/.local/bin
- **WHEN** chezmoi apply 完成 Wave 5 階段
- **THEN** `~/.local/bin/dockerd.exe` 不存在（archive 中的 `dockerd.exe` 因 `path` 過濾未抽出）

#### Scenario: Windows 上 docker 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-containers.ps1.tmpl`（或其他 install 腳本）執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "docker"`

### Requirement: docker-compose 在 Windows 上由 chezmoi-external 安裝
Windows 上 docker-compose SHALL 由 `.chezmoiexternal.toml` 從 GitHub Release `docker/compose` 直接下載 `docker-compose-windows-x86_64.exe`（裸 binary，無 archive）至 `~/.local/bin/docker-compose.exe`。版本以 `$dockerComposeVersion` 變數 pinned；URL tag 帶 `v` prefix。

#### Scenario: Windows 上下載 docker-compose.exe
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 從 `https://github.com/docker/compose/releases/download/v<version>/docker-compose-windows-x86_64.exe` 下載至 `~/.local/bin/docker-compose.exe`，設為 executable

#### Scenario: Windows 上 docker-compose 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-containers.ps1.tmpl`（或其他 install 腳本）執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "docker-compose"`

### Requirement: DOCKER_HOST env var 由 dotfiles 管理（Windows User scope）
Windows 上 SHALL 存在 `run_onchange_before_set-docker-host.ps1.tmpl`，在 chezmoi apply 的 `run_before_` 階段執行，職責為：確保 User-scope 環境變數 `DOCKER_HOST` 的值為 `tcp://127.0.0.1:2375`。

腳本 SHALL 為冪等：值已正確時 SHALL NOT 再次寫入。

腳本 SHALL 為 Windows-only，透過 chezmoi template `{{ if eq .chezmoi.os "windows" }}` 守衛。

腳本 SHALL 假設「個人開發機、單一架構」場景，**不**支援跳板機、CI runner、多 host 切換等情境。

#### Scenario: Fresh machine 上 DOCKER_HOST 不存在
- **WHEN** Windows 機器上 User env var `DOCKER_HOST` 為 null 或空字串，chezmoi apply 執行至 `run_before_` 階段
- **THEN** 腳本透過 `[Environment]::SetEnvironmentVariable("DOCKER_HOST", "tcp://127.0.0.1:2375", "User")` 寫入，並印出提示要求重開 session 讓變更生效

#### Scenario: DOCKER_HOST 已是正確值時 no-op
- **WHEN** Windows 機器上 User env var `DOCKER_HOST` 已等於 `tcp://127.0.0.1:2375`，chezmoi apply 執行
- **THEN** 腳本不重新寫入，不印出 setx 訊息（可印 "already set" gray 訊息）

#### Scenario: DOCKER_HOST 被使用者改成其他值時被覆寫
- **WHEN** Windows 機器上 User env var `DOCKER_HOST` 被使用者改為其他值（例如 `tcp://remote-host:2375`），chezmoi apply 執行
- **THEN** 腳本將 `DOCKER_HOST` 覆寫回 `tcp://127.0.0.1:2375`，印出 warning 註明值被回正

### Requirement: Wave 5 一次性遷移腳本
`run_once_after_migrate-scoop-wave5.ps1.tmpl` SHALL 在 Windows 上執行一次性遷移：卸載 2 個 scoop 套件 `docker`、`docker-compose`。腳本 SHALL 為冪等：scoop 未安裝對應套件時視為 no-op；scoop 未安裝時整支 skip。

腳本 SHALL NOT 卸載 `lazydocker`（依 user 指示保持 scoop 安裝，不受 chezmoi 控管）。

腳本 SHALL NOT 動 User PATH（Wave 1 的 `run_once_after_migrate-scoop-to-external.ps1.tmpl` 已把 `~/.local/bin` 排在 `~/scoop/shims` 之前）。

#### Scenario: 已安裝 scoop 硬清套件被卸載
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list <pkg>` 回報已安裝（pkg ∈ {docker, docker-compose}）
- **THEN** 腳本執行 `scoop uninstall <pkg>`，scoop apps 目錄該套件被移除

#### Scenario: lazydocker 不被卸載
- **WHEN** chezmoi apply 在 Windows 執行且 `scoop list lazydocker` 回報已安裝
- **THEN** Wave 5 migration 腳本 SHALL NOT 執行 `scoop uninstall lazydocker`

#### Scenario: scoop 硬清套件未安裝時 no-op
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list <pkg>` 回報未安裝
- **THEN** 腳本不執行 `scoop uninstall`，繼續處理下一個

#### Scenario: scoop 未安裝時 no-op
- **WHEN** chezmoi apply 在 Windows 執行，且 `Get-Command scoop` 回 not found
- **THEN** 腳本印警告訊息並 return，不嘗試任何 scoop 命令

#### Scenario: User PATH 不被本腳本修改
- **WHEN** Wave 5 migration 腳本執行
- **THEN** User PATH 環境變數值維持不變（PATH 排序為 Wave 1 migration 腳本的責任）
