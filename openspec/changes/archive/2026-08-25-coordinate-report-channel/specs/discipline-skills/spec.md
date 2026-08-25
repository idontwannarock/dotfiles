## ADDED Requirements

### Requirement: coordinate 線間訊息的載體
`coordinate` SHALL 規定線與線之間(含協調者與線雙向)的每一則往來要選一個載體,判準 SHALL 以「這則內容要在對方的**哪個時刻**生效」為軸,SHALL NOT 改以「是資料還是指令」為軸。判準 SHALL 有**三格**,SHALL NOT 只有二選一。

#### Scenario: 三格,而第三格是兩者皆是
- **WHEN** skill 呈現載體判準
- **THEN** SHALL 以清單或表格列出三格:「只是現在要對方知道」→ 訊息;「要在對方未來某個時刻生效」→ 檔案,訊息只說有一份東西在那裡;「**現在要知道,且未來要能重讀**」→ **檔案 ＋ 帶摘要的 prompt,兩個都要**
- **AND** SHALL 寫明第三格**不是二選一**,SHALL NOT 讓讀者以為寫了檔就不必通知
- **AND** 跨線事實 SHALL 明文歸入第三格,理由 SHALL 是「它現在就要對方知道,但它是資料且未來要能重讀」

#### Scenario: 立論不得以省 context 為主
- **WHEN** skill 說明為什麼要走檔案
- **THEN** SHALL 以「可重讀」「吃字整族消失」「留下事情確實發生過的證據」三者立論
- **AND** SHALL 寫明省 context 這個動機**經不起推敲**——對方仍要把檔案讀進 context,真正省到的只有選擇性讀／晚點讀／根本不用讀三種情況
- **AND** SHALL NOT 把省 context 放在承重位置,因為下游會拿弱理由把規則推廣到錯的地方

#### Scenario: 一條升級規則,兩個觸發條件
- **WHEN** 一則內容依判準落在「只是現在要對方知道」那一格
- **THEN** 若它含反引號、`$`、`!`、括號**任一**,或超過 **5 行或 500 字元**,SHALL 自動升為第三格
- **AND** 該規則 SHALL 寫成**一條規則兩個觸發條件**,SHALL NOT 拆成兩條——兩者處置相同,拆開即為〈複寫了別處的事實〉
- **AND** SHALL 寫明為何是雙上限:只設行數會漏掉「一行三千字」,而那正是本規則要防的情況
- **AND** SHALL 寫明門檻不得放大到超過第三格通知本身的長度,否則通知會自己觸發升級

#### Scenario: 守衛不是告誡
- **WHEN** skill 說明為什麼吃字這一族要用機械判準
- **THEN** SHALL 指出告誡在這一族已有實測敗績——協調者曾在撰寫「怎麼避免被吃字」那則廣播時自己被吃
- **AND** SHALL 寫明升級方向與判準自洽:含高密度技術符號或長度超標者,正是事後最需要重讀的那種

#### Scenario: 一則一檔,動作是建檔
- **WHEN** 內容要落成檔案
- **THEN** SHALL 規定一則一檔、檔名唯一,動作 SHALL 是**建檔**,SHALL NOT 是對既有檔案覆寫或 append
- **AND** SHALL 寫明理由是讓〈整份覆寫之前先讀〉那一族的失敗在**結構上不存在**,而非靠規則擋住
- **AND** SHALL 寫明收訊方因此沒有「讀到哪了」這個無處可記的狀態

#### Scenario: 不設回執
- **WHEN** 協調者要確認一則訊息被接住了
- **THEN** SHALL 去查對方的產物(差分、檔案存在與否、收尾訊號),SHALL NOT 建立回執機制
- **AND** 理由 SHALL 引既有兩條:回執是「一個永遠有答案的讀取」,且是自述不是量測
- **AND** 裁決類訊息 SHALL 要求對方在**下一則本來就要發的**回報裡引用該訊息檔名——搭在既有訊息上故不遞迴,其價值 SHALL 寫明為「引用錯會露出來」而非「知道他讀了」
- **AND** SHALL 寫明買單項:協調者分不出「對方根本沒開那個檔」與「開了但判斷不需行動」

#### Scenario: 線側義務要送達得到線
- **WHEN** 本協定課給線任何義務
- **THEN** 該義務 SHALL 進派線訊息的酬載,並 SHALL 同步寫進 `dev-workflow` 的線側契約
- **AND** 理由 SHALL 是「沒有任何機制會讓實作線載入本 skill」,SHALL NOT 寫成建議事項

## MODIFIED Requirements

### Requirement: coordinate 艦隊產物的落點
`coordinate` SHALL 規定艦隊產物(名冊、map 與**線間訊息**)落在 `~/.agent/fleets/<repo-slug>/<fleet>/`,SHALL NOT 與 `active_workflows.md` 混放於同一目錄。`<repo-slug>` SHALL 採用既有的正典 repo slug 定義,SHALL NOT 另立一套。線間訊息 SHALL 落在該目錄下的 `msgs/` 子目錄。

#### Scenario: 目錄邊界跟著生命週期
- **WHEN** skill 說明為什麼不放在 workflow 那棵樹底下
- **THEN** SHALL 寫明兩者生命週期不同:`active_workflows.md` 跨所有艦隊且沒有艦隊時照樣存在,而名冊、map 與線間訊息與艦隊同生同滅
- **AND** SHALL 寫明混放會使拆艦隊變成「刪二留一」,分開之後拆艦隊就是刪一個目錄

#### Scenario: 目錄名可重用,開艦隊時要處置
- **WHEN** 開一支艦隊而該 `<fleet>` 目錄已經存在
- **THEN** SHALL 停下來要求裁決(接續這支艦隊,或確認是殘留後清空),SHALL NOT 直接沿用
- **AND** skill SHALL 寫明成因:前綴只在**活著的 agent 之間**唯一而非跨時間唯一,整支艦隊異常關閉時目錄不會被刪

#### Scenario: map 站在 workflow 之上
- **WHEN** 有人提議把 map 收進 workflow 目錄
- **THEN** SHALL 指出 map 明文要求「一條線自己的狀態指回 `active_workflows.md`」,它跨越多個 workflow,收進去是降一層且會使目錄名說謊

#### Scenario: 線間訊息不落在 attachments
- **WHEN** 有人提議把線間訊息落在 `~/.agent/handoffs/<repo-slug>/attachments/`
- **THEN** SHALL 指出該目錄綁 repo 不綁艦隊、**沒有淘汰機制**,而線間訊息的量級遠大於協調者交付物
- **AND** SHALL 寫明淹沒本身會讓「可重讀」變成「找不到」,即該落點會消滅本協定要買的那樣東西

#### Scenario: 該活過艦隊的要在收線時搬出去
- **WHEN** 一條線收線,或整支艦隊要拆
- **THEN** SHALL 把要活過艦隊的內容搬到既有的長命載體(handoff、memory 或 `attachments/`),該項 SHALL 掛在收尾清單上
- **AND** SHALL 寫明漏搬的失敗是**靜默**的:目錄被刪之後沒有人會知道少了什麼
- **AND** SHALL 寫明引用該內容時要用它**搬移後**的路徑,與 handoff 歸檔同一條規則

### Requirement: coordinate 傳訊管道分兩層
`coordinate` SHALL 把跨 agent 傳訊寫成兩層:結構上免疫於吃字與 append 的管道,與仍然適用全部吃字機制的退路。退路那一節 SHALL NOT 被刪除。**縮小該節的適用範圍 SHALL NOT 被視為刪除**,兩者 SHALL 明確區分。

#### Scenario: 免疫管道有前提
- **WHEN** 存在一條不經 shell、不碰輸入框的傳訊管道
- **THEN** SHALL 優先使用它,但 SHALL 寫明它的前提是「對方可達」,而該前提會失敗
- **AND** 前提不成立時 SHALL 退回經 shell 的管道,並 SHALL 適用該管道的全部規則(先讀輸入框、引號 delimiter 或走檔案)

#### Scenario: 縮範圍不等於刪除
- **WHEN** 載體判準把高風險內容導向檔案,使吃字機制不再適用於那些內容
- **THEN** 退路那一節 SHALL 保留,並 SHALL 標明它現在的適用範圍是「未升級的純訊息那一格」
- **AND** SHALL NOT 因為多數內容已改走檔案就刪除該節——升級規則的**兩個觸發條件都可能漏判**,而漏判之後唯一還在守的就是那一節
- **AND** 覆核者 SHALL 能從 spec 本身分辨「縮範圍」與「刪除」,SHALL NOT 需要靠比對 diff 才知道哪一種發生了
