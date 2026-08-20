# session-handoff Specification

## Purpose
定義 `handoff` / `pickup` / `handoff-list` 三者組成的 session 交接生命週期契約:產物落點與 repo slug 規則、寫入端的必要段落、跨 repo 交接的指定方式與 header 形狀、resume 提示行的語言標記、完成後的封存機制,以及清單查詢的唯讀邊界。補足既有實作把契約只寫在讀取端所造成的靜默失敗——檔案寫得出來、找得到、讀起來完整,只有接手那一刻才發現無事可做。

## Requirements
### Requirement: 跨工具部署形狀

`handoff`、`pickup`、`handoff-list` 三者 SHALL 各以一份 chezmoi shared body(`home/.chezmoitemplates/skills/<name>.md`)搭配 per-tool wrapper 部署:Claude 端為 command(`home/dot_claude/commands/<name>.md.tmpl`),Codex 端為 skill(`home/dot_codex/skills/<name>/SKILL.md.tmpl`)。兩端 SHALL 共用同一份 body,行為 SHALL NOT 分叉。

#### Scenario: chezmoi apply 後雙工具可用

- **WHEN** `chezmoi apply` 完成
- **THEN** `~/.claude/commands/{handoff,pickup,handoff-list}.md` 與 `~/.codex/skills/{handoff,pickup,handoff-list}/SKILL.md` SHALL 皆存在,且各自的 body 內容 SHALL 一致

#### Scenario: Codex frontmatter 為嚴格 YAML

- **WHEN** 產生 Codex 端 `SKILL.md` 的 frontmatter
- **THEN** 含冒號的 `description` SHALL 加引號 —— Codex 的 YAML 解析不容忍未加引號的冒號,Claude 端則容忍,僅在單一端測試無法發現此問題

### Requirement: repo slug 取自 git common dir 的父目錄

handoff 產物落點所用的 repo slug SHALL 由 `git rev-parse --path-format=absolute --git-common-dir` 去除最後一段後導出,其中 slug 化為將絕對路徑中每個 `:`、`\`、`/`、`.` 替換為 `-`。`handoff`、`pickup`、`handoff-list` 與 `arch-review` SHALL 使用同一條規則。SHALL NOT 使用 `git rev-parse --show-toplevel` 作為 slug 來源。

`--path-format=absolute` SHALL NOT 省略:未加時 git 印出的是相對於**呼叫者** cwd 的路徑,搭配 `-C <目標>` 會靜默解析成當前 repo。

此規則與 `context/glossary.md` 記載的 auto-memory path-slug 規則一致,兩個系統對「同一個 repo」的定義 SHALL 對齊。

#### Scenario: normal 佈局

- **WHEN** 在 normal 佈局的 repo(`git-common-dir` 為 `<repo>/.git`)執行 `handoff`
- **THEN** slug SHALL 由 `<repo>` 導出,結果與舊規則相同,既有目錄 SHALL NOT 受影響

#### Scenario: bare+worktree 佈局收斂到容器

- **WHEN** 在 bare+worktree 佈局的任一 worktree(`git-common-dir` 為 `<repo>/.bare`)執行 `handoff`
- **THEN** slug SHALL 由 `<repo>` 容器導出,SHALL NOT 含 worktree 名稱

#### Scenario: 跨 worktree 互相可見

- **WHEN** 在 bare+worktree 佈局的 worktree A 寫出 handoff 後,於同一 repo 的 worktree B 開新 session 執行 `pickup`
- **THEN** `pickup` SHALL 解析得到該 handoff

#### Scenario: 非 git 目錄

- **WHEN** `git rev-parse --git-common-dir` 失敗(當前目錄不在 git repo 內)
- **THEN** SHALL 退回以 `$PWD` 導出 slug,並照常寫檔

#### Scenario: 既有錯位目錄已遷移

- **WHEN** 本變更落地後檢視 `~/.agent/handoffs/`
- **THEN** SHALL NOT 存在以 worktree 名稱為尾綴的目錄(如 `*-main`、`*-add-self-service-portal`),同一 repo 的 handoff SHALL 位於單一容器 slug 目錄下

### Requirement: pickup 解析的跨 repo 回退

`pickup` 在當前 repo slug 目錄與兩個 legacy 位置皆未命中時,SHALL 再掃一次 `~/.agent/handoffs/` 底下全部 slug 目錄,以同一組解析規則比對。此回退 SHALL 位於解析順序的最後。

命中時 SHALL 在讀取檔案前明講該 handoff 所屬的 repo,以及本次 session 將代該 repo 工作 —— 此回退比前述位置寬鬆,靜默命中會使「正在為哪個 repo 工作」不可見。全部位置皆未命中時 SHALL 回報所有搜尋過的絕對路徑並停止,SHALL NOT 虛構檔案。

#### Scenario: 跨 repo handoff 由回退掃描命中

- **WHEN** 使用者在來源 repo 的 session 中以完整 ID 發動一份寫給別的 repo 的 handoff
- **THEN** SHALL 由全域掃描解析到該檔,並在讀取前明講它屬於哪個 repo

#### Scenario: 回退命中不得靜默

- **WHEN** 回退掃描命中
- **THEN** SHALL 明講所屬 repo 與代工對象,SHALL NOT 直接進入 `Apply` 流程

#### Scenario: 全部位置皆未命中

- **WHEN** 當前 slug 目錄、兩個 legacy 位置與全域掃描皆無匹配
- **THEN** SHALL 列出所有搜尋過的絕對路徑並停止,SHALL NOT 虛構檔案

### Requirement: 寫入端強制必要段落

`handoff` 的 compose 段 SHALL 明文標示 `## Suggested skills` 與 `## Next steps` 為必要段落,其餘段落形狀自由。`handoff` SHALL 在寫檔前執行自我檢查,確認兩段皆存在,且 `## Next steps` 之下每一條都帶可驗證的成功判準。

自我檢查 SHALL 另含一項:寫檔前重讀易變事實(HEAD sha、目標 handoff 目錄列表、worktree 列表)並與草稿對帳,SHALL NOT 沿用 compose 當下的記憶 —— compose 與 write 之間隔了多輪,平行 session 會在期間合併分支、歸檔被引用的檔案或新增 worktree。易變事實 SHALL 以快照措辭書寫(如「寫這份時 HEAD 為 X,開工前重驗」),SHALL NOT 寫成無時態的斷言 —— 接手者無法從斷言分辨過期與現行。

#### Scenario: 缺少必要段落時不得寫檔

- **WHEN** 自我檢查發現 `## Suggested skills` 或 `## Next steps` 缺漏
- **THEN** SHALL 補齊後才寫檔,SHALL NOT 寫出缺段的檔案

#### Scenario: next step 缺成功判準

- **WHEN** `## Next steps` 之下有條目未帶可驗證的成功判準
- **THEN** SHALL 補上成功判準後才寫檔 —— 缺判準時 `pickup` 的封存收尾無法列出達成證據,只能回到推測

#### Scenario: 無建議 skill 時不得使用 bullet

- **WHEN** 本次無 skill 可建議、`## Suggested skills` 段無內容可列
- **THEN** SHALL 以非 bullet 的句子表達(如 `No skills needed.`),SHALL NOT 寫成 `- None` —— bullet 形式與真實 skill 條目無法區分,`pickup` 會嘗試呼叫它

#### Scenario: 寫檔前重讀易變事實

- **WHEN** 草稿完成、即將寫入檔案
- **THEN** SHALL 重跑 HEAD sha、目標 handoff 目錄列表與 worktree 列表,並依結果修正草稿 —— 2026-08-20 有 handoff 被接手時其基準 commit 已落後兩個 merge,另有草稿正在撰寫期間、其引用的檔案被平行 session 歸檔

#### Scenario: 易變事實以快照措辭書寫

- **WHEN** 檔案中記錄 HEAD、分支、同目錄其他 handoff 等會被平行 session 改動的事實
- **THEN** SHALL 標明其為寫檔當下的快照並提示開工前重驗,SHALL NOT 以無時態斷言呈現

### Requirement: 文件內路徑引用指向現行位置

`handoff` 與 `pickup` 的 body SHALL NOT 引用已作廢的 `~/.claude/projects/<slug>/` 作為 auto-memory 位置。凡需說明 slug 慣例與其他系統的對齊關係時,SHALL 指向現行的 `~/.claude/memory/<id>/`。

#### Scenario: body 不含作廢路徑

- **WHEN** 檢視 `home/.chezmoitemplates/skills/{handoff,pickup}.md`
- **THEN** SHALL NOT 出現 `~/.claude/projects/` 作為現行 auto-memory 位置的描述

#### Scenario: 其他檔案的舊路徑引用不受影響

- **WHEN** repo 內其他檔案(如 `claude-memory-seed` 的遷移來源路徑、`bare-worktree/claude-state.md` 的 transcripts 說明)引用 `~/.claude/projects/`
- **THEN** SHALL 保留不動 —— 該處指涉舊路徑正確且必要

### Requirement: resume 提示行帶 session 語言

`handoff` SHALL 記錄本次 session 使用的語言,並將其反映在檔尾的 resume 提示行。非英文 session SHALL 產出形如 `/pickup <ID> in <lang>` 的可複製指令;英文 session SHALL 產出 `/pickup <ID>`,不加後綴。`handoff` 向使用者回報時印出的那一行 SHALL 與檔內一致。

#### Scenario: 中文 session

- **WHEN** 本次 session 以繁體中文進行
- **THEN** resume 行 SHALL 為 `/pickup <ID> in zh-tw`

#### Scenario: 英文 session

- **WHEN** 本次 session 以英文進行
- **THEN** resume 行 SHALL 為 `/pickup <ID>`,SHALL NOT 附加語言後綴

#### Scenario: pickup 消化語言後綴

- **WHEN** `pickup` 收到的 args 以 `in <語言>` 結尾
- **THEN** SHALL 以該語言進行本次 session,並將該後綴自 args 移除,SHALL NOT 把它當成對第一條 next step 的補充說明

#### Scenario: arch-review 產出沿用同一形狀

- **WHEN** `arch-review` 寫出報告的 resume 行
- **THEN** SHALL 套用同一條語言後綴規則 —— 該產物與 handoff 共用 `pickup` 契約,形狀不得分叉

### Requirement: 跨 repo 交接只接受明講的目標

`handoff` SHALL 支援將產物寫入其他 repo 的 handoff 目錄。目標 repo SHALL 只由使用者明講指定(wrapper 參數或 args 中明確指名)。未指定時 SHALL 落在當前 repo。`handoff` SHALL NOT 從對話內容推斷而自行改變落點。

目標 repo 的絕對路徑 SHALL 由 `git -C <目標> rev-parse --path-format=absolute --git-common-dir` 取得後套用 slug 規則。SHALL NOT 以 `~/.agent/workflow-registry.md` 作為目標路徑的權威來源。目標 SHALL 以路徑指定;使用者僅給 repo 名稱時 SHALL 詢問對應路徑,SHALL NOT 自行搜尋。

跨 repo 產物的 resume 提示行 SHALL 帶上切換到目標 repo 的動作(形如 `cd <目標絕對路徑> && claude "/pickup <ID> in <lang>"`),`handoff` 回報給使用者的那一行 SHALL 與檔內一致。同 repo 產物 SHALL 維持不帶 `cd` 的短形式。

#### Scenario: 明講跨 repo 目標

- **WHEN** 使用者在 args 中明講目標 repo
- **THEN** 產物 SHALL 寫入該 repo 的 slug 目錄,並向使用者印出該絕對路徑

#### Scenario: 未指定時落在當前 repo

- **WHEN** 使用者未指定目標 repo,且無跡象顯示內容屬於別的 repo
- **THEN** 產物 SHALL 寫入當前 repo 的 slug 目錄,SHALL NOT 詢問確認

#### Scenario: 偵測到內容屬於別的 repo

- **WHEN** `handoff` 判斷本次內容明顯屬於另一個 repo,但使用者未明講
- **THEN** MAY 向使用者提議改變落點,但在使用者確認前 SHALL 維持當前 repo 為落點

#### Scenario: 目標路徑無效

- **WHEN** 使用者指定的目標路徑不存在或不是 git repo
- **THEN** SHALL 回報並停止,SHALL NOT 猜測其他落點

#### Scenario: 跨 repo 時 header 區分來源與目標

- **WHEN** 產物寫入非當前 repo
- **THEN** header SHALL 同時標示來源 repo 與目標 repo,且分支欄位 SHALL 明確標註其屬於來源 repo —— 來源分支對接手者無意義,不加標註會誤導

#### Scenario: 跨 repo 時 resume 行帶目標 repo

- **WHEN** 產物寫入非當前 repo
- **THEN** resume 行 SHALL 形如 `cd <目標絕對路徑> && claude "/pickup <ID> in <lang>"` —— 不帶 `cd` 的 resume 行會在**來源** repo 的 session 被發動,而 `pickup` 的前三個解析位置都以當前 repo slug 為準,找不到該檔

### Requirement: pickup 遇缺必要段落時不得靜默發明

`handoff` 保證兩個必要段落,但任何 session 都能手寫檔案進 `~/.agent/handoffs/`,report 形狀的產物尤其常缺 `## Next steps`。`pickup` 遇此情形 SHALL NOT 自行發明清單,亦 SHALL NOT 靜默開工:SHALL 在**第一則訊息**指名它打算當作 next steps 的段落,使用者得以在任何工作發生前否決。無可指名的段落時 SHALL 停下來詢問,SHALL NOT 開工。

缺 `## Suggested skills` 時 SHALL 不呼叫任何 skill,並明講此事。

#### Scenario: 缺 Next steps 時指名頂替段落

- **WHEN** 被解析到的 handoff 沒有 `## Next steps`,但有可充當待辦的段落(如未決問題或裁決題清單)
- **THEN** SHALL 在第一則訊息明講「本檔無 `## Next steps`,我以 <段落名> 代之」,才開始工作

#### Scenario: 無段落可頂替時停止

- **WHEN** 被解析到的 handoff 既無 `## Next steps`,也無任何可指名為待辦的段落
- **THEN** SHALL 停止並詢問使用者,SHALL NOT 自行推導待辦

#### Scenario: 缺 Suggested skills 時明講

- **WHEN** 被解析到的 handoff 沒有 `## Suggested skills`
- **THEN** SHALL 不呼叫任何 skill 並說明此事,SHALL NOT 自行猜測應呼叫哪些

### Requirement: pickup 完成後提議封存

`pickup` SHALL 在 `## Next steps` 全數達成時執行收尾步驟:逐條列出達成證據;將需要活過 lookup 的內容先行搬出;詢問使用者是否封存;確認後將檔案移入 `archive/` 子目錄。

「搬出」SHALL 涵蓋兩類:工作期間產生的**裁決** SHALL 先寫入 `~/.claude/memory/<repo-slug>/`;仍具價值的**耐久參考內容** SHALL 由活著的 artifact(後繼 handoff 或 memory)以**歸檔後**的絕對路徑 `~/.agent/handoffs/<repo-slug>/archive/<ID>.md` 指名,SHALL NOT 以當前路徑書寫 —— 以當前路徑寫成的引用會在建立它的同一步失效。

詢問步驟 SHALL 在使用者有常設指示(per-repo memory 或本次 session 中明講)時省略。常設指示 SHALL 只取代詢問,SHALL NOT 取代證據列舉;其效力 SHALL 只及於剛完成的該份 handoff,SHALL NOT 及於同目錄的其他 handoff。

封存落點的 `<repo-slug>` SHALL 取自**解析到該檔的目錄**(即該 handoff 所屬的目標 repo),SHALL NOT 取自當前 repo 的 slug。

`pickup` SHALL NOT 自行判定 handoff 是否完成,SHALL NOT 在未確認且無常設指示的情況下移動或刪除任何 handoff,SHALL NOT 以 `rm` 處置。此收尾步驟 SHALL NOT 與 `finish-branch` 耦合。

#### Scenario: 全數達成時提議封存

- **WHEN** `## Next steps` 每一條都已達成其成功判準,且無常設指示
- **THEN** SHALL 逐條列出達成證據,並詢問使用者是否封存

#### Scenario: 有常設指示時不再詢問但仍列證據

- **WHEN** 使用者已有「證據列得出來就直接封存」之類的常設指示(per-repo memory 或本次 session 明講)
- **THEN** SHALL 照常逐條列出達成證據後直接封存,SHALL NOT 再問一次 —— 常設指示免除的是打擾,不是舉證責任

#### Scenario: 常設指示不及於鄰居

- **WHEN** 常設指示生效,且同目錄另有其他 handoff
- **THEN** SHALL 只封存剛完成的那一份,SHALL NOT 一併處置其他檔案

#### Scenario: 裁決先進 memory 才封存

- **WHEN** 本次工作產生了裁決或刻意留下的未決題
- **THEN** SHALL 先將其寫入 `~/.claude/memory/<repo-slug>/`,才執行 `mv` —— 歸檔後的檔案不再被任何 lookup 撿到

#### Scenario: 耐久參考以歸檔後路徑被指名

- **WHEN** 該 handoff 除了已完成的待辦之外,還含後續 session 仍需要的盤點、依賴圖或批次計畫
- **THEN** SHALL 由活著的 artifact 以 `~/.agent/handoffs/<repo-slug>/archive/<ID>.md` 指名之,SHALL NOT 以其當前(未歸檔)路徑書寫

#### Scenario: 使用者確認後封存

- **WHEN** 使用者確認封存
- **THEN** SHALL 將檔案移入 `~/.agent/handoffs/<repo-slug>/archive/<ID>.md`,SHALL NOT 刪除檔案

#### Scenario: 封存落點取自解析來源而非 cwd

- **WHEN** 該 handoff 是由跨 repo 回退掃描解析到的,其所屬 repo slug 與當前 repo slug 不同
- **THEN** SHALL 封存至**該 handoff 所屬 repo** 的 `archive/` 子目錄,SHALL NOT 落在當前 repo 的目錄下 —— 落錯目錄等於讓檔案從唯一有人會找的位置消失

#### Scenario: 使用者不封存

- **WHEN** 使用者拒絕或未回應封存提議
- **THEN** 檔案 SHALL 留在原位

#### Scenario: 未全數達成時不提封存

- **WHEN** `## Next steps` 尚有未達成項目
- **THEN** SHALL NOT 提及封存

#### Scenario: 封存項不被 pickup 撿到

- **WHEN** `pickup` 解析 handoff 檔(Exact ID / slug glob / date prefix / latest mtime)
- **THEN** `archive/` 子目錄下的檔案 SHALL NOT 被納入候選 —— 解析僅 glob `<repo-slug>/*.md`

### Requirement: handoff-list 只列與標註

`handoff-list` SHALL 列出指定 repo(預設為當前 repo)下未封存的 handoff,每項 SHALL 含 ID、日期、一行 Task 摘要、`## Next steps` 條數。SHALL NOT 推測任何 handoff 是否已完成,SHALL NOT 標註完成候選,SHALL NOT 移動或刪除任何檔案。

#### Scenario: 列出當前 repo 的未封存項

- **WHEN** 使用者執行 `handoff-list`
- **THEN** SHALL 列出當前 repo slug 目錄下所有 `*.md`,每項含 ID、日期、一行 Task 摘要與 next steps 條數

#### Scenario: 不列封存項

- **WHEN** 列出清單
- **THEN** `archive/` 子目錄下的項目 SHALL NOT 出現在預設輸出中

#### Scenario: 不推測完成狀態

- **WHEN** 某 handoff 的主題與已合併的 PR 相似,或其 next steps 看似已有對應產出
- **THEN** SHALL NOT 標註為「可能已完成」或任何等價提示 —— 名稱相似度與主題相似度已被實證證明會誤判(2026-08-03 誤刪事件),而清單的閱讀者正是封存決策的唯一把關者

#### Scenario: 主目錄為空但 legacy 位置有項目

- **WHEN** `~/.agent/handoffs/<repo-slug>/` 不存在或無 `.md`,但 `~/.local/state/handoffs/<repo-slug>/` 或 `<repo>/.claude/handoffs/` 有項目
- **THEN** SHALL 列出這些項目並標示為 legacy —— `pickup` 仍會回退查找它們,回報「無未封存項」會是假的空清單

#### Scenario: 全部位置皆為空

- **WHEN** 主目錄與兩個 legacy 位置皆不存在或無未封存項
- **THEN** SHALL 明確回報無項目,SHALL NOT 報錯
