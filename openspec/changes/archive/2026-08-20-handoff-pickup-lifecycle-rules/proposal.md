## Why

一次完整的 `/pickup` → 裁決 → 交接 → 歸檔循環(2026-08-20,`mms_product_grouping_api`),外加緊接著的第二次 `/pickup`,共暴露 `handoff`／`pickup` 的五個缺口。**每一條都有當次的實際證據,不是推測**:

1. 被 pickup 的檔案沒有 `## Next steps`(手寫進 handoff 目錄、繞過 `handoff` §4 self-check 的 report-shaped 檔案)。`Apply` 第 2、4 步與整個 `Close out` 同時落空,當時是接手者自行決定拿哪一節頂替 —— 對的判斷,但 skill 既沒授權也沒禁止。全域掃描 61 份 live + archived handoff,**只有 1 份**是這個形狀:這條規則是便宜的保險,不是在補普遍破口。
2. `Close out` 的「列證據 → 問 → mv」中間少兩件事:**裁決沒搬進 memory 就跟著歸檔消失**;**耐久參考內容沒被活著的 artifact 用歸檔後路徑指名**。`Close out` 末段自己寫著「archived files drop out of every lookup」,但只寫了前半,沒寫出必然推論。
3. `handoff` 的 `Gather` 在 compose 前跑 git 指令,而 compose→write 之間隔了很多輪。當次撞到兩回:接手的報告寫著兩個 merge 之前的基準 commit;正在寫新 handoff 的同時,平行 session 歸檔了該草稿引用的檔案。**本變更實作期間又撞第三回** —— 平行 session 把前四項 commit 成 `dbf5aa4`,本 session 的 HEAD 快照當場過期。
4. 分鐘級 ID 在平行 session 下不唯一(當次出現兩份 `2026-08-20-0818__` 同前綴檔案)。不致命,但代表 slug 必須自身可辨識。
5. **跨 repo handoff 的 resume 行不帶目標 repo。** header 有 `- Target repo:`,底部要複製的 `/pickup <ID>` 沒有,於是它從**來源** repo 的 session 被發動。`pickup` 的 Resolve 規則本該「report the absolute paths searched and stop」,實際是靠人工全域 glob 才撈到。舊的跨 repo handoff resume 行已寫死,只修 `handoff` 端救不了它們,故兩端都修。

## What Changes

- `pickup` `Apply`:新增「檔案無 `## Next steps` 時」的處置 —— 不得靜默發明清單,**在第一則訊息指名頂替的段落**;無可指名者停下來問。缺 `## Suggested skills` 同理。
- `pickup` `Close out`:由 3 步變 4 步,`mv` 之前插入「搬出要活過 lookup 的東西」—— 裁決寫進 `~/.claude/memory/<repo-slug>/`,耐久參考由活著的 artifact 以 **post-archive 路徑**指名。
- `pickup` `Close out` 提問改為 **ask unless standing instruction**:常設指示(per-repo memory 或本次 session 說過的話)取代提問,**永不取代第 1 步的證據列舉**,且只覆蓋剛完成的那一份,不及於鄰居。
- `pickup` `Resolve`:三個位置皆未命中時,允許掃一次全部 slug 目錄;命中則**先告知這份屬於哪個 repo**再讀。
- `pickup` `Close out` 第 4 步:歸檔落點綁**解析來源目錄**(handoff 的目標 repo),不是 cwd 的 slug。
- `handoff` `Gather`:明示所取為快照,且要寫成快照措辭而非斷言。
- `handoff` §4 self-check 增第 4 項:寫檔前重跑 HEAD sha、handoff 目錄 `ls`、`git worktree list`,並與草稿對帳。
- `handoff` §2:註明分鐘級 ID 非唯一鍵,slug 須自身可辨識。
- `handoff` §2b:跨 repo 時 resume 行寫成 `cd <target> && claude "/pickup <ID> in <lang>"`,回報給使用者的那行同形。

無 BREAKING:既有的 slug 規則、必要段落、語言後綴、`archive/` 不被 glob 撿到、`finish-branch` 不耦合,全部不動。

## Capabilities

### New Capabilities

(無)

### Modified Capabilities

- `session-handoff`:`寫入端強制必要段落`(self-check 第 4 項)、`跨 repo 交接只接受明講的目標`(resume 行帶 `cd`)、`pickup 完成後提議封存`(pre-mv 兩檢查、standing-instruction 例外、歸檔落點綁解析來源);新增 `pickup 缺必要段落時的處置` 與 `pickup 解析的跨 repo 回退` 兩條 requirement。

## Impact

- `home/.chezmoitemplates/skills/handoff.md`、`home/.chezmoitemplates/skills/pickup.md`(唯二的原始碼改動)
- 下游共用者:`home/dot_claude/commands/{handoff,pickup}.md.tmpl`、`home/dot_codex/skills/{handoff,pickup}/SKILL.md.tmpl`(僅 render 結果改變,檔案本身不動)
- `openspec/specs/session-handoff/spec.md`(archive 時同步)
- 不影響 `handoff-list`、`arch-review`(兩者只消費既有契約,本次無形狀變動)
