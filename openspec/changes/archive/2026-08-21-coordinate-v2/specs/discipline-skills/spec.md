## ADDED Requirements

### Requirement: coordinate 證據的資格
`coordinate` SHALL 要求協調者在採信任何「這個綠了就算過」的東西之前,先驗它有沒有資格當證據。判準 SHALL 是機械的、且 SHALL 以清單或表格呈現——SHALL NOT 只寫在散文、括號、附註或引言中,那些位置在覆核時會被略讀。

#### Scenario: 顯示欄位不得單獨當證據
- **WHEN** 協調者要拿一個顯示欄位、狀態列或工具輸出判定某件事成立
- **THEN** SHALL 先問「這個欄位對『是』與『否』兩種輸入會不會給出**不同**的答案」
- **AND** 對兩種輸入給同一個答案的欄位 SHALL NOT 用來區分那兩種輸入,不論其措辭多像在回答該問題
- **AND** SHALL 以一個**已知為否**的樣本做決定性反例

#### Scenario: 一個永遠有答案的讀取,答案可能屬於上一個時刻
- **WHEN** 協調者讀取任何「永遠給得出答案」的狀態來源(畫面快照、pipeline 狀態、工作區是否乾淨)
- **THEN** SHALL 先確認該答案屬於哪一個時刻,SHALL NOT 只看它的內容
- **AND** skill SHALL 以多個載體不同、機制相同的實例呈現,使讀者認得這一族而不是記住其中一條

#### Scenario: 派下去的驗證步驟本身要被證明會紅
- **WHEN** 協調者把一項主觀判斷換成一個機械檢查
- **THEN** 驗收條件 SHALL 包含它自己的反向測試——①兩邊相同時通過,且②注入真實差異時全部抓到
- **AND** SHALL NOT 只給①——一個什麼都不做的實作在只有①的測試下是滿分

#### Scenario: 注入的差異本身要被驗證
- **WHEN** 一條線「做給你看」它的檢查會紅
- **THEN** SHALL 再問一層:你注入的真的是一個差異嗎(no-op 的注入配上壞掉的檢查會互相掩護成一次成功的示範)

#### Scenario: 涵蓋範圍與位置是不同族的漏
- **WHEN** 驗收一個機械檢查
- **THEN** SHALL 另外問「它比的東西涵蓋了交付物的全部嗎」——這一層最難,因為前兩層都會過:一個只比 schema 的檢查真的會紅、注入也是真差異,它只是沒有看那一半

#### Scenario: 紅燈要為主張的那一個變因而紅
- **WHEN** 以紅燈先行證明某項主張
- **THEN** 探針 SHALL 單獨改變該主張所依賴的那一個變因;若順帶改變其他變因,該紅燈 SHALL NOT 被採信為該主張的證據

#### Scenario: 失敗的計數是盤點完整性的證據
- **WHEN** 驗收一份唯讀盤點
- **THEN** SHALL 問「有沒有一個動作,它的結果會在你漏掉東西時不一樣」,SHALL NOT 只問搜尋方法——搜尋方法只證明「我找到的都在這裡」,證不了「沒有我沒找到的」

#### Scenario: 用守衛而不是告誡取得嚴謹度
- **WHEN** 協調者要一條線做出某種嚴謹度
- **THEN** SHALL 要求它先找出「這個 repo 裡有誰會因為這個探針而不高興」——那些會不高興的東西就是探針的規格說明書
- **AND** 「沒有人會不高興」SHALL 被讀成「沒有東西在守這一格」,SHALL NOT 被讀成安全訊號

### Requirement: coordinate 決策地圖的格子與寫入權
`coordinate` SHALL 定義協調者維護的決策地圖在 wayfinder 四格之外多出的兩格,且 SHALL 明示兩者性質相反:**資源佔用登記處是互斥的**(誰佔了別人不能用),**跨線量測是分歧的**(數字都對,要的是合併值)。兩者 SHALL NOT 併為一格——併格會讓「報了數字」被誤讀成「認領了」。

#### Scenario: 資源格至少三欄
- **WHEN** 地圖登記配給各線的編號區間或其他互斥資源
- **THEN** SHALL 至少有「配了什麼／目前用到哪／已回收」三欄——少了第三欄,沒用完的號段會在線收工那一刻永久蒸發且 grep 不到

#### Scenario: 寫入權依格子分配
- **WHEN** 地圖被多條線共寫
- **THEN** 裁決類內容(Destination／Out of scope／解鎖條件) SHALL 只由協調者寫;資源格的「目前用到哪／已回收」SHALL 由線自己寫;跨線量測的原始值 SHALL 由線寫且註明站在哪個 commit 上量的;合併值 SHALL 由協調者寫且標明是合併值

#### Scenario: 地圖不得複寫別處已有的事實
- **WHEN** 要把某條線的分支、基底、任務進度或下一步寫進地圖
- **THEN** SHALL 改為指回 `active_workflows.md`——抄進地圖即為〈複寫了別處的事實〉,來源一動地圖不會知道,且不會有任何東西轉紅

#### Scenario: 三個載體的分工要寫明
- **WHEN** skill 描述地圖
- **THEN** SHALL 寫明 handoff 目錄答「有哪些事」、`active_workflows.md` 答「誰跑到哪一步」、地圖只答「這件事在哪、卡著誰、誰卡著它」——handoff 目錄是一堆各自獨立的檔案,地圖是一個有拓撲的物件

#### Scenario: 強制更新點含 rebase 之後
- **WHEN** 一條線被 rebase 或被別條線搶先合併
- **THEN** SHALL 視為地圖的強制更新點——那正是「你量的數字站在哪個版本上」失效的時刻,且是事後才知道的事

### Requirement: coordinate 結論重驗的方向
`coordinate` SHALL 涵蓋結論被推翻的多個方向,SHALL NOT 只寫「協調者不要照單全收線報上來的結論」。

#### Scenario: 接手包含重驗前任的結論
- **WHEN** 協調者交接,後任接手前任留下的裁決與結論
- **THEN** 接手 SHALL 包含重驗要繼承的結論,SHALL NOT 只照著做——交接是唯一一次有人帶著新鮮眼睛重讀前任全部結論的時刻
- **AND** 前任自陳的失誤 SHALL 一併重驗——難堪的結論更少人去查,而它會經由 handoff 原樣傳給沒有現場可查的下一個人

#### Scenario: 否定斷言要對過合併佇列
- **WHEN** 一條線提出 `grep` 型的否定斷言(零讀取端、沒有別的 caller、沒有人動這個檔)
- **THEN** 該斷言 SHALL 連同「已對過當時開著的 N 個 MR/PR」一起報,或 SHALL 交由協調者確認
- **AND** 協調者 SHALL 主動比對合併佇列,SHALL NOT 只採信
- **AND** 肯定斷言 SHALL NOT 受此限——「有三處在用」不會因為別人加了第四處而變假

#### Scenario: 斷言之前先確認讀的是能回答它的那個東西
- **WHEN** 任何一方要斷言一件事
- **THEN** SHALL 先確認自己讀的是**能回答該問題的那個東西**——佇列與測試只是兩個具體的實例
- **AND** skill SHALL 記下協調者這一側的不對稱:一條線往「風險被高估」方向的自我更正比往嚴重方向的更難出現,因為沒有人會因為風險被高估而受害

#### Scenario: 協調者不得以推論回答查得到的問題
- **WHEN** 要回答「某條線有沒有動某個檔案」
- **THEN** SHALL 實際去查(`git diff --stat <base> <head> -- <path>`),SHALL NOT 憑記憶、憑該線的自述或憑任務範圍推論
- **AND** SHALL 分辨兩種強度不同的保證:「沒碰那個檔案」對任何問題都安全,「碰了但沒碰你在乎的那一段」只對特定問題安全
- **AND** skill SHALL 寫明協調者犯此錯比線貴——它的答案會被多條線當成跨線事實採信

#### Scenario: 回報要分辨量到的與記得的
- **WHEN** 一條線回報它遵守了某條規則
- **THEN** 協調者 SHALL 問它是去量的還是引用記憶,並 SHALL 在派工時就要求前者(「請附上你量到的值,不要只說你遵守了」)——引用記憶的結論換一台機器或換一個環境就失效

### Requirement: coordinate 共寫資源不限於檔案
`coordinate` SHALL 把共寫資源的判準寫成「有沒有第二個人的行為會透過它改變我的結果」,SHALL NOT 僅列舉檔案。

#### Scenario: 共用 checkout 的 HEAD 是共寫資源
- **WHEN** 要在一個共用的 git checkout 上切換分支
- **THEN** SHALL 先查 `active_workflows.md` 是否有別條線佔著它
- **AND** 自己已有 worktree 時 SHALL NOT 碰主 checkout

#### Scenario: 工具讀取設定的位置也是共寫資源
- **WHEN** 某個工具的來源目錄指向一個被別條線佔用的 checkout
- **THEN** skill SHALL 記下這種形狀:兩條線各自都正確,而兩者的組合產生第三個效果,且雙方都看不見
- **AND** SHALL 給出限縮該工具作用範圍的做法,SHALL NOT 只提醒小心

### Requirement: coordinate 收尾的第六項
`coordinate` SHALL 在四訊號與第五項(編號回收)之外,加上第六項:**「還有什麼只有你知道?」** 該項 SHALL 與第五項同性質——只能問、查不到。

#### Scenario: 產出落地與未決事項是兩件事
- **WHEN** 一條線的四訊號全齊、產出全在檔案裡
- **THEN** 協調者 SHALL 仍然問一次還有沒有未決事項——四訊號量的是「產出有沒有落地」,未決事項是「有沒有問題還掛著」,兩者可以同時為真,而只有線自己知道後者

#### Scenario: 順手解掉的小坑要有住址
- **WHEN** 一條線回報它順手解決了一個小坑
- **THEN** 協調者 SHALL 問它有沒有住址——活在某個人操作習慣裡的知識在那個人收線之後就不存在,而小坑正是重複成本最高的一類

### Requirement: coordinate 工具回報成功不等於做了事
`coordinate` SHALL 收錄「靜默 no-op」這一族的失敗形狀,且 SHALL 把規則放在讀者實際會動到該載體的那一節,SHALL NOT 另立一個抽象章節。

#### Scenario: 跨 agent 傳訊一律不走裸插值
- **WHEN** 協調者送訊息給一條線,而內容含反引號、`$`、`!` 或括號
- **THEN** SHALL 走引號包住 delimiter 的 heredoc 或先寫進檔案再 `"$(cat file)"`,SHALL NOT 內嵌於裸字串
- **AND** SHALL 寫明它防的是兩種靜默機制(指令代換、history expansion)與一種會爆掉的機制(heredoc 提前結束),且會爆掉的那一種反而最安全
- **AND** delimiter SHALL 挑一個不可能出現在內文的字串

#### Scenario: 症狀是空白不是錯字
- **WHEN** 判斷一次寫入或一則訊息有沒有被吃字
- **THEN** SHALL 把成品讀回來看,SHALL NOT 只看工具的回報——下游的每一個檢查都會通過(斷言過了、工具回報已寫入、檔案真的被改了)
- **AND** 掃描 SHALL 找**空白**而不是錯字

#### Scenario: 條件寫的三層
- **WHEN** 要修改一個共寫且無版控的檔案
- **THEN** SHALL 依序滿足:①先讀(擋盲寫) ②條件寫或錨點斷言(擋錨點消失) ③只碰自己那一列(擋別人新增)
- **AND** skill SHALL 寫明 `assert` 保護的是「我的錨點還在」,不是「這個檔案沒有被別人動過」
- **AND** 當整檔重寫無法避免時,SHALL 記下讀取當下的 `mtime_ns` 與 `size` 並於寫入前重驗——它不是第三層,但它把靜默還原變成一次中止

#### Scenario: 還原一次成功的操作要靠起點 sha
- **WHEN** 要「試一下再還原」一個會成功的 git 操作
- **THEN** SHALL 先記下起點 sha 並以 `git reset --hard` 還原,SHALL NOT 依賴 `--abort`——成功時沒有東西可以 abort,那是空操作

### Requirement: coordinate 誰有資格說這句話
`coordinate` SHALL 收錄「署名與來源對不上」這一族,並 SHALL 寫明它的共同代價:**下游分辨不出來**——收訊方看到的署名是對的,內容也通順。

#### Scenario: 該由誰說是一格獨立的判斷
- **WHEN** 某條線做了影響使用者的事,而協調者知道了
- **THEN** SHALL 先問那條線要不要自己說,SHALL NOT 先轉達——先問的成本是零,搶一步的成本是使用者收到同一起事故的兩份敘述
- **AND** 兩方都要對使用者講同一件事時 SHALL 先對齊措辭

#### Scenario: 轉述第三方要分清來源
- **WHEN** 協調者轉述另一條線的提醒
- **THEN** SHALL 分清「它說了什麼」與「我因此想到什麼」,後者 SHALL 以協調者自己的名義說

#### Scenario: 有一類授權協調者連轉述都不夠
- **WHEN** 一條線需要的是使用者本人的授權(判準 SHALL 為「這件事的授權本身是不是一個權限決定」——派 agent、越過一條常設授權自帶的例外都是),而非重要性
- **THEN** 協調者的轉述 SHALL NOT 被當成該授權;線 SHALL 有權拒絕
- **AND** skill SHALL 一併寫明代價與解法:線問不到人、協調者又不能代答時,該 pane 會進入沒有出口的狀態,解法 SHALL 為協調者把人帶到那個 pane 而非代答——升級鏈的終點是人的鍵盤,不是協調者的複述

#### Scenario: 協調者自己的選單可能回一個從未被選過的答案
- **WHEN** 協調者以選單向使用者提問
- **THEN** skill SHALL 記下該回值可能與使用者的實際選擇不同,且**偵測不了**——回值的形狀與真答案一模一樣
- **AND** SHALL 寫明這一族與〈整份覆寫〉方向不同:那一族蓋掉別人已寫下的東西,這一族**憑空生出一個從未存在的決定,並以使用者的名義生效**
- **AND** 緩解 SHALL 為:一次只問一題,且在做重的或不可逆的事之前以純文字覆述裁決請對方確認

#### Scenario: 規則的前提要跟著規則一起傳
- **WHEN** 協調者把一條規則傳給一條線
- **THEN** SHALL 一併傳它的前提與已知例外——下游收到規則會照做,而它看不到前提,無法判斷規則適不適用於自己

#### Scenario: 要在別人未來生效的意見寫成檔案
- **WHEN** 一則內容需要在對方未來某個時刻生效(尤其是一條線收線前交出的知識)
- **THEN** SHALL 寫成檔案並放在活得比 session 久的位置,訊息 SHALL 只用來說「有一份東西在那裡」
- **AND** skill SHALL 標明協調者最容易搞錯的那一格:收線前交出的知識幾乎一定屬於前者,因為需要它的人往往還沒開工

#### Scenario: 統一處理之前先問現況為何不統一
- **WHEN** 協調者要派下「照規則 X 統一處理這批東西」
- **THEN** SHALL 先問「現況為什麼不統一」——不統一往往不是疏忽,而是一條沒被寫下來的規則在起作用,且它的證據就攤在正要被覆寫的那些檔案裡

#### Scenario: 規則的來源鏈就是它的適用範圍
- **WHEN** 記錄一條由某條線提出的規則
- **THEN** SHALL 記下它是怎麼被逼出來的,SHALL NOT 只記誰提出的——來源鏈給出它的適用條件,少了它,下一個想推翻或延伸的人只能重新論證

### Requirement: coordinate 輸入框判斷之前的機械檢查
`coordinate` SHALL 在「那段文字是誰留的」這張判斷表之前,先放一步機械檢查,SHALL NOT 讓協調者從猜測開始。

#### Scenario: dim placeholder 不是 buffer 內容
- **WHEN** 協調者看到某條線的輸入框非空
- **THEN** SHALL 先以顯示原始控制碼的方式讀一次;帶 dim 標記的內容 SHALL 判定為 placeholder ghost,不屬於任何人,輸入框實際為空
- **AND** 只有非 dim 的非空內容 SHALL 進入「是誰留的」那張表

### Requirement: coordinate 覆核者的資格
`coordinate` SHALL 規定:一份交付物若動到多個由不同線建立的東西,「找一個懂那些東西的人覆核」SHALL 被視為唯一能發現跨物件耦合的機制,SHALL NOT 被當成禮貌。

#### Scenario: 差分驗證抓不到語意上的不可復原
- **WHEN** 一份交付物已通過機械的差分驗證
- **THEN** 協調者 SHALL 仍安排領域持有者覆核——差分驗證抓得到「不等價」,抓不到「等價但語意上不可復原」

#### Scenario: 覆核有時間窗
- **WHEN** 唯一懂那些物件的線正在收線
- **THEN** 協調者 SHALL 在它收線前取得覆核——把它留下來是整條鏈成立的唯一原因

### Requirement: coordinate 守衛存在但守著錯的東西
`coordinate` SHALL 在〈複寫了別處的事實〉一族之外,標出比它高一階的形態:**測試站在錯的那一邊**——守衛存在,但它正面斷言了錯誤的規則並因此一直是綠的。

#### Scenario: 兩種形態的修法不同
- **WHEN** 一條線報上來的缺陷是「守衛守著錯的東西」而非「沒有守衛」
- **THEN** SHALL 先拆掉該守衛對錯誤規則的背書,再補正確的守衛,SHALL NOT 只是加測試——否則新測試會與它打架

#### Scenario: 合成共用常數不是修法
- **WHEN** 某個事實被複寫在多處
- **THEN** SHALL 讓它去數而不是讓它記;把多份會過期的複本合成一份 SHALL NOT 被當成已修復——去重讓複本看起來消失了,但複寫的關係還在
- **AND** 修這一族 SHALL 連散文一起改——以英文字寫的數量詞任何數字型 grep 都抓不到,且修完之後它會從「多餘」變成「錯的」
- **AND** 驗證 SHALL 為「先改來源,證明複寫的那一側會紅」,SHALL NOT 以推理代替

### Requirement: coordinate 傳訊管道分兩層
`coordinate` SHALL 把跨 agent 傳訊寫成兩層:結構上免疫於吃字與 append 的管道,與仍然適用全部吃字機制的退路。退路那一節 SHALL NOT 被刪除。

#### Scenario: 免疫管道有前提
- **WHEN** 存在一條不經 shell、不碰輸入框的傳訊管道
- **THEN** SHALL 優先使用它,但 SHALL 寫明它的前提是「對方可達」,而該前提會失敗
- **AND** 前提不成立時 SHALL 退回經 shell 的管道,並 SHALL 適用該管道的全部規則(先讀輸入框、引號 delimiter 或走檔案)

### Requirement: coordinate 狀態條件不得寫成時序條件
`coordinate` SHALL 要求協調者派下的順序約束以**狀態**表述,SHALL NOT 以時序表述——兩者只在該狀態尚未成立時一致。

#### Scenario: 等待一個已經成立的狀態
- **WHEN** 協調者寫下「等 X 變成 Y 之後再做 Z」
- **THEN** SHALL 檢查 X 是否已經是 Y;若是,該句 SHALL 改寫為真正的約束(什麼事會讓 Y 失效)
- **AND** skill SHALL 記下同族形狀:約束寫的是狀態,而判斷那個狀態要看的東西另有其物

### Requirement: coordinate 收尾訊號要能接受「不適用」
`coordinate` 的四訊號中,凡依賴某個載體存在的項目 SHALL 允許「該載體從未產生」這個結果,且 SHALL 要求明說是哪一種。

#### Scenario: 從未產生 handoff 的線
- **WHEN** 一條線從未建立 handoff 檔
- **THEN** 該訊號 SHALL 判定為「不適用」並明說,SHALL NOT 讓協調者去找一個不存在的檔案
- **AND** 判準 SHALL 為「有沒有那個載體」,不是「有沒有做那個動作」——「還沒歸檔」與「不需要歸檔」的處置完全相反

## MODIFIED Requirements

### Requirement: coordinate 派線時關閉線的直接發問管道
新增一個 Scenario:pane 的按鍵行為與「依線的 kind 而定的事實」屬同一族,SHALL NOT 依讀者的 kind 條件化。其餘內容不變。

#### Scenario: 軸的宣告有機械守衛
- **WHEN** 共用 skill body 新增一個依 `.n.tool` 的條件分支
- **THEN** 該分支上一行 SHALL 帶 `axis: reader` 標記並說明為何這是讀者自身的性質
- **AND** `tests/skill-name-map-axis.test.sh` SHALL 在缺少該標記時失敗——這一族三次都不是不小心,而是兩個軸在該位置看起來都合理,所以 SHALL NOT 只靠散文提醒

#### Scenario: pane 的按鍵行為依被驅動的 pane 而定
- **WHEN** 內容描述協調者對某條線的 pane 送按鍵的後果(方向鍵、選單操作)
- **THEN** SHALL 以涵蓋各 kind 的對照表呈現,SHALL NOT 以渲染此檔的工具做條件分支——那是被驅動的 pane 的 TUI 行為,與協調者自己跑在哪個 agent 上無關
