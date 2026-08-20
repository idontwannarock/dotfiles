## Context

`handoff`／`pickup` 的契約原本只寫在讀取端能看見的地方:寫入端保證兩個必要段落、讀取端照著跑。五個缺口全部落在「保證不成立時怎麼辦」與「檔案離開目錄之後怎麼辦」這兩塊,證據來自 2026-08-20 的兩次連續 pickup 循環。

## Decisions

### D1. `Close out` 採「ask unless standing instruction」

不是「一律問」,也不是「一律不問」。使用者已在 `mms_product_grouping_api` 留下 per-repo memory `archive-handoff-without-asking`,與 skill 的「Ask whether to archive」正面衝突;讓 memory 悄悄覆蓋 skill 會讓兩份正典互相矛盾且都看不出對方存在。

常設指示取代的是**提問那一步**,不是第 1 步的證據列舉 —— 免除的是打擾,不是舉證責任。且常設指示只覆蓋剛完成的那一份 handoff,不及於同目錄鄰居:2026-08-03 誤刪五份的事故正是從「順手處理鄰居」開始的。

### D2. 第五個缺口兩端都修

只修 `handoff` 端(resume 行帶 `cd`)救不了任何既有檔案 —— 它們的 resume 行已經寫死在磁碟上,而 `~/.agent/handoffs/` 不在版控裡,沒有批次改寫的安全方式。所以 `pickup` 端也要能救:三個位置皆未命中時掃一次全部 slug 目錄。

這個回退**刻意放在最後且刻意吵**。它比前三個位置寬鬆得多,靜默命中會讓「我在哪個 repo 工作」這件事變得不可見;所以命中時必須先講出這份屬於哪個 repo,讓使用者有機會否決。

### D3. 歸檔落點綁解析來源,不綁 cwd

D2 的回退一旦命中,cwd 的 slug 與檔案所屬 repo 的 slug 就不一致。`mv` 到 cwd 的 `archive/` 會讓檔案從唯一有人會找的目錄消失 —— 比不歸檔更糟。落點一律取**解析到它的那個目錄**。

### D4. 「歸檔不等於丟棄,前提是有人指得回去」

`Close out` 末段早就寫了「archived files drop out of every lookup」,但只寫了前半。必然推論是:凡是還需要被找到的東西,必須在 `mv` 之前搬到 lookup 撿得到的地方。裁決 → memory(永久、有索引);耐久參考 → 留在檔案裡,但由活著的 artifact 用**歸檔後**的絕對路徑指名。用當前路徑寫的引用,會在建立它的同一步壞掉。

<!-- evergreen-candidate -->
三分流:**裁決 → memory(永久、有索引)／待辦 → handoff(做完即歸檔)／盤點與參考 → 歸檔檔案本身,但被前兩者用絕對路徑指名**。這是 agent 產物落點的通則,不限於 handoff 家族。

### D5. 快照事實要寫成快照

self-check 第 4 項要求重跑 volatile gather,但重跑只縮短窗口,消不掉它 —— 寫檔到接手之間還有更長的空白。所以措辭同樣是規範的一部分:「寫這份時 HEAD 是 X,開工前重驗」與「HEAD 是 X」對接手者的成本差很多,後者讓人分不出過期事實與現行事實。

### D6. 分鐘級 ID 不改格式

`YYYY-MM-DD-HHMM__<slug>` 在平行 session 下會撞前綴,已實際發生兩次。判定**不值得改格式**:完整 ID 一定唯一解析,date-prefix 查詢本來就會要求使用者選。真正的結論是 slug 必須自身可辨識,所以寫成一句對 slug 的要求,而不是換 ID 格式。

## Open Questions

(無)
