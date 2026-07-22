# Tasks

## 1. grill 讀 project.md + 標記長青候選
- [x] 編輯 `home/.chezmoitemplates/skills/grill.md`:於 `## 規則` 加「訪談開場讀 `openspec/project.md`(若存在)當 grounding」;於 `## 產出去向` 加第四去向「長青候選(domain 詞彙/反覆適用原則)→ 以 `<!-- evergreen-candidate -->` 標記進 design.md `## Decisions`,明確不寫 project.md」
- [x] 驗證:純文字段落,無新增 `{{ .n.* }}` token

## 2. dev-workflow sync/archive 晉升步驟
- [x] 編輯 `home/.chezmoitemplates/skills/dev-workflow.md`:Small 與 Large 兩條 flow 的 `openspec-sync-specs` 步驟加註「晉升 design.md 長青候選進 openspec/project.md」;可加一段短說明點出晉升閘門(對照 shipped、只升反覆適用原則)
- [x] 驗證:僅改純文字,既有 `{{ .n.* }}` token 不動

## 3. 部署與驗證(blocked by #1, #2)
- [x] `chezmoi apply`(先本機測)
- [x] 確認 `~/.claude/skills/grill/SKILL.md`、`~/.codex/skills/grill/SKILL.md` 含新段落;`~/.claude/skills/dev-workflow/SKILL.md`、Codex 對應檔含晉升步驟
- [x] name-map 回歸:render 全 wrappers、grep 無 no-value 標記(chezmoi-author guard)
- [x] `openspec validate add-project-context-doc` 通過
