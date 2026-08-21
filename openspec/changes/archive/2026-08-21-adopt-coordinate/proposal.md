## Why

兩個問題，一個是遺失風險，一個是設計缺陷。

**遺失風險**：`coordinate` 這支 skill 只存在於本機 `~/.claude/skills/`，chezmoi 完全不知道它存在；而 `dev-workflow` 的 SKILL.md 被**直接改在 target 上**（`chezmoi status` 顯示 `MM`），它是 chezmoi 管的檔案，**下一次 `chezmoi apply` 會把那段改動蓋掉**。

**設計缺陷**：凍結版把三層不同性質的東西寫在同一份宣稱跨 repo 的檔案裡——agent 專屬（8 處）、部署平台專屬（5 處）、來源 repo 專屬（5 處）。其中 `memory` 指標是**雙重懸空**：`ci-gate-and-draft-trap` 等三個 slug 是 `mms_product_grouping_api` 的 repo-scoped memory，而 Claude 與 Codex 的 memory store 各自獨立（Codex 是 `~/.codex/memories/` 平的一層），那三個 slug 在 Codex 端一個都不存在。

這個缺陷剛好是這支 skill 自己定義的失敗族群：它有一整節〈認得「複寫了別處的事實」這一族〉，判準是**「讓它去數，不要讓它記」**，而它自己把 GitLab 專案設定、來源 repo 的 D 號段、Claude 的 memory slug 全部抄了進來。來源一改（換 repo、換平台、換 agent），這份不會知道，失效是靜默的。

## What Changes

- **新增 `coordinate` skill**，以 chezmoi shared body + per-tool name-map wrapper 部署，Claude 與 Codex 兩邊都有（同 `dev-workflow` 的既有結構）。
- **內容重構為兩層**：主體是**平台中立的協調原則**；平台／工具相依的機制收進**附錄**。判準是「換一個 repo、換一個 merge 平台、換一個 agent kind，哪些句子會靜默失效」——會的進附錄並標明前提，不會的留主體。
- **拔掉三個 memory 指標**。三處的操作性事實本來就已內聯在 skill 內文（auto-merge 被取消、一段 handoff 一個 session、三層同名的完整指令行），指標移除不損失可執行內容。
- **`dev-workflow` 的本機編輯移進共用 body 並參數化**：新增一節 `## When this line is one of several (coordinated mode)`（line-side contract），寫死的 `finish-branch` 與 `coordinate` 改走 name-map。
- **兩份 name-map 各新增 key**：`coordinate`（Claude `coordinate`／Codex `$coordinate`）。

**BREAKING**: 無。既有 skill 的行為契約與 `dev-workflow` 原有流程全部不動。

## Capabilities

### New Capabilities

(無 — `coordinate` 的部署與行為契約併入既有的 `discipline-skills`)

### Modified Capabilities

- `discipline-skills`: 跨工具部署 requirement 由六支 skill 擴為七支；新增 `coordinate` 的行為契約（協調者角色、兩層結構、不得指向 repo-scoped memory）。
- `workflow-instructions`: 新增 coordinated mode 的 line-side contract requirement（對協調者的回報義務、跨線事實即時回報、可推翻前提、finish-branch 四訊號）。

## Impact

- 新增 `home/.chezmoitemplates/skills/coordinate.md`（共用 body）
- 新增 `home/dot_claude/skills/coordinate/SKILL.md.tmpl`、`home/dot_codex/skills/coordinate/SKILL.md.tmpl`
- 修改 `home/.chezmoitemplates/skills/dev-workflow.md`（+1 節）
- 修改 `home/dot_claude/skills/dev-workflow/SKILL.md.tmpl`、`home/dot_codex/skills/dev-workflow/SKILL.md.tmpl`（各 +1 name-map key）
- 修正 `~/.claude/skills/dev-workflow/SKILL.md` 的違規本機編輯（改動移進 source 後由 apply 回填）
- 不影響 `grill`、`tdd`、`diagnose`、`verify-done`、`worktree`、`finish-branch` 的既有內容
