---
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git show:*), Bash(gh pr:*), Bash(git branch:*)
description: 快速 code review — 單一 code-reviewer agent
---

## Context

- Status: !`git status --short`
- Branch: !`git branch --show-current`

## Review Scope

取得完整 diff，依照以下順序判斷：

1. `$ARGUMENTS` 是數字 → `gh pr diff $ARGUMENTS`，同時 `gh pr view $ARGUMENTS --json title,author,baseRefName,headRefName,url`
2. `$ARGUMENTS` 是 URL（含 `/pull/`）→ `gh pr diff "$ARGUMENTS"`，同時取得 PR 資訊
3. `$ARGUMENTS` 包含 `..` → `git diff $ARGUMENTS`
4. `$ARGUMENTS` 是其他字串 → `git diff main...$ARGUMENTS`
5. 無引數，有 staged changes → `git diff --cached`
6. 無引數，有 unstaged changes → `git diff`
7. 無引數，clean working tree → `git show HEAD`

## Task

取得 diff 後，使用 **Task tool** 啟動 1 個 agent：

- **subagent_type**: `pr-review-toolkit:code-reviewer`
- **Prompt**: 包含完整 diff，請 review 程式碼品質、風格一致性、最佳實踐、潛在 bug、命名慣例

## Output

根據 agent 回饋，產出以下格式報告：

---

**Quick Review**

**Scope**: [reviewed what]
**Diff size**: [N files changed, +X/-Y lines]

🔴 **Critical Issues** (must fix)
- [issue]

🟡 **Suggestions** (should consider)
- [suggestion]

🟢 **Good Practices** (well done)
- [positive observation]

---

## Guardrails

- **不修改程式碼** — 純粹的 review
- **完整 diff** — agent 要收到完整 diff
- **無發現時** — 簡短說明即可
