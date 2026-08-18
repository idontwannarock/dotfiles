## Why

`grill` 目前只有兩種狀態:問題已問完(共識達成)、或還在問。它沒有地方承接兩件實際會發生的事——**「我知道還有東西沒釐清,但現在還問不出精確的問題」**,以及**「這題要等那題有答案才問得下去」**。前者在訪談結束時靜靜消失,變成 spec 漏項;後者只靠對話順序記在腦子裡,一旦跨 session(handoff/pickup)就丟失。

評估 Matt Pocock 的 wayfinder skill 時確認:它真正比本專案現有機制多出來的,就是這兩樣(fog of war + 問題層級的 blocking edges)。整套引進會多出第三個「正典」與 issue tracker 相依,不划算;但這兩個觀念本身成本極低,直接補進 `grill` 即可拿到八成價值。

## What Changes

- `grill` 的產出分流新增一節「尚未釐清」:訪談過程中浮現、但還無法收斂成精確問題的不確定性,SHALL 明確記錄而非丟棄,並在共識確認時一併呈給使用者裁決(接受風險 / 繼續問 / 移出範圍)。
- `grill` 的追問紀律新增未決問題的依賴宣告:當一題的答案取決於另一題時,SHALL 標記 blocked by,並優先問沒有被擋住的問題。
- 兩項皆寫入共用 body `home/.chezmoitemplates/skills/grill.md`,Claude 與 Codex wrapper 自動共享,無需改動任一 wrapper。

無 BREAKING:既有的單一 stop-gate、產出分流、context grounding、evergreen-candidate 紀律全部不動。

## Capabilities

### New Capabilities

(無)

### Modified Capabilities

- `discipline-skills`: `grill 訪談紀律` requirement 增補兩條行為——未釐清項的記錄與裁決、未決問題的 blocking 宣告與提問順序。

## Impact

- `home/.chezmoitemplates/skills/grill.md`(唯一的原始碼改動)
- 下游共用者:`home/dot_claude/skills/grill/SKILL.md.tmpl`、`home/dot_codex/skills/grill/SKILL.md.tmpl`(僅 render 結果改變,檔案本身不動)
- `openspec/specs/discipline-skills/spec.md`(archive 時同步)
- 不影響 `dev-workflow`、`tdd`、`context/` 晉升流程
