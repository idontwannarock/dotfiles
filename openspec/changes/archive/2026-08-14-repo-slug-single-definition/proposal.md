## Why

前一個 change（`60ad1c2`）把 `Repo` 欄釘到 `principles.md` 的單一 repo 身分定義，並明寫「此處 SHALL NOT 複述該定義」——然後在同一份 spec 的兩處複述了它，而且複述的版本是錯的。

正典定義是 `slug(dirname(realpath(git-common-dir)))`。兩處都只寫「由 `git rev-parse --git-common-dir` slugify 而得」，漏掉 `dirname` 與 `realpath`。照字面執行會得到 `-home-howardwang-ws-github-dotfiles-.git`（bare+worktree 下是 `…-.bare`），與實際使用的 key 不同——正是該 change 新增的 scenario 宣告為缺陷的分裂目錄。

同一個缺陷也在共用 body 的兩處。前一個 change 的 proposal 聲稱「body 本來就是對的」，那句話就欄名而言成立，就 slug 推導而言不成立，而 body 才是實際被執行的那份。

## What Changes

- `workflow-concurrency` 的兩處 slug 推導改為單向指路，不再各自複述。
- 共用 body 兩處的 slug 推導同樣改為指向正典定義。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `workflow-concurrency`: 移除 `Workflow Registry` 與 `Active Workflows Index` 兩則 requirement 中的 slug 推導複本。

## Impact

- `openspec/specs/workflow-concurrency/spec.md`
- `home/.chezmoitemplates/skills/dev-workflow.md`（ARCH dispatch table 與 2b）
- 本機 `~/.agent/` 資料已在前一個 change 收斂為正典形式，不需再遷移。
