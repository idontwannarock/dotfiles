## 1. claude-memory-seed helper

- [x] 1.1 撰寫 `dot_local/bin/executable_claude-memory-seed`(POSIX sh):common-dir 解析(絕對化)、bare+worktree 偵測(`basename(realpath(common)) = ".bare"`)、`<repo-name>` 推導(`basename(dirname(realpath(common)))`)、目標檔 `<toplevel>/.claude/settings.local.json`
- [x] 1.2 子命令 `apply`(非 bare / 已設值 / 無 jq → 安靜 no-op;否則 jq 併入 `autoMemoryDirectory`,LF 結尾,不覆寫既有 keys)、`where`(印目標路徑除錯用)
- [x] 1.3 本機實測:`shoalter-ai-toolkit/main`(bare+worktree,目前無 `autoMemoryDirectory`)→ `apply` 寫入 `~/.claude/memory/shoalter-ai-toolkit`;再次 `apply` 不重寫;dotfiles(一般 repo)→ no-op;container 根目錄 → no-op

## 2. (C) post-checkout dispatcher 加一步

- [x] 2.1 `dot_config/git/hooks/executable_post-checkout`:於 `localfiles restore` 後加 `command -v claude-memory-seed >/dev/null 2>&1 && claude-memory-seed apply || true`,既有 repo-local hook chaining 不動
- [x] 2.2 本機實測:於 bare+worktree repo `git worktree add` 新 worktree → 確認 `autoMemoryDirectory` 被種;放一個 `.githooks/post-checkout` 確認仍被 chain(C 不覆蓋 project hook)

## 3. (A) SessionStart hook(union-append)

- [x] 3.1 `dot_claude/modify_settings.json.sh.tmpl`:加 `.hooks.SessionStart` 的 union-append jq(既有 command 含 `claude-memory-seed` 則不重加;entry 用 `matcher:"*"` + `bash ~/.local/bin/claude-memory-seed apply`),不改動既有 PreToolUse/UserPromptSubmit/SessionEnd
- [x] 3.2 本機實測:把含 herdr/agent-sessions SessionStart 的現行 settings.json 餵進 modify 腳本 → 確認既有 SessionStart entries 保留、本 hook 被加且僅加一次(重跑 idempotent)

## 4. 文件整合

- [x] 4.1 `dot_agent/reference/bare-worktree/claude-state.md`:「A repo `post-checkout` hook seeds this file on new worktrees」一節更新為集中式自動種子(SessionStart + 全域 post-checkout 共用 helper),並註明 `baseRef` 仍為手動設定

## 5. chezmoi 驗證

- [x] 5.1 `chezmoi diff` 確認 `~/.local/bin/claude-memory-seed`(具可執行位)、`~/.config/git/hooks/post-checkout` 新增行、settings.json 的 SessionStart 變更如預期
- [x] 5.2 `chezmoi apply` 後:`claude-memory-seed` 在 PATH 可執行;於 bare+worktree worktree 跑確認種對路徑;dotfiles 跑確認 no-op
- [x] 5.3 確認 `.chezmoiignore.tmpl` 不排除新 helper(三平台)、`.gitattributes` 對 sh helper 採 LF
