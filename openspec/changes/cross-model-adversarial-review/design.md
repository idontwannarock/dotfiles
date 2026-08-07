## Context

現行大型流程的 review 關卡是 `code:review-comprehensive`:六個 lens 平行跑、haiku 逐條打 confidence、過濾 <80。六個 lens 與打分者同屬一個模型家族,且每個 lens 的輸入 diff 由主 agent 挑選並餵入。因此關卡能抓**誤判**(打分過濾得掉),但抓不到**漏看** —— 漏看正是同源盲點的表現形式,而現行結構裡沒有任何獨立來源可以指出「你們六個都沒看這裡」。

herdr(本機已有,`HERDR_ENV=1`)提供 `pane split` / `agent start --kind` / `agent prompt --wait` / `agent wait --until` / `pane close`,使「在獨立 pane 起一個異種 agent、派工、等收斂、收掉」成為可腳本化的序列。`--kind` 支援 21 種(含 `claude`、`codex`、`gemini` 等),派工對象是參數而非常數。

本設計的決策全部來自 2026-08-06 的 grill 共識。

## Goals / Non-Goals

**Goals:**
- 為 review 關卡引入**模型層**而非 prompt 層的多樣性。
- 讓對造的證據鏈不經主 agent 之手,以偵測同源漏看。
- 成本可預測、失敗可見、資源不殘留。

**Non-Goals:**
- 不取代既有六個 lens,也不改動其內容。
- 不讓對造改碼、跑測試或開 worktree(見 Decisions 2)。
- 不追求兩造達成共識 —— 分歧是輸出,不是待消除的雜訊。
- 不納入小型流程。

## Decisions

### 1. 掛進大型流程的 review 關卡,小型不掛

大型流程本來就重(多輪 grill + design + tdd),多一個對造 session 的邊際成本低,而這類 change 正是最值得挑戰的。小型流程常只有數十行,跨模型反駁大機率回「無發現」,跑幾次之後就會被學會忽略。

另提供可獨立呼叫的入口,供不在流程中的臨時取用。

**Alternative considered**:比照 `arch-review` 完全不掛進任何流程。否決理由 —— `arch-review` 不掛是因為它掃全庫、訊號密度隨時間稀釋,故綁里程碑;本能力的訊號密度綁**這次 diff**,只要有 diff 就有訊號,兩者不同類。

<!-- evergreen-candidate -->
**關卡該不該自動掛,取決於它的訊號密度綁在什麼上。** 綁 diff 的關卡可以每次跑;綁時間或綁整庫規模的關卡必須綁里程碑,否則會被學會忽略。這是「被學會忽略的 gate 比沒有 gate 更糟」的可操作化判準 —— 該原則本身不告訴你頻率該多高,這條才告訴你去問什麼。

### 2. 對造為唯讀:獨立 review + 一輪交叉反駁,不開 worktree

對造只讀 repo 與 git 歷史,產出 findings;不改檔、不跑測試、不建 worktree。與現行 review 的 read-only guardrail 一致,且避免引入「agent 驅動 agent 改碼」這種無界的行為鏈。

不開 worktree 的附帶好處:唯讀操作不汙染使用者的工作樹,也就不需要 worktree 生命週期管理 —— 少一類殘留。

**Alternative considered**:讓對造在自己的 worktree 裡跑測試、寫重現腳本來證實/推翻 findings(真正的 adversarial verification)。否決理由 —— 時間從秒級拉到分鐘級,且引入第二種資源生命週期。列為未來可獨立提案的擴充。

### 3. 分工:打分過濾噪音,跨模型反駁定分級

haiku 打分擅長且便宜地濾掉明顯的誤判與 nitpick,保留此職責;**過濾之後**才送跨模型反駁。反駁結果決定分級:

| 狀態 | 分級 |
|------|------|
| 兩造都提出,或一造提出、另一造反駁不掉 | Critical |
| 一造提出、另一造成功反駁 | 降級或剔除,附反駁理由 |
| 僅單造提出且對方未表態 | **分歧**,明列並交由使用者裁決 |

對造獨立發現的 findings SHALL 走同一套打分後才進入上表,否則兩邊的門檻不同、無從比較。

兩者不衝突,因為答的不是同一題:打分答「這條像不像真的」,反駁答「另一個模型同不同意」。

**Alternative considered**:以跨模型共識取代打分。否決理由 —— 未過濾的噪音會整批丟給對造,往返變貴且訊號被稀釋。

### 4a. kind-specific 的部分外置為資料表

2026-08-06 的首次實跑推翻了「body 只要不寫死對造是誰就夠 model-neutral」這個假設。實際上有兩處無法迴避 kind 知識:**沙箱預授權的啟動參數**與**結束指令**。

解法是既有的資料表驅動慣例:`~/.agent/reference/cross-model-counterparts.md` 一列一個 kind,存啟動參數、結束指令與驗證狀態;body 只留演算法並在執行時查表。無對應列的 kind 走預設並跳過禮貌退出。

這同時解掉 Decision 10 遺留的「未知 kind 就跳過禮貌退出」—— 兩者是同一張表的兩個欄位。

表中每列 SHALL 標示是否經真機驗證。**未經驗證的列比缺列更糟**:缺列會顯性退化,錯列看起來權威卻安靜地失敗。

### 4b. 唯讀邊界改採偵測,對造留在 repo 內

4a 的預授權設計實測後再次修正。兩項實測資料推翻了「以沙箱預防」這個路線:

- **沒有任何受測 kind 能做到「某子目錄可寫、其餘唯讀」。** codex 的 `--sandbox read-only` 與 `--add-dir` 互斥(明文拒絕);claude 的 `--disallowedTools "Write(<repo>/**)"` 未能擋下寫入。可寫根就是 workspace 本身。
- 因此預防只能靠「把 workspace 移出 repo」,而那有一個先前未計入的成本:**agent 的 session 依工作目錄歸檔**。實測 codex 的 `session_meta.cwd` 記的正是那個拋棄式路徑,於是該次 review 對話在其所審專案的歷史中不可檢索 —— transcript 保住了,卻歸進一個過幾天就不存在的抽屜。

改採:對造的工作目錄是 repo,findings 寫進 gitignored 的 `<repo>/.cross-model-review/<run id>/`;沙箱(有的話)只負責把寫入限制在 repo 之內;repo 內容則由**派工前後的工作樹快照比對**把關,差異即還原並揭露。

這也消除了原設計的不一致:預防只在 codex 成立,claude 那側的「唯讀」從頭到尾只是措辭。偵測對所有 kind 一致。

**Alternative considered**:維持 workspace 在 repo 外以保住沙箱預防。否決理由 —— 換來的是 session 歸檔錯位,且該預防本來就只涵蓋一半的 kind。

**2026-08-06 修正(來自本 change 自身的跨模型 review)。** 上面那句「版控之下可完全復原」被對造指出是錯的:**可復原的是已 commit 的內容,而這個機制號稱保護的正是未 commit 的髒工作樹**。對一個使用者改過但未 commit 的檔案,從 git 還原會為了撤銷對造的改動而銷毀使用者的工作。

因此三處收緊:

1. 快照涵蓋**全部** tracked 檔與全部未忽略的 untracked 檔,不再限於 review scope —— 否則改動 scope 外的既有髒檔時 porcelain 不變、完全隱形。
2. 偵測到偏差**只回報、不自動還原**。雜湊能證明變了,不能重建先前內容;把不可回復的還原動作交給使用者決定。
3. **對造必須是寫入可被限制在 repo 內的 kind**,否則不合格。比對只涵蓋 repo,repo 外的寫入不受限、不被偵測、也不可復原 —— 一個止於 git 已經保護的那個目錄的邊界,不算邊界。

<!-- evergreen-candidate -->
**偵測只在「偵測到之後有救」時才等價於預防。** 版控讓比對變便宜,但便宜的是*發現*,不是*復原* —— 而未 commit 的內容從來不在 git 的復原範圍內。把「目標在版控之下」直接當成「可完全復原」,是把兩件事混為一談;正確的問法仍是「誤判時損失什麼」,而答案取決於損失的東西有沒有被 commit 過。

<!-- evergreen-candidate -->
**限制範圍與事後比對涵蓋不同的事,不能互相取代。** 前者決定損害能落在哪裡,後者告訴你界內是否真的落了。只有後者而沒有前者,等於只檢查你本來就檢查得到的那一塊。

<!-- evergreen-candidate -->
**唯讀邊界要由執行機制施加,不能只由 prompt 措辭表達。** 措辭是指示,機制才是強制;兩者同時存在時,可驗證的那一個才是邊界。機制不必是沙箱 —— 事後可驗證的比對同樣算數,只要它真的會被執行。

### 4. Body 為 model-neutral:規定「kind ≠ 當前工具」

Shared body 不寫死對造是誰,只規定其 kind 必須與當前執行工具不同;Claude 端跑就派 codex,Codex 端跑就派 claude。`--kind` 本就是參數,額外成本近乎零,且直接套用既有的「文件要 model-agnostic」與「shared body + 薄指標」兩條原則。

寫死單向會在 Codex 端留下一個沒有技術原因的能力落差。

### 5. 第一輪只給 branch/commit range 與 repo 路徑

對造自己跑 `git diff`、自己決定讀哪些檔。證據鏈不經主 agent 之手,這是跨模型價值的主體;若改為貼上主 agent 圈定的 diff,剩下的只有「不同模型讀同一份材料」這一層,恰好放棄了偵測漏看的能力。

OpenSpec artifacts 就在 repo 裡,對造想讀得到 —— 不主動指路,是為了不讓主 agent 的框架先行滲入。

### 6. 一輪交叉反駁即停

兩個模型可以無限互相不同意,沒有客觀收斂判準;而「已無新論點」的判定得由模型自評,那個自評本身不可靠。分歧項本來就要攤給使用者裁決,不需要機器談到共識。成本因此可預測。

### 7. 資料通道是檔案,pane 只當 RPC trigger

`agent read` 回的是**螢幕文字**而非結構化輸出,且 source 選錯會靜默拿到空字串(`recent`/`recent-unwrapped` 讀 host scrollback,新 pane 未捲動時兩者皆回空、無錯誤、exit code 為 0)。拿它當 review 關卡的資料輸入,失敗模式是「安靜地拿到空的 findings」,而空 findings 與「無發現」在下游無法區分。

因此:要求對造把 findings **寫進約定路徑的檔案**,主 agent 讀檔;pane 只負責派工與等待收斂。`agent read` 僅用於診斷與錯誤回報。

<!-- evergreen-candidate -->
**代理外部 agent 時,資料通道不得是螢幕輸出。** 終端輸出的失敗模式是靜默空值而非錯誤,且與合法的「沒有結果」無法區分。以檔案為通道、以 pane 為 trigger,失敗才會顯性。

### 8. 收斂判定要區分 `blocked` 與 `idle`/`done`

`agent wait` 預設把 `idle`、`done`、`blocked` 都當作收斂。但 `blocked` 意為對造停在等待輸入(權限提示、澄清問題),它**沒有完成工作**。若一律視為成功,會在對造卡住時讀到不完整或不存在的 findings 檔。

規則:僅 `idle`/`done` 視為完成;`blocked`、timeout、`agent_prompt_stalled` 一律走退化路徑並回報實際狀態。

### 9. 軟退化,但退化必須顯式可見

herdr 不可用、對造 CLI 未安裝或未登入、`agent start` timeout、對造 blocked —— 皆不阻斷大型流程,review 照常產出。但報告 SHALL 在顯著位置標註「跨模型反駁:未執行 —— <原因>」。

靜默跳過會讓報告看起來像已經跨模型驗證過,那是不可驗證的宣稱,比一開始不宣稱更糟。

### 10. 收尾為強制,且涵蓋失敗路徑

序列:`agent wait --until idle --until done --timeout N` → 讀 findings 檔 → **有時限的 best-effort 禮貌退出** → 無條件 `pane close <pane>` → `agent list` 確認該 agent 不在清單。

失敗路徑同樣必須走完後三步 —— 殘留最容易發生在異常路徑,而那正是最不會被注意到的時候。只關自己開的 pane(id 取自 `pane split` 的回應,不自行推導);SHALL NOT 使用 `herdr server stop` 或關閉非自己建立的 pane。

**禮貌退出與強制關閉的職責分離。** `herdr agent` 無 `stop` 子命令,但 agent 可經 `agent prompt` / `send-keys` 收到自己的結束指令(Claude Code / Codex CLI / agy CLI 皆有 `/exit`),而 herdr 明確把「agent exits」建模為正典狀態 —— agent name 會在其 exit / released / replaced 時被釋放,pane 回到 shell prompt。

禮貌退出的價值在於**讓對造跑自己的收尾**,但這個價值的範圍經 2026-08-06 實測後必須收窄:

對 codex 而言**測不到好處**。同一份工作分別以 `/exit` 與硬關 pane 結束,session 檔在硬關前後皆為 14 行、結尾都是完整的 `task_complete`(transcript 逐筆寫入,不依賴結束時的 flush);`ppid=1` 的孤兒行程數為 0。原本寫的「transcript flush 與子行程收尾」對這個 kind 是錯的。

仍保留禮貌退出,理由只剩一項:**具備 session-end hook 的 kind**(如 Claude Code)在硬關時不會執行那些 hook,而本機的 episodic-memory 索引正是掛在 hook 上。此項尚未實測,因此屬於保守而非已證實的收益 —— 它便宜、有時限、失敗不影響保證,所以留著;但不得再以「保住 transcript」為由主張它。

但它 SHALL NOT 被當作保證,原因有三:

1. **kind-specific**。`/exit` 並非 21 種 kind 皆通,寫死會讓 kind 知識滲回本應 model-neutral 的 body(違反 Decision 4)。
2. **最需要收尾的情境下最不可靠**。對造 `blocked` 時停在權限對話框上,送出的文字會被該對話框消費而非被指令解析器讀到;需先 `send-keys esc` 才有機會,而這串本身也可能無效。
3. **它自己會 hang**,因而需要自己的 timeout;逾時之後仍須 `pane close`。

因此規則是:禮貌退出為**有時限的 best-effort**,失敗或逾時 SHALL NOT 重試、SHALL NOT 阻斷後續;`pane close` 無論如何都執行。保證不建立在禮貌之上。

<!-- evergreen-candidate -->
**代理外部程序的收尾要把「禮貌」與「保證」分成兩步,且保證不得以禮貌為前提。** 禮貌退出讓對方跑完自己的清理(hook、flush、子行程),強制關閉才是不變量。把兩者合併成一步,結果不是更乾淨而是更糟:成功時看不出差別,失敗時保證跟著禮貌一起失效。

## Risks / Trade-offs

- **對造在 Windows 上不可靠** → Windows 端 herdr 仍是 preview(cwd 回報等已知限制)。以 Decision 9 的退化路徑吸收;不為 Windows 另立分支邏輯。
- **對造的 CLI 需已登入,而登入狀態無法從 repo 保證** → 屬機器本地狀態,與既有的「有些機器狀態刻意不在 repo 裡」一致;退化路徑覆蓋。
- **對造自行蒐證可能偏離主題或重複勞動** → 接受。這是 Decision 5 的代價,而偏離帶來的正是漏看偵測。分歧項交由使用者裁決,誤報成本落在人的注意力而非流程正確性。
- **多一個模型的 token 成本** → 限縮在大型流程,且僅一輪。成本上限可預測。
- **findings 檔的路徑衝突或殘留** → 置於 scratchpad 類的暫存位置並帶 change/branch 識別;檔案殘留為可忽略的雜訊,與 pane 殘留不同量級(參照「不可回復的操作要問誤判時損失什麼」—— 此處保守選項的代價是雜訊)。

## Open Questions

無 —— grill 共識已覆蓋全部決策點。實作期若出現新分岔,回到 grill 而非就地決定。
