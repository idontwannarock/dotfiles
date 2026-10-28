# cross-model-review Specification

## Purpose
定義跨模型 adversarial review 能力的行為契約:跨工具部署形狀、對造 agent 的挑選與沙箱預授權、給予對造的上下文邊界、以檔案為資料通道、一輪交叉反駁與三級分級、退化可見性,以及 agent 與其終端的生命週期收尾(經 `agent-mux`,支援 herdr 與 Ghostex)與工作樹比對。補足既有品質關卡(`review-*` 的六個 lens 與 confidence 打分)同屬單一模型家族所造成的盲區——多樣性只在 prompt 層,先驗與盲點共享,且證據由主 agent 挑選,因此能抓誤判而抓不到共同漏看。
## Requirements
### Requirement: 跨工具部署形狀

`review-cross-model` SHALL 以 chezmoi shared-body(`home/.chezmoitemplates/skills/review-cross-model.md`)搭配 per-tool wrapper 部署:Claude 端為 command(`home/dot_claude/commands/code/review-cross-model.md.tmpl`),Codex 端為 skill(`home/dot_codex/skills/review-cross-model/SKILL.md.tmpl`)。兩端 SHALL 共用同一份 body,行為 SHALL NOT 分叉。

本能力唯讀、可逆且非外部可見,故依 `model-invocability` 的判準 SHALL NOT 標記 `disable-model-invocation: true`。

#### Scenario: chezmoi apply 後雙工具可用
- **WHEN** `chezmoi apply` 完成
- **THEN** `~/.claude/commands/code/review-cross-model.md` 與 `~/.codex/skills/review-cross-model/SKILL.md` SHALL 存在,且由同一份 shared body 渲染

#### Scenario: Codex frontmatter 為嚴格 YAML
- **WHEN** 以 YAML parser 解析 `~/.codex/skills/review-cross-model/SKILL.md` 的 frontmatter
- **THEN** SHALL 解析成功 —— 含冒號的 `description` SHALL 加引號

### Requirement: 對造的 kind 必須異於當前工具

body SHALL NOT 寫死對造的 agent kind。派工時 SHALL 選擇一個 kind 與當前執行工具**不同**的 agent(Claude 端派非 claude、Codex 端派非 codex)。

#### Scenario: Claude 端執行
- **WHEN** 由 Claude 端呼叫本能力
- **THEN** 起始的 agent kind SHALL NOT 為 `claude`

#### Scenario: Codex 端執行
- **WHEN** 由 Codex 端呼叫本能力
- **THEN** 起始的 agent kind SHALL NOT 為 `codex`

#### Scenario: 優先選寫入受限的 kind,但不因此放棄執行
- **WHEN** 挑選對造 kind
- **THEN** SHALL 優先採用 profile 表中「寫入受限於 repo」為真的 kind
- **AND** 若僅有寫入不受限的 kind 可用,SHALL 仍執行,但報告 SHALL 揭露「對造寫入未受限,僅驗證 repo 範圍」
- **AND** SHALL NOT 以寫入不受限為由拒絕執行 —— 真實失敗模式是對造改動它正在讀的 repo,而該處正是比對涵蓋範圍;為低機率風險放棄整個關卡,換來的是關卡在該工具上完全不存在
- **AND** 預授權的指令集 SHALL 限於唯讀子命令 —— `Bash(git *)` 這類寬鬆授權涵蓋 `git reset --hard`、`git clean`,而對造的職責只有讀

#### Scenario: 派工前執行 readiness 探測
- **WHEN** 選定對造 kind 之後、建立 pane 之前
- **THEN** SHALL 執行 profile 表所載的 readiness 探測命令
- **AND** 探測失敗 SHALL 以 `counterpart not authenticated` 退化 —— 未登入的 CLI 啟動得起來、回報 ready,再卡在登入畫面,而該情形會被歸類成 `blocked`,指向錯誤的原因

#### Scenario: 探測結果不得被留存
- **WHEN** 記錄 profile 表或任何文件
- **THEN** SHALL 只記錄探測**命令**,SHALL NOT 記錄探測**結果**
- **AND** 理由:登入狀態是會變的 session 狀態,快取下來的「未登入」會在使用者重新登入後持續壓制對造

#### Scenario: 無可用的異種 kind
- **WHEN** 找不到異於當前工具且通過 readiness 探測的 agent
- **THEN** SHALL 走退化路徑並回報原因,SHALL NOT 退而求其次派同 kind 的 agent

### Requirement: 對造的上下文邊界

第一輪派工 SHALL 只提供 branch 或 commit range、以及 repo 路徑。SHALL NOT 提供主 agent 產出的 diff 文本、findings、或對 OpenSpec artifacts 的指路。

理由:證據鏈若經主 agent 之手,跨模型只剩「不同模型讀同一份材料」,而本能力的目的是偵測同源**漏看**。

#### Scenario: 派工內容
- **WHEN** 對造 agent 收到第一輪 prompt
- **THEN** 該 prompt SHALL 含 branch/commit range 與 repo 路徑,SHALL NOT 含主 agent 的 diff 摘要或既有 findings

### Requirement: 派工前確認 scope 對對造可見

派工前 SHALL 確認交付的 branch/commit range 對對造非空。若該範圍為空(例如變更尚未 commit),SHALL 走退化路徑並具名回報,SHALL NOT 派工。

理由:主 agent 看得到未 commit 的工作樹,對造只收到一個 ref。範圍為空時,合規的對造會正確地回報「無發現」,而該回報在下游與「兩造一致」無法區分 —— 失敗會偽裝成共識。

#### Scenario: 分支上沒有 commit
- **WHEN** `git diff <base>...<branch>` 為空
- **THEN** SHALL 以 `scope not visible to counterpart` 退化,SHALL NOT 派工,SHALL NOT 將對造的空結果解讀為一致

### Requirement: 對造的沙箱預授權以 per-kind profile 表提供

kind-specific 的啟動參數與結束指令 SHALL 外置於 tool-neutral 的 reference(`~/.agent/reference/cross-model-counterparts.md`),body SHALL 僅保留演算法並於執行時查表。body SHALL NOT 內含任何 kind 專屬的旗標或指令字串。

啟動時 SHALL 依該表預授權,使 findings 目錄可寫而 repo 維持唯讀。唯讀邊界 SHALL 由 sandbox/權限旗標施加,SHALL NOT 僅以 prompt 措辭表達。

理由:協定要求對造做的唯一一次寫入,正是預設沙箱最可能攔下的動作;而攔下的形式是核准對話框,即 `blocked`,亦即失敗。未預授權時,成功路徑對有沙箱的對造是系統性走不通的。

#### Scenario: 有 profile 的 kind
- **WHEN** 對造的 kind 在 profile 表中有對應列
- **THEN** SHALL 以該列的啟動參數啟動,使 findings 檔的寫入不觸發核准

#### Scenario: 無 profile 的 kind
- **WHEN** 對造的 kind 在表中無對應列
- **THEN** SHALL 以預設參數派工並跳過禮貌退出,SHALL NOT 以類比其他 kind 的方式猜測旗標或指令字串

#### Scenario: 對造的工作目錄為 repo
- **WHEN** 建立對造所在的 pane
- **THEN** 其工作目錄 SHALL 為 repo,findings SHALL 寫入 repo 內已被 gitignore 的 scratch 目錄
- **AND** 理由為 session 歸檔:agent 的 transcript 依其工作目錄歸檔,置於拋棄式路徑會使該次 review 對話對其所審之專案不可檢索

#### Scenario: 沙箱只負責限制寫入範圍不超出 repo
- **WHEN** 對造的 kind 具備可用沙箱
- **THEN** 啟動參數 SHALL 將其寫入範圍限縮於 repo,SHALL NOT 宣稱其對 repo 內容唯讀 —— 受測的 kind 皆無法做到「某子目錄可寫、其餘唯讀」

#### Scenario: 未經實測的 profile 列
- **WHEN** 某列尚未在真機上端到端驗證
- **THEN** 該列 SHALL 標示為未驗證;啟動失敗或仍被 blocked 時 SHALL 退化並回報,SHALL NOT 臨場改寫旗標繞過

### Requirement: 唯讀邊界

對造 SHALL 被明確指示為唯讀:SHALL NOT 修改任何檔案、SHALL NOT 執行測試或建置、SHALL NOT 建立 worktree 或分支。

#### Scenario: 派工時聲明邊界
- **WHEN** 組裝第一輪 prompt
- **THEN** 該 prompt SHALL 明確聲明唯讀邊界

#### Scenario: 工作樹以偵測而非預防把關
- **WHEN** 本能力執行結束(含失敗路徑)
- **THEN** SHALL 以派工前的 `git status --porcelain` 與**全部** tracked 檔及全部未被忽略之 untracked 檔的內容雜湊比對當前狀態
- **AND** 雜湊範圍 SHALL NOT 限縮於 review scope —— 對造改動 scope 外的既有髒檔時 porcelain 輸出不變,範圍受限的快照看不見;未雜湊的 untracked 檔則完全無從檢查
- **AND** 快照 SHALL 在派工前取得 —— 工作樹本就可能是髒的,沒有前置快照就無法區分「對造改的」與「使用者改的」

#### Scenario: 偵測到偏差時不得自動還原
- **WHEN** 比對發現 scratch 目錄以外的差異
- **THEN** SHALL 列出路徑並於報告揭露,且 SHALL 聲明對造的 findings 因此可疑
- **AND** SHALL NOT 自動還原 —— 還原的內容只能取自 git,對使用者已修改但未 commit 的檔案而言,那會為了撤銷對造的改動而銷毀使用者的工作
- **AND** SHALL NOT 宣稱未 commit 的內容可復原 —— 雜湊能證明檔案變了,無法重建它先前的內容

#### Scenario: scratch 目錄在任意目標 repo 皆不進入 status
- **WHEN** 在任一 repo 建立 scratch 目錄
- **THEN** SHALL 將其加入該 repo 的 `.git/info/exclude`,並於收尾時移除該條目
- **AND** SHALL NOT 依賴 dotfiles repo 自身的 `.gitignore` —— 該條目只在這個 repo 生效,其他 repo 於 run 期間會看到未追蹤檔,併發的 `git add -A` 可能將其暫存

#### Scenario: 偵測取代預防的適用範圍
- **WHEN** 有人主張把此偵測式邊界套用到非版控的目標
- **THEN** SHALL NOT 採納 —— 該取捨成立的前提是目標在版控之下,使檢查便宜且偏差可完全復原

#### Scenario: scratch 目錄不留存
- **WHEN** 兩個方向的檔案皆已讀取,或執行因任何原因中止
- **THEN** SHALL 移除本次 run 的 scratch 目錄,且該目錄 SHALL 已被 gitignore 涵蓋

### Requirement: 一輪交叉反駁

雙方各自產出 findings 後,SHALL 互換並各做**恰好一輪**反駁。SHALL NOT 進行第二輪或以「已無新論點」為由自行延長。

#### Scenario: 反駁回合數
- **WHEN** 雙方 findings 皆已取得
- **THEN** SHALL 各執行一輪反駁後即進入彙整,SHALL NOT 再次往返

### Requirement: 分級由反駁結果決定,打分僅負責過濾

現行 confidence 打分 SHALL 保留為噪音過濾器,於送交反駁**之前**執行;對造獨立發現的 findings SHALL 走同一套打分後才納入比較,否則兩造門檻不同而無從比較。分級 SHALL 由反駁結果決定。

#### Scenario: 兩造皆認可
- **WHEN** 一條 finding 由兩造提出,或由一造提出而另一造反駁不成立
- **THEN** SHALL 列為 Critical

#### Scenario: 反駁成立
- **WHEN** 一條 finding 被對造成功反駁
- **THEN** SHALL 降級或剔除,並附上反駁理由

#### Scenario: 分歧
- **WHEN** 一條 finding 僅單造提出且對造未表態
- **THEN** SHALL 於報告中明列為分歧項並交由使用者裁決,SHALL NOT 由模型逕自裁定

### Requirement: 資料通道為檔案,pane 僅為 trigger

對造的 findings SHALL 以檔案傳遞:派工時指定輸出路徑,主 agent 讀該檔取得結果。SHALL NOT 以終端讀取(`agent-mux classify-read`)的輸出作為 findings 的資料來源。

理由:終端讀取的失敗模式是靜默空字串(來源選錯時無錯誤、exit code 為 0),而空 findings 與「無發現」在下游無法區分。終端讀取僅得用於診斷與錯誤回報。

#### Scenario: 取得 findings
- **WHEN** 對造回報完成
- **THEN** 主 agent SHALL 自約定路徑讀取 findings 檔

#### Scenario: findings 檔不存在或為空
- **WHEN** 對造收斂但約定路徑無檔案或內容為空
- **THEN** SHALL 視為失敗並走退化路徑,SHALL NOT 解讀為「無發現」

#### Scenario: 反駁同樣走檔案通道
- **WHEN** 請對造反駁主 agent 的 findings
- **THEN** SHALL 指定獨立的反駁輸出檔並自該檔讀取,SHALL NOT 以終端讀取取得反駁內容
- **AND** 反駁檔缺失時 SHALL 在報告中記為「該向交換未完成」,SHALL NOT 逕自套用分級規則

#### Scenario: 輸出路徑必須檔名安全
- **WHEN** 組出 findings 與反駁檔的路徑
- **THEN** 路徑中的 scope 標籤 SHALL 經過消毒(`[A-Za-z0-9._-]` 以外一律替換)—— branch 名常含 `/`,原樣內插會產生未建立的巢狀目錄,導致寫入失敗而退化理由指向錯誤的原因

### Requirement: 收斂判定區分 blocked

`agent-mux prompt` 印出的 `idle`、`done` 與 `unknown` SHALL 僅視為「已收斂」,是否完成工作由 findings 檔決定。`blocked`、`timeout`、`gone`、`failed` SHALL 視為未完成並走退化路徑。

理由:`blocked` 意為對造停在等待輸入(權限提示或澄清問題),其工作並未完成;而多工器的等待條件把 `blocked` 也算作收斂。

多工器回報的是**終端的狀態**,不是工作的狀態。因此任何收斂狀態 SHALL NOT 單獨作為工作已完成的證據,findings 檔的存在與內容 SHALL 為唯一證據。

「對造停在自身的信任／授權提示」與「對造什麼都沒做」在外顯訊號上完全相同——皆為收斂狀態加上沒有 findings 檔。因此退化理由 SHALL 由一次明確的分類讀取決定,SHALL NOT 由讀者無從觀測的事實決定:重送一次後仍無檔案時,SHALL 以 `agent-mux classify-read` **僅為分類**讀取一次。此用途屬既有的診斷例外,與「SHALL NOT 以終端讀取收割結果」不衝突——分界在於讀來當結果或讀來分類失敗。

#### Scenario: 對造停在等待輸入
- **WHEN** 對造的最終狀態為 `blocked`
- **THEN** SHALL 視為未完成,SHALL NOT 讀取並採信其 findings

#### Scenario: 收斂狀態但沒有 findings 檔
- **WHEN** 最終狀態為 `idle`、`done` 或 `unknown`,而 findings 檔不存在
- **THEN** SHALL 先重送該 prompt 一次(見〈收斂狀態不等於 prompt 已送達〉)
- **AND** 仍無檔案時 SHALL 以 `agent-mux classify-read` 分類一次:pane 上可見對造自身的信任／授權／目錄確認提示 → 退化理由 SHALL 為 `counterpart blocked on input`;否則 → SHALL 為 `counterpart produced no findings file`
- **AND** SHALL NOT 在未分類的情況下任選其一 —— 兩者的可修復性不同,收斂成單一理由會丟掉唯一能讓人修好它的資訊

#### Scenario: 對造停在自身的信任或授權提示
- **WHEN** 對造 CLI 停在它自己的信任／授權／目錄確認提示上,而多工器回報的狀態為 `done` 或 `idle`(herdr 報 `done`;Ghostex 對 Codex 的更新提示報 idle)
- **THEN** SHALL 視為未完成並走 blocked 處置,退化原因 SHALL 為 `counterpart blocked on input`
- **AND** SHALL NOT 因收斂狀態而採信其結果 —— 該提示屬對造自身的啟動流程,多工器無從分辨它與工作結束後的閒置

#### Scenario: agent 已退出但狀態仍回報 idle
- **WHEN** 對造 agent 已從終端退出
- **THEN** 多工器的活動狀態 SHALL NOT 被當作存活的判準 —— 實測 Ghostex 的 activity 於 agent 退出後仍回報 `idle`
- **AND** 存活 SHALL 由 `agent-mux alive` 判定:herdr 以 `agent get` 能否解析出該名字的 agent;Ghostex 以該 session 的終端是否仍存在(agent 以 `exec` 啟動,agent 結束即終端結束)

#### Scenario: 步驟開頭的敘述不得與其判定表相斥
- **WHEN** 本步驟同時以散文與表格陳述收斂判定
- **THEN** 兩者 SHALL 一致 —— 由上而下閱讀者可能停在散文而未讀到表格,故散文 SHALL NOT 宣稱任何收斂狀態本身即為成功

#### Scenario: 送出前確認終端仍由 agent 佔用
- **WHEN** 準備送出任一 prompt(含重送)
- **THEN** `agent-mux prompt` SHALL 先確認該終端仍由預期的 agent 佔用;此檢查 SHALL 在腳本內,SHALL NOT 依賴呼叫端記得先呼叫
- **AND** 若 agent 已不存在,SHALL 印出 `gone` 並以 `counterpart no longer present` 退化,SHALL NOT 送出 —— agent 退出後 herdr pane 回到 shell,送出的 prompt 文字會被 shell 逐行當指令執行,而 review prompt 是任意文字且 cwd 就是 repo
- **AND** agent 自我更新等啟動期行為可造成此情形,`interactive_ready` 為真不構成後續仍存活的保證

#### Scenario: 收斂狀態不等於 prompt 已送達
- **WHEN** 對造回報收斂狀態但 findings 檔不存在
- **THEN** SHALL 重送該 prompt **一次**後才退化 —— 啟動後的首個 prompt 可能被 agent 自身的啟動通知吞掉,而多工器仍回報收斂狀態(兩個受測 kind 皆再現)

### Requirement: 退化必須顯式可見

前置條件不滿足時(沒有可用的 agent 多工器、對造 CLI 未安裝或未登入、啟動或等待逾時、對造 blocked、findings 檔缺失),本能力 SHALL 軟退化 —— 既有 review 照常產出,SHALL NOT 阻斷流程。但報告 SHALL 於顯著位置標註跨模型反駁未執行及其原因。

理由:靜默跳過會使報告看起來像已經過跨模型驗證,構成不可驗證的宣稱。

#### Scenario: 沒有可用的 agent 多工器
- **WHEN** `agent-mux detect` 失敗
- **THEN** SHALL 跳過跨模型段並照常產出 review,且報告 SHALL 標註「跨模型反駁:未執行 —— `no agent multiplexer available — <detect 印出的細節>`」
- **AND** 細節 SHALL 逐一列出每個後端與它失敗的原因(不在其中、找不到 binary、或環境變數在但命令失敗),因為三者的修法不同

#### Scenario: 任一失敗原因
- **WHEN** 跨模型段因任何原因未完成
- **THEN** 報告 SHALL 標註未執行並指明實際原因,SHALL NOT 省略該標註

### Requirement: 生命週期收尾涵蓋失敗路徑

本能力 SHALL 在結束前關閉自己建立的終端並確認無殘留:等待收斂 → 讀取 findings → 有時限的 best-effort 禮貌退出(`agent-mux exit`)→ 關閉並確認(`agent-mux close`:關閉 `start` 記下的終端,再以多工器自己的清單確認該 agent 已不在)。後兩步 SHALL 於成功與失敗路徑皆執行。`agent-mux close` 無法確認時,報告 SHALL 記載 `teardown not confirmed`。

終端識別碼(herdr 的 pane id、Ghostex 的 session globalRef)SHALL 取自建立時的回應並由 `agent-mux` 記錄,SHALL NOT 自行推導。SHALL NOT 關閉非自己建立的終端,SHALL NOT 停止多工器的 server。

#### Scenario: 成功路徑收尾
- **WHEN** 跨模型段正常完成
- **THEN** SHALL 先嘗試禮貌退出,再關閉自己建立的終端,並確認該 agent 已不在多工器的清單中

#### Scenario: 失敗路徑收尾
- **WHEN** 跨模型段因逾時、blocked、啟動失敗或任何錯誤而中止
- **THEN** SHALL 仍執行關閉與確認,SHALL NOT 留下終端或 agent 殘留

### Requirement: 禮貌退出為 best-effort,不得成為保證的前提

收尾 SHALL 先嘗試讓對造自行結束(送出該 agent 自身的結束指令),使其 SessionEnd hook、transcript flush 與自起的子行程有機會正常收尾。

該步驟 SHALL 有時限。逾時或失敗時 SHALL NOT 重試、SHALL NOT 阻斷後續步驟 —— 關閉與確認 SHALL 無條件執行。

對造為 `blocked` 時,SHALL 先送出取消鍵再嘗試結束指令;若仍無效,直接進入強制關閉。Ghostex 後端 SHALL 一律先送取消鍵——啟動期的對話框在 Ghostex 回報為 idle 而非 blocked,而在 Codex 的更新提示上按 Enter 會選中「立即更新」(2026-10-28 實測)。

#### Scenario: 禮貌退出成功
- **WHEN** 對造收到結束指令並自行退出
- **THEN** SHALL 接續執行關閉與確認 —— agent 已退出不豁免關閉終端

#### Scenario: 禮貌退出逾時或無效
- **WHEN** 結束指令送出後於時限內未觀察到對造退出
- **THEN** SHALL 直接執行關閉,SHALL NOT 重試結束指令,SHALL NOT 因此中止收尾

#### Scenario: 結束指令因 kind 而異
- **WHEN** 對造的 kind 無已知的結束指令
- **THEN** SHALL 跳過禮貌退出直接強制關閉,SHALL NOT 猜測指令字串,SHALL NOT 因缺少該指令而放棄收尾

#### Scenario: 不碰他人資源
- **WHEN** 執行收尾
- **THEN** SHALL 僅關閉自己建立的終端,SHALL NOT 關閉使用者或其他 client 的終端,SHALL NOT 停止多工器的 server

### Requirement: 一個情境只對應一個退化理由

退化理由的集合 SHALL 為互斥:任一實際情境 SHALL 恰好對應一個理由。當某步驟以「比照前一步驟」承接另一步驟的程序時,SHALL 明述承接的範圍,並 SHALL 釘死該情境自身的退化理由。

理由:理由的唯一用途是讓人知道要去修什麼。三個理由競逐同一個條件時,報告寫哪一個變成任意的,而「跨模型 review 失敗」這種收斂寫法丟掉的正是唯一能讓人修好它的資訊。

#### Scenario: rebuttal 檔缺失

- **WHEN** 一輪反駁後 `counterpart-rebuttal.md` 不存在
- **THEN** 退化理由 SHALL 為 `rebuttal exchange incomplete`
- **AND** SHALL NOT 沿用 findings 檔缺失時的分類程序所產生的理由 —— 該程序的兩個出口皆針對 findings 檔

#### Scenario: 步驟間的「比照前一步驟」

- **WHEN** 某步驟以「confirm as in <前一步驟>」承接程序
- **THEN** SHALL 明述承接的是等待與存活確認,SHALL NOT 連同該步驟專屬的退化理由一併承接

### Requirement: 空的 findings 檔等同於沒有檔案

findings 檔存在但內容為空 SHALL 與檔案不存在等同處置。判定表與逐步程序 SHALL 各自涵蓋此情形,SHALL NOT 僅於散文中提及。

理由:讀者照著表格與編號程序執行。一個只寫在收尾散文裡的規則,對停在表格第一列的讀者不生效——而該列若只判「檔案存在」,零位元組的檔案就會被讀成「沒有發現問題」,正是檔案通道要防的那個混同。

#### Scenario: 收斂但檔案為空

- **WHEN** 最終狀態為 `idle` 或 `done`,findings 檔存在但為空
- **THEN** SHALL 走與「檔案不存在」相同的路徑:重送一次,仍為空則以一次分類讀取決定退化理由
- **AND** SHALL NOT 將其讀為「沒有發現問題」

### Requirement: 多工器操作集中於 agent-mux

skill body SHALL NOT 含任何多工器專屬的指令。所有終端操作 SHALL 經由 `~/.local/bin/agent-mux`(source:`home/dot_local/bin/executable_agent-mux`)。該腳本 SHALL 提供下列動詞:`detect`、`start <name> <kind> <repo> [-- <launch args>]`、`alive <name>`、`state <name>`、`prompt <name> <file> [--timeout <seconds>]`、`classify-read <name>`、`exit <name> <exit command>`、`close <name>`。

後端 SHALL 為 herdr 與 Ghostex。兩者的差異 SHALL 只存在於腳本內。

#### Scenario: 選擇後端
- **WHEN** 呼叫 `agent-mux detect`
- **THEN** SHALL 先試 herdr,再試 Ghostex,印出第一個可用的後端名稱
- **AND** 兩者皆不可用時 SHALL 以非零結束,並在 stderr 逐一列出每個後端失敗的原因

#### Scenario: prompt 的結果字
- **WHEN** `agent-mux prompt` 結束
- **THEN** SHALL 在 stdout 印出恰好一個字:`idle`、`done`、`unknown`、`blocked`、`timeout`、`gone` 或 `failed`
- **AND** SHALL 僅在 `idle` 與 `done` 時以 0 結束

#### Scenario: close 只碰 start 開的終端
- **WHEN** 呼叫 `agent-mux close <name>`
- **THEN** SHALL 只關閉同名 `start` 記錄下來的終端,並以多工器自己的清單確認它已消失
- **AND** 清單本身讀取失敗時 SHALL 以非零結束,SHALL NOT 當作「已消失」

### Requirement: 偵測多工器必須執行真實命令

`agent-mux detect` SHALL NOT 僅憑環境變數判定後端可用。每個後端 SHALL 同時滿足:表示「正在其中」的環境變數存在(herdr:`HERDR_ENV=1`;Ghostex:`GHOSTEX_SESSION_ID`),且一個唯讀命令成功(herdr:`herdr agent list` 回傳 `.result`;Ghostex:`ghostex agents list --json` 回傳 `ok: true`)。

理由:在 Codex 的 sandbox 內 `HERDR_ENV=1` 仍被設定,但 unix socket 被當成網路,所以每個 herdr 命令都以 PermissionDenied 失敗;Ghostex 的 gxserver 在 127.0.0.1,同樣連不上。只信環境變數會在派工之後才失敗。

#### Scenario: 環境變數在但命令失敗
- **WHEN** `HERDR_ENV=1` 已設定,但 `herdr agent list` 失敗
- **THEN** `detect` SHALL NOT 回報 herdr,且失敗原因 SHALL 含該命令的錯誤訊息

#### Scenario: 只有 binary
- **WHEN** `ghostex` 在 PATH 上,但 `GHOSTEX_SESSION_ID` 未設定
- **THEN** `detect` SHALL NOT 回報 Ghostex —— 在 Ghostex 之外的終端開 session 會在使用者沒預期的地方出現

### Requirement: Ghostex 後端的對應做法

Ghostex 沒有 split pane。`agent-mux` SHALL 以 repo 所屬 Ghostex project 中的一個新 session 作為對等物。

#### Scenario: repo 不是 Ghostex project
- **WHEN** repo 路徑不等於任何 Ghostex project 的路徑
- **THEN** `start` SHALL 以 `counterpart failed to start` 失敗,SHALL NOT 呼叫 `add-project` —— 那會改變使用者的 sidebar

#### Scenario: 啟動參數
- **WHEN** 以 Ghostex 啟動對造
- **THEN** SHALL 以 `exec <Ghostex agent type 的 command> <launch args>` 作為 session 的輸入,command SHALL 取自 `ghostex agents types`,SHALL NOT 猜測
- **AND** 理由:`exec` 讓 agent 結束時終端隨之結束,所以沒有 shell 會收到後續打入的文字,而終端是否存在就是存活訊號

#### Scenario: attention 狀態的歧義
- **WHEN** Ghostex 的 activity 為 `attention`
- **THEN** SHALL 以 agent 自報的 program status 區分:`blocked` → `blocked`,`done` → `done`;沒有 program status 時 SHALL 印 `unknown`
- **AND** 理由:`attention` 同時代表「等待權限或回答」與「已完成但尚未被查看」

#### Scenario: 送出被拒
- **WHEN** `ghostex agents send` 因輸入框被對話框佔用而失敗,而 agent 仍存活
- **THEN** `prompt` SHALL 印出 `blocked`

#### Scenario: 等待收斂
- **WHEN** 訊息已送達
- **THEN** SHALL 輪詢狀態,直到觀察到 `working` 之後的第一個非 `working` 狀態;送出 10 秒後仍未觀察到 `working` 時,第一個非 `working` 狀態亦視為收斂 —— 短於輪詢間隔的回合可能整段被錯過,而是否完成由 findings 檔決定

