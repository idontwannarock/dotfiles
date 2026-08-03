## MODIFIED Requirements

### Requirement: 跨工具部署與手動觸發
`arch-review` SHALL 以 chezmoi shared-body(`home/.chezmoitemplates/skills/arch-review.md`)搭配 per-tool wrapper 部署:Claude 端為 command(`home/dot_claude/commands/arch-review.md.tmpl`),Codex 端為 skill(`home/dot_codex/skills/arch-review/SKILL.md.tmpl`)。兩端 SHALL 共用同一份 body,行為 SHALL NOT 分叉。

`arch-review` 的產物為 `~/.agent/handoffs/` 下的報告檔,可逆且非外部可見,故依 `model-invocability` 的判準 SHALL NOT 標記 `disable-model-invocation: true`。控制體檢頻率的責任在 skill body 自身的觸發條件與「關卡頻率由訊號密度決定」的原則,不在 wrapper 的 flag。

#### Scenario: chezmoi apply 後雙工具可用
- **WHEN** `chezmoi apply` 完成
- **THEN** `~/.claude/commands/arch-review.md` 與 `~/.codex/skills/arch-review/SKILL.md` SHALL 存在,且由同一份 shared body 渲染

#### Scenario: 兩端可呼叫性一致
- **WHEN** 比較 Claude 端 command 與 Codex 端 skill 的可呼叫性
- **THEN** 兩端 SHALL 皆允許模型自行呼叫 —— Claude 端 wrapper SHALL NOT 含 `disable-model-invocation`,Codex 端無對應限制機制

#### Scenario: Codex frontmatter 為嚴格 YAML
- **WHEN** 以 YAML parser 解析 `~/.codex/skills/arch-review/SKILL.md` 的 frontmatter
- **THEN** SHALL 解析成功 —— 含冒號的 `description` SHALL 加引號
