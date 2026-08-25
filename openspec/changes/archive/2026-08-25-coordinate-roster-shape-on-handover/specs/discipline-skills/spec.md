## MODIFIED Requirements

### Requirement: coordinate 艦隊名冊
`coordinate` SHALL 要求協調者維護一份艦隊名冊,記錄這支艦隊**該有**哪些 session。名冊 SHALL 只記「session 被換掉時不會變的東西」——名字、**啟動形狀**(agent kind ＋ 角色 ＋ 該不該帶關閉發問管道的旗標)、**指派的工作樹**、這條線是幹嘛的——SHALL NOT 記 status、pane、進度或換手任數,亦 SHALL NOT 記 `cmdline` 字串。

#### Scenario: 立論要建立在 herdr 答不出的那一格上
- **WHEN** skill 說明為什麼要有名冊
- **THEN** SHALL 寫明 `herdr agent` 沒有 history 子命令、名字在 agent 退出時被清除,因此**已死的 session 與從未存在的 session 完全無法區分**
- **AND** SHALL 寫明 herdr 只有「在」沒有「應該在」,缺席在它眼裡永遠不是異常
- **AND** SHALL NOT 以「方便查閱」之類的理由立論——那個理由對一份會過期的鏡子同樣成立

#### Scenario: 名冊與 herdr 的差集是偵測器
- **WHEN** 協調者要盤點艦隊
- **THEN** SHALL 以名冊與 `herdr agent list` 的**差集**判讀:名冊有而 herdr 無 = 漏掉或被關掉,可依名冊上的**指派工作樹**＋啟動形狀原地重開;herdr 有而名冊無 = 不屬於本艦隊
- **AND** skill SHALL 指出後者補掉了「三態使分母不可知」的一半——分母不可知是因為沒有分子

#### Scenario: 記的是指派的工作樹,不是觀測到的 cwd
- **WHEN** 協調者要在名冊上記一條線的落點
- **THEN** SHALL 記**指派的工作樹**(不可變),SHALL NOT 記從 agent 清單觀測到的 cwd——pane 的 cwd 跟著 `cd` 走,且線可能從主 checkout 起手後才開 worktree
- **AND** 依名冊重開一條線之前 SHALL 再與 `active_workflows.md` 的落點欄核對
- **AND** skill SHALL 寫明拿過期落點重開的後果:**在錯的工作樹上開出一條名字完全正常的線**

#### Scenario: 記啟動形狀,不記 cmdline 字串
- **WHEN** 有人要把某個 session 的 `cmdline` 原文寫進名冊當硬證據
- **THEN** SHALL NOT 寫——`cmdline` 是 per-process 事實,process 一換就變,屬於名冊明文排除的「會變的欄位」
- **AND** SHALL 改記**啟動形狀**(kind ＋ 角色 ＋ 該不該帶旗標),因為重開一條線需要的是形狀而不是原文
- **AND** skill SHALL 寫明為什麼那格證據不值得留:旗標欄位對「協調者」與「路人」給**同一個答案**,它沒有資格區分這兩者

#### Scenario: 不得複寫別處的事實
- **WHEN** 有人要在名冊上加「跑到第幾步」「目前狀態」
- **THEN** SHALL NOT 加——那是 `active_workflows.md` 的欄位,抄進來即屬〈複寫了別處的事實〉
- **AND** 名冊 SHALL 只保留「把不見的那個重開起來」所需的最小集合

#### Scenario: 寫入時機限於派線與收尾
- **WHEN** 一條線自我交接(名字搬到新 session)
- **THEN** 名冊 SHALL NOT 需要任何修改——**因為交接時啟動形狀不得變**,而名冊只記不會變的欄位;SHALL NOT 以「名字沒變」立論,那個理由對已經過期的 kind 與旗標欄同樣成立
- **AND** 寫入 SHALL 只發生在派線(增一列)與線正常收尾(刪一列),使其避開平行 append
- **AND** 刪列 SHALL 掛在既有的收尾清單上,否則偵測器會永久誤報

## ADDED Requirements

### Requirement: coordinate 交接的啟動形狀不得改變
`coordinate` SHALL 規定交接即「照名冊那一列的啟動形狀原地重開」,啟動形狀 SHALL NOT 在交接時改變。要改變形狀 SHALL 走「該線收尾 ＋ 協調者重新派線」,SHALL NOT 另開名冊的第三個寫入時機。

#### Scenario: 換形狀不是交接
- **WHEN** 一條線要以不同的 agent kind 或不同的旗標接手
- **THEN** SHALL 判定那不是交接,而是「這條線收掉、協調者重新派一條」,並走既有的派線寫入時機
- **AND** skill SHALL 寫明理由:旗標由**角色**決定而非由 session 決定,交接改它是 bug 而不是要被記錄的新事實
- **AND** SHALL 寫明第二個理由:維持協調者是名冊的唯一寫入者,平行 append 那一族的風險才維持為零

#### Scenario: 前任在讓出名字之前交代形狀
- **WHEN** 一條線或協調者即將把名字讓給接班 session
- **THEN** 前任 SHALL 在讓名之前把自己的 kind ＋ 該不該帶旗標寫進交接文件,並明訂接班者 SHALL 以同形狀開出來
- **AND** skill SHALL 以「只約束得到現任」立論:現任讀規則的時候接班人還不存在,所以責任 SHALL 落在**還存在的那一方**
- **AND** SHALL 寫明前任是唯一知道自己 argv 的人——process 一結束就沒有任何地方查得到

#### Scenario: 接班者上任自檢,偵測並回報而非自行代償
- **WHEN** 一個接班 session 上任
- **THEN** SHALL 查自己的 process cmdline 並與名冊那一列的形狀比對,不符 SHALL **具名回報協調者**
- **AND** SHALL NOT 自行繞過、SHALL NOT 改設定檔補旗標——那是啟動參數,跑到一半補不回來
- **AND** skill SHALL 區分兩個半邊:**旗標**補不回來,**升級契約**由協調者重發即可;並 SHALL 寫明契約才是承重的那一半(移除工具本身不產生停下來的行為)
- **AND** skill SHALL 寫明這道自檢**取代不了**前任交代那道,兩者防的是不同的失效:前者防「交代了但沒照做」,後者防「前任沒交代」

#### Scenario: 自檢可行不等於稽核可行
- **WHEN** skill 說明為什麼有自檢卻沒有事後稽核
- **THEN** SHALL 寫明「`ps` 分不出該不該有旗標」這個結論綁的是**第三方稽核者手上的資訊**,而 agent 自己知道自己的角色,同一個讀數配上這項資訊就答得出來
- **AND** SHALL 寫明名冊 ∩ herdr 的差集在交接後兩邊都在、一律判「正常」,所以形狀錯了偵測器不會轉紅
- **AND** SHALL 明白宣告這一族**不可事後稽核**,以免日後有人誤以為漏做了一個檢查而補上一個測不準的 gate
