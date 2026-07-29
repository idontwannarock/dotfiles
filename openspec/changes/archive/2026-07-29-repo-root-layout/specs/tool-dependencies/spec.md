## MODIFIED Requirements

### Requirement: Scoop 殘餘職責邊界——GUI app 清單外置、僅保留互動更新腳本

跨平台工具已全數移出 scoop 後，scoop 在本 repo 的職責 SHALL 收斂為「僅負責不經 chezmoi 跨平台管理的部分」。具體而言：本 repo MUST NOT 維護 scoop 安裝的 GUI app 清單（其 source of truth 為外部 gist），且 MUST NOT 由任何腳本 `scoop import` / 部署該清單；本 repo SHALL 僅保留供使用者手動執行的互動更新腳本（經 `scoopupdate` alias 暴露）。

該腳本 SHALL 位於 chezmoi source root 之內（`home/dot_local/bin/scoop-interactive-update.ps1`），與同性質的手動輔助腳本並列，使其確實被部署到 `~/.local/bin/`。腳本 MUST NOT 置於 repo root 的 `home/` 之外——那裡的檔案 chezmoi 看不到，`scoopupdate` alias 指向的路徑將永不存在。

因 scoop 僅存在於 Windows，該腳本 SHALL 由 `.chezmoiignore.tmpl` 的 Windows-only 守衛排除於非 Windows 平台之外，與同目錄的 `switch-pwsh-to-msi.ps1` 適用同一條件。

#### Scenario: repo 不再維護 scoop GUI app 清單
- **WHEN** 檢視 repo
- **THEN** 不存在 `scoop/scoopfile.json`（或任何 scoop app 匯出清單），且無腳本 `scoop import` 此類清單；GUI app 清單由外部 gist 維護，README 僅以連結 reference

#### Scenario: 互動更新腳本位於 chezmoi source 內
- **WHEN** 檢視 repo
- **THEN** `home/dot_local/bin/scoop-interactive-update.ps1` 存在，且 repo root 不存在 `scripts/` 目錄

#### Scenario: 互動更新腳本實際被部署
- **WHEN** 在 Windows 上執行 `chezmoi apply`
- **THEN** `~/.local/bin/scoop-interactive-update.ps1` 存在，且 `scoopupdate` alias 指向的路徑可解析到該檔案

#### Scenario: 非 Windows 平台不部署該腳本
- **WHEN** 在 Linux/WSL 或 macOS 上執行 `chezmoi managed`
- **THEN** 輸出不含 `.local/bin/scoop-interactive-update.ps1`

#### Scenario: scoop 不再是 chezmoi 安裝任何工具的依賴
- **WHEN** grep runtime 安裝腳本（`run_once_install-*.ps1.tmpl`）
- **THEN** 無任何未註解的 `Install-ScoopPackage` 呼叫（所有工具改由 `.chezmoiexternal.toml` 或官方安裝方式提供）
