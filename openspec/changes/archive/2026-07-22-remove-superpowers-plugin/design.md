## Context

這是 dev-workflow rework 的兩階段 plugin 處置(原始 design D7)之第二階段。第一階段(已於 commit 9102f18/56fa59f 完成)解除 superpowers plugin 與 dev-workflow 的接線;第二階段驗證 episodic-memory 獨立性後移除 plugin 本體。

驗證結果(load-bearing):
- `superpowers@claude-plugins-official` 與 `episodic-memory@superpowers-marketplace`、`elements-of-style@superpowers-marketplace` 來自**不同 marketplace**。
- episodic-memory 自帶 `hooks/hooks.json`,SessionStart sync 指令為 `node "${CLAUDE_PLUGIN_ROOT}/cli/episodic-memory.js" sync --background`,plugin-relative,不觸及 superpowers plugin。
- superpowers plugin **無 hooks 目錄**,對 `~/.config/superpowers/conversation-archive/` 零引用。
- 自家 discipline skills 全在 `~/.claude/skills/`(chezmoi 部署),不受 plugin 移除影響。

## Goals / Non-Goals

**Goals:**
- 停止在新機器安裝 superpowers plugin。
- 移除 §8 過渡護欄與 docs 中的暫留說明。
- 本機實際 uninstall 並驗證 episodic-memory 不受影響。

**Non-Goals:**
- 移除 `obra/superpowers-marketplace`(episodic-memory + elements-of-style 仍依賴,必留)。
- 清理 docs plugin 表中既有的其他 spec drift(多列 official plugins 未同步於 enabledPlugins)—— 屬另案。
- 改動自家 discipline skills。

## Decisions

- **保留 marketplace add,只移除 plugin install**:episodic-memory / elements-of-style 由該 marketplace 供應,marketplace 必留;移除的僅是 line 24 的 `claude plugin install superpowers`。
- **保留 cache cleanup `rm -rf .../superpowers-marketplace/superpowers`**:marketplace clone 可能帶入 superpowers 原始碼子目錄;停止安裝後,此防禦性清理反而更必要,避免殘留的 marketplace superpowers 陰影載入 skills。措辭不改。
- **本機 uninstall 走 runtime 而非 chezmoi**:`enabledPlugins` 由 `modify_settings.json.sh.tmpl` 明確保留(不 hard-assign),故移除須用 `claude plugin uninstall`,chezmoi 不管這塊。
- **test-first 順序**:依專案 CLAUDE.md,先本機 uninstall + 驗證 episodic-memory,確認無誤再定稿 repo 檔案。

## Risks / Trade-offs

- [本機 uninstall 後當前 session 仍持有已載入的 `superpowers:*` skills] → 影響僅限「下個 session 起這些 skills 消失」,且它們已廢棄,無實質風險。
- [marketplace clone 未必產生 superpowers 子目錄,cleanup 可能 no-op] → `rm -rf ... 2>/dev/null || true` 本就冪等,保留無害。
- [遺漏 `~/.claude/CLAUDE.md` §8(全域,dotfiles 外)] → 明確列入 tasks,單獨手動處理。

## Migration Plan

1. 本機 `claude plugin uninstall superpowers@claude-plugins-official`。
2. 驗證 episodic-memory sync/search 正常。
3. 定稿 repo 檔案(install scripts / user-system-prompt / docs)。
4. `chezmoi apply` 確認腳本冪等、無非預期 diff。
- Rollback:`claude plugin install superpowers` 即復原;repo 變更 git revert。

## Open Questions

（無)
