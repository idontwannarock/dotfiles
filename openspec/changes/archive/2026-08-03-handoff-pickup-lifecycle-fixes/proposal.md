## Why

`handoff` / `pickup` 這對 skill 已是跨 session、跨工具、跨 repo 的主要交接管道,`~/.agent/handoffs/` 目錄同時被當待辦清單使用。但它目前有六個缺陷,其中三個已造成真實事故:

- 2026-07-31:一個 ai-toolkit session 要把修正交給 dotfiles,照 `handoff.md:39` 指向的作廢路徑寫檔,靜默孤兒化,隔天 `/pickup` 完全找不到。
- 2026-08-03:一個 session 拿 slug 字面相似度判定 5 份 handoff「全部已完成」並當場 `rm`,其中 2 份根本沒開始做。
- 2026-08-03:兩份 handoff 初版都漏寫 `## Next steps` —— 唯一 load-bearing 的段落,而寫入端從未把它列為必要。

三者的共同病灶相同:**失敗是靜默的**。檔案寫得出來、找得到、讀起來完整,只有接手那一刻才發現無事可做,而那時原始上下文已經沒了。

第六個缺陷在本次調查中新發現:`~/.agent/handoffs/` 下 `shoalter-ai-toolkit` 有三個目錄、`hktv-product-category-classification-api-poc` 有一個 `-main` 尾綴目錄 —— 因為 slug 規則用 `git rev-parse --show-toplevel`,在 bare+worktree 佈局下回傳的是當前 worktree 而非 repo 容器,導致同一個 repo 的 handoff 依 worktree 分裂,互相看不見。

## What Changes

- **A —— 完成後封存步驟**:`pickup` 新增收尾步驟,`## Next steps` 逐條達成後列出證據並詢問使用者;經確認才將 handoff 移入 `<repo-slug>/archive/`。不刪除、不自行判定完成。封存步驟住在 handoff/pickup 這一對內,**不與 `finish-branch` 耦合**。
- **A' —— 新增 `handoff-list` skill**:列出未封存的 handoff(ID、日期、一行 Task、next steps 條數)。只列與標註,不推測完成與否、不動手。
- **B —— 修正作廢路徑**:`handoff.md:39` 的 `~/.claude/projects/<slug>/` 改為現行的 `~/.claude/memory/<id>/`。查證確認全 repo 6 處 `claude/projects` 引用中只有此處是錯的,其餘指涉舊路徑正確且必要,不動。
- **C —— 跨 repo 交接**:`handoff` 支援將檔案寫入其他 repo 的 handoff 目錄。目標 repo **只接受使用者明講**;agent 偵測到內容屬於別的 repo 時可以詢問,但 SHALL NOT 自行改變落點。header 拆為來源與目標兩欄,避免 `- Branch:` 記的是來源分支而誤導接手者。
- **D —— 必要段落契約上移到寫入端**:`handoff` 的 compose 段明文標示 `## Suggested skills` 與 `## Next steps` 為必要段落(含 `- None` 陷阱),並在寫檔前加自我檢查:兩段皆存在,且每條 next step 都帶可驗證的成功判準。
- **E —— resume 提示行帶語言**:`handoff` 記錄本次 session 使用的語言,resume 行 render 成 `/pickup <ID> in zh-tw`;英文 session 不加後綴。
- **F —— **BREAKING** repo slug 規則改為 `slug(dirname(realpath(git-common-dir)))`**:與 `context/glossary.md` 已記載的 auto-memory path-slug 規則對齊。normal 佈局結果不變;bare+worktree 佈局下所有 worktree 收斂到同一個容器 slug。同時遷移現有 4 個錯位目錄。

## Capabilities

### New Capabilities
- `session-handoff`: `handoff` / `pickup` / `handoff-list` 三個 skill 的行為契約 —— 落點與 repo slug 規則、必要段落、跨 repo 交接、語言標記、完成後封存、清單查詢,以及跨工具部署形狀。

### Modified Capabilities
<!-- 無。`arch-review` spec 以「沿用既有 handoff 約定」的引用方式描述 repo-slug 與段落規則,F 改的是被引用的規則本身,該 spec 的 requirement 不需變更。 -->

## Impact

**Shared body(source of truth,改一份雙工具生效)**
- `home/.chezmoitemplates/skills/handoff.md` —— B / C / D / E / F
- `home/.chezmoitemplates/skills/pickup.md` —— A / F
- `home/.chezmoitemplates/skills/handoff-list.md` —— 新增(A')

**Per-tool wrapper**
- `home/dot_claude/commands/handoff.md.tmpl` —— C 的 `--repo` 參數說明
- `home/dot_claude/commands/pickup.md.tmpl`
- `home/dot_claude/commands/handoff-list.md.tmpl` —— 新增
- `home/dot_codex/skills/{handoff,pickup,handoff-list}/SKILL.md.tmpl` —— 新增 handoff-list;frontmatter 須嚴格 YAML,含冒號的 description 必須加引號

**磁碟狀態(非 repo 內,需一次性遷移)**
- `~/.agent/handoffs/-home-howardwang-ws-github-shoalter-ai-toolkit-{main,add-agent-sessions-collector,add-self-service-portal}/` → 合併至 `-home-howardwang-ws-github-shoalter-ai-toolkit/`
- `~/.agent/handoffs/-home-howardwang-ws-hktv-tw-poc-hktv-product-category-classification-api-poc-main/` → 去尾綴

**不受影響**
- `finish-branch` —— A 明確不與其耦合
- `arch-review` —— 以引用方式沿用 handoff 約定,自動獲得 F 的修正
- `~/.agent/workflow-registry.md` —— C-2 不使用它
