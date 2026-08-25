## MODIFIED Requirements

### Requirement: coordinate 艦隊名冊
`coordinate` SHALL 要求協調者維護一份艦隊名冊,記錄這支艦隊**該有**哪些 session,**含協調者自己那一列**。名冊 SHALL 只記「session 被換掉時不會變的東西」——名字、**啟動形狀**(agent kind ＋ 角色 ＋ 該不該帶關閉發問管道的旗標)、**指派的工作樹**、這條線是幹嘛的——SHALL NOT 記 status、pane、進度或換手任數,亦 SHALL NOT 記 `cmdline` 字串。

#### Scenario: 立論要建立在 herdr 答不出的那一格上
- **WHEN** skill 說明為什麼要有名冊
- **THEN** SHALL 寫明 `herdr agent` 沒有 history 子命令、名字在 agent 退出時被清除,因此**已死的 session 與從未存在的 session 完全無法區分**
- **AND** SHALL 寫明 herdr 只有「在」沒有「應該在」,缺席在它眼裡永遠不是異常
- **AND** SHALL NOT 以「方便查閱」之類的理由立論——那個理由對一份會過期的鏡子同樣成立

#### Scenario: 名冊與 herdr 的差集是偵測器
- **WHEN** 協調者要盤點艦隊
- **THEN** SHALL 以名冊與 `herdr agent list` 的**差集**判讀:名冊有而 herdr 無 = 漏掉或被關掉,可依名冊上的**指派工作樹**＋啟動形狀原地重開;herdr 有而名冊無 = 不屬於本艦隊
- **AND** skill SHALL 指出後者補掉了「三態使分母不可知」的一半——分母不可知是因為沒有分子
- **AND** 協調者自己 SHALL 在名冊上有一列,否則差集會把它判成「不屬於本艦隊」,且協調者猝死將永遠不可偵測——而線猝死可偵測

#### Scenario: 記的是指派的工作樹,不是觀測到的 cwd
- **WHEN** 協調者要在名冊上記一條線的落點
- **THEN** SHALL 記**指派的工作樹**(不可變),SHALL NOT 記從 agent 清單觀測到的 cwd——pane 的 cwd 跟著 `cd` 走,且線可能從主 checkout 起手後才開 worktree
- **AND** 依名冊重開一條線之前 SHALL 再與 `active_workflows.md` 的落點欄核對
- **AND** skill SHALL 寫明拿過期落點重開的後果:**在錯的工作樹上開出一條名字完全正常的線**

#### Scenario: 記啟動形狀,不記 cmdline 字串
- **WHEN** 有人要把某個 session 的 `cmdline` 原文寫進名冊當硬證據
- **THEN** SHALL NOT 寫——`cmdline` 是 per-process 事實,process 一換就變,屬於名冊明文排除的「會變的欄位」
- **AND** SHALL 改記**啟動形狀**(kind ＋ 角色 ＋ 該不該帶旗標),因為重開一條線需要的是形狀而不是原文
- **AND** skill SHALL 寫明為什麼那格證據不值得留:旗標欄位對「**沒帶旗標的**協調者」與「**沒帶旗標的**路人」給同一個答案,它沒有資格區分這兩者

#### Scenario: 不得複寫別處的事實
- **WHEN** 有人要在名冊上加「跑到第幾步」「目前狀態」
- **THEN** SHALL NOT 加——那是 `active_workflows.md` 的欄位,抄進來即屬〈複寫了別處的事實〉
- **AND** 名冊 SHALL 只保留「把不見的那個重開起來」所需的最小集合

#### Scenario: 承重的是單一寫入者,不是時機的數量
- **WHEN** 一條線或協調者自我交接(名字搬到新 session)
- **THEN** 名冊 SHALL NOT 需要任何修改——**因為交接時啟動形狀不得變**,而名冊只記不會變的欄位;SHALL NOT 以「名字沒變」立論,那個理由對已經過期的 kind 與旗標欄同樣成立
- **AND** 寫入 SHALL 只發生在**派線**(增線的一列)、**開艦隊**(建協調者那一列)與**線正常收尾**(刪一列)
- **AND** skill SHALL 以「**寫入者只有協調者一個**」立論避開平行 append,SHALL NOT 以「時機只有兩個」立論——後者是手段,而它會在補上協調者那一列時失效
- **AND** 刪列 SHALL 掛在既有的收尾清單上,否則偵測器會永久誤報

### Requirement: coordinate 交接的啟動形狀不得改變
`coordinate` SHALL 規定交接即「照名冊那一列的啟動形狀原地重開」,啟動形狀 SHALL NOT 在交接時改變。要改變形狀 SHALL 走「該線收尾 ＋ 協調者重新派線」。前任 SHALL NOT 把形狀值複製進交接文件,只 SHALL 指名名冊那一列。

#### Scenario: 換形狀不是交接
- **WHEN** 一條線要以不同的 agent kind 或不同的旗標接手
- **THEN** SHALL 判定那不是交接,而是「這條線收掉、協調者重新派一條」,並走既有的派線寫入時機
- **AND** skill SHALL 寫明理由:旗標由**角色**決定而非由 session 決定,交接改它是 bug 而不是要被記錄的新事實
- **AND** SHALL 寫明第二個理由:維持協調者是名冊的唯一寫入者,平行 append 那一族的風險才維持為零

#### Scenario: 前任只指路,不搬資料
- **WHEN** 一條線或協調者即將把名字讓給接班 session
- **THEN** 前任 SHALL 在讓名之前於交接文件寫下一句指路——接班者要以**名冊那一列**的形狀開出來——SHALL NOT 複製 kind 與旗標的值
- **AND** skill SHALL NOT 以「前任是唯一知道自己 argv 的人」立論:名冊記的是**指派的形狀**而非**觀測到的 argv**,該理由已不成立
- **AND** SHALL 寫明只指路的三個好處:不與〈不要抄一份到 handoff〉相斥、不需要優先權規則(名冊是唯一權威)、`handoff` 那支 skill 不必新增欄位

#### Scenario: 接班者上任自檢,偵測並回報而非自行代償
- **WHEN** 一個接班 session 上任
- **THEN** SHALL 查自己的 process cmdline 並與名冊那一列的形狀比對
- **AND** 處置 SHALL 依角色分流:**線**具名回報協調者;**協調者**立刻對使用者說並請使用者重開一個沒帶旗標的 session——因為接班協調者的失效態正是升級鏈已斷,它沒有上級可報
- **AND** SHALL NOT 自行繞過、SHALL NOT 改設定檔補旗標——那是啟動參數,跑到一半補不回來
- **AND** 「**名冊上沒有我這一列**」SHALL 本身即是一個 finding 並被回報,SHALL NOT 被當成「沒事可查」
- **AND** skill SHALL 區分兩個半邊:**旗標**補不回來,**升級契約**由協調者重發即可

#### Scenario: 指路防的是重開走錯,自檢防的是重開已經走錯
- **WHEN** skill 說明為什麼指路與自檢兩道都要
- **THEN** SHALL 直接命名兩者的角色——**指路是預防**(讓重開這個動作一開始就對)、**自檢是偵測**(重開已經發生之後才驗)——SHALL NOT 用「前者／後者」指涉,亦 SHALL NOT 寫成「前任交代防前任沒交代」這類套套邏輯
- **AND** SHALL 寫明少了預防會怎樣(旗標錯了只能事後發現,而那時補不回來)與少了偵測會怎樣(沒有任何東西會轉紅)

#### Scenario: 旗標的可行性依 kind 退化,不得靜默通過
- **WHEN** 接班的線不是有機械手段的 kind
- **THEN** skill SHALL 寫明「該不該帶旗標」是**角色層的應然**,而「帶得帶不上」依 kind 而定——只有部分 kind 有機械手段
- **AND** 自檢在沒有機械手段的 kind 上 SHALL **顯性退化**並說明退化了什麼,SHALL NOT 靜默通過——否則「不適用」與「檢查過了沒問題」無法區分

#### Scenario: 不可事後稽核的成因是缺少 name 到 process 的 join
- **WHEN** skill 說明為什麼有自檢卻沒有事後稽核
- **THEN** SHALL 以「**herdr 的名字與 process 之間沒有可靠的 join**」立論——`agent list` 不給 pid、不給啟動參數
- **AND** SHALL NOT 以「第三方不知道每個 session 的角色」立論:名冊現在正是那一欄,該理由已被本身的設計推翻
- **AND** SHALL 寫明名冊 ∩ herdr 的差集在交接後兩邊都在、一律判「正常」,所以形狀錯了偵測器不會轉紅
- **AND** 禁令 SHALL 綁在該成因上,使 join 出現時它失效,SHALL NOT 寫成一條沒有人記得為什麼的永久禁令

#### Scenario: 線側義務要有投遞路徑
- **WHEN** skill 對**線**課予任何義務
- **THEN** 該義務 SHALL 進派線訊息的酬載(與位址、升級契約同一則),因為沒有任何機制會讓實作線載入本 skill
- **AND** SHALL 同步寫進 `dev-workflow` 的線側契約
- **AND** SHALL NOT 僅以「線不讀你的 handoff」立論——那句講的是 handoff,不是 skill
