## 1. claude-memory-seed helper 改寫

- [x] 1.1 key 改 path-slug:`canonical=dirname(realpath(common))`、`id=slug(canonical)`(`/`→`-`)、`target=~/.claude/memory/<id>`;移除 `.bare` gate,改為「有 toplevel 的 git repo」皆適用
- [x] 1.2 加遷移步驟:target 空/不存在時依序 `mv` 來源 memory/ 進 target —— ① `~/.claude/memory/<basename(canonical)>/` ② `~/.claude/projects/<id>/memory/`(只搬 memory/、不動 transcripts);target 已有內容→不搬+警告
- [x] 1.3 放寬覆寫政策:現值缺、或開頭為 `~/.claude/memory/` 或 `~/.claude/projects/` → 寫 canonical;否則尊重不動
- [x] 1.4 `where` 同步印新 target;保留無 jq / 非 git → no-op
- [x] 1.5 本機實測(拋棄式 repo):一般 repo 主 checkout → 種 + 從 projects/<id>/memory 遷移;其 worktree → 解析到同一 id；bare worktree → 同既有行為但 key 為 path-slug;basename 舊目錄存在 → 自動 rename;target 已有內容 → 不覆蓋;idempotent

## 2. localfiles repo_id 一致

- [x] 2.1 `dot_local/bin/executable_localfiles`:`repo_id()` 從 `basename(dirname(realpath(common)))` 改為 `slug(dirname(realpath(common)))`(`/`→`-`)
- [x] 2.2 本機實測:`localfiles where` 在一般 repo / worktree / bare worktree 印出 path-slug 桶路徑,且同 repo 跨 worktree 一致

## 3. 文件

- [x] 3.1 `dot_agent/reference/bare-worktree/claude-state.md`:key 描述改 path-slug + 適用全 repo;補一句 Codex 等工具 memory 不可原生共享、故維持 `~/.claude/memory/`
- [x] 3.2 `dot_agent/reference/local-files/index.md`:`<repo-id>` 推導描述同步改 path-slug

## 4. 驗證與一次性遷移

- [x] 4.1 `chezmoi diff` / `apply` 部署改寫後的兩支 helper
- [x] 4.2 於真實 shoalter worktree 實跑 `claude-memory-seed apply`:確認 `~/.claude/memory/shoalter-ai-toolkit` 被 rename 成 path-slug、settings 升級、目錄內容完整
- [x] 4.3 確認 dotfiles 本 session **不**被手動遷移(留待下個 session);`localfiles where` 反映新 key
- [x] 4.4 確認 transcripts 未被動到(`projects/<id>/*.jsonl` still there)
