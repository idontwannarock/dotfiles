## ADDED Requirements

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

### Requirement: chezmoi external 自動下載對應平台 binary
`.chezmoiexternal.toml` SHALL 宣告 statusline binary 的下載規則，chezmoi apply 時自動下載與當前 OS/arch 對應的版本到 `~/.local/bin/statusline`。

#### Scenario: 正確平台 binary 被下載
- **WHEN** chezmoi apply 在各平台執行
- **THEN** 依 `.chezmoi.os` 與 `.chezmoi.arch` 組合下載對應 binary（e.g., darwin+arm64 → `statusline-darwin-arm64`）

#### Scenario: Binary 設定為可執行
- **WHEN** chezmoi apply 完成 binary 下載
- **THEN** `~/.local/bin/statusline` 具有執行權限

#### Scenario: Binary 已是最新版本時不重複下載
- **WHEN** chezmoi apply 執行，且 binary 已存在且未變更
- **THEN** 跳過下載（chezmoi external 的 checksum 機制處理）

### Requirement: GitHub Release tag 使用 force update
GitHub Release SHALL 使用固定 tag `statusline-latest`，每次新編譯都覆蓋舊版本。

#### Scenario: 新版本覆蓋舊版本
- **WHEN** workflow 發佈新編譯的 binary
- **THEN** `statusline-latest` release 的 assets 被新版本替換
