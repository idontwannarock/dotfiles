## MODIFIED Requirements

### Requirement: Claude plugin 安裝透過 run_onchange_ 腳本
superpowers marketplace 與所需 plugins 的安裝 SHALL 由 chezmoi `run_onchange_` 腳本處理,腳本內容改變時自動重新執行。所需 plugins 為 episodic-memory 與 elements-of-style(均來自 `obra/superpowers-marketplace`),以及 official marketplace 的必要 plugins;**不含**已退役的 superpowers plugin(其 workflow skills 已由 `~/.claude/skills/` 自家 discipline skills 取代)。

#### Scenario: 首次 apply 自動安裝 plugins
- **WHEN** 全新機器執行 chezmoi apply
- **THEN** `run_onchange_install-03-claude-config` 執行,加入 superpowers marketplace 並安裝 episodic-memory、elements-of-style 等所需 plugins,但不安裝 superpowers plugin

#### Scenario: Plugin 腳本更新時重新執行
- **WHEN** plugin 安裝腳本內容變更後執行 chezmoi apply
- **THEN** 腳本重新執行,套用最新的 plugin 設定

#### Scenario: 移除 superpowers plugin 後 episodic-memory 不受影響
- **WHEN** superpowers plugin 已從系統移除,但 marketplace 與 episodic-memory 保留
- **THEN** episodic-memory 的 SessionStart sync hook 仍由其自身 `hooks/hooks.json` 註冊並正常運作,對話 search/archive 功能不中斷
