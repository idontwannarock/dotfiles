## 1. 改動共用 body

- [x] 1.1 在 `home/.chezmoitemplates/skills/grill.md` 的 `## 規則` 中,緊接「一次只問一題」之後,加入未決問題的 `blocked by` 宣告與「優先問沒被擋住的」提問順序(D4、D5)
- [x] 1.2 在同檔 `## 產出去向` 加入「尚未釐清」分流路徑:記錄條件、共識確認時的三選一裁決、去向為 `design.md` 的 `## Open Questions`、明示不構成 gate(D1、D2、D3)
- [x] 1.3 確認兩個 wrapper(`home/dot_claude/skills/grill/SKILL.md.tmpl`、`home/dot_codex/skills/grill/SKILL.md.tmpl`)無需改動——body 新增內容未引入任何工具專屬 token

## 2. 驗證

- [x] 2.1 `chezmoi execute-template` 或 `chezmoi diff` 限縮到 grill 子樹,確認 Claude 與 Codex 兩份 render 結果都含新內容且格式正確
- [x] 2.2 檢查 Codex wrapper 的 YAML frontmatter 仍為 strict-YAML 合法(description 內含冒號須引號包覆)
- [x] 2.3 限縮 `chezmoi apply` 至 `~/.claude/skills/grill` 與 `~/.codex/skills/grill`,不全量 apply
- [x] 2.4 `openspec validate --strict` 通過
