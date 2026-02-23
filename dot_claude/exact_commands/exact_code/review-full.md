---
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git show:*), Bash(gh pr:*), Bash(git branch:*)
description: 完整 code review — 平行派發 code-reviewer、silent-failure-hunter、test-analyzer、linus-torvalds
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

取得 diff 後，使用 **Task tool** 平行啟動以下 4 個 agent。每個 agent 的 prompt 都必須包含完整 diff。

| Agent | subagent_type | Prompt 重點 |
|-------|--------------|-------------|
| Code Reviewer | `pr-review-toolkit:code-reviewer` | 程式碼品質、風格一致性、最佳實踐、潛在 bug、命名慣例 |
| Silent Failure Hunter | `pr-review-toolkit:silent-failure-hunter` | 靜默失敗、錯誤處理不當、被吞掉的例外、不適當的 fallback |
| Test Analyzer | `pr-review-toolkit:pr-test-analyzer` | 測試覆蓋率、缺少的邊界案例、測試品質與可維護性 |
| Linus Torvalds | `linus-torvalds` | 架構簡潔性、不必要的複雜度、good taste、特殊案例是否能消除、向後相容性 |

## Output

等待所有 agent 完成後，彙整回饋產出以下格式報告：

---

**Code Review Report**

**Scope**: [reviewed what — PR #N / staged changes / branch diff / HEAD]
**Diff size**: [N files changed, +X/-Y lines]

**Summary**: [一句話總結整體品質與最重要的發現]

🔴 **Critical Issues** (must fix)
- [issue description] — _source: [agent name]_

🟡 **Suggestions** (should consider)
- [suggestion description] — _source: [agent name]_

🟢 **Good Practices** (well done)
- [positive observation]

**Details by Perspective**

_Code Quality_ (code-reviewer)
...

_Error Handling_ (silent-failure-hunter)
...

_Test Coverage_ (test-analyzer)
...

_Architecture & Simplicity_ (linus-torvalds)
...

---

## Guardrails

- **不修改程式碼** — 這是純粹的 review，不改任何檔案
- **完整 diff** — 每個 agent 都要收到完整 diff，不要摘要或截斷
- **大型 diff** — 超過 500 行變更時，在報告開頭提醒使用者可考慮拆分 review
- **無發現時** — 如果某個 agent 沒有發現問題，簡短說明即可，不要硬湊
