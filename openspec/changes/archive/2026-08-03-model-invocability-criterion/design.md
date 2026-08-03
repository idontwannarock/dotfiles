## Context

Claude command 支援 `disable-model-invocation: true`,標了模型就無法把它當工具呼叫,只有使用者打 `/name` 才會觸發。Codex 沒有 command 的概念,同一份 shared body 在那邊包成 skill,而 skill 就是給模型自行判斷時機用的——這個 repo 的 Codex frontmatter 從頭到尾只用過 `name:` 與 `description:`,沒有任何 gate 欄位可用。

所以「兩邊都鎖住」不是一個可達成的狀態。可達成的只有三種:Claude 也開放(真正對稱)、Codex 補一句軟性的 description 提示(不對稱縮小但不消失)、或承認不對稱並記錄下來。

現行判準寫在 `context/principles.md` 的「跨平台與跨工具部署」組:純手動觸發的能力走 command + flag,理由是「成本高或有副作用的操作不該由模型在使用者沒開口時自行啟動」。

## Goals / Non-Goals

**Goals:**

- 用一條能真正區分風險的判準取代「有無副作用」。
- 消除 12 個能力的 cross-tool parity 破洞。
- 讓判準涵蓋全部 16 個 Claude command,不只有 parity 破洞的那 12 個。
- 留下明文拒絕反向改動的依據。

**Non-Goals:**

- **不改任何 Codex wrapper。** 解鎖後兩邊自然一致,不需要軟約束。
- **不改 `git/clean-gone`。** 它現況無 flag,新判準下是對的。
- **不重新設計 command / skill 的部署形狀。** Claude 端仍是 command,只是拿掉 flag;`session-handoff` 與 `discipline-skills` 對部署形狀的斷言不受影響。
- **不處理系統提示層級的行為約束。** 「Commit or push only when the user asks」是另一層機制,與 flag 獨立。

## Decisions

### D1. 判準改為「不可逆或外部可見」

`disable-model-invocation: true` 只用於**做錯了救不回來,或外面已經看到**的能力。其餘一律開放。

現行判準「有副作用」把兩件風險差一個量級的事歸為同級:

| 能力 | 副作用 | 可逆? | 外部可見? |
|---|---|---|---|
| `git/commit` | 改 git 歷史 | 是(reflog) | 否 |
| `git/sync` | fetch + rebase | 是(reflog) | 否(fetch 是讀) |
| `handoff` | 寫 `~/.agent/` 下的檔 | 是(檔案還在) | 否 |
| `arch-review` | 寫報告檔 | 是 | 否 |
| `code/review-*` | 派 subagent、燒 token | n/a | 否 |
| `worklog-daily` | 寫 GitHub Issue comment | **否** | **是** |
| `worklog-team-status` | 觸發 GitHub Actions | **否** | **是** |

「有副作用」這個判準對前五列與後兩列給出相同答案,但只有後兩列真的需要人在迴圈裡。判準失去鑑別力,就會出現現況這種矛盾:`git/clean-gone` 會刪本地分支卻沒鎖,而唯讀的 `code/review-types` 鎖著。

`.git` 還在,commit 與 rebase 都救得回來。Issue comment 刪掉也已經被人看過,workflow 跑了就是跑了。

<!-- evergreen-candidate -->
**可逆性而非副作用決定 gate 的位置。** 判斷一個能力該不該讓模型自行啟動,問「做錯了救不救得回來、外面看不看得到」,不是問「它有沒有寫東西」。本地檔案與 git 物件可救;遠端寫入與外部通知不可救。用「有副作用」當判準會把兩者歸為同級,而它們的風險差一個量級——判準一旦失去鑑別力,實際分類就會靠直覺,於是同類能力散落在閘門兩側。

### D2. 解鎖 Claude,而非在 Codex 補限制

三個方向裡,只有解鎖能真正消除不對稱。Codex 端補 description 提示永遠只是軟約束——description 是寫給模型看的提示,不是關卡,所以它不是「另一個選項」,而是「承認偏離」之上的 best-effort 減災。

選解鎖的實質理由有三個:

1. **flag 擋的是自動啟動,不是能力。** 2026-07-30 模型讀了 `~/.claude/commands/handoff.md` 的規格,自行產出一份符合 pickup 契約的檔案。門鎖著,牆是紙的——鎖住換來的是「模型繞路自己實作一份沒有護欄的版本」,比讓它用正版更糟。
2. **真正該擋的行為另有把關。** 系統提示已有「Commit or push only when the user asks」。flag 與它是兩層獨立機制:flag 管「這個 command 能不能被當工具呼叫」,基線管「主動 commit 這個行為該不該發生」。解鎖 flag 不會讓模型開始主動 commit。
3. **`git-commit` 值得被模型用到。** 它的價值不在 commit 本身,而在敏感檔阻擋清單(`.env`、`.env.*`、`credentials.*`、`*.pem`、`*.key`、`secrets.*`、junk 檔)與禁止 `git add -A` / `git add .`。這是**在模型本來就會 commit 的前提下加的護欄**,鎖住它等於讓模型只能用沒護欄的預設路徑。對一個公開 repo 而言,這個取捨方向是反的。

### D3. 判準套用到全部 16 支,不只有 parity 破洞的 12 支

`code/review-{security,spec,types}` 在 Codex 沒有對應能力,所以不構成 parity 破洞。但它們是唯讀 review,按 D1 的判準同樣該解鎖。

只處理有破洞的 12 支會留下三支無理由鎖著的唯讀 review,而這正是 `context/principles.md` 已記載的破口形態:「修掉一個這類斷言時,要把同份 spec 全掃一遍——同類實例不會因為只有一個被指出就只有一個存在」。判準是能力屬性,不是 parity 屬性;套用範圍要跟著判準走。

### D4. 明文拒絕反向改動

解鎖後,下一個看到「模型可以自己跑 code review / 寫 handoff」的人,合理反應是把 flag 加回去。所以要在 spec 留一條 Scenario 明確拒絕,並寫出理由,而不只是描述現狀。

參考 2026-08-03 在 `discipline-skills` 為兩處 `git branch -D` 把關不對稱所做的處理:把「為什麼這兩處看起來一樣卻不該一致」寫成 Scenario,而非留給後人重新推導。

### D5. commit trailer 去型號

`home/.chezmoitemplates/skills/git-commit.md` 的 HEREDOC 範例寫死 `Co-Authored-By: Claude Opus 4.6`,已與現行模型不符。改成指示「用當前 model 的名稱」,避免每次換代都要回來改這一行——這與 `context/principles.md`「規範要寫成可機械套用的規則,不是個案判斷」同源:把具體值凍進文件,就是把當下狀態誤當成需求。

## Risks / Trade-offs

- **[模型可能在使用者沒開口時跑 `arch-review` 或 `code/review-*`,燒掉可觀 token]** → 這兩者屬可逆且非外部可見,符合判準。真正的浪費防線是 `context/principles.md` 已有的「被學會忽略的 gate 比沒有 gate 更糟……關卡的頻率由訊號密度決定」,以及各 skill body 自身的觸發條件描述,而非 flag。
- **[解鎖 `git/commit` 後模型自行 commit]** → 由系統提示的基線約束把關(D2-2),與 flag 無關。若日後觀察到實際發生,該修的是基線或 skill description,不是回頭加 flag——那會讓模型退回沒護欄的預設路徑(D2-3)。
- **[判準本身可能被誤用成「只要可逆就都開放」]** → 判準有兩個條件且為 OR:不可逆**或**外部可見。可逆但外部可見的操作(例如發 Slack 訊息後撤回)仍應鎖住。Scenario 要涵蓋這格。
- **[`worklog-*` 兩支維持鎖住,Codex 端仍可自呼叫,破洞未完全消除]** → 這兩支的破洞確實留著。與其在 Codex 補無效的軟約束,不如誠實記錄:判準說明為何它們鎖住,Codex 的限制是平台能力問題而非本 repo 的決策失誤。

## Migration Plan

1. 改 13 個 wrapper 移除 flag(其中 3 支是非 `.tmpl` 的純檔案)。
2. 改 `git-commit.md` 的 trailer。
3. 改寫 `context/principles.md` 的判準條目。
4. `arch-review` spec 的 delta:移除 flag 斷言與對應 Scenario。
5. 點名 target 執行 `chezmoi apply`,確認 13 個目標檔的 frontmatter 已無該欄位、2 個 worklog 仍有。

回滾:全部走 git,單一 commit 可 revert。

## Open Questions

無。判準、範圍、例外清單皆已於 grill 階段由使用者確認。
