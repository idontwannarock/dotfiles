## MODIFIED Requirements

### Requirement: Claude Code 設定透過 chezmoi exact_ 目錄部署
`~/.claude/agents/` SHALL 由 chezmoi 以 `exact_` 目錄(`dot_claude/exact_agents/`)管理,確保 repo 中移除的 agent 檔案在 apply 後自動從系統清除。

`exact_` 的前提是**該目錄的內容完全屬於 chezmoi**;僅在此前提成立時才 SHALL 使用它。`~/.claude/commands/` 與 `~/.claude/skills/` 不滿足此前提(見「退役的 Claude command 由 .chezmoiremove 跨機器修剪」requirement),故 SHALL NOT 改為 `exact_`。

#### Scenario: 新增 agent 後自動部署
- **WHEN** repo 中新增 `dot_claude/exact_agents/engineering/new-agent.md` 並執行 chezmoi apply
- **THEN** `~/.claude/agents/engineering/new-agent.md` 出現在系統

#### Scenario: 移除 agent 後自動清除
- **WHEN** repo 中刪除 `dot_claude/exact_agents/engineering/old-agent.md` 並執行 chezmoi apply
- **THEN** `~/.claude/agents/engineering/old-agent.md` 從系統移除

#### Scenario: commands 不得改為 exact_
- **WHEN** 有人提議將 `dot_claude/commands/` 或 `dot_claude/skills/` 改為 `exact_` 前綴以取得自動修剪
- **THEN** SHALL 拒絕,因該目錄存在非 chezmoi 管理的檔案,`exact_` 會靜默刪除它們;退役修剪 SHALL 改用 `.chezmoiremove` 點名

### Requirement: 退役的 Claude command 由 .chezmoiremove 跨機器修剪
`~/.claude/commands/` 與 `~/.claude/skills/` 為非 `exact_` 目錄,source 中不存在的檔案不會被自動修剪。已退役且未受 chezmoi 管理的 command 或 skill 檔案 SHALL 於 `home/.chezmoiremove` 中點名,使其在所有機器 apply 時一併移除。

此判準為結構性的:這兩個目錄天生會有非 chezmoi 管理的內容 —— 機器專屬的、實驗中的、或由 plugin 與其他工具寫入的檔案。因此 SHALL NOT 對其套用 `exact_`;**僅刪除 source 中的檔案是不足的**,已 apply 過的機器會永久保留該檔。

#### Scenario: 退役的 opsx:workflow command 被移除
- **WHEN** 機器上存在 `~/.claude/commands/opsx/workflow.md`(已由 `dev-workflow` skill 取代)且執行 chezmoi apply
- **THEN** 該檔案被移除,`/opsx:workflow` command 不再出現於 Claude Code

#### Scenario: 已移除的機器重跑不報錯
- **WHEN** 該路徑在機器上不存在且再次執行 chezmoi apply
- **THEN** apply 正常完成,不因缺少該路徑而失敗

#### Scenario: 退役 skill 同樣需點名
- **WHEN** 某 skill 自 `home/dot_claude/skills/` 或 `home/dot_codex/skills/` 移除
- **THEN** 其部署路徑 SHALL 於 `home/.chezmoiremove` 點名,否則已 apply 過的機器會保留該 skill

#### Scenario: 非 chezmoi 管理的檔案不受影響
- **WHEN** 機器上存在未被 chezmoi 管理的 command 或 skill(例如手動放置或由 plugin 寫入者)且執行 chezmoi apply
- **THEN** 該檔案 SHALL 保持不變,SHALL NOT 因 apply 而被刪除
