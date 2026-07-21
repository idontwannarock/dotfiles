# Proposal: rework-dev-workflow-skills

## Why

dev-workflow 目前依賴 superpowers plugin 的 5 個 skills、一支 Codex symlink 腳本與設計文件改道補丁,層層疊加造成維護成本,也讓前端(brainstorming)背負過多 approval gates;同時流程缺少 TDD 與 debugging 紀律。評估 mattpocock/skills 後決議(design doc 2026-07-21 已核可):吸收其紀律精華、改寫為自家 chezmoi shared-body skills,讓 harness 完全 model-agnostic,並保留 OpenSpec 管線為脊椎。

## What Changes

- 新增 6 個自家 cross-tool skills(chezmoi shared-body + per-tool name-map):`grill`、`tdd`、`diagnose`、`verify-done`、`worktree`、`finish-branch`
- 改寫 dev-workflow:Large 流程以 `grill` 取代 `superpowers:brainstorming`;移除 `superpowers:writing-plans` 條件步驟(tasks.md 切片慣例取代);`openspec-apply-change` 期間接上 `tdd`;新增 bug 任務進入點(`diagnose`);`verify-done` 取代 `superpowers:verification-before-completion`;`finish-branch` 取代 `superpowers:finishing-a-development-branch`(雙架構原生內建,dispatch table 的 finishing 特例列刪除)
- **BREAKING**:dev-workflow 不再引用任何 superpowers skill(plugin 本體保留,移除屬後續 change)
- 刪除 `home/dot_agent/bin/executable_install-superpowers-codex.sh`(Codex symlink hack)
- user-system-prompt.md:刪除 §8(superpowers 設計文件改道)、刪除 §7 的 finishing override 段

## Capabilities

### New Capabilities

- `discipline-skills`:六個自家流程/紀律 skills 的行為要求 — grill 的單一 stop-gate 訪談與產出分流、tdd 的 seam-based 循環、diagnose 的 feedback-loop 硬 gate、verify-done 的證據先於宣稱、worktree 與 finish-branch 的雙架構(normal / bare-worktree)原生支援,以及全部走 shared-body + name-map 的跨工具部署

### Modified Capabilities

- `workflow-instructions`:小型/大型核心流程的執行順序改為新 skill 鏈;worktree 建立改用自家 `worktree` skill;新增 bug 進入點與 tasks.md 切片慣例要求
- `workflow-concurrency`:workflow 完成清理的觸發點由 `superpowers:finishing-a-development-branch` 改為 `finish-branch`

## Impact

- chezmoi source:`home/.chezmoitemplates/skills/`(+6 bodies + references)、`home/dot_claude/skills/`、`home/dot_codex/skills/`(+6 wrappers 各)、`home/.chezmoitemplates/skills/dev-workflow.md`(改寫)、`home/.chezmoitemplates/user-system-prompt.md`(§7/§8)、刪 `home/dot_agent/bin/executable_install-superpowers-codex.sh`
- 本機部署:`chezmoi apply` 後 Claude 與 Codex 雙端實測
- 不動:openspec-* skills(CLI 生成)、code:review-*、git:*、handoff/pickup、workflow registry、superpowers plugin 安裝(claude-config spec 不變)
