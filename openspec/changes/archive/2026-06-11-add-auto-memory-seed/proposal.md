## Why

Claude Code 的 auto-memory 預設寫到 `~/.claude/projects/<cwd-slug>/memory/`。bare+worktree 佈局下,為了讓同一 repo 的多個 worktree 共用一份 memory,`bare-worktree/claude-state.md` 用每個 worktree 的 `.claude/settings.local.json` 裡的 **`autoMemoryDirectory`** override 成 `~/.claude/memory/<repo-name>`,並靠「repo `post-checkout` hook 在新 worktree seed 這個檔」來自動化。

這個機制有兩個缺口:

1. **只在 checkout 事件觸發,不回溯** —— `post-checkout` hook 只在 `git worktree add` / branch checkout 當下跑一次。任何在 hook 存在**之前**就已建好的 worktree,永遠不會被補種,仍停在舊的 per-project 路徑。`local-files-store` 的 design 已預留伏筆指向「bare 佈局用來 seed `autoMemoryDirectory` 的那支」,但那支從未以可分發形式存在。
2. **repo-local hook 對現有 repo 形同不存在** —— 種子邏輯若放在 repo-local `.githooks/post-checkout`,本身也得逐 repo 安裝,對既有 repo 一樣不生效,等於把問題往下推一層。

## What Changes

把 `autoMemoryDirectory` 的種子邏輯抽成**單一 idempotent helper**,並從**兩個高頻觸發點**呼叫它,徹底覆蓋現有與未來的 bare+worktree repo:

- **`claude-memory-seed` helper**(`~/.local/bin/claude-memory-seed`,仿 `localfiles` 結構):偵測 cwd 是否為 bare+worktree(`basename(realpath(git-common-dir)) == ".bare"`),是則在該 worktree 的 `.claude/settings.local.json` 缺 `autoMemoryDirectory` 時寫入 `~/.claude/memory/<repo-name>`;非 bare+worktree 或已設值則安靜 no-op。`<repo-name>` 推導與 `localfiles` 的 repo-id 一致(`basename(dirname(realpath(git-common-dir)))`)。
- **(A)全域 SessionStart hook**:在 `modify_settings.json.sh.tmpl` 以 **union-append**(非覆寫)把一個 SessionStart hook 併入 settings.json,每次開 repo 都呼叫 helper。這是解「現有 repo 不靠 checkout」的主力 —— 對你正在用的 repo 等於下一個 session 就生效,且不需任何 git 動作。
- **(C)全域 post-checkout dispatcher 加一步**:在既有 `~/.config/git/hooks/post-checkout`(`local-files-store` 已建)的 `localfiles restore` 之後加一行呼叫 helper,讓 checkout / `worktree add` 也即時種。dispatcher 既有的「chain repo-local `.githooks/` + `.git/hooks/`」邏輯原封不動 —— **不覆蓋 project-level githook**。
- **A 與 C 共用同一支 helper**,單一事實來源,行為一致;偵測與 idempotent 守衛只寫一處。
- **整合既有文件**:`bare-worktree/claude-state.md` 中「repo `post-checkout` hook seeds this file」一句更新為指向這個集中式自動種子機制。

## Capabilities

### New Capabilities

- `claude-memory-seed`: bare+worktree 的 `autoMemoryDirectory` 自動種子機制 —— helper 的偵測/推導/idempotent 寫入語意、SessionStart 與 post-checkout 兩個觸發點、union-append 不覆寫既有 SessionStart hook、以及對非 bare+worktree repo 的 no-op 行為。

### Modified Capabilities

(無既有 spec 需修改。`local-files-store` 的 dispatcher 多工/不覆蓋行為不變,僅在其 restore 後新增一步呼叫;bare-worktree 的 `autoMemoryDirectory` 為 reference 內文,非 spec 化需求,隨文件更新。)

## Impact

- **新增檔案(可執行)**:`dot_local/bin/executable_claude-memory-seed`(POSIX sh helper)→ `~/.local/bin/claude-memory-seed`。
- **修改檔案**:
  - `dot_config/git/hooks/executable_post-checkout` —— `localfiles restore` 後加一行 `claude-memory-seed apply`(C)。
  - `dot_claude/modify_settings.json.sh.tmpl` —— union-append SessionStart hook(A),刻意**不**改動既有 PreToolUse/UserPromptSubmit/SessionEnd 的 hard-assign。
  - `dot_agent/reference/bare-worktree/claude-state.md` —— 「post-checkout hook seeds this file」一節改述為集中式自動種子。
- **依賴**:helper 用 `jq` 合併 JSON(dotfiles 已全機器安裝 jq;缺 jq 時 helper 安靜 no-op,不阻斷)。
- **跨平台**:helper 為 POSIX sh;git hook 在 Windows 由 git-bash 執行;SessionStart hook 以 `bash ~/.local/bin/claude-memory-seed apply` 呼叫,三平台一致。
- **scope 邊界**:只種 `autoMemoryDirectory`;`worktree.baseRef: "head"` 仍為 claude-state.md 記載的手動設定,不在本變更內。
- **blast radius**:helper 只在 bare+worktree(`.bare` 為 common-dir)且缺值時寫入;一般 repo(含 dotfiles 本身)一律 no-op,維持預設 per-project memory 路徑不變。
