# Tasks: rework-dev-workflow-skills

切片依循新慣例:每節為 tracer-bullet 垂直切片(body + 雙工具 wrapper + 渲染驗證一次到位),1-5 互相獨立,6 blocked by 1-5,7 獨立,8 blocked by 全部。

## 1. grill skill

- [x] 1.1 建 `home/.chezmoitemplates/skills/grill.md`,內容照 design.md 附錄核可全文(訪談規則、stop-gate、產出去向)
- [x] 1.2 建 Claude wrapper `home/dot_claude/skills/grill/SKILL.md.tmpl`:frontmatter(name、description 含觸發語)+ name-map dict + `{{ template "skills/grill.md" ... }}`
- [x] 1.3 建 Codex wrapper `home/dot_codex/skills/grill/SKILL.md.tmpl`(YAML description 含冒號必須加引號 — Codex 嚴格模式)
- [x] 1.4 `chezmoi execute-template` 驗證兩邊渲染無誤

## 2. tdd skill

- [x] 2.1 建 `home/.chezmoitemplates/skills/tdd.md`(design.md 附錄骨架)+ references 依 agent-reference-layout spec 放 `home/dot_agent/reference/tdd/{tests,mocking}.md`(跨工具共用、不重複部署)
- [x] 2.2 建 Claude / Codex wrappers(body 指向 ~/.agent/reference/tdd/)
- [x] 2.3 渲染驗證

## 3. diagnose skill

- [x] 3.1 建 `home/.chezmoitemplates/skills/diagnose.md`(六 phases;feedback-loop 硬 gate)
- [x] 3.2 建 Claude / Codex wrappers
- [x] 3.3 渲染驗證

## 4. verify-done + worktree skills

- [x] 4.1 建 `home/.chezmoitemplates/skills/verify-done.md`(證據先於宣稱,~10 行,取材 verification-before-completion 核心)
- [x] 4.2 建 `home/.chezmoitemplates/skills/worktree.md`:ARCH 偵測 → normal 用 `git worktree add`、bare 用 `git --git-dir=.bare worktree add -b <branch> <dir> main` → 登記 active_workflows;隔離判斷指向 `~/.agent/reference/dev-workflow-isolation.md`
- [x] 4.3 建兩 skill 的 Claude / Codex wrappers,渲染驗證

## 5. finish-branch skill

- [x] 5.1 建 `home/.chezmoitemplates/skills/finish-branch.md`:驗證通過 → 選項(本地 merge / push+PR / 保留 / 丟棄)→ normal arm(checkout base + merge)/ bare arm(rebase → 從 `main/` worktree `--ff-only` merge → 處置 worktree+branch)→ 移除 active_workflows 列;內容吸收 `~/.agent/reference/bare-worktree/operating.md` 的 finishing 段
- [x] 5.2 建 Claude / Codex wrappers,渲染驗證

## 6. dev-workflow body 改寫(blocked by 1-5)

- [x] 6.1 改 `home/.chezmoitemplates/skills/dev-workflow.md`:Large 流程換 grill、apply 步驟註明可測 seam 套 tdd、verify-done 取代 verification、finish-branch 取代 finishing;Small 流程換 finish-branch;移除 writing-plans 條件步驟
- [x] 6.2 新增 bug 進入點段(diagnose 先行,根因 → proposal.md Why)與 tasks.md 切片慣例段(~5 行)
- [x] 6.3 dispatch table:New-branch workspace 列改用 `worktree` skill;Finishing 特例列刪除(finish-branch 原生雙架構)
- [x] 6.4 更新 Claude / Codex 兩邊 wrapper 的 name-map:新增 grill/tdd/diagnose/verifyDone/worktree/finishBranch tokens,移除 brainstorm/writingPlans/verification/finishing/worktrees(superpowers)tokens;渲染驗證兩邊 sigil 正確
- [x] 6.5 檢查 `~/.agent/reference/dev-workflow-isolation.md` 與 `bare-worktree/*.md` 中的 superpowers skill 名稱引用,改為新 skill 名(chezmoi source:`home/dot_agent/reference/`)

## 7. 依賴清除(獨立)

- [x] 7.1 移除機器本地 `~/.agent/bin/install-superpowers-codex.sh`(從未在 chezmoi source;rm + `.chezmoiremove` 跨機清除)
- [x] 7.2 `home/.chezmoitemplates/user-system-prompt.md`:刪 §8 全段(superpowers 文件改道);§7 刪 finishing override 段(保留 bare-worktree 通用指引)
- [x] 7.3 本機清理 `~/.codex/skills/` superpowers symlinks — 實測本機不存在(no-op);installer 改列 `.chezmoiremove` 跨機清除

## 8. Apply + 驗證 + 文件(blocked by 全部)

- [x] 8.1 `chezmoi apply`;確認 `~/.claude/skills/` 與 `~/.codex/skills/` 各出現 6 個新 skill、dev-workflow 已更新、無 superpowers 引用殘留(grep 驗證)
- [x] 8.2 Claude 端實測:apply 後本 session 六個新 skill 全部註冊、描述正確;Codex 端待使用者以 `$dev-workflow` 抽查
- [x] 8.3 更新文件:README 或 `docs/` 對應頁記錄新 workflow 與六個 skill(依 repo 慣例)
- [x] 8.4 `openspec validate rework-dev-workflow-skills --strict`
