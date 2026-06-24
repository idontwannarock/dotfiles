## ADDED Requirements

### Requirement: Scoop 殘餘職責邊界——GUI app 清單外置、僅保留互動更新腳本

跨平台工具已全數移出 scoop 後，scoop 在本 repo 的職責 SHALL 收斂為「僅負責不經 chezmoi 跨平台管理的部分」。具體而言：本 repo MUST NOT 維護 scoop 安裝的 GUI app 清單（其 source of truth 為外部 gist），且 MUST NOT 由任何腳本 `scoop import` / 部署該清單；本 repo SHALL 僅保留供使用者手動執行的互動更新腳本 `scripts/scoop-interactive-update.ps1`（經 `scoopupdate` alias 暴露）。

#### Scenario: repo 不再維護 scoop GUI app 清單
- **WHEN** 檢視 repo
- **THEN** 不存在 `scoop/scoopfile.json`（或任何 scoop app 匯出清單），且無腳本 `scoop import` 此類清單；GUI app 清單由外部 gist 維護，README 僅以連結 reference

#### Scenario: 互動更新腳本保留
- **WHEN** 檢視 repo 與部署結果
- **THEN** `scripts/scoop-interactive-update.ps1` 存在，且 `scoopupdate` alias 指向其部署位置 `~/.local/bin/scoop-interactive-update.ps1`

#### Scenario: scoop 不再是 chezmoi 安裝任何工具的依賴
- **WHEN** grep runtime 安裝腳本（`run_once_install-*.ps1.tmpl`）
- **THEN** 無任何未註解的 `Install-ScoopPackage` 呼叫（所有工具改由 `.chezmoiexternal.toml` 或官方安裝方式提供）
