---
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git show:*), Bash(gh pr:*), Bash(git branch:*)
description: 型別設計 review — 封裝、不變量表達、型別安全
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

- **subagent_type**: `pr-review-toolkit:type-design-analyzer`
- **Prompt**: 包含完整 diff，分析新增或修改的型別定義，重點關注：
  - **封裝** — 型別是否正確隱藏內部實作？是否暴露了不該暴露的細節？
  - **不變量表達** — 型別系統是否能在編譯期阻止無效狀態？
  - **實用性** — 型別是否易於使用？API 是否直觀？
  - **強制性** — 不變量是否靠紀律維持（fragile）還是靠型別系統強制（robust）？

## Output

根據 agent 回饋，產出以下格式報告：

---

**Type Design Review**

**Scope**: [reviewed what]
**Types analyzed**: [list of type names]

For each type:

**`TypeName`**
- Encapsulation: [score/5] — [assessment]
- Invariant Expression: [score/5] — [assessment]
- Usefulness: [score/5] — [assessment]
- Enforcement: [score/5] — [assessment]
- Recommendations: [specific improvements]

**Overall Assessment**
[summary of type design quality and key recommendations]

---

## Guardrails

- **不修改程式碼** — 純粹的 review
- **完整 diff** — agent 要收到完整 diff
- **僅分析型別** — 只聚焦在型別設計，不評論其他程式碼品質問題
- **無新型別時** — 如果 diff 中沒有新增或修改型別定義，直接告知使用者
