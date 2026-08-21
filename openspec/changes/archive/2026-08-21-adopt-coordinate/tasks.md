## 1. coordinate 進 chezmoi source

- [x] 1.1 以凍結版為來源（先核對 `md5 = 1e5591bcdd36357b6dc86e8bb2f7fcc9`），建立共用 body `home/.chezmoitemplates/skills/coordinate.md`，內容重構為主體＋附錄兩層（D1、D2）
- [x] 1.2 拔掉三個 repo-scoped memory 指標，確認三處操作性事實仍內聯於內文（D3）
- [x] 1.3 agent 專屬處走 name-map／gap 字串：`--kind claude` → `{{ .n.agentKind }}`，改名那族 → per-tool gap（D4）
- [x] 1.4 建立兩份 wrapper：`home/dot_claude/skills/coordinate/SKILL.md.tmpl`、`home/dot_codex/skills/coordinate/SKILL.md.tmpl`，frontmatter 沿用凍結版的 name/description

## 2. dev-workflow 違規編輯移進 source

- [x] 2.1 把 `## When this line is one of several (coordinated mode)` 一節加進 `home/.chezmoitemplates/skills/dev-workflow.md`，位置在 `### tasks.md slicing conventions` 之後、`## Code Review Commands` 之前
- [x] 2.2 參數化該節：`finish-branch` → `{{ .n.finishBranch }}`，`coordinate` → `{{ .n.coordinate }}`；`active_workflows.md` 是檔名，保持原樣
- [x] 2.3 兩份 dev-workflow tmpl 的 name-map 各新增 `coordinate` key（Claude `coordinate`／Codex `$coordinate`）

## 3. 驗證

- [x] 3.1 四個 tmpl 全部 `chezmoi execute-template` 不報錯，各自 name-map 值出現在輸出裡
- [x] 3.2 渲染出來的 Claude 版 dev-workflow 新節與備份的本機版逐字相同（除刻意參數化處）
- [x] 3.3 Codex 版該節裡沒有裸的 `finish-branch`／`coordinate`；Codex 版 coordinate 裡沒有 Claude 專屬旗標
- [x] 3.4 兩份 coordinate wrapper 的 YAML frontmatter 通過 strict 解析（Codex 要求）
- [x] 3.5 限縮 `chezmoi apply` 至 coordinate 與 dev-workflow 四個 target；apply 後 `chezmoi status` 對它們乾淨
- [x] 3.6 `openspec validate --strict` 通過
