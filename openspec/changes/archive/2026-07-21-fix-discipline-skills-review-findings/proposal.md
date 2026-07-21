# Proposal: fix-discipline-skills-review-findings

## Why

rework-dev-workflow-skills 的 comprehensive review(六 agent + confidence scoring)發現:worktree / finish-branch 兩個新 skill 的指令文本存在會被 agent 逐字踩中的真 bug(錯誤分支起點、dispose 誤傷未定義選項、無 stop-on-failure、registry 推導自相矛盾),且 superpowers 護欄拆除後仍有殘留風險與過時敘述。

## What Changes

- `worktree`:normal arm 補 `main` 起點;Register 段補 bare-worktree 的 registry 手動分派;bare 命名改通用 `<branch>`;補失敗指引與 `mkdir -p`
- `finish-branch`:重構為「每選項 × 每架構」明確行為;dispose 與 row 移除只在 merge 確認後;全序列 stop-on-first-failure;Discard 的 `-D` 需確認 gate
- `user-system-prompt`:補一行過渡護欄 — superpowers 的 brainstorming / writing-plans / finishing 已被自家 skill 取代,plugin 移除前不得使用
- Codex 安裝腳本(sh + ps1):移除 superpowers 安裝與已失真的註解(Codex 端已零消費者)
- `operating.md` Finishing 段縮成 rationale + 指向 finish-branch(命令只留一份)
- workflow-concurrency spec:補 tool-neutral Current Step invariant
- 文件修正:exact_agents/README.md 舊敘述、docs/claude-code.md:150 澄清、dev-workflow sigil 反例改寫、archived proposal/tasks 的 installer 敘述更正
- `chezmoi-author` skill:Authoring Checklist 加 render + grep `<no value>` 的 name-map regression guard

## Capabilities

### New Capabilities

(無)

### Modified Capabilities

- `discipline-skills`:worktree 與 finish-branch 的 requirement 補上分支起點、選項行為、失敗中止的 scenarios
- `workflow-concurrency`:Active Workflows Index 補 tool-neutral Current Step invariant

## Impact

- chezmoi source:skills/{worktree,finish-branch,dev-workflow}.md、user-system-prompt.md、run_install-04-codex-plugins.{sh,ps1}.tmpl、dot_agent/reference/bare-worktree/operating.md、dot_claude/skills/chezmoi-author、exact_agents/README.md、docs/claude-code.md
- openspec:兩個 capability 的 delta;archive 內文字更正
- 本機:`chezmoi apply` 重佈
