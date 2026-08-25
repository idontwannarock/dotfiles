## Why

跨模型對抗覆核(counterpart:`codex`,不同 kind、獨立蒐證、只拿到 branch 名)找出九項缺陷。它們的共同形狀是**上一輪修得不完整或修錯理由**,而**五個同家族 lens 全部漏掉其中三項**——那三項需要的是不同的先驗,不是更多同一種眼睛。

三項特別重:

1. **上一輪把危險字元集的「括號」從協調者那份移除了,卻沒改線那份。** `dev-workflow.md` 仍寫 `or parentheses`——而**線只載入那一份**。壞掉的規則正好留在唯一會執行它的那一端,於是那次修正在實際生效的位置上等於沒發生。
2. **`<repo-slug>` 是過度宣稱。** `~/.agent/reference/repo-identity.md` 明文寫著 slugify 兩派不一致,且「a new mechanism **SHOULD NOT assume the two produce the same key**」。而本 skill 寫的正是「與 handoff、workflow 狀態同一個 key」。路徑含點的 repo 會讓兩個協調者導出**不同的 `<fleet>` 目錄**,於是交接看起來像「沒有名冊也沒有訊息」,而兩者其實都寫成功了,只是在別的 key 底下。
3. **一句技術事實寫錯了。** 上一輪說 `"$(cat file)"` 會讓內容「照樣經過 shell」。command substitution 的**輸出不會被再次展開**,所以那句是假的。該條的**結論仍然成立**(內容整段進對方 context、檔案沒有落點與生命週期、與載體規則矛盾),但支撐它的三個理由裡有一個是假的——**而假理由會在下一輪被人拿去推廣**。

## What Changes

**線側契約與協調者側對齊(線只載入前者)**

- `dev-workflow.md` 的觸發字元集**移除 parentheses**,與機制表對齊
- `dev-workflow.md` 補上 **create-only 機制**(存在即中止),不再只給散文
- 線的**接班人也要讀 `msgs/`**:接手清單目前寫「其餘只有協調者做」,而裁決是寫給線的

**過度宣稱改為誠實**

- **`<repo-slug>` 明確選派**:跟 handoff 家族(`:` `\` `/` `.` 四個字元都換 `-`),理由是 `msgs/` 的搬移目的地正是 handoff 的 `attachments/`——不同派會讓兩者互相找不到。同時**移除「與 workflow 狀態同一個 key」**這個 `repo-identity.md` 明文禁止的假設
- **`"$(cat file)"` 那條的理由改正**:刪掉「照樣經過 shell」,留下三個真的理由
- **路徑安全的宣稱縮回**:只約束 `<topic>` 不等於整條路徑安全;`<ts>` 要定格式,`<repo-slug>` 的字元由所選派別的轉換保證

**覆蓋缺口**

- 寫檔成功、通知失敗的 **orphan 要有復原路徑**——定序解決了先後,沒解決殘留態
- 拆艦隊 gate 的**引導句與表格自相矛盾**:引導句說「不屬於任何單線」,表格卻含「死掉的線留下的」,那**屬於**某條線
- 第二格要有**發現路徑**:檔案落在無索引目錄、收件人往往還沒開工、沒有人負責日後轉交

## Capabilities

### New Capabilities

(無)

### Modified Capabilities

- `discipline-skills`:〈coordinate 線間訊息的載體〉補線側對齊、路徑元件約束、orphan 復原與第二格發現路徑;〈coordinate 艦隊產物的落點〉改為明確選派並移除同 key 假設;〈coordinate 傳訊管道分兩層〉修正 `"$(cat file)"` 的理由。

## Impact

- `home/.chezmoitemplates/skills/coordinate.md`、`home/.chezmoitemplates/skills/dev-workflow.md`
- `openspec/specs/discipline-skills/spec.md`
- 不影響:三格判準、一則一檔、不設回執、5 行/500 字元這四個決策
