# Agent 在 worktree 裡工作

`dev-workflow` 併行開發時會開 linked worktree（`../<repo>-<branch>`）。三個 agent
搬進去的方式都不一樣，其中一個根本搬不了。本文只記實測結果與該下什麼指令。

機制面的規則在 `~/.agent/reference/git-worktree-hazards.md`；skill 裡每個 agent
該做什麼由各自的 name-map 渲染，見 `home/dot_claude/` 與 `home/dot_codex/` 下的
`skills/dev-workflow/SKILL.md.tmpl`。

驗證環境：Claude Code（Opus 5）、Codex CLI 0.154.0、Antigravity CLI 1.2.5，
WSL2，2026-09-17。測試用一個 `~/ws/wt-lab` 臨時 repo 加一個 sibling worktree，
刻意不放 `/tmp` —— `/tmp` 在 Codex 的預設可寫根裡，放那裡會測出假綠燈。

## `cd` 在三個 agent 都不會留

每一次 shell 呼叫都是獨立的 process，起點是 session 自己的 cwd。`cd` 在呼叫內有效，
下一個呼叫就沒了。Antigravity 的 `run_command` schema 自己寫得最清楚：

> persistent terminals share variables but are separate `bash -c` invocations;
> shell state like working directory, aliases, and functions are not shared.

所以「搬 session」是 harness 層的動作，不是 shell 指令。

## 三個 agent 的實測結果

| | 搬 cwd 進 worktree | worktree 可讀寫 | 主 checkout 可讀 | 主 checkout 可寫 |
|---|---|---|---|---|
| Claude Code | ✅ `EnterWorktree` | ✅ | ✅ | 未測 |
| Codex | ✅ `/cd` | ✅ | ✅ | ❌ 搬走後唯讀 |
| Antigravity | ❌ 沒有機制 | ✅ | ✅ | ✅ |

### Claude Code

`EnterWorktree(path: "<worktree 絕對路徑>")`。agent 自己叫得動，不需要人介入。
`path` 形式吃既有的 sibling worktree，所以 `../<repo>-<branch>` 佈局不用改成它
預設的 `.claude/worktrees/`。

收尾前用 `ExitWorktree(action: "keep")` 回主 checkout。**`keep` 是承重的** ——
`remove` 會把後面處置步驟還要用的 worktree 刪掉。

### Codex

`/cd <worktree 絕對路徑>`，**由人打**。slash command 是使用者輸入的 UI，agent
沒有工具叫得動它，shell 也碰不到。所以 skill 會停下來請使用者貼這一行。

可寫根跟著 `/cd` 走，是對調不是疊加：搬進 worktree 後主 checkout 變成可讀不可寫。
`/debug-config` 顯示設定層也跟著重算，讀的是 worktree 裡的 `.codex/config.toml`。

`/add-dir` **不存在**（只有啟動旗標 `codex --add-dir`），所以中途補不回來。要兩邊
都可寫只能在啟動時就決定。

> `--add-dir` 在 `read-only` sandbox 下會被吃掉，只留一行 `Ignoring --add-dir (...)
> because the effective permissions do not allow additional writable roots.`

### Antigravity

**搬不了。** 官方 CLI reference 沒有任何 slash command 或旗標會改變 session 的
工作目錄；`/add-dir` 的定義是 "Add a directory path to the active workspace"，
實測下完之後 `pwd` 完全沒動，檔案落在原本的目錄。

唯一的做法是**啟動時就站在 worktree 裡**：

```bash
cd <worktree 絕對路徑> && agy --add-dir <worktree 絕對路徑>
```

`--add-dir` 是保險。[Google Cloud 社群有一篇](https://medium.com/google-cloud/antigravity-cli-tutorial-series-12b46cfe3bf2)
回報 agy 不把 process cwd 當 workspace，會把輸出寫到
`~/.gemini/antigravity-cli/scratch/`，而且 exit 0、模型回報成功、workspace diff
是空的 —— 無聲失敗。1.2.5 沒重現，但補上這個旗標的成本是零。

Antigravity 目前不由此 repo 納管，所以沒有對應的 skill 副本，這一節就是它的全部指示。

## Codex 在 herdr 裡碰不到 herdr

`dev-workflow` 原本想加一條「有 herdr 就自動搬」的例外，對 Codex 做不到：

```
$ echo "$HERDR_ENV / $HERDR_PANE_ID"
1 / wK:p56
$ herdr agent list
Error: Os { code: 1, kind: PermissionDenied, message: "Operation not permitted" }
```

環境變數全部正確設好，所以這是假綠燈：看起來可用，一條指令都下不了。

**根因是 Codex 把 unix socket 連線歸在網路那一類。** 不是檔案權限 —— socket 在
`~/.config/herdr/herdr.sock`，用 `codex --add-dir ~/.config/herdr` 把它放進可寫根
**沒有用**，一樣 PermissionDenied。放行的是這一個：

```bash
codex -c 'sandbox_workspace_write.network_access=true'
```

**刻意不開。** 這會給 Codex 全部的網路，不只是 herdr，而換到的只是省下「請使用者
貼一行 `/cd`」。開了之後 Codex 確實能自己搬自己，但那條路也是壞的：
`herdr agent prompt` 送過去的文字停在輸入框，要**再補一次 Enter** 才送得出去，而
agent 在自己的 turn 裡按不到那個 Enter。

另外，`herdr agent get` 回報的 cwd **追不到 Codex 的 `/cd`** —— 只有 TUI 狀態列
是新的。協調多條線時不要拿它當落點。

Claude Code 不需要這條例外 —— `EnterWorktree` 是原生工具，本來就不必繞 herdr。

## 代理：搬不了就派一個新 session 進去

agy 搬不了自己，但**驅動得了 herdr**（實測 `herdr agent list` 通，不用改任何權限）。
所以它可以不搬自己，改成開第二個 session 直接站在 worktree 裡，自己當協調者：

```bash
herdr pane split --current --direction right --cwd <worktree 絕對路徑> --no-focus
herdr agent start <name> --kind <kind> --pane <上一步回傳的 pane id>
```

新 session 的可寫根就是那個目錄。不用搬、不用改權限、不用人動手。

**這招救不了 Codex。** 它當不了協調者 —— 要開別人的 session 就得用 herdr，而 herdr
正是被擋的那個東西。

兩個實際成本，用之前先知道：

- **新 session 沒有你的上下文。** 任務要整包寫成訊息交過去，那是 `handoff` /
  `coordinate` 的工作，不是一行 prompt 打發得掉的。
- **協調者要自己顧授權對話框。** agy 停在 `Run this command?` 時，
  `herdr agent get` 回報的是 **`done`** —— herdr 認不出那個對話框。`agent wait`
  在 agy 身上會騙人，要改成輪詢 pane 內容才推得動。
