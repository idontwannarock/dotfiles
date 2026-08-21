## Context

`coordinating-lines` 是 2026-08-21 一個協調者 session 帶四條實作線（`!42`／`!44`／`!45`／`!46` 全數合併）時，**在工作中途**寫下的田野筆記，加上 frontmatter 就成了 skill。它的可信度來自真實事故，過度綁定也來自同一個原因——兩者是同一件事的兩面。

它刻意寫成 Matt Pocock `wayfinder` 的延伸：wayfinder 規劃一張決策地圖並明說「一個 session 只解一張票」，本 skill 處理它排除的那半——**多條線同時在解票**。

凍結版（244 行，`md5 = 1e5591bcdd36357b6dc86e8bb2f7fcc9`）是本次唯一來源。已查證本機那份此刻與凍結版逐字相同，無第二版漂移。

現況兩個問題：

1. skill 完全不在 chezmoi source；`dev-workflow` 的 SKILL.md 有違規本機編輯（`chezmoi status` = `MM`），下次 apply 會蓋掉。
2. 內容混了三層綁定，掃描結果：agent-bound 8 處、deploy-bound 5 處、project-bound 5 處。

## Goals / Non-Goals

**Goals:**

- 讓正本轉移到 chezmoi source，本機那份改由 apply 回填。
- 修好 `dev-workflow` 的違規編輯，且 Codex 渲染出來不得有裸的 skill 名。
- 讓 skill 換 repo、換 merge 平台、換 agent kind 之後**不會靜默失效**。

**Non-Goals:**

- 不改 skill 的論點、不刪任何一條規則。重構只動**位置**與**前提的顯性程度**。
- 不刪來源軼事。`D294` 回收、8／7／10→9 那些是**證據**，不是要照做的設定。
- 不引進 wayfinder skill 本身（見 `2026-08-17-grill-fog-of-war` 的裁決：它需要 issue tracker 當正典，與既有兩個正典衝突）。
- 不處理本機那份日後可能出現的第二版改動——那不屬於這份交辦。

## Decisions

### D1: 分層判準是「換掉底層會不會靜默失效」，不是「聽起來抽不抽象」

一句話進附錄的條件：**換一個 repo、換一個 merge 平台、或換一個 agent kind 之後，它會變成錯的，而且沒有東西會報錯。**

這個判準比「抽象 vs 具體」好用，因為它可測：對每一句問「`merge_method` 不是 `ff` 的 repo 上這句還對嗎」「Codex 上這句還對嗎」。答案是否的就帶前提或搬走。

替代方案:以「有沒有出現專有名詞」分。否決——`D294` 那個軼事有專有名詞但完全不會失效（它是過去發生的事，不是現在的設定）；而「不要輪詢 CI」沒有專有名詞卻綁死了 auto-merge 的存在。專有名詞與綁定程度沒有相關性。

### D2: 軼事留在主體，設定進附錄

**軼事是時間戳記的事實**（「2026-08-21 三條線各報 8／7／10」），換平台不會讓它變假；**設定是現在式的宣告**（「`merge_method=ff` 的 repo 上 dev 一動就 need_rebase」），換平台就變假。

所以留下軼事、把設定帶上前提，是兩件不同的事，不能一起處理。協調者自己也判斷〈跨線事實〉那節是全篇唯一無法從別處推導的內容——那節的價值**全在軼事**。

### D3: 三個 memory 指標拔掉，不是改寫

`ci-gate-and-draft-trap`、`one-handoff-one-session`、`session-display-names` 是雙重綁定：既是 Claude 的 memory 定址慣例（`~/.claude/memory/<repo-slug>/<slug>.md`），又只存在於 `mms_product_grouping_api`。Codex 的 store 是 `~/.codex/memories/` 平的一層，三個 slug 一個都沒有。

**拔掉而非改寫的理由**：三處的操作性事實本來就已內聯（第 111-121 行講完了 auto-merge 被取消、第 155 行講完了一段 handoff 一個 session、第 42 行給了完整的三層同名指令行）。指標只提供 provenance，而 provenance 指向一個大多數 repo 到不了的地方。

替代方案:改成「見 mms_product_grouping_api 的 memory」。否決——那讓一份跨 repo 的 skill 永久指向某個特定 repo，等於把綁定寫死而不是解開。替代方案:改成「見你這個 repo 的 memory（若有）」。否決——除了那一個 repo 以外每個 repo 都指向不存在的東西，是把懸空引用包裝成條件句。

### D4: 兩邊都做 Codex 版，因為 herdr 不是 Claude 專屬

`herdr agent start --kind` 支援 21 種 agent（`pi, claude, codex, gemini, cursor, ...`），協調機制本身與 agent kind 無關。真正 Claude 專屬的只有**改名那一族**：`/rename`、`-n`、`--remote-control` 是 Claude CLI 旗標，以及 Claude Code pane 的方向鍵／多題選單行為。

所以 `--kind claude` 參數化為 `{{ .n.agentKind }}`，改名那節走 per-tool gap 字串——與共用 body 既有的 `teamDoc`／`teamDocGap` 同構，不發明新寫法。

### D5: `dev-workflow` 新節維持英文

共用 body 全篇英文，新節照舊。`workflow-instructions` 的〈文件語言為中文〉requirement 只約束全域 CLAUDE.md，不及於此。

## Risks / Trade-offs

- **[重構動到結構，與協調者本機那份分岔]** → 凍結版是唯一來源、md5 已核對；完成後正本轉移到 chezmoi source，並主動回報協調者實際改了什麼，讓它知道之後的本機改動不會自動進 source。
- **[附錄被讀成「可以略過的部分」，機制細節失效]** → 附錄標題寫明它是**前提**不是補充；主體引用附錄處直接點名。
- **[拔掉 memory 指標後 provenance 消失]** → 軼事本身帶日期與情境，且 skill 內文已內聯操作性事實；真要追來源，`~/.agent/handoffs/` 那條線的 handoff 仍在。
- **[Codex 端沒有 herdr 或行為不同]** → 已查證 `--kind codex` 是支援值；附錄的改名那節以 gap 字串標明 Claude 專屬，Codex 渲染不會指向不存在的旗標。
- **[本機 target 已存在，apply 衝突]** → `coordinating-lines` 目前是 unmanaged，納入後首次 apply 會以 source 覆蓋 target；已確認本機那份與凍結版逐字相同，覆蓋不損失內容。

## Open Questions

(無)
