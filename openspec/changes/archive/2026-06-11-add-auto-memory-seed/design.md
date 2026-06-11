# Design — claude-memory-seed

## 約束與心智模型

Claude Code 的 `autoMemoryDirectory`(寫在 repo 的 `.claude/settings.local.json`)是讓 bare+worktree 多 worktree 共用一份 auto-memory 的 override。要種它,過去靠 repo-local `post-checkout` hook,但有兩個本質限制:

- git 只在 **checkout 類事件**觸發 hook(沒有「開啟 repo」的 git 事件),所以 checkout-only 的種子對**已建好**的 worktree 不回溯。
- repo-local hook 本身要逐 repo 安裝,對既有 repo 一樣不存在。

對策:把種子做成**一支 idempotent helper**,從兩個觸發點呼叫 —— 一個高頻且與 git 無關(Claude SessionStart),一個沿用既有全域 git dispatcher(post-checkout)。helper 自帶守衛,重複跑安全。

## `<repo-name>` 與 bare+worktree 偵測(與 localfiles 一致)

```
common  = git rev-parse --git-common-dir       # 解析為絕對路徑後取用
is_bare = [ basename(realpath(common)) = ".bare" ]
repo    = basename( dirname( realpath(common) ) )   # = container 名
target  = ~/.claude/memory/<repo>
```

- bare+worktree 任一 worktree:common=`<container>/.bare` → `is_bare` 真、`repo`=`<container>`,跨 worktree 一致。**實測**:`shoalter-ai-toolkit/main` → `~/.claude/memory/shoalter-ai-toolkit`,精確對上既有 consolidated dir。
- 一般 repo:common=`<repo>/.git` → `is_bare` 假 → helper no-op(維持預設 `projects/<slug>/memory`)。
- container 根目錄(只有 `.bare/`,本身非 worktree):git 無 common-dir → helper no-op。符合「絕不在 container 層操作」。

`repo` 推導與 `localfiles` 的 `repo_id` 同式,兩機制對同一 repo 解析到同名 key。

## helper 介面

```
claude-memory-seed apply     # 偵測 → 缺值才寫入,idempotent
claude-memory-seed where     # 印出將寫入的目標路徑(除錯用),非 bare 印空
```

行為:

1. 非 git repo / 非 bare+worktree → 安靜 exit 0。
2. 目標檔 `<toplevel>/.claude/settings.local.json` 已有非空 `autoMemoryDirectory` → 不覆寫,exit 0(**in-repo 既設為準**)。
3. 否則:確保 `<toplevel>/.claude/` 存在,以 `jq` 把 `.autoMemoryDirectory = "~/.claude/memory/<repo>"` 併入(檔不存在以 `{}` 起);輸出強制 LF(`tr -d '\r'`,對齊 `modify_settings`)。
4. 缺 `jq` → 安靜 no-op(不阻斷 checkout / session start)。

只種 `autoMemoryDirectory`。`worktree.baseRef: "head"` 仍為 claude-state.md 的手動設定,不在此 helper 範圍(語意不同:memory 一致性 vs. 隔離 worktree 的 base ref)。

## (A) SessionStart hook —— union-append,不覆寫

`modify_settings.json.sh.tmpl` 目前對 PreToolUse / UserPromptSubmit / SessionEnd 採 **hard-assign**,且**刻意不碰 SessionStart**(herdr、agent-sessions 等工具在 runtime 把自己的 SessionStart entry 寫進 settings.json)。因此本 hook **必須 union-append**,否則 chezmoi apply 會清掉那些 runtime entry。

jq(idempotent 守衛 = 既有任一 command 含 `claude-memory-seed` 則不再加):

```jq
| .hooks.SessionStart = (
    (.hooks.SessionStart // []) as $ss
    | if ($ss | map((.hooks // []) | map(.command // "")) | flatten | any(test("claude-memory-seed")))
      then $ss
      else $ss + [ { matcher: "*", hooks: [ { type: "command", command: "bash ~/.local/bin/claude-memory-seed apply" } ] } ]
      end
  )
```

- `matcher: "*"` → startup/resume/clear/compact 都跑(idempotent,重複種無害)。
- 用 `bash ~/.local/bin/...` 顯式路徑而非靠 PATH(Claude hook 環境 PATH 不保證含 `~/.local/bin`),對齊其他 Claude hook 的呼叫風格。
- **生效時點**:`autoMemoryDirectory` 在 session 啟動時讀取,hook 寫入後**下個 session 生效**。對 pre-existing worktree 的價值在於「不需 git 動作即可種」,首次開啟即種、之後恆正確。

## (C) post-checkout dispatcher 加一步

`dot_config/git/hooks/executable_post-checkout`(`local-files-store` 已建)在 `localfiles restore` 之後加:

```sh
command -v claude-memory-seed >/dev/null 2>&1 && claude-memory-seed apply || true
```

- 沿用 dispatcher 既有環境(git 注入 user PATH,`command -v` 可解析 `~/.local/bin`,與 `localfiles` 同條件)。
- dispatcher 既有「chain repo-local `.githooks/post-checkout` + `.git/hooks/post-checkout`(realpath 防遞迴)」邏輯**不動** → **不覆蓋 project-level githook**(本變更的硬性要求)。
- 失敗以 `|| true` 吸收,不阻斷 checkout。

## A vs C 為何都要

- **C(checkout)**:在 `worktree add` 當下即種,新 worktree 一建好就對。
- **A(SessionStart)**:覆蓋「hook 之前就建好、永遠不會再 checkout」的存量 worktree —— 正是使用者點名的缺口。下次用 Claude 開該 repo 即補。
- 兩者共用同一 helper 與守衛,重疊觸發只會 no-op,不會雙寫。

## 安裝與驗證(chezmoi)

- helper 由 chezmoi 以 `executable_` 部署到 `~/.local/bin`。
- dispatcher、modify_settings 為既有檔修改,隨 `chezmoi apply` 生效。
- 驗證:於 `shoalter-ai-toolkit/main`(bare+worktree、目前該 worktree 無 `autoMemoryDirectory`)跑 `claude-memory-seed apply`,確認 `.claude/settings.local.json` 出現 `~/.claude/memory/shoalter-ai-toolkit` 且不動既有 keys;於 dotfiles(一般 repo)跑確認 no-op;再次跑確認不重寫。
