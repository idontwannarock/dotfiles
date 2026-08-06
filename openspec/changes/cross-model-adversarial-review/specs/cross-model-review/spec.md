## ADDED Requirements

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

#### Scenario: 無可用的異種 kind
- **WHEN** 找不到任何已安裝且可用、且 kind 異於當前工具的 agent
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

#### Scenario: 未經實測的 profile 列
- **WHEN** 某列尚未在真機上端到端驗證
- **THEN** 該列 SHALL 標示為未驗證;啟動失敗或仍被 blocked 時 SHALL 退化並回報,SHALL NOT 臨場改寫旗標繞過

### Requirement: 唯讀邊界

對造 SHALL 被明確指示為唯讀:SHALL NOT 修改任何檔案、SHALL NOT 執行測試或建置、SHALL NOT 建立 worktree 或分支。

#### Scenario: 派工時聲明邊界
- **WHEN** 組裝第一輪 prompt
- **THEN** 該 prompt SHALL 明確聲明唯讀邊界

#### Scenario: 工作樹未被更動
- **WHEN** 本能力執行結束(含失敗路徑)
- **THEN** 使用者的工作樹狀態 SHALL 與執行前一致

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

對造的 findings SHALL 以檔案傳遞:派工時指定輸出路徑,主 agent 讀該檔取得結果。SHALL NOT 以 `agent read` 的終端輸出作為 findings 的資料來源。

理由:終端讀取的失敗模式是靜默空字串(來源選錯時無錯誤、exit code 為 0),而空 findings 與「無發現」在下游無法區分。`agent read` 僅得用於診斷與錯誤回報。

#### Scenario: 取得 findings
- **WHEN** 對造回報完成
- **THEN** 主 agent SHALL 自約定路徑讀取 findings 檔

#### Scenario: findings 檔不存在或為空
- **WHEN** 對造收斂但約定路徑無檔案或內容為空
- **THEN** SHALL 視為失敗並走退化路徑,SHALL NOT 解讀為「無發現」

#### Scenario: 反駁同樣走檔案通道
- **WHEN** 請對造反駁主 agent 的 findings
- **THEN** SHALL 指定獨立的反駁輸出檔並自該檔讀取,SHALL NOT 以 `agent read` 取得反駁內容
- **AND** 反駁檔缺失時 SHALL 在報告中記為「該向交換未完成」,SHALL NOT 逕自套用分級規則

#### Scenario: 輸出路徑必須檔名安全
- **WHEN** 組出 findings 與反駁檔的路徑
- **THEN** 路徑中的 scope 標籤 SHALL 經過消毒(`[A-Za-z0-9._-]` 以外一律替換)—— branch 名常含 `/`,原樣內插會產生未建立的巢狀目錄,導致寫入失敗而退化理由指向錯誤的原因

### Requirement: 收斂判定區分 blocked

僅 `idle` 與 `done` SHALL 視為對造完成工作。`blocked`、timeout、以及 herdr 回報的 stalled 狀態 SHALL 視為未完成並走退化路徑。

理由:`blocked` 意為對造停在等待輸入(權限提示或澄清問題),其工作並未完成;而 herdr 的預設等待條件把 `blocked` 也算作收斂。

#### Scenario: 對造停在等待輸入
- **WHEN** 對造的最終狀態為 `blocked`
- **THEN** SHALL 視為未完成,SHALL NOT 讀取並採信其 findings

### Requirement: 退化必須顯式可見

前置條件不滿足時(herdr 不可用、對造 CLI 未安裝或未登入、啟動或等待逾時、對造 blocked、findings 檔缺失),本能力 SHALL 軟退化 —— 既有 review 照常產出,SHALL NOT 阻斷流程。但報告 SHALL 於顯著位置標註跨模型反駁未執行及其原因。

理由:靜默跳過會使報告看起來像已經過跨模型驗證,構成不可驗證的宣稱。

#### Scenario: herdr 不可用
- **WHEN** `HERDR_ENV` 未設定或 herdr 不可執行
- **THEN** SHALL 跳過跨模型段並照常產出 review,且報告 SHALL 標註「跨模型反駁:未執行 —— herdr 不可用」

#### Scenario: 任一失敗原因
- **WHEN** 跨模型段因任何原因未完成
- **THEN** 報告 SHALL 標註未執行並指明實際原因,SHALL NOT 省略該標註

### Requirement: 生命週期收尾涵蓋失敗路徑

本能力 SHALL 在結束前關閉自己建立的 pane 並確認無殘留:等待收斂 → 讀取 findings → 有時限的 best-effort 禮貌退出 → `pane close` → 以 `agent list` 確認該 agent 已不在清單。後三步 SHALL 於成功與失敗路徑皆執行。

pane id SHALL 取自建立時的回應,SHALL NOT 自行推導。SHALL NOT 關閉非自己建立的 pane,SHALL NOT 使用 `herdr server stop`。

#### Scenario: 成功路徑收尾
- **WHEN** 跨模型段正常完成
- **THEN** SHALL 先嘗試禮貌退出,再關閉自己建立的 pane,並確認該 agent 不在 `agent list` 中

#### Scenario: 失敗路徑收尾
- **WHEN** 跨模型段因逾時、blocked、啟動失敗或任何錯誤而中止
- **THEN** SHALL 仍執行關閉與確認,SHALL NOT 留下 pane 或 agent 殘留

### Requirement: 禮貌退出為 best-effort,不得成為保證的前提

收尾 SHALL 先嘗試讓對造自行結束(送出該 agent 自身的結束指令),使其 SessionEnd hook、transcript flush 與自起的子行程有機會正常收尾。

該步驟 SHALL 有時限。逾時或失敗時 SHALL NOT 重試、SHALL NOT 阻斷後續步驟 —— `pane close` 與確認 SHALL 無條件執行。

對造為 `blocked` 時,SHALL 先送出取消鍵再嘗試結束指令;若仍無效,直接進入強制關閉。

#### Scenario: 禮貌退出成功
- **WHEN** 對造收到結束指令並自行退出
- **THEN** SHALL 接續執行 `pane close` 與確認 —— agent 已退出不豁免關閉 pane

#### Scenario: 禮貌退出逾時或無效
- **WHEN** 結束指令送出後於時限內未觀察到對造退出
- **THEN** SHALL 直接執行 `pane close`,SHALL NOT 重試結束指令,SHALL NOT 因此中止收尾

#### Scenario: 結束指令因 kind 而異
- **WHEN** 對造的 kind 無已知的結束指令
- **THEN** SHALL 跳過禮貌退出直接強制關閉,SHALL NOT 猜測指令字串,SHALL NOT 因缺少該指令而放棄收尾

#### Scenario: 不碰他人資源
- **WHEN** 執行收尾
- **THEN** SHALL 僅關閉自己建立的 pane,SHALL NOT 關閉使用者或其他 client 的 pane,SHALL NOT 停止 herdr server
