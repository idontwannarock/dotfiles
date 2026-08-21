# discipline-skills Specification

## Purpose
定義自家開發紀律 skills(grill/tdd/diagnose/verify-done/worktree/finish-branch/coordinate)的跨工具(Claude/Codex)部署方式與各自行為契約。
## Requirements
### Requirement: 跨工具部署
七個自家流程/紀律 skills(`grill`、`tdd`、`diagnose`、`verify-done`、`worktree`、`finish-branch`、`coordinate`)SHALL 以 chezmoi shared-body(`home/.chezmoitemplates/skills/<name>.md`)+ per-tool name-map wrapper 部署,Claude 與 Codex 共用同一份身體。

#### Scenario: chezmoi apply 後雙工具可用
- **WHEN** `chezmoi apply` 完成
- **THEN** `~/.claude/skills/<name>/SKILL.md` 與 `~/.codex/skills/<name>/SKILL.md` SHALL 存在且由同一份 shared body 渲染,skill 引用依各工具 name-map 呈現(Claude 用 namespaced 名稱、Codex 用 `$` sigil)

#### Scenario: 不再依賴 superpowers symlink
- **WHEN** 檢查 `~/.codex/skills/`
- **THEN** SHALL NOT 存在指向 Claude plugin cache 的 superpowers symlink,`install-superpowers-codex.sh` SHALL 不存在於 chezmoi source

### Requirement: grill 訪談紀律
`grill` SHALL 以一次一題的訪談把模糊想法收斂成共識:每題附建議答案;能從環境查到的事實自己查、決策問使用者;解法有分岔時提出 2-3 個方案與推薦;每一題都必須可能改變後續行為。訪談開場,grill SHALL 讀取 `context/`(若存在)作為 domain grounding,併入其「事實自己查」紀律,避免重問已記載的背景。grill SHALL NOT 寫入 `context/`;凡發現疑似長青的 domain 詞彙或反覆適用原則,SHALL 以候選標記(如 `<!-- evergreen-candidate -->`)記入 `design.md` 的 `## Decisions`,待 sync/archive 階段對照實作再決定晉升。

選題順序 SHALL 由依賴決定:當一題的答案取決於另一題時,grill SHALL 標記其 `blocked by`,並優先問沒有被擋住的問題。

訪談中浮現、但尚無法收斂成精確問題的不確定性,grill SHALL 記錄為「尚未釐清」項而非丟棄,並於共識確認時一併呈給使用者裁決;確認後其去向為 `design.md` 的 `## Open Questions`。未釐清項 SHALL NOT 構成 gate——本 skill 的唯一 gate 仍是使用者明確確認共識達成。

#### Scenario: 單一 stop-gate
- **WHEN** 使用者尚未明確確認「共識達成」
- **THEN** Claude SHALL NOT 開始撰寫 openspec artifacts 或實作

#### Scenario: 產出分流
- **WHEN** 使用者確認共識達成
- **THEN** 結論 SHALL 直接分流至 openspec artifacts(決策→design.md Decisions;動機範圍→proposal.md;行為要求→spec delta),grill SHALL NOT 產生獨立的 design 文件

#### Scenario: 開場讀 context 當 grounding
- **WHEN** grill 訪談開始且 `context/` 存在
- **THEN** grill SHALL 先讀取它作為 domain 背景,SHALL NOT 重問其中已記載的事實

#### Scenario: 長青候選標記而非寫入
- **WHEN** 訪談中出現疑似長青的 domain 詞彙或反覆適用原則
- **THEN** grill SHALL 將其以候選標記記入 `design.md`,SHALL NOT 直接寫入 `context/`

#### Scenario: 未決問題的依賴決定提問順序
- **WHEN** 一個未決問題的答案取決於另一個未決問題
- **THEN** grill SHALL 標記其 `blocked by`,並先問沒有被擋住的問題

#### Scenario: 未釐清項於共識確認時裁決
- **WHEN** 使用者確認共識達成,且存在已記錄的未釐清項
- **THEN** grill SHALL 一併呈出並請使用者就每項擇一:接受風險往下走 / 現在再問 / 移出這次範圍;經裁決後仍保留的項 SHALL 記入 `design.md` 的 `## Open Questions`

#### Scenario: 未釐清項不構成第二個 gate
- **WHEN** 存在尚未釐清的項目,而使用者已明確確認共識達成
- **THEN** grill SHALL NOT 因此阻擋後續 artifacts 撰寫或實作

#### Scenario: 無未釐清項時不製造噪音
- **WHEN** 訪談過程未浮現任何無法收斂成精確問題的不確定性
- **THEN** grill SHALL NOT 提及「尚未釐清」,SHALL NOT 為了填欄位而硬擠條目

### Requirement: tdd 循環紀律
`tdd` SHALL 只在預先同意的 seam 上測試(seam 於 grill / design 階段決定並記錄於 design.md),以垂直切片循環:red before green、一次一片、refactoring 不在循環內、mock 只在系統邊界。

#### Scenario: 實作期間套用
- **WHEN** `openspec-apply-change` 進行中且任務有可測 seam
- **THEN** Claude SHALL 依 tdd 循環實作(先看測試失敗,再寫實作)

#### Scenario: 無可測 seam
- **WHEN** 任務無可測 seam 或不值得建測試設施
- **THEN** Claude SHALL 明說跳過 tdd,結果正確性由 verify-done 把關

### Requirement: diagnose 除錯紀律
`diagnose` SHALL 以 feedback loop 為先:先建立能穩定重現失敗的命令,之後才允許提出假設;假設 SHALL 為 3-5 個可否證項目並排序;一次只驗證一個變數。

#### Scenario: 硬 gate
- **WHEN** 尚無能穩定變紅的重現命令
- **THEN** Claude SHALL NOT 提出根因假設或著手修復

#### Scenario: regression test 的 seam 判斷
- **WHEN** 根因確定、準備修復
- **THEN** Claude SHALL 先在正確的 seam 寫 regression test;若不存在正確的 seam,SHALL 將此事實回報為發現而非硬寫測試

### Requirement: verify-done 證據紀律
`verify-done` SHALL 要求在宣稱「完成 / 修好 / 通過」之前實際執行驗證命令並確認輸出;測試失敗時 SHALL 如實回報並附輸出。

#### Scenario: 完工宣稱前驗證
- **WHEN** Claude 準備宣稱實作完成
- **THEN** SHALL 先執行驗證命令並以實際輸出為證據

### Requirement: worktree 與 finish-branch 雙架構支援
`worktree` 與 `finish-branch` SHALL 原生支援 normal 與 bare-worktree 兩種 repo 架構,依 ARCH 偵測自動選擇對應機制,不依賴外部 override 說明。

#### Scenario: normal 架構下建立工作區
- **WHEN** ARCH=normal 且需要新工作區
- **THEN** `worktree` SHALL 以最新的 `main` 為明確起點建立 worktree(命令含 `main` start-point),SHALL NOT 從當前 HEAD 分支

#### Scenario: bare-worktree 下建立工作區
- **WHEN** ARCH=bare-worktree 且需要新工作區
- **THEN** `worktree` SHALL 以 `git --git-dir=.bare worktree add -b <branch> <branch> main` 建立(目錄與 branch 同名,無強制前綴),並依 bare-worktree 的手動規則(autoMemoryDirectory key)解析 registry 後登記 active_workflows

#### Scenario: finish-branch 選項行為
- **WHEN** 使用者選擇 Keep 或 Push + PR(PR 尚未 merge)
- **THEN** `finish-branch` SHALL 保留 worktree 與 branch,SHALL NOT 移除 active_workflows row(僅更新 status/step)

#### Scenario: finish-branch 失敗中止
- **WHEN** merge/rebase 序列中任一命令失敗(含 `--ff-only` 失敗)
- **THEN** `finish-branch` SHALL 立即停止,SHALL NOT 執行後續 dispose 或 row 移除,並回報狀態

#### Scenario: bare-worktree 下收尾
- **WHEN** ARCH=bare-worktree 且執行 `finish-branch` 的本地 merge
- **THEN** SHALL rebase 後從 `main/` worktree 以 `--ff-only` merge;merge 確認完成後才處置 worktree 與 branch,全程不需查閱額外 override 文件

#### Scenario: Discard 確認 gate
- **WHEN** 使用者選擇 Discard(捨棄未 merge 的工作)
- **THEN** `finish-branch` SHALL 在執行 `git branch -D` 前再次向使用者確認

#### Scenario: Push + PR 的 PR 合併後收尾
- **WHEN** 使用者選擇 Push + PR 且該 PR 已 merge
- **THEN** `finish-branch` SHALL 先同步 base,並確認 branch 的樹狀內容已完整落在 base 上,確認後才處置 branch/worktree 並移除 active_workflows row
- **AND** SHALL NOT 以 `git branch -d` 的祖先關係檢查作為該判準;squash 與 rebase merge 會改寫 commit,使該檢查對已合併與未合併的 branch 給出相同結果
- **AND** 該內容比對 SHALL 限縮於 branch 自身變更過的路徑;未限縮的全樹比對會在 base 於 PR 開啟期間前進時誤報,而 base 前進屬正常情形

#### Scenario: 兩處 `git branch -D` 的把關不對稱
- **WHEN** 有人主張為 Push + PR 收尾的 `git branch -D` 補上使用者確認,或反過來移除 Discard 的確認 gate
- **THEN** SHALL NOT 採納。兩者風險不同:Discard 銷毀的是未合併的成果,Push + PR 收尾在此之前已有內容比對把關
- **AND** 為每次例行清理加設確認會使該 gate 被學會忽略,而被學會忽略的 gate 比沒有 gate 更糟

### Requirement: coordinate 協調者契約
`coordinate` SHALL 定義**協調者**角色:自己不寫程式,產出是裁決、跨線事實、handoff。它 SHALL 明示自己是 wayfinder 的延伸,處理 wayfinder 排除的那半——多條線同時解票——並以對應表把既有載體對上 wayfinder 概念(map↔handoff、decision ticket↔線＋編號、fog↔待認領清單、blocking↔解鎖條件)。

skill 內文 SHALL 分兩層:**主體為平台中立的協調原則**,**附錄收平台／工具相依的機制**。分層判準 SHALL 為「換一個 repo、換一個 merge 平台、或換一個 agent kind 之後,這句話會不會靜默失效」——會的進附錄並標明前提,不會的留主體。

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

### Requirement: coordinate 派線時關閉線的直接發問管道
`coordinate` SHALL 規定派線時關閉線在自己 session 直接詢問真人的能力,且 SHALL 要求同一次派工附上升級契約——兩者 SHALL NOT 分開使用。

關閉的範圍 SHALL 是**單一 session**（啟動參數）,SHALL NOT 寫入任何層級的設定檔——協調者本身必須保留該能力,它是唯一該升級到真人的角色。

skill SHALL 標明此機制在哪些 agent 有機械保障:Claude 端以 `--disallowedTools AskUserQuestion` 達成,其他 agent kind 若無等價機制 SHALL 明說只有 prompt 約束。

#### Scenario: 旗標與契約必須同時給
- **WHEN** 協調者派出一條線並關閉其發問管道
- **THEN** 同一次派工 SHALL 附上升級契約(撞到做不了的決策 → 具名回報協調者並停下、不要挑預設值)
- **AND** SHALL NOT 只關閉管道而不給契約——僅移除工具不會產生停下來的行為,只會讓線在命名風險之後仍以預設值繼續

#### Scenario: 不得寫入設定檔
- **WHEN** 要讓被協調的線失去直接發問能力
- **THEN** SHALL 以啟動參數限定於該 session,SHALL NOT 寫入 user 層、repo 層或 repo-local 層的設定檔——那會一併關閉協調者自己的發問能力,使升級鏈斷在最上面

#### Scenario: 標明機械保障的範圍
- **WHEN** skill 描述這個做法
- **THEN** SHALL 標明哪些 agent kind 有機械保障、哪些只有 prompt 約束,SHALL NOT 讓讀者以為所有 kind 一致

#### Scenario: pane 的按鍵行為依被驅動的 pane 而定
- **WHEN** 內容描述協調者對某條線的 pane 送按鍵的後果(方向鍵、選單操作)
- **THEN** SHALL 以涵蓋各 kind 的對照表呈現,SHALL NOT 以渲染此檔的工具做條件分支——那是被驅動的 pane 的 TUI 行為,與協調者自己跑在哪個 agent 上無關

#### Scenario: 軸的宣告有機械守衛
- **WHEN** 共用 skill body 新增一個依 `.n.tool` 的條件分支
- **THEN** 該分支上一行 SHALL 帶 `axis: reader` 標記並說明為何這是讀者自身的性質
- **AND** `tests/skill-name-map-axis.test.sh` SHALL 在缺少該標記時失敗——這一族三次都不是不小心,而是兩個軸在該位置看起來都合理,所以 SHALL NOT 只靠散文提醒

#### Scenario: 依線的 kind 而定的事實不得依讀者的 kind 條件化
- **WHEN** 內容描述的是「被派出的線是哪一種 agent」所決定的事實(例如某個 kind 有沒有關閉發問管道的機械手段)
- **THEN** SHALL 以涵蓋各 kind 的對照表呈現,SHALL NOT 以渲染此檔的工具做條件分支——協調者派得出多種 kind,依它自己的 kind 分支會讓它讀到與手上那條線無關的答案(Claude 協調者派 codex 線會誤以為有保障,反之會誤以為沒有)

#### Scenario: 真人失去繞過通道的代價要寫明
- **WHEN** skill 描述這個做法
- **THEN** SHALL 一併寫明代價:協調者因此成為沒有 bypass 的單點,而線推翻錯誤前提的管道改為文字回報而非選單

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

### Requirement: coordinate 承重規則置頂
`coordinate` 每一節的**首段** SHALL 是該節的承重規則。判準 SHALL 為「**讀者若只讀這一句,會不會做出正確的動作**」——動機、前提、軼事 SHALL NOT 佔據首段,因為單獨讀它們都不會使人做出動作。

#### Scenario: 軼事不得排在它所支持的規則之前
- **WHEN** 一節同時含承重規則與支持它的軼事
- **THEN** 規則 SHALL 在前,軼事 SHALL 緊接其後
- **AND** 軼事 SHALL NOT 被刪除或搬進附錄——帶時間戳的事實是規則適用條件的唯一證據

#### Scenario: 前提降在規則之後但不得移除
- **WHEN** 一節的規則只在某個前提下成立
- **THEN** 承重規則 SHALL 置頂,前提 SHALL 緊接其後並標記為前提
- **AND** SHALL NOT 因為前提重要就讓它佔據首段——讀者要先知道規則是什麼,才需要判斷它適不適用自己

#### Scenario: 分散在散文中的多項規則要有置頂清單
- **WHEN** 一節含多項並列的規則,而它們之間夾著軼事或說明
- **THEN** SHALL 於節首以清單一次列完,細節與軼事留在下方
- **AND** 清單 SHALL 標明哪幾項的性質不同(例如「只能問、查不到」與「自己查得到」)

#### Scenario: 這一條不設機械守衛
- **WHEN** 有人提議為本要求加自動檢查
- **THEN** SHALL NOT 加——「首段是不是承重規則」是內容問題而非形式問題,沒有可機械化的判準
- **AND** 一個沒有標明母體的綠燈 SHALL 被視為比沒有守衛更糟,因為下一個人會把它讀成「這一族已經解決了」

### Requirement: coordinate 接班協調者必須驗自己的發問能力
`coordinate` SHALL 要求接手的協調者在**接手後第一件事**就驗證自己手上有沒有直接詢問真人的能力,SHALL NOT 等到需要用它的時候才發現。

關閉發問管道的旗標 SHALL NOT 被帶進開接班協調者的那道指令——那道指令與派線用的是同一道,而範圍正確(單一 session)不代表套對了 session。

#### Scenario: 範圍太寬與套錯 session 是兩種形狀
- **WHEN** skill 描述關閉發問管道的風險
- **THEN** SHALL 分開寫兩種失效:**範圍太寬**(寫進設定檔,所有 session 一起被關)與**套錯 session**(範圍正確,但那個 session 是接班的協調者)
- **AND** SHALL NOT 合成一條——前者的動作是「不要那樣寫」,後者的動作是「開完之後去驗」

#### Scenario: 防線放在接班人身上而非前任身上
- **WHEN** 決定這條規則寫在哪一節
- **THEN** SHALL 以「接手後第一件事」為承重位置——讀者是接班人本人,且它是唯一能實際驗證的人
- **AND** 前任那側 SHALL 也寫一句,但 SHALL NOT 只寫在那裡:前任可能正在收尾、context 將滿,或根本不是它開的

#### Scenario: 接手後的檢查要是清單
- **WHEN** skill 描述接手後第一件事
- **THEN** SHALL 以逐條清單呈現,至少含:名字指著自己、**手上有沒有發問工具**、廣播一次
- **AND** SHALL NOT 寫成「確認一切正常」這種無法逐條核對的句子

#### Scenario: 沒有那個工具時的處置
- **WHEN** 接班協調者發現自己沒有發問能力
- **THEN** SHALL 立刻說出來,並 SHALL 請使用者重開一個未帶該旗標的 session——那是啟動旗標,跑到一半補不回來
- **AND** SHALL NOT 自行繞過或以預設值繼續——那正是本 skill 的頭號失敗

#### Scenario: 這一條不設機械守衛
- **WHEN** 有人提議自動檢查某個 session 有哪些工具
- **THEN** SHALL NOT 加——從外部查不到某個 pane 的 agent 手上有哪些 tool,唯一能驗的是該 session 自己

#### Scenario: 對名字提問得到的答案只對當下有效
- **WHEN** 協調者以名字向另一個角色(如 `coordinator`)提問其當下狀態
- **THEN** SHALL 把時間或 pane 釘住,或明確接受該答案只對當下有效——名字不是 session,同一個問題在不同時刻問會得到不同任的答案,而回答者不會提醒提問者
