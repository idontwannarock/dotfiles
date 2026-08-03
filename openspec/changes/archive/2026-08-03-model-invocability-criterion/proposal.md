## Why

15 個 Claude command 帶 `disable-model-invocation: true`,模型無法自行呼叫;其中 12 個在 Codex 端有同名能力,而 Codex 沒有 command 概念,同一份 body 包成 skill,模型本來就能自行呼叫。同一個能力在兩個工具上可呼叫性不同,這與 `context/glossary.md` 的 **cross-tool parity** 約定衝突。此事 2026-07-30 提出,至今未決策。

更根本的問題是**判準本身錯了**。`context/principles.md` 現行寫的是「成本高或有副作用的操作不該由模型在使用者沒開口時自行啟動」,但「有副作用」無法區分真正需要把關的事:

- `git commit` 有副作用,但只要 `.git` 還在就能靠 reflog 回復
- `worklog-daily` 寫的 GitHub Issue comment 別人立刻看得到,刪掉也已經被看過

兩者按現行判準同級,實際風險差一個量級。這也讓現況自相矛盾:`git/clean-gone` 會刪除本地分支,卻是唯一沒有 flag 的 command。

還有一個削弱鎖住效果的旁證:模型即使不能觸發 command,仍可讀 `~/.claude/commands/handoff.md` 的規格自行產出等效檔案(2026-07-30 實際發生過一次,產物符合 pickup 契約)。flag 阻止的是「自動啟動」,不是「有能力做」。

## What Changes

- **判準從「有無副作用」改為「可逆性與外部可見性」。** 只有**不可逆或外部可見**的操作才鎖住;本地且可回復的操作放行。改寫 `context/principles.md` 中「能力的部署形狀由觸發模式決定」那一條——這是取代,不是補充,因為被推翻的正是它的判準。
- **13 個 Claude command 移除 `disable-model-invocation: true`**:`handoff`、`pickup`、`handoff-list`、`arch-review`、`git/commit`、`git/sync`、`code/review-{surgical,comprehensive,linus,uncommitted,security,spec,types}`。
- **2 個維持鎖住**:`worklog-daily`(寫 GitHub Issue comment)、`worklog-team-status`(觸發 GitHub Actions workflow)。兩者皆為遠端寫入。
- **Codex 端不動。** 解鎖後兩邊行為自然一致,parity 破洞消失,不需要在 Codex description 補軟約束,也不需要把不對稱記成已知偏離。
- **留下明文拒絕反向改動的 Scenario。** 否則下一個看到 review 類 command 可被模型呼叫的人會好心把 flag 加回去。
- 順帶修正 `home/.chezmoitemplates/skills/git-commit.md` 寫死的 `Co-Authored-By: Claude Opus 4.6` trailer,改為不綁型號。

## Capabilities

### New Capabilities
- `model-invocability`: 決定一個能力該不該讓模型自行啟動的判準,以及它在 Claude command / Codex skill 兩種部署形狀上的具體落點。涵蓋全部 16 個 Claude command 的分類結果與反向改動的禁止。

### Modified Capabilities
- `arch-review`: 「跨工具部署與手動觸發」這條 requirement 明文要求 `disable-model-invocation: true`,且有一個 Scenario 斷言「Claude SHALL NOT 自行啟動架構體檢」。新判準下 `arch-review` 屬於可逆、非外部可見(只寫 `~/.agent/handoffs/` 下的報告),應解鎖。

## Impact

**wrapper(移除 flag)**
- `home/dot_claude/commands/{handoff,pickup,handoff-list,arch-review}.md.tmpl`
- `home/dot_claude/commands/git/{commit,sync}.md.tmpl`
- `home/dot_claude/commands/code/review-{surgical,comprehensive,linus,uncommitted}.md.tmpl`
- `home/dot_claude/commands/code/review-{security,spec,types}.md`(非 `.tmpl`,純檔案)

**wrapper(維持不動)**
- `home/dot_claude/commands/worklog-{daily,team-status}.md.tmpl`
- `home/dot_claude/commands/git/clean-gone.md`(現況已無 flag,新判準下正確)

**shared body**
- `home/.chezmoitemplates/skills/git-commit.md` — trailer 去型號

**長青文件**
- `context/principles.md` — 改寫「能力的部署形狀由觸發模式決定」

**不受影響**
- 所有 Codex `SKILL.md.tmpl` — 一行不改
- `session-handoff` spec — 它斷言 Claude 端為 command、Codex 端為 skill,未斷言 flag;解鎖後仍是 command
