## MODIFIED Requirements

### Requirement: GitHub Actions 自動編譯並發佈 statusline binary
當 `claude/statusline/statusline.go` 有變更並 push 到 main branch 時，GitHub Actions workflow SHALL 自動編譯四個平台的二進位並上傳至 GitHub Release（tag: `statusline-latest`）。

#### Scenario: statusline.go 變更時觸發編譯
- **WHEN** 包含 `claude/statusline/statusline.go` 變更的 commit push 到 main
- **THEN** GitHub Actions workflow 觸發，開始編譯流程

#### Scenario: 四個平台二進位均被產生
- **WHEN** workflow 執行完成
- **THEN** `statusline-linux-amd64`、`statusline-darwin-amd64`、`statusline-darwin-arm64`、`statusline-windows-amd64.exe` 四個二進位均上傳至 Release

#### Scenario: statusline.go 未變更時不觸發
- **WHEN** push 到 main 的 commit 不含 `claude/statusline/` 下的變更
- **THEN** statusline 編譯 workflow 不觸發
