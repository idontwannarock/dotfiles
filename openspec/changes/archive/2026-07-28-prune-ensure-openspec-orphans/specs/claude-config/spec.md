## ADDED Requirements

### Requirement: 退役的跨 OS 腳本副本一併修剪
腳本正典位置改變後遺留的舊副本 SHALL 於 `home/.chezmoiremove` 中點名移除，不得僅刪除新位置以外的來源檔。在 WSL 環境下 PATH interop 會將 Windows 家目錄的 `~/.local/bin` 併入 PATH，因此以 bare 名稱呼叫的腳本可能命中 Windows 側的過時副本而非正典。

具體而言，`~/.local/bin/ensure-openspec.sh`（正典已移至 `~/.agent/bin/ensure-openspec.sh`）與 `~/.claude/commands/ensure-openspec.md`（功能已由 `dev-workflow` skill 開場步驟涵蓋，且其 bare 呼叫會命中前述過時副本）SHALL 被修剪。

#### Scenario: 過時的 ensure-openspec 腳本副本被移除
- **WHEN** 機器上存在 `~/.local/bin/ensure-openspec.sh` 且執行 chezmoi apply
- **THEN** 該檔案被移除，`~/.agent/bin/ensure-openspec.sh` 成為唯一副本

#### Scenario: 冗餘的 ensure-openspec command 被移除
- **WHEN** 機器上存在 `~/.claude/commands/ensure-openspec.md` 且執行 chezmoi apply
- **THEN** 該檔案被移除，OpenSpec 的初始化改由 `dev-workflow` 以絕對路徑 `~/.agent/bin/ensure-openspec.sh` 觸發

#### Scenario: 已修剪的機器重跑不報錯
- **WHEN** 兩個路徑皆不存在且再次執行 chezmoi apply
- **THEN** apply 正常完成，不因缺少路徑而失敗

### Requirement: install 腳本在嚴格錯誤模式下不因 plugin 指令的 stderr 中斷
`run_onchange_install-03-claude-config.ps1.tmpl` 在 `$ErrorActionPreference = "Stop"` 下執行。PowerShell 的 `2>&1` 會將 native command 的 stderr 逐行轉為 `ErrorRecord`，在 `Stop` 下構成 terminating error。因此所有以 `2>&1` 重導向輸出的 `claude` 指令 SHALL 以 `$ErrorActionPreference = "Continue"` / `"Stop"` 包夾，使其 stderr 不致中斷腳本。

#### Scenario: plugin 指令輸出 stderr 時腳本仍完成
- **WHEN** 任一 `claude plugin install` 或 `claude plugin uninstall` 於 Windows 執行時輸出 stderr（警告、棄用通知、進度訊息）
- **THEN** 腳本不中斷，後續的 cache 清理、hook 路徑修復、BOM 移除、MCP 註冊等段落皆正常執行完畢

#### Scenario: 失敗不留下反覆重試的狀態
- **WHEN** plugin 指令失敗但腳本正常結束
- **THEN** chezmoi 記錄該 `run_onchange_` 腳本的執行狀態，下次 apply 不因同一錯誤重跑

### Requirement: cache 清理訊息須反映實際動作
`install-03-claude-config` 的 plugin cache 清理 SHALL 僅在目標路徑確實存在並被刪除時輸出移除訊息。`rm -rf` 對不存在的路徑仍以 0 結束，故 SHALL NOT 以其結束碼作為「已刪除」的判斷依據。

#### Scenario: 路徑不存在時不輸出移除訊息
- **WHEN** cache 路徑不存在且執行 chezmoi apply
- **THEN** 該路徑對應的 "Removed …" 訊息不出現於輸出

#### Scenario: 路徑存在時輸出移除訊息
- **WHEN** cache 路徑存在且執行 chezmoi apply
- **THEN** 該路徑被刪除並輸出對應的 "Removed …" 訊息
