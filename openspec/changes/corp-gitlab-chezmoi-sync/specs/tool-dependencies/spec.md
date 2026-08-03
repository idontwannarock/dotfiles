## ADDED Requirements

### Requirement: glab 由單一跨平台 external 提供

`glab` SHALL 由 `home/.chezmoiexternal.toml` 的**單一** entry 提供,同時涵蓋 Linux、macOS 與 Windows。上游的 release asset 命名為 `glab_<version>_<os>_<arch>.<ext>`,其中 `<os>`/`<arch>` 與 chezmoi 的 `.chezmoi.os`／`.chezmoi.arch` 逐字相符,故三個平台共用一組 URL 樣板,僅副檔名與封存內路徑隨 `$ext` 變動。

該 entry SHALL NOT 被包在檔案中既有的 `{{ if eq .chezmoi.os "windows" }}` 區塊內 —— 那些區塊來自 scoop 遷移,只適用於 Windows-only 的工具。

此 entry 取代 2026-06 手動放進 `~/.local/bin/` 的未納管 binary。

#### Scenario: 三個平台各自渲染出正確的下載來源
- **WHEN** 在 Linux、macOS、Windows 上分別渲染 `.chezmoiexternal.toml`
- **THEN** 各自得到對應該 OS 的 archive URL,且封存內路徑分別為 `bin/glab`、`bin/glab`、`bin/glab.exe`

#### Scenario: apply 後 binary 可執行且版本符合 pin
- **WHEN** `chezmoi apply` 完成
- **THEN** `~/.local/bin/glab` 存在且具執行權限,`glab --version` 回報的版本等於 `.chezmoiexternal.toml` 中釘住的版本

### Requirement: glab 的版本 pin 由 Renovate 追蹤

`glab` 的版本 pin SHALL 帶有行內 `# renovate:` 註解,使既有的 custom regex manager 能偵測上游新版。其 datasource SHALL 為 `gitlab-releases`(本檔第一個非 GitHub 的 datasource),並 SHALL 指定 `extractVersion`,因為上游 tag 帶 `v` 前綴而 asset 檔名不帶。

`docs/renovate.md` SHALL 記錄這個新增的 datasource。

#### Scenario: 註解格式能被既有 manager 解析
- **WHEN** `renovate.json` 的 custom regex manager 掃描 `.chezmoiexternal.toml`
- **THEN** `glab` 的 pin 被辨識為一個 dependency,其 datasource 為 `gitlab-releases`、depName 為 `gitlab-org/cli`

#### Scenario: renovate 設定仍通過驗證
- **WHEN** `npx --yes renovate-config-validator` 對 `renovate.json` 執行
- **THEN** 回報設定有效、無錯誤
