## ADDED Requirements

### Requirement: coordinate 定址名要艦隊限定
`coordinate` SHALL 規定協調者與線的 herdr 名稱一律帶艦隊前綴(`<fleet>-coordinator`、`<fleet>-<change>`),SHALL NOT 把協調者的位址寫成一個固定字串。理由 SHALL 寫明:herdr 名稱是整台機器一個扁平命名空間且在活著的 agent 之間唯一,固定字串等於宣告全機只能有一支艦隊。

#### Scenario: 缺陷形狀是靜默投遞到錯的收件人
- **WHEN** skill 說明為什麼要加前綴
- **THEN** SHALL 寫明唯一性約束**保證**該名字解得開,所以投遞端不會報錯、收訊端看到的是格式與署名都正確的回報
- **AND** SHALL 標明它屬於〈誰有資格說這句話〉同一族:**下游分辨不出來**
- **AND** SHALL NOT 把它描述成解析失敗或找不到目標

#### Scenario: 名字會易主
- **WHEN** skill 列出撞名的發生方式
- **THEN** SHALL 涵蓋第二種:先佔用該名字的 agent 退場後名字被釋放、由後來者接走,**原本那批線的回報自此改道**
- **AND** SHALL NOT 只寫「兩支同時跑會撞」——那會讓人以為錯開時間就安全

#### Scenario: 前綴是決定不是推導
- **WHEN** skill 規定前綴怎麼產生
- **THEN** SHALL 寫明名稱受 `[a-z][a-z0-9_-]{0,31}` 約束,以 repo 全名推導必然溢位,因此前綴 SHALL 由人在開艦隊時選定
- **AND** SHALL 寫明自動推導配截斷會把撞名從顯性選擇降級為隱性碰撞
- **AND** SHALL 明寫 32 字元上限如何被 `<fleet>-` 吃掉,使人在**命名當下**知道 change 名稱的可用長度

#### Scenario: 前綴要能跨換手存活
- **WHEN** 協調者換手
- **THEN** 前綴 SHALL 以裁決的身分寫進 handoff,由接班協調者繼承
- **AND** SHALL NOT 要求接班者重新選一個

#### Scenario: 前綴套三層
- **WHEN** 開一條 `claude` 線
- **THEN** 前綴 SHALL 套在三層命名共用的那個字串上,使既有的一行三層同名寫法自然帶著前綴
- **AND** 〈命名三層各自獨立〉SHALL NOT 因此被改寫成一道指令決定三層

### Requirement: coordinate 前綴與 cwd 是兩道正交檢查
`coordinate` SHALL 把「哪一支艦隊」與「哪一個 repo」寫成**兩道各自獨立**的檢查:前綴分艦隊(同一個 repo 內也分得出),`cwd` 分 repo。SHALL NOT 把 cwd 描述成艦隊歸屬的判準。cwd 驗證 SHALL 被定位為派線訊息漏給位址或位址已過期時的**機械後盾**,SHALL NOT 取代前綴。

#### Scenario: 兩端各自要檢查
- **WHEN** skill 描述 cwd 驗證
- **THEN** SHALL 分別寫出協調者定址一條線之前、以及收到回報之時各要檢查什麼,以及不符時的處置(不投遞/不處理並退回)
- **AND** SHALL NOT 只寫其中一端——只驗投遞端擋不住別支艦隊投進來的回報

#### Scenario: cwd 不等於 repo
- **WHEN** 被協調的 repo 是 bare+worktree 佈局
- **THEN** 判準 SHALL 寫成「在本艦隊 repo 的工作樹範圍內」並以 git common dir 為準
- **AND** SHALL NOT 寫成對 repo 路徑做字串前綴比對——線的 cwd 是 worktree 路徑,不是 main repo 路徑

#### Scenario: 取 common dir 的指令形式要完整
- **WHEN** skill 給出比對用的指令
- **THEN** SHALL 為 `realpath "$(git rev-parse --path-format=absolute --git-common-dir)"`——路徑格式旗標 SHALL 置於它所影響的選項**之前**,且結果 SHALL 再經 `realpath`
- **AND** SHALL 標明裸指令回傳的是 **cwd 相對路徑**,而旗標置後會**靜默無效且 exit code 為 0**
- **AND** SHALL 標明寫錯的後果是另一個 worktree 上的合法對象被判成別的 repo,使守衛變成通訊中斷

### Requirement: coordinate 艦隊名冊
`coordinate` SHALL 要求協調者維護一份艦隊名冊,記錄這支艦隊**該有**哪些 session。名冊 SHALL 只記「session 被換掉時不會變的東西」——名字、agent kind、**指派的工作樹**、開線旗標與角色、這條線是幹嘛的——SHALL NOT 記 status、pane、進度或換手任數。

#### Scenario: 立論要建立在 herdr 答不出的那一格上
- **WHEN** skill 說明為什麼要有名冊
- **THEN** SHALL 寫明 `herdr agent` 沒有 history 子命令、名字在 agent 退出時被清除,因此**已死的 session 與從未存在的 session 完全無法區分**
- **AND** SHALL 寫明 herdr 只有「在」沒有「應該在」,缺席在它眼裡永遠不是異常
- **AND** SHALL NOT 以「方便查閱」之類的理由立論——那個理由對一份會過期的鏡子同樣成立

#### Scenario: 名冊與 herdr 的差集是偵測器
- **WHEN** 協調者要盤點艦隊
- **THEN** SHALL 以名冊與 `herdr agent list` 的**差集**判讀:名冊有而 herdr 無 = 漏掉或被關掉,可依名冊上的 cwd＋kind＋旗標原地重開;herdr 有而名冊無 = 不屬於本艦隊
- **AND** skill SHALL 指出後者補掉了「三態使分母不可知」的一半——分母不可知是因為沒有分子

#### Scenario: 記的是指派的工作樹,不是觀測到的 cwd
- **WHEN** 協調者要在名冊上記一條線的落點
- **THEN** SHALL 記**指派的工作樹**(不可變),SHALL NOT 記從 agent 清單觀測到的 cwd——pane 的 cwd 跟著 `cd` 走,且線可能從主 checkout 起手後才開 worktree
- **AND** 依名冊重開一條線之前 SHALL 再與 `active_workflows.md` 的落點欄核對
- **AND** skill SHALL 寫明拿過期落點重開的後果:**在錯的工作樹上開出一條名字完全正常的線**

#### Scenario: 不得複寫別處的事實
- **WHEN** 有人要在名冊上加「跑到第幾步」「目前狀態」
- **THEN** SHALL NOT 加——那是 `active_workflows.md` 的欄位,抄進來即屬〈複寫了別處的事實〉
- **AND** 名冊 SHALL 只保留「把不見的那個重開起來」所需的最小集合

#### Scenario: 寫入時機限於派線與收尾
- **WHEN** 一條線自我交接(名字搬到新 session)
- **THEN** 名冊 SHALL NOT 需要任何修改——名字沒變
- **AND** 寫入 SHALL 只發生在派線(增一列)與線正常收尾(刪一列),使其避開平行 append
- **AND** 刪列 SHALL 掛在既有的收尾清單上,否則偵測器會永久誤報

### Requirement: coordinate 艦隊產物的落點
`coordinate` SHALL 規定艦隊產物(名冊與 map)落在 `~/.agent/fleets/<repo-slug>/<fleet>/`,SHALL NOT 與 `active_workflows.md` 混放於同一目錄。`<repo-slug>` SHALL 採用既有的正典 repo slug 定義,SHALL NOT 另立一套。

#### Scenario: 目錄邊界跟著生命週期
- **WHEN** skill 說明為什麼不放在 workflow 那棵樹底下
- **THEN** SHALL 寫明兩者生命週期不同:`active_workflows.md` 跨所有艦隊且沒有艦隊時照樣存在,而名冊與 map 與艦隊同生同滅
- **AND** SHALL 寫明混放會使拆艦隊變成「刪二留一」,分開之後拆艦隊就是刪一個目錄

#### Scenario: 目錄名可重用,開艦隊時要處置
- **WHEN** 開一支艦隊而該 `<fleet>` 目錄已經存在
- **THEN** SHALL 停下來要求裁決(接續這支艦隊,或確認是殘留後清空),SHALL NOT 直接沿用
- **AND** skill SHALL 寫明成因:前綴只在**活著的 agent 之間**唯一而非跨時間唯一,整支艦隊異常關閉時目錄不會被刪

#### Scenario: map 站在 workflow 之上
- **WHEN** 有人提議把 map 收進 workflow 目錄
- **THEN** SHALL 指出 map 明文要求「一條線自己的狀態指回 `active_workflows.md`」,它跨越多個 workflow,收進去是降一層且會使目錄名說謊

### Requirement: coordinate 資源池不得共用
`coordinate` SHALL 規定:一支艦隊必須完整擁有它所仲裁的稀缺資源池,兩支艦隊 SHALL NOT 共用同一個池。該限制 SHALL 寫在資源那一層,SHALL NOT 寫成「一個 repo 只能有一支艦隊」。

#### Scenario: 理由要在 domain 不在機制
- **WHEN** skill 說明這條限制的理由
- **THEN** SHALL 以「協調者存在的意義是仲裁稀缺資源,而合併位、migration 版號、編號區間等資源綁 repo」立論
- **AND** SHALL NOT 以「cwd 分不出同 repo 的兩支艦隊」立論——前綴那道分得出,且從機制反推的限制會在機制改變時無聲失效

#### Scenario: 共用池的失敗形狀
- **WHEN** skill 描述兩支艦隊共用一個池會怎樣
- **THEN** SHALL 寫明兩邊各自的登記處都會顯示「乾淨」,因為它們互相看不見——**兩份都對,合起來錯**,與跨線量測合併值同一形狀

#### Scenario: 艦隊限定定址使撞號更難被察覺
- **WHEN** skill 說明為什麼這條不變量是必須而非最好有
- **THEN** SHALL 寫明艦隊限定定址讓兩支艦隊的訊息不再交錯,**而訊息交錯原本是撞號唯一會露出來的地方**
- **AND** SHALL 寫明隔離之後兩邊的登記處各自內部一致,衝突只在合併時才炸

#### Scenario: 合法的例外要答得出來
- **WHEN** 兩支艦隊打不同的 base branch
- **THEN** skill SHALL 承認這是合法例外,並 SHALL 要求**逐項**判斷每一項資源會不會被爭
- **AND** SHALL 標明 base branch 分開不代表整個池分開——migration 版號通常仍是同一條全域遞增序列

### Requirement: coordinate map 的層級
`coordinate` SHALL 明示 `map` 是與艦隊同生同滅的**工作面**,SHALL NOT 被升進長青的 repo-level context bundle。其中可重用的殘留 SHALL 走既有的晉升閘門。

#### Scenario: 工作面不進長青載體
- **WHEN** 有人提議把 map 併入 repo-level 的長青 context
- **THEN** SHALL 指出 map 的內容是小時級變動(某線現在卡著某線),放進要走 review 的長青載體會立即腐爛
- **AND** SHALL 指出 durable 的殘留另有路徑,與一次性設計決策的晉升同一條

## MODIFIED Requirements

### Requirement: coordinate 協調者契約
`coordinate` SHALL 定義**協調者**角色:自己不寫程式,產出是裁決、跨線事實、handoff。它 SHALL 明示自己是 wayfinder 的延伸,處理 wayfinder 排除的那半——多條線同時解票——並以對應表把既有載體對上 wayfinder 概念(decision ticket↔線＋編號、fog↔待認領清單、blocking↔解鎖條件)。對應表 SHALL 寫明 wayfinder 的 **map issue 在此裂成兩個載體**(handoff ＋ map),SHALL NOT 只對上其中一個。

skill 內文 SHALL 分兩層:**主體為平台中立的協調原則**,**附錄收平台／工具相依的機制**。分層判準 SHALL 為「換一個 repo、換一個 merge 平台、或換一個 agent kind 之後,這句話會不會靜默失效」——會的進附錄並標明前提,不會的留主體。

#### Scenario: map 這個詞在同一份文件裡不得有兩個意思
- **WHEN** 讀者對照開頭的對齊表與內文的 map 專節
- **THEN** 兩處 SHALL 一致——對齊表 SHALL 寫明多線把 wayfinder 的單一物件裂成 handoff 與 map 兩個載體,理由是拓撲不屬於任何一個 session
- **AND** SHALL NOT 讓「map」在同一份文件裡同時指 handoff 與線間拓撲

#### Scenario: 主體不綁定部署平台
- **WHEN** 讀者所在的 repo 其 merge 方式不是 ff + squash
- **THEN** 主體的排程規則 SHALL 仍然可讀且不誤導——凡依賴該設定的句子 SHALL 標明前提或位於附錄

#### Scenario: 不得指向 repo-scoped memory
- **WHEN** skill 內文要引用某條經驗的來源
- **THEN** SHALL NOT 以裸 slug 指向任一 repo-scoped memory;操作性事實 SHALL 內聯於 skill 內文本身

#### Scenario: agent 專屬機制走 name-map
- **WHEN** 內容只在特定 agent 成立(如 `/rename`、`-n`、`--remote-control` 等 Claude CLI 旗標)
- **THEN** SHALL 經 per-tool name-map 或 gap 字串呈現,渲染出來的 Codex 版 SHALL NOT 指向 Codex 不存在的旗標或 skill

#### Scenario: 來源軼事保留
- **WHEN** 內文含帶日期的實戰軼事(某日某線報了什麼數字、回收了哪個編號)
- **THEN** SHALL 保留於主體——軼事是時間戳記的事實,換平台不會使其為假,且為規則提供唯一無法從別處推導的證據

### Requirement: coordinate 收尾的第六項
`coordinate` SHALL 在四訊號與編號回收之外,加上**「還有什麼只有你知道?」** 該項 SHALL 與編號回收同性質——只能問、查不到。收尾清單中 SHALL NOT 以序號指涉某一項,序號 SHALL 僅為呈現順序。

#### Scenario: 序號不得承重
- **WHEN** 收尾清單中插入新的一項
- **THEN** 既有條文 SHALL 不因此失效——指涉 SHALL 以該項的內容命名(如「編號回收」),SHALL NOT 以「第五項」這類序號
- **AND** 理由 SHALL 為:序號是位置不是身分,插入一項就會讓所有指涉它的文字同時變假,而且沒有任何東西會轉紅

#### Scenario: 產出落地與未決事項是兩件事
- **WHEN** 一條線的四訊號全齊、產出全在檔案裡
- **THEN** 協調者 SHALL 仍然問一次還有沒有未決事項——四訊號量的是「產出有沒有落地」,未決事項是「有沒有問題還掛著」,兩者可以同時為真,而只有線自己知道後者

#### Scenario: 順手解掉的小坑要有住址
- **WHEN** 一條線回報它順手解決了一個小坑
- **THEN** 協調者 SHALL 問它有沒有住址——活在某個人操作習慣裡的知識在那個人收線之後就不存在,而小坑正是重複成本最高的一類

#### Scenario: 名冊列的移除屬於收尾
- **WHEN** 一條線在語意上退出艦隊(收尾或取消)
- **THEN** 收尾清單 SHALL 含「名冊那一列已移除」,且 SHALL 標明它由協調者自己查
- **AND** SHALL 明文區隔:**行程意外死亡不刪列**——留著才叫得出「有一條線不見了」,把兩者混為一談等於關掉偵測器
