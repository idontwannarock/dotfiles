## Context

`grill` 的身體是 `home/.chezmoitemplates/skills/grill.md`,由 Claude 與 Codex 兩個 wrapper 共用(`$n` name-map 目前為空 dict,body 內無工具專屬 token)。現行結構三節:`## 規則`(訪談紀律)、`## Stop-gate`(單一 gate)、`## 產出去向`(結論分流)。

現行 body 有兩個結構性缺口:

1. **訪談只記錄「已答」**。`## 產出去向` 五條分流路徑全部預設問題有答案。訪談中冒出來但收斂不成精確問題的不確定性,沒有任何一條路徑接得住,於是在共識確認的那一刻靜靜蒸發。
2. **提問順序完全隱含**。「一次只問一題」規定了節奏,但沒規定**下一題選哪題**。當 A 的答案決定 B 該不該問時,這個依賴只存在於當下的對話脈絡;跨 session(handoff → pickup)必然丟失。

這次改動的來源是評估 Matt Pocock 的 wayfinder skill。該 skill 的核心是把大工程的**決策**做成帶 blocking edges 的圖並附一節 "Not yet specified"。整套引進需要 issue tracker 當正典,與本專案既有的 OpenSpec artifacts + `~/.agent/handoffs/` 兩個正典衝突,已判定不引進;但上述兩個觀念本身與載體無關,可直接落在 `grill` body。

## Goals / Non-Goals

**Goals:**

- 讓「已知的未知」在訪談結束時成為**顯性、待使用者裁決**的項目,而非默默消失。
- 讓未決問題之間的依賴成為**寫下來的**資訊,使提問順序可推導、跨 session 可還原。
- 改動限縮在共用 body 一個檔案,兩個 wrapper 零改動。

**Non-Goals:**

- 不引進 wayfinder skill 本身,不引進 issue tracker 當正典,不新增第三個正典載體。
- 不改動 stop-gate 語意——共識確認仍是唯一 gate,新增的「尚未釐清」節**不會**變成第二個 gate。
- 不做跨 session 的持久化機制。未釐清項與依賴標記寄生在既有載體(訪談對話 → design.md;跨 session 靠既有的 handoff)上,不另建檔案格式。
- 不改 `dev-workflow`。grill 在 Large workflow 的位置與前後銜接完全不動。

## Decisions

### D1: 「尚未釐清」歸屬 `## 產出去向`,不另開頂層節

未釐清項的本質是**訪談的一種產出**,與現有五條分流路徑同層;放進 `## 產出去向` 讓它跟著既有的分流心智模型走。

替代方案:開一個 `## 尚未釐清` 頂層節。否決——頂層節在這份 body 裡目前對應的是「階段」(規則 / gate / 產出),多一個同層節會讓它讀起來像一個獨立步驟,誘發 agent 把它當成額外 gate 來執行。

**Review 後修正**:第一版把整條規則都放進 `## 產出去向`,但該節的開頭是「共識確認後,結論直接分流」——**記錄**未釐清項是訪談進行中的義務,被這句話錯誤地推遲到 gate 之後,恰好讓它要保住的東西先蒸發。修正為拆成兩半:**記錄**的義務進 `## 規則`(與 D4 的 `blocked by` 同性質,都是訪談中的紀律),**去向與裁決**留在 `## 產出去向`。D1 的本意(不開頂層節)不受影響。

### D2: 未釐清項的去向是 design.md 的 `## Open Questions`,不是 `## Decisions`

OpenSpec 的 design.md 模板本來就有 `## Open Questions`(見本檔上游模板),語意完全吻合「outstanding decisions or unknowns」。沿用既有欄位,不發明新標記。

替代方案:比照長青候選,用 `<!-- unresolved -->` 之類的 HTML comment 標記塞進 `## Decisions`。否決——`## Decisions` 的語意是「已經決定的事」,把未決項混進去會污染 sync/archive 階段掃 `<!-- evergreen-candidate -->` 的那條路徑。

### D3: 未釐清項在共識確認時一併呈上,由使用者三選一

呈上時給三個處置:**接受風險往下走 / 現在再問 / 移出這次範圍**。這讓未釐清項變成一個顯性決策點,而不是一份無人負責的清單。

三個選項是刻意的完整集合:它涵蓋了「知道有洞但先走」「洞值得現在補」「洞不在這次的範圍」全部三種真實處置。少任何一個都會逼使用者在錯的選項裡挑。

替代方案:未釐清項非空就擋住共識確認。否決——這等於製造第二個 stop-gate,直接違反 body 現有的「這是本 skill 唯一的 gate」。而且「已知的未知」在真實專案裡永遠不會歸零,一個永遠擋著的 gate 就是一個大家學會繞過的 gate(同 `dev-workflow` 對 cross-model review 的判準)。

### D4: blocking 宣告放 `## 規則`,與「一次只問一題」相鄰

依賴宣告要解決的是**選題**問題,屬於訪談紀律,自然落在 `## 規則`。放在「一次只問一題」那條之後,因為它正是在補完那條沒講的另一半:一次一題,那麼是哪一題。

### D5: 依賴的表達法沿用 `blocked by`,與 tasks.md 同詞

`dev-workflow` 的 tasks.md 切片慣例已經用 `blocked by #N` 表達執行依賴。同一個詞在 grill 表達**決策**依賴,兩者處在流程的前後段但形狀相同,共用詞彙降低心智負擔。

替代方案:引進 wayfinder 的 `frontier` 一詞。否決——那是為了在 issue tracker 上做查詢而生的名詞,本專案沒有那個載體,引進只是多一個要學的字。用白話寫「優先問沒有被擋住的問題」即可。

## Risks / Trade-offs

- **[新增內容稀釋 body 的密度,agent 抓不到重點]** → 兩項各控制在 1-3 行,插入既有節內而非新增節;body 總長仍在一頁內。
- **[agent 把「尚未釐清」誤當成必填欄位,每次訪談都硬擠出幾條]** → 措辭寫成條件式(有才記、沒有就不提),與 `dev-workflow` team-doc 步驟「不值得寫就什麼都別說」同一套反噪音原則。
- **[未釐清項被當成 gate,擋住共識確認]** → D3 明確寫入「不構成 gate」;spec delta 亦以獨立 Scenario 把這點釘死,讓 `openspec-verify-change` 能查。
- **[本機 `~/.claude/skills/` 的 grill 比 repo 新或舊,apply 時互相覆蓋]** → 依既有紀律,`chezmoi apply` 只限縮到本次子樹(`~/.claude/skills/grill`、`~/.codex/skills/grill`),不全量 apply。

## Open Questions

(無)
