## 1. 建立 ~/.agent/reference/bare-worktree/ 拆分檔

- [x] 1.1 由 `.chezmoitemplates/bare-worktree-workflow.md` 逐段對應，建立 `dot_agent/reference/bare-worktree/operating.md`（§How to detect + §Operating rules）
- [x] 1.2 建立 `dot_agent/reference/bare-worktree/setup.md`（§Bootstrapping on a new machine + §Converting an existing flat repo）
- [x] 1.3 建立 `dot_agent/reference/bare-worktree/claude-state.md`（§Claude state across worktrees + §Settings per repo + §Workflow registry + §Migrating Claude state + §Not the same as --bare），檔頭標明 Claude-specific
- [x] 1.4 新寫 `dot_agent/reference/bare-worktree/index.md`：說明用途、何時讀、路由表（註明 claude-state.md 為 Claude 專屬，他 tool 可跳過）
- [x] 1.5 確認四檔內容無遺漏原 157 行任何段落

## 2. 收斂指標與移除舊副本

- [x] 2.1 改寫 `.chezmoitemplates/user-system-prompt.md` §7 指標為 `~/.agent/reference/bare-worktree/index.md`
- [x] 2.2 更新 `dot_claude/skills/dev-workflow/SKILL.md` L33 → `~/.agent/reference/bare-worktree/claude-state.md`
- [x] 2.3 更新 `dot_claude/skills/dev-workflow/SKILL.md` L44 → `~/.agent/reference/bare-worktree/index.md`
- [x] 2.4 刪除 `dot_claude/bare-worktree-workflow.md.tmpl`
- [x] 2.5 刪除 `dot_codex/bare-worktree-workflow.md.tmpl`
- [x] 2.6 刪除 `.chezmoitemplates/bare-worktree-workflow.md`

## 3. 驗證 chezmoi 部署

- [x] 3.1 `chezmoi diff` 確認 `~/.agent/reference/bare-worktree/*.md` 將生成、`~/.claude/bare-worktree-workflow.md` 與 `~/.codex/bare-worktree-workflow.md` 將移除
- [x] 3.2 確認渲染後的 `~/.claude/CLAUDE.md` 與 `~/.codex/AGENTS.md` §7 指向新絕對路徑
- [x] 3.3 `chezmoi apply` 後實際確認新檔存在、舊檔已移除、dev-workflow SKILL 連結指向存在路徑

## 4. 清理 machine-local 孤兒檔

- [x] 4.1 確認 `~/.claude/reference.md` 仍無 referrer 後 `rm`
- [x] 4.2 確認 `~/.claude/worklog-config.md` 確未被 skill 讀取後 `rm`
