## Context

superpowers plugin 在 `rework-dev-workflow-skills` 已被自家 discipline skills 取代,`2026-07-22-remove-superpowers-plugin` 接著移除了安裝指令。但該 change 的 Decisions 明確寫道「本機 uninstall 走 runtime 而非 chezmoi」— uninstall 是執行者手動跑的一次性動作,不在 `chezmoi apply` 的收斂範圍內。plugin 的安裝狀態存在 Claude Code 自己的 `~/.claude/plugins/installed_plugins.json` 與 `settings.json` 的 `enabledPlugins`,不是 chezmoi 管理的檔案 — chezmoi 無從 declare 它的消失。

本機稽核結果(已驗證):

- `superpowers@claude-plugins-official` v6.2.0 仍安裝,`installedAt` 停留在 2026-05-17(未經 uninstall/reinstall 循環),`lastUpdated` 隨 Claude Code 每次啟動更新 → 該機器從未收到前次 change 的手動 uninstall
- 腳本第 67 行(`.sh`)/ 第 51 行(`.ps1`)清理 `superpowers-marketplace/superpowers`。實測 marketplace clone 僅含 `.claude/`、`.claude-plugin/`、`LICENSE`、`README.md`,cache 下僅 `elements-of-style/` 與 `episodic-memory/` — 該行為 no-op,但依 archived design 是**刻意的防禦性清理**(防 marketplace clone 帶入 superpowers 原始碼子目錄陰影載入 skills),非筆誤
- plugin 實際殘留在 `claude-plugins-official/superpowers`(4.2 MB),無任何清理涵蓋
- **使用者回報的「chezmoi update 後仍看到 superpowers plugin 更新」確為 chezmoi 所致**:`run_update-claude-plugins.{sh,ps1}.tmpl` 是 `run_` 前綴,每次 apply/update 都跑,讀 `settings.json` 的 `enabledPlugins` 逐個 `claude plugin update`。superpowers 仍列於 `enabledPlugins`,因此每次 apply 都被更新一次
- `~/.claude/commands/opsx/workflow.md` 為 unmanaged 孤兒,內文 10 處引用 `superpowers:*` skill
- episodic-memory **不依賴** superpowers plugin — 它只是共用 `~/.config/superpowers/` 這個 XDG 資料目錄名(`src/paths.ts:88-103`),MCP server 與 SessionStart hook 皆自帶

## Goals / Non-Goals

**Goals:**
- 讓 `chezmoi apply` 在所有機器上收斂到「superpowers plugin 不存在、其 cache 不存在」— 把前次 change 的一次性手動步驟固化為可傳播的腳本
- 增補涵蓋 `claude-plugins-official/superpowers` 的 cache 清理
- 跨機器清除退役的 `opsx:workflow` command

**Non-Goals:**
- 移除 `obra/superpowers-marketplace` marketplace 註冊 — episodic-memory 與 elements-of-style 依賴它
- 為 `writing-skills`、`subagent-driven-development`、`dispatching-parallel-agents` 這三個無替代的 skill 補寫自家版本(獨立議題)
- 把 `dot_claude/commands` 改為 `exact_commands`

## Decisions

**[以 `claude plugin list` 前置判斷,而非無條件 uninstall]**
腳本是 `set -euo pipefail`,且 uninstall 一個不存在的 plugin 會非零退出。無條件執行需靠 `|| true` 吞掉,但那會連同真正的失敗一起吞。改為先 `claude plugin list` grep,命中才 uninstall — 與腳本現有的 `explanatory-output-style` / `learning-output-style` 處理手法一致,沿用既有慣例。

替代方案:直接 `claude plugin uninstall ... || true`。較短,但在 plugin 尚在卻 uninstall 失敗時靜默通過,留下不一致狀態且無訊息。捨棄。

**[cache 清理與 uninstall 分開兩步]**
`claude plugin uninstall` 會清 `installed_plugins.json` 與 `settings.json` 的 `enabledPlugins`,但**不刪** cache 目錄。兩者是獨立狀態,所以 uninstall 之後仍需顯式 `rm -rf`;且 cache 清理必須無條件執行(冪等),涵蓋「plugin 早已 uninstall、cache 卻殘留」的機器。

**[增補而非取代既有的 marketplace cache 清理]**
既有的 `rm -rf .../superpowers-marketplace/superpowers` 實測為 no-op,但 archived design 記載它是防 marketplace clone 帶入 superpowers 原始碼子目錄的防禦性清理。上游 marketplace 佈局隨時可能改變,移除它等於拆掉一道還在守的護欄卻只省一行。改為在其旁增補 `claude-plugins-official/superpowers` 一行,兩者並存。

替代方案:把該行改指 `claude-plugins-official`。省一行,但犧牲既有防禦且違背前次 change 的明示決定。捨棄。

<!-- evergreen-candidate -->
**[命令式 `run_*` 腳本的副作用需顯式反轉]**
chezmoi 的宣告式模型只涵蓋它 declare 的檔案。`run_*` 腳本造成的系統狀態(套件安裝、plugin 註冊、外部 CLI 的設定)不在其中 — 刪掉腳本裡的一行 install 不會反轉它過去的副作用。退役任何由 `run_*` 安裝的東西時,必須補一段冪等的反安裝,或在 `.chezmoiremove` 中宣告;否則已套用過的機器會永久漂移。

**[不改動 `run_update-claude-plugins`,靠 uninstall 清空 `enabledPlugins` 收斂]**
該腳本以 `enabledPlugins` 為單一事實來源,不維護自己的 plugin 清單 — `claude plugin uninstall` 移除該鍵後,update loop 自然不再碰它,無需在腳本裡加黑名單。

執行順序是 load-bearing:chezmoi phase 3 內按檔名字母序,`install-03-claude-config`(uninstall)排在 `update-claude-plugins`(update loop)之前,因此同一次 apply 會先移除、後續 loop 已看不到該 plugin。若順序相反,每台機器會多下載一次才移除 — 僅浪費一次頻寬,不影響正確性,故不額外加前綴強制排序。

**[孤兒 command 走 `.chezmoiremove` 而非改用 `exact_commands`]**
`dot_claude/commands` 是非 `exact_` 目錄,所以 source 中不存在的檔案不會被修剪 — 這正是 `opsx/workflow.md` 存活至今的原因。改為 `exact_` 能根治,但會讓所有機器上任何非 source 的 `~/.claude/commands/` 檔案被靜默刪除(例如同樣未受管的 `ensure-openspec.md`),blast radius 遠超本次範圍。改用 `.chezmoiremove` 點名單一路徑,與 repo 既有慣例一致。

## Risks / Trade-offs

**[`run_onchange_` 內容變更 → 所有機器重跑整支腳本]** → 腳本本身各段皆為冪等(marketplace add、plugin install、jdtls 存在性檢查、MCP `mcp_add_if_missing`),重跑僅產生 log 噪音,無副作用。

**[uninstall 失敗導致後續步驟中斷]** → 前置 `claude plugin list` 判斷 + 沿用既有 `|| true` 於 uninstall 本身,失敗時仍繼續執行 jdtls / MCP / episodic-memory 修復段。

**[使用者機器上仍有引用 `superpowers:*` 的個人 command]** → `.chezmoiremove` 只處理已知的 `opsx/workflow.md`;其他未受管檔案不在 chezmoi 視野內,本次無法涵蓋,屬已知限制。

**[既有的 `rm -rf ... && echo` 訊息為假陽性]** → `rm -rf` 對不存在的路徑仍 exit 0,故 `&& echo "Removed marketplace superpowers"` 每次 apply 都印,即使什麼都沒刪。新增的 `claude-plugins-official` 清理改用 `[ -d ]` 前置判斷(與 `.ps1` 的 `Test-Path` 語義一致)避免重蹈;既有那行屬本次範圍外的既存問題,未改動,已回報使用者。

**[`.ps1.tmpl` 無法於本機驗證]** → 此機器無 pwsh/powershell,且 template 的 `{{ if eq .chezmoi.os "windows" }}` 守衛使其在 Linux 渲染為空。新增區塊為既有 working block(`learning-output-style` uninstall、marketplace cache `Test-Path`)的逐字複製僅換名稱,語法風險低,但實際執行待 Windows 機器 apply 時確認。

**[三個無替代的 skill 消失]** → `writing-skills`、`subagent-driven-development`、`dispatching-parallel-agents` 移除後無對應自家版本。已與使用者確認接受,列為後續獨立議題。

## Migration Plan

1. 本機已手動執行並驗證(uninstall + cache 清除 + 孤兒刪除)— 本 change 只是把它固化成跨機器可重現的腳本
2. 其他機器於下次 `chezmoi apply` 時,因腳本內容變更觸發 `run_onchange_` 重跑,自動收斂
3. Rollback:`claude plugin install superpowers@claude-plugins-official` 可還原 plugin;`opsx/workflow.md` 內容保留在 git 歷史的 `openspec/changes/archive/` 與本次備份中
