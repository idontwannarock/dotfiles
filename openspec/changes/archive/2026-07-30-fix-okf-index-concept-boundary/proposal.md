## Why

前一個 change（`2026-07-30-add-okf-frontmatter-to-agent-reference`）新增了一條 normative 需求：`index.md` 只放路由，知識 SHALL 置於具名 concept 檔。但同一個 commit 沒有把這條判準施加到 `bare-worktree/index.md` —— 它的 `## Scope` 段（`.git` vs `.bare` dispatch 規則、2×2 layout×discipline 分析、以及「若出現未填的格子就 rename 成 `git-layouts/<arch>/`」的前瞻決定）正是 agent 會當答案引用的知識。**該 commit 違反了它自己剛加的規範**，且與 `local-files/index.md` 的處置不一致。

同時 spec 的 root-index scenario 斷言「列出三個子目錄」，實作卻直接連 `tdd/` 底下兩個檔 —— 這是 sync 後的 spec drift。

## What Changes

- `bare-worktree/index.md` 的 `## Scope — why only this one architecture` 段搬到新檔 `bare-worktree/scope.md`（`type: Reference`），`index.md` 只留 scope 一句話摘要 + 「When to read which file」路由表。
- 修正 root-index scenario 的措辭以符合實作，並寫明規則：**有 `index.md` 的目錄連目錄，沒有的連檔案**。不新增 `tdd/index.md`（兩個檔再包一層 index 正是前一個 change 的 design.md 自己警告的過度拆分）。
- 修正前一個 commit 的 message：移除「root index 讓 `tdd/` 與 `dev-workflow-isolation.md` 變可發現」的宣稱。root index 目前**沒有任何 inbound pointer**，它成立的理由只有一個：OKF §12 規定 `okf_version` 只能放在 bundle-root `index.md`。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `agent-reference-layout`: 修正兩處。「index.md 為 reserved filename」需求補上 `bare-worktree/` 的 scenario 與「連目錄 vs 連檔案」規則；root-index scenario 的斷言改為與實作一致。

## Impact

- `home/dot_agent/reference/bare-worktree/index.md`（縮減）、`home/dot_agent/reference/bare-worktree/scope.md`（新增）。
- `openspec/specs/agent-reference-layout/spec.md`。
- 前一個 commit 的 message（`git commit --amend`，尚未 push 故無 rewrite 風險）。
- **不影響** inbound pointer：`user-system-prompt.md` 與 `worktree`／`dev-workflow` skill 指向的 `bare-worktree/index.md`、`operating.md`、`claude-state.md` 路徑全部不變。
- **明確不做**：把 root index 接進各 tool 的 prompt。那會改變每個 session 的載入行為與 token 成本，是獨立的設計題。
