## Why

herdr 的 agent 名稱是**整台機器一個扁平命名空間**,且「在活著的 agent 之間必須唯一」
(`~/.claude/skills/herdr/SKILL.md:56`)。但 `coordinate` 把協調者位址寫成固定字串
`coordinator`(body `:35`、`:796`、`:955`),`dev-workflow` 的線側契約也寫死
`herdr agent prompt coordinator "..."`(body `:193`)。**一個固定字串在全機唯一的命名空間裡,
等於宣告全台機器只能有一支艦隊。**

實際後果已經發生:不同 repo 的被協調者把回報投給了錯的協調者。這個缺陷的形狀是
**靜默投遞到一個真實但錯誤的收件人**——因為唯一性約束保證 `coordinator` 一定解得開,
只是解到先搶到名字的那一支,兩端都不會報錯。第二種發生方式對稱:先搶到的那支退場、
名字被釋放,後來者接走,**原本那批線的回報從此全部投到新主人**(名字跟著 pane 佔用者走)。

量到的現場證據(`herdr agent list`):`coordinator` 在 `…/mms_product_grouping_api`,
而 `…/mms_chat_api` 那支已經被人手動改名成 `chat-api-coordinator` 才避得開——
**那是症狀,不是設計**。

## What Changes

- **艦隊前綴**:協調者與線一律為 `<fleet>-coordinator` 與 `<fleet>-<change>`。
  前綴在**開艦隊時選定**,不由 repo 全名推導——名稱受 `[a-z][a-z0-9_-]{0,31}` 限制,
  `mms_product_grouping_api-coordinator` 是 36 字元,塞不進去。前綴是**裁決**,
  寫進 handoff 的〈本輪產生的裁決〉讓接班協調者繼承。
- **前綴與 cwd 兩道正交檢查**:前綴分「哪一支艦隊」(同 repo 內也分得出),
  `cwd` 分「哪一個 repo」。cwd 驗證擺在投遞前與收報時兩端。
- **線側位址改為由派線訊息帶來**:線不讀協調者的 handoff,位址與升級契約走同一則派線訊息。
  訊息裡沒給位址就是派線壞了,線 SHALL NOT 自行猜 `coordinator`。
- **新增艦隊名冊 `fleet.md`**:記 session 被換掉時**不會變**的東西(名字、kind、cwd、
  開線旗標與角色、這條線是幹嘛的),不記 status 與進度。
  **`herdr agent` 沒有 history 子命令**,已死的 session 與從未存在的完全無法區分——
  名冊與 herdr 的**差集**就是「漏掉的／被關掉的線」偵測器,並提供原地重開所需的最小集合。
- **艦隊產物集中落點** `~/.agent/fleets/<repo-slug>/<fleet>/`:`fleet.md` 與 `map.md` 同層。
  map 從協調者的 handoff 搬出來——它跨越所有線,不屬於任何一個 session。
- **資源池不變量取代「一個 repo 一支艦隊」**:一支艦隊必須完整擁有它所仲裁的稀缺資源池;
  兩支艦隊 SHALL NOT 共用同一個池。base branch 不同是合法例外,但要逐項判。
- **修掉一個既有斷點**:開頭對齊表寫「wayfinder map issue → handoff」,而 `:150` 另有一個 `map`——
  同一份文件裡「map」有兩個意思。實情是多線把 wayfinder 的單一物件裂成兩個載體。

## Capabilities

### New Capabilities

(無)

### Modified Capabilities

- `discipline-skills`: `coordinate` 的定址規則從固定名改為艦隊限定名;新增前綴／cwd 兩道正交檢查、
  艦隊名冊與其落點、資源池不變量、map 的層級與對齊表修正。
- `workflow-instructions`: `dev-workflow` 線側契約的〈以名字定址協調者〉場景,
  位址來源從寫死的 `coordinator` 改為派線訊息所給,並補上投遞前的 cwd 驗證。

## Impact

- `home/.chezmoitemplates/skills/coordinate.md` — 對齊表、§定址、〈map〉、收尾清單、
  〈與 dev-workflow 的關係〉、附錄 B
- `home/.chezmoitemplates/skills/dev-workflow.md` — coordinated mode 線側契約
- 兩支 skill 的 Claude/Codex wrapper 共讀同一份 body,無須各自改動
- **新增機器層目錄** `~/.agent/fleets/<repo-slug>/<fleet>/`(不進版控,由 skill 規範其形狀)
- 明列為 Non-Goals 的後續兩輪:**自動交接**、**多層載體導航索引**(後者有命名前置條件,見 design D9)
