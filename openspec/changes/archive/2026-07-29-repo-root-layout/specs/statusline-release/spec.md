## MODIFIED Requirements

### Requirement: GitHub Actions 自動編譯並發佈 statusline binary
當 `tools/statusline/statusline.go` 有變更並 push 到 main branch 時，GitHub Actions workflow SHALL 自動編譯四個平台的二進位並上傳至 GitHub Release（tag: `statusline-latest`）。

statusline 原始碼 SHALL 置於 `tools/statusline/`，與同性質的 `tools/passgen/` 並列——兩者皆為 repo 內由 CI 編譯、經 `.chezmoiexternal.toml` 拉回部署的工具程式原始碼，皆位於 chezmoi source root 之外。

#### Scenario: statusline.go 變更時觸發編譯
- **WHEN** 包含 `tools/statusline/statusline.go` 變更的 commit push 到 main
- **THEN** GitHub Actions workflow 觸發，開始編譯流程

#### Scenario: 四個平台二進位均被產生
- **WHEN** workflow 執行完成
- **THEN** `statusline-linux-amd64`、`statusline-darwin-amd64`、`statusline-darwin-arm64`、`statusline-windows-amd64.exe` 四個二進位均上傳至 Release

#### Scenario: statusline.go 未變更時不觸發
- **WHEN** push 到 main 的 commit 不含 `tools/statusline/` 下的變更
- **THEN** statusline 編譯 workflow 不觸發

#### Scenario: 原始碼搬遷不改變下載契約
- **WHEN** 原始碼由 `claude/statusline/` 移至 `tools/statusline/` 後 workflow 重新發佈
- **THEN** Release tag（`statusline-latest`）與四個 artifact 名稱均不變，`.chezmoiexternal.toml` 的下載 URL 無須調整
