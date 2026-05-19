## ADDED Requirements

### Requirement: Fresh VM bootstrap 確保 modify_ 依賴的 CLI 在執行前可用
Windows 上 SHALL 存在 `run_onchange_before_setup-paths.ps1.tmpl`，在 chezmoi apply 的 `run_before_` 階段（早於 step 4 update entries）執行，職責有二：

1. **確保 ~/.local/bin/jq.exe 物理存在**：若不存在，從 GitHub Release（與 `.chezmoiexternal.toml` 同一 URL 與 pinned version）以 `Invoke-WebRequest` 下載並設為 executable。Fresh VM 上此步必跑；既有機器上 jq.exe 已存在 → no-op。
2. **確保 User PATH 含 ~/.local/bin**：若不存在於 User-scope `Path` 環境變數，prepend 之並持久化（給未來 shell session）。已存在 → no-op。

腳本 SHALL 為冪等：對於兩個職責，已達標時 SHALL 跳過實際操作而非報錯。

#### Scenario: Fresh VM 上 setup-paths 下載 jq.exe
- **WHEN** Windows VM 上 `~/.local/bin/jq.exe` 不存在，chezmoi apply 執行至 `run_before_` 階段
- **THEN** setup-paths 透過 `Invoke-WebRequest` 從 `https://github.com/jqlang/jq/releases/download/jq-<version>/jq-windows-amd64.exe` 下載 jq.exe 至 `~/.local/bin/jq.exe`；下載失敗時 throw 終止 apply

#### Scenario: 既有機器上 setup-paths 為 no-op
- **WHEN** Windows 機器上 `~/.local/bin/jq.exe` 已存在
- **THEN** setup-paths 不重新下載 jq.exe

#### Scenario: Fresh VM 上 User PATH 加入 ~/.local/bin
- **WHEN** Windows VM 上 User PATH 不含 `~/.local/bin`（展開後等於 `%USERPROFILE%\.local\bin`），chezmoi apply 執行至 `run_before_` 階段
- **THEN** setup-paths 透過 `[Environment]::SetEnvironmentVariable("Path", ..., "User")` 將 `~/.local/bin` prepend 到 User PATH

#### Scenario: 既有機器上 User PATH 不重複加 ~/.local/bin
- **WHEN** Windows 機器上 User PATH 已含 `~/.local/bin`（不論位置）
- **THEN** setup-paths 不修改 User PATH

#### Scenario: setup-paths 早於 modify_settings.json 執行
- **WHEN** chezmoi apply 進入 step 4 update entries
- **THEN** `~/.local/bin/jq.exe` 已存在於檔案系統，且 chezmoi 子程序的 PATH 包含 `~/.local/bin`（由 `[scriptEnv]` 提供），因此 `modify_settings.json.sh.tmpl` 內的 `jq` 呼叫能正常解析

## MODIFIED Requirements

### Requirement: jq 在 Windows 上由 chezmoi-external 安裝
Windows 上 jq SHALL 由 `.chezmoiexternal.toml` 直接下載 GitHub Release 的 `jq-windows-amd64.exe` 至 `~/.local/bin/jq.exe`（jq 是裸 `.exe`，非 archive）。Fresh VM 上由於 external 在 step 4 才執行（晚於同階段、字母順序較早的 modify_ files），SHALL 另由 `run_onchange_before_setup-paths.ps1.tmpl`（step 3）負責在 modify_ 跑之前把 jq.exe 落地；該 setup-paths 腳本與 external 用同一 URL 與 pinned version，確保兩處不會出現版本飄移。

#### Scenario: Windows 上下載 jq binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 從 `https://github.com/jqlang/jq/releases/download/jq-<version>/jq-windows-amd64.exe` 下載至 `~/.local/bin/jq.exe`，設為 executable

#### Scenario: Windows 上 jq 不再經由 Scoop prereq 腳本
- **WHEN** 在 Windows 上的 `run_onchange_before_install-prereqs.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Ensure-ScoopTool "jq"`

#### Scenario: Fresh VM 上 jq.exe 早於 modify_settings 落地
- **WHEN** 全新 Windows VM 上 `chezmoi init <repo> && chezmoi apply`，且 modify_ 階段（step 4）尚未開始
- **THEN** `run_onchange_before_setup-paths.ps1.tmpl`（step 3）已從 GitHub Release 下載 jq.exe 至 `~/.local/bin/`；後續 `modify_settings.json.sh.tmpl` 啟動的 bash 程序透過 scriptEnv 注入的 PATH 解析到該 jq.exe 並成功 patch settings.json

#### Scenario: 既有機器上 setup-paths 與 external 都不重做下載
- **WHEN** Windows 機器上 `~/.local/bin/jq.exe` 已存在且版本與 pinned 一致
- **THEN** setup-paths 偵測檔案存在後 no-op；step 4 的 external entry 因 hash 一致也 skip 重下
