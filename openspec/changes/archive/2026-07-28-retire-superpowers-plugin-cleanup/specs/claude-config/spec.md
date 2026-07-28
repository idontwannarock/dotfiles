## MODIFIED Requirements

### Requirement: Claude plugin 安裝透過 run_onchange_ 腳本
superpowers marketplace 與所需 plugins 的安裝 SHALL 由 chezmoi `run_onchange_` 腳本處理，腳本內容改變時自動重新執行。所需 plugins 為 episodic-memory 與 elements-of-style（均來自 `obra/superpowers-marketplace`），以及 official marketplace 的必要 plugins。

已退役的 superpowers plugin（其 workflow skills 已由 `~/.claude/skills/` 自家 discipline skills 取代）SHALL NOT 被安裝，且腳本 SHALL 主動將其自既有機器移除，使移除隨 apply 傳播至所有機器，而非僅止於執行者當下那台：偵測到 `superpowers@claude-plugins-official` 已安裝時執行 uninstall，並無條件清除其 plugin cache 目錄 `~/.claude/plugins/cache/claude-plugins-official/superpowers`。既有的 `~/.claude/plugins/cache/superpowers-marketplace/superpowers` 防禦性清理 SHALL 保留。uninstall 與 cache 清除 SHALL 各自冪等，在 plugin 或 cache 不存在時靜默通過，SHALL NOT 中斷腳本後續的 jdtls、MCP、episodic-memory 修復步驟。

`obra/superpowers-marketplace` 的 marketplace 註冊 SHALL 保留，因 episodic-memory 與 elements-of-style 由其供應。

#### Scenario: 首次 apply 自動安裝 plugins
- **WHEN** 全新機器執行 chezmoi apply
- **THEN** `run_onchange_install-03-claude-config` 執行，加入 superpowers marketplace 並安裝 episodic-memory、elements-of-style 等所需 plugins，但不安裝 superpowers plugin

#### Scenario: Plugin 腳本更新時重新執行
- **WHEN** plugin 安裝腳本內容變更後執行 chezmoi apply
- **THEN** 腳本重新執行，套用最新的 plugin 設定

#### Scenario: 既有機器上主動移除 superpowers plugin
- **WHEN** 機器上 `superpowers@claude-plugins-official` 仍為已安裝狀態且執行 chezmoi apply
- **THEN** 腳本執行 uninstall，`installed_plugins.json` 與 `settings.json` 的 `enabledPlugins` 中不再有該 plugin，且 `~/.claude/plugins/cache/claude-plugins-official/superpowers` 被刪除

#### Scenario: 已移除的機器重跑不報錯
- **WHEN** 機器上 superpowers plugin 早已不存在且腳本再次執行
- **THEN** 跳過 uninstall，cache 清除為 no-op，腳本繼續執行後續步驟並正常結束

#### Scenario: 移除 superpowers plugin 後 episodic-memory 不受影響
- **WHEN** superpowers plugin 已從系統移除，但 marketplace 與 episodic-memory 保留
- **THEN** episodic-memory 的 SessionStart sync hook 仍由其自身 `hooks/hooks.json` 註冊並正常運作，對話 search/archive 功能不中斷

#### Scenario: 移除後 marketplace 與 elements-of-style 保留
- **WHEN** superpowers plugin 已從系統移除
- **THEN** `obra/superpowers-marketplace` 仍註冊於 `settings.json` 的 `extraKnownMarketplaces`，elements-of-style 仍為已安裝且啟用狀態

#### Scenario: 移除後 plugin 更新迴圈不再觸及 superpowers
- **WHEN** superpowers plugin 已移除後執行 chezmoi apply，`run_update-claude-plugins` 依 `enabledPlugins` 逐一更新
- **THEN** 更新清單中不含 superpowers，apply 輸出不再出現其更新訊息

## ADDED Requirements

### Requirement: 退役的 Claude command 由 .chezmoiremove 跨機器修剪
`~/.claude/commands/` 為非 `exact_` 目錄，source 中不存在的檔案不會被自動修剪。已退役且未受 chezmoi 管理的 command 檔案 SHALL 於 `home/.chezmoiremove` 中點名，使其在所有機器 apply 時一併移除。

#### Scenario: 退役的 opsx:workflow command 被移除
- **WHEN** 機器上存在 `~/.claude/commands/opsx/workflow.md`（已由 `dev-workflow` skill 取代）且執行 chezmoi apply
- **THEN** 該檔案被移除，`/opsx:workflow` command 不再出現於 Claude Code

#### Scenario: 已移除的機器重跑不報錯
- **WHEN** 該路徑在機器上不存在且再次執行 chezmoi apply
- **THEN** apply 正常完成，不因缺少該路徑而失敗
