## Context

`handoff` / `pickup` 以 chezmoi shared body(`home/.chezmoitemplates/skills/`)搭配 per-tool wrapper 部署,Claude 端 render 成 command、Codex 端 render 成 skill。產出落在 `~/.agent/handoffs/<repo-slug>/<ID>.md`,位置刻意中性,任何工具都能接手。

該目錄同時被當**待辦清單**使用(memory `project-handoff-as-todo-list`),但清單缺乏兩件基礎建設:沒有「完成」的出場機制,也沒有查詢工具。清單靠人腦維持,於是混進已完成項目;有人想清理時,又只能靠推測。

現行實作的三個結構性問題:

1. **契約只寫在讀取端。** `pickup` 與 `context/glossary.md` 都說「含 `## Suggested skills` 與 `## Next steps` 就能被接手」,但 `handoff` 的 compose 段沒把這兩段列成硬性要求。寫的人照既有檔案的觀感仿寫,力氣花在自由形狀的背景敘述,漏掉唯一 load-bearing 的段落。
2. **落點規則假設交接對象是當前 repo。** `handoff.md:19` 把「寫到別的 repo」一律當錯誤,但真實情境裡它正確且必要。skill 沒有這條路,agent 只好自行發明落點。
3. **repo 身分定義與 auto-memory 不一致。** handoff 用 `git rev-parse --show-toplevel`,auto-memory 用 `dirname(realpath(git-common-dir))`。normal 佈局下兩者相同,bare+worktree 下前者依 worktree 分裂。

約束:

- 改 shared body 一份,雙工具自動同步;行為 SHALL NOT 分叉。
- Codex 的 `SKILL.md` frontmatter 需嚴格 YAML,含冒號的 description 必須加引號(memory `reference-codex-skill-yaml-strict`)。
- 這台機器常有無關的既有 drift,驗收時 SHALL NOT 跑裸的 `chezmoi apply`,要點名 target(memory `feedback-chezmoi-apply-scope`)。
- `~/.agent/handoffs/` 不在 git 版控內,沒有 undo。

## Goals / Non-Goals

**Goals:**

- 讓 handoff 目錄能真正當待辦清單用:有出場機制(封存)、有查詢工具(`handoff-list`)。
- 把必要段落契約從讀取端上移到寫入端,讓「漏寫 `## Next steps`」在寫檔前就被擋下。
- 讓跨 repo 交接成為 skill 支援的一級路徑,而非 agent 自行發明。
- 統一 repo slug 定義,消除 bare+worktree 下的目錄分裂。
- resume 提示行帶上語言,讓接手 session 不必重新猜。

**Non-Goals:**

- **不動 `finish-branch`。** 時機雖然重疊,但 handoff 的生命週期不該綁在 branch 生命週期上 —— 有些 handoff(殘骸交接、`arch-review` 報告)根本不對應任何分支。
- **不做自動完成判定。** agent SHALL NOT 從內容推測 handoff 是否完成,任何封存都要使用者確認。
- **不改 `pickup` 的檔案解析順序**(Exact ID → slug glob → date prefix → latest mtime)。封存改用子目錄,現有 glob 天然不會撿到,解析邏輯零改動。
- **不修 `~/.agent/workflow-registry.md`。** 它只有 8 筆且欄位語意混雜,本次不依賴它,也不順手重整。
- **不解決 `project-handoff-invocability`**(Claude 端 command vs Codex 端 skill 的形狀不對稱)。那是 wrapper 形狀問題,與本次改 body 內容互不阻擋。

## Decisions

### D1. 封存步驟住在 `pickup`,不掛 `finish-branch`

`finish-branch` 已在 merge 確認後移除 `active_workflows.md` 的 row,是同類動作、同一個可驗證訊號,看起來是自然掛點。**不採用**:那會把 handoff 機制耦合到 branch 機制,而兩者的生命週期不同構 —— 不對應分支的 handoff 將永遠不會被封存,清單還是會臭掉。

採用:`pickup` 新增收尾步驟。`## Next steps` 逐條達成後,列出每條的達成證據,詢問使用者是否封存。`handoff` / `pickup` 本來就是一對,出場機制住在這一對裡是自足的。

替代方案「完全人工」被排除:那等於維持現狀,清單腐化不會停。替代方案「`pickup` 自行判定完成後自動封存」已被實證排除(見 D2)。

### D2. 封存 = 移入 `<repo-slug>/archive/`,不是 `rm`

爭論點:做完的 handoff 該記錄的東西理論上都已進 spec / docs / `context/`,為何不直接刪?

這個論點對「內容」成立,但對**實際發生的失敗模式**不成立。2026-08-03 那次誤刪丟掉的不是已完成 handoff 的知識,而是**兩份根本沒開始做的 handoff** —— 判定方式是 slug 字面相似度,不是逐條讀 `## Next steps` 查證。風險不在「刪掉已完成的」,在「把未完成的誤判成已完成」。

新流程有使用者確認把關,誤判率大幅下降,但殘餘風險仍在(在清單上一次確認多筆時看漏一筆),而 `~/.agent/handoffs/` 沒有 undo。

成本不對稱:`archive/` 的代價是永遠不會看的檔案佔一層目錄;`rm` 的代價是偶爾但不可回復的資料消失。當保守選項的代價是可忽略的雜訊時,不值得為了乾淨換取不可回復性。

`archive/` 子目錄相對於其他封存形狀的額外好處:`pickup` 只 glob `<repo-slug>/*.md`,子目錄天然不會被撿到 —— 解析邏輯一行都不用改。改檔名前綴(`done__<ID>.md`)要改 glob 且打亂日期排序;檔內加狀態欄位會讓 `pickup` 從檔名 glob 退化成全文掃描。

<!-- evergreen-candidate -->
**不可回復操作的成本不對稱原則**:當保守選項的代價是可忽略的雜訊、激進選項的代價是不可回復的資料消失時,選保守。「內容已經備份在別處」不足以支持不可回復操作 —— 要問的是「誤判時損失什麼」,不是「正確時損失什麼」。

### D3. repo slug 改用 `slug(dirname(realpath(git-common-dir)))`

現行 `git rev-parse --show-toplevel` 在 bare+worktree 佈局下回傳當前 worktree 路徑:

| 佈局 | `git-common-dir` | `dirname` | 現行 `--show-toplevel` |
|---|---|---|---|
| normal | `<repo>/.git` | `<repo>` | `<repo>` —— 相同 |
| bare+worktree | `<repo>/.bare` | `<repo>` 容器 | `<repo>/<worktree>` —— **分裂** |

實測後果:`~/.agent/handoffs/` 下 `shoalter-ai-toolkit` 有三個目錄(`-main`、`-add-agent-sessions-collector`、`-add-self-service-portal`),`hktv-product-category-classification-api-poc` 有一個 `-main` 尾綴目錄。在 worktree A 寫的 handoff,在 worktree B 開 session 完全看不到。

新規則不是發明的 —— `context/glossary.md` 的 **auto-memory / path-slug** 條目已記載這條規則,`claude-memory-seed` 也在用。改用它讓 handoff 與 auto-memory 對「同一個 repo」的定義對齊,normal 佈局的既有目錄完全不受影響。

<!-- evergreen-candidate -->
**repo 身分的單一定義**:凡是以 repo 為單位的 agent 產物(auto-memory、handoff、未來同類),slug 一律取 `slug(dirname(realpath(git-common-dir)))`,SHALL NOT 用 `git rev-parse --show-toplevel` —— 後者在 bare+worktree 佈局下依 worktree 分裂,會讓同一 repo 的產物互相看不見。

### D4. 跨 repo 目標只接受使用者明講

兩個候選:使用者明講 vs agent 從內容推斷。

推斷被排除:2026-07-31 那起孤兒化事故的機制正是 agent 自行發明落點。推斷錯誤時的失敗是靜默的 —— 檔案寫得出來,只是沒人找得到。把推斷制度化等於把事故機制寫進規格。

採用:預設落在當前 repo(維持 `handoff` 的 "No confirmation" 原則,涵蓋 99% 情境);跨 repo 必須在 args 明講。agent 偵測到內容明顯屬於別的 repo 時**可以問**,但 SHALL NOT 自行改變落點 —— 提議與擅自行動的差別,就是失敗會不會被看見。

目標 repo 的絕對路徑從 `git -C <目標> rev-parse --git-common-dir` 取得,再套 D3 的 slug 規則。**不使用 `~/.agent/workflow-registry.md`** —— 它只有 8 筆(本次要交接的 10 個殘骸 repo 有 8 個不在表裡),且 `Project Memory Path` 欄位混雜舊 projects 路徑、新 memory 路徑、active_workflows 路徑三種語意,拿它當權威來源會踩空。原 handoff 檔「優先複用 registry」的建議指錯方向。

跨 repo 時 header 拆為來源 / 目標兩欄:現行 `- Branch:` 記的是**來源** repo 的分支,對接手者無意義甚至誤導。

### D5. 必要段落契約上移到寫入端 + 寫檔前自我檢查

契約目前只存在讀取端(`pickup.md:22`、`context/glossary.md:32`)。寫入端不知道契約,就只能靠仿寫既有檔案的觀感。

兩處改動,成本近乎零:

1. compose 段明文標示 `## Suggested skills` 與 `## Next steps` 為**必要**,其餘段落自由。順帶把 glossary 已記的 `- None` 陷阱寫進去(無內容時要寫成非 bullet 的句子,否則 `pickup` 會去呼叫它)。
2. 寫檔前加自我檢查:兩段皆存在,且 `## Next steps` 每條都帶可驗證的成功判準。

第 2 點同時是 D1 的前提 —— 沒有成功判準,`pickup` 收尾時就無法「列出達成證據」,只能回到推測,而那正是 D2 排除掉的做法。

### D6. resume 行帶語言,而非寫死

`handoff` 記錄本次 session 使用的語言,resume 行 render 成 `/pickup <ID> in zh-tw`;英文 session 不加後綴。

替代方案「永遠固定加 `in zh-tw`」被排除:未來英文 session 產出的 handoff 會被硬塞中文指示。替代方案「加 `- Language:` header 欄位,由 `pickup` 讀取後遵循」被排除:使用者要的是**可複製的那一行**就帶著語言,加在 header 需要 `pickup` 額外讀取與遵循,多一層間接。

### D7. `handoff-list` 只列與標註,不推測

列出未封存的 handoff:ID、日期、一行 Task、`## Next steps` 條數。**SHALL NOT 推測完成與否**。

替代方案「額外比對可驗證訊號(相關 PR 已 merge、next steps 有對應產出)並標出『可能已完成』候選」被排除:那正是 2026-08-03 誤刪事件的推測行為。即使不自動動手,一個標著「可能已完成」的清單也會誤導確認者 —— 而確認者正是這套設計唯一的把關者。

## Risks / Trade-offs

- **[D3 是 BREAKING,現有 4 個目錄會孤兒化]** → 同一次改動內執行遷移(合併 shoalter 三個目錄、去掉 poc 的 `-main` 尾綴),不留 legacy fallback 讓分裂狀態長期存在。遷移前先確認無檔名衝突。
- **[`archive/` 永久累積]** → 接受。單檔數 KB,且 `handoff-list` 預設不列封存項,視覺上不佔位。真要清理是未來的獨立決定。
- **[封存仰賴使用者確認,使用者可能草率點頭]** → 這是為何 `handoff-list` 不做推測標註(D7),也是為何封存不是 `rm`(D2)。兩層設計互為備援。
- **[跨 repo 需明講,使用者可能不知道有這條路]** → wrapper 的 description 與 body 的 Flow 段都要寫明 `--repo` 用法;`handoff` 偵測到內容屬別的 repo 時主動提議。
- **[新增第三個 skill 擴大跨工具維護面積]** → 三個 skill 共用同一套 chezmoi shared body + wrapper 慣例,無新機制。`handoff-list` body 極短(只讀目錄與檔頭)。
- **[`pickup` 收尾步驟可能讓「純讀取」的 pickup 也被追問封存]** → 收尾只在 `## Next steps` 全數達成時觸發;未達成時 SHALL NOT 提及封存。

## Migration Plan

1. 改 shared body(`handoff.md`、`pickup.md`),新增 `handoff-list.md`。
2. 改 / 新增雙工具 wrapper。
3. 點名 target 執行 `chezmoi apply`(SHALL NOT 裸跑),確認 `~/.claude/commands/` 與 `~/.codex/skills/` 兩端內容一致。
4. 遷移 `~/.agent/handoffs/` 的 4 個錯位目錄。此步驟只搬檔,不刪檔;衝突時停下回報。
5. 驗收:真的跑一次跨 repo handoff → 到目標 repo 開新 session → `/pickup` 接得到。紙上推演不算。

回滾:shared body 與 wrapper 走 git;目錄遷移是 `mv`,反向 `mv` 即可還原。

## Open Questions

無。六項決策皆已於 grill 階段由使用者確認。
