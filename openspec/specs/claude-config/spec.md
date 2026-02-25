## ADDED Requirements

### Requirement: Claude Code 設定透過 chezmoi exact_ 目錄部署
`~/.claude/` 下的 CLAUDE.md、commands、agents SHALL 由 chezmoi 以 `exact_` 目錄管理，確保 repo 中移除的檔案在 apply 後自動從系統清除。

#### Scenario: 新增 command 後自動部署
- **WHEN** repo 中新增 `dot_claude/exact_commands/exact_opsx/new-cmd.md` 並執行 chezmoi apply
- **THEN** `~/.claude/commands/opsx/new-cmd.md` 出現在系統

#### Scenario: 移除 command 後自動清除
- **WHEN** repo 中刪除 `dot_claude/exact_commands/exact_sp/old-cmd.md` 並執行 chezmoi apply
- **THEN** `~/.claude/commands/sp/old-cmd.md` 從系統移除

#### Scenario: 移除 agent 後自動清除
- **WHEN** repo 中刪除 `dot_claude/exact_agents/engineering/old-agent.md` 並執行 chezmoi apply
- **THEN** `~/.claude/agents/engineering/old-agent.md` 從系統移除

### Requirement: Claude plugin 安裝透過 run_onchange_ 腳本
superpowers marketplace 與 plugin 的安裝 SHALL 由 chezmoi `run_onchange_` 腳本處理，腳本內容改變時自動重新執行。

#### Scenario: 首次 apply 自動安裝 plugins
- **WHEN** 全新機器執行 chezmoi apply
- **THEN** `run_onchange_install-claude-plugins.sh` 執行，安裝 superpowers marketplace 與 plugin

#### Scenario: Plugin 腳本更新時重新執行
- **WHEN** plugin 安裝腳本內容變更後執行 chezmoi apply
- **THEN** 腳本重新執行，套用最新的 plugin 設定

### Requirement: Windows hook 修復腳本由 chezmoi 管理
Windows 特有的 hook 路徑修復（cygpath workaround）與 BOM 清除 SHALL 由 chezmoi `run_onchange_` PowerShell 腳本處理，僅在 Windows 環境執行。

#### Scenario: Windows 環境自動執行 hook 修復
- **WHEN** chezmoi apply 在 Windows 執行，且修復腳本內容有變更
- **THEN** hook 路徑修復與 BOM 清除腳本執行

#### Scenario: 非 Windows 環境跳過修復腳本
- **WHEN** chezmoi apply 在 macOS 或 Linux 執行
- **THEN** Windows hook 修復腳本不執行（由 .chezmoiignore 或 template OS 判斷排除）
