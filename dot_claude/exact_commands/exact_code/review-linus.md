---
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git show:*), Bash(gh pr:*), Bash(git branch:*)
description: Linus Torvalds 風格 review — 架構簡潔性、good taste、消除特殊案例、向後相容
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

- **subagent_type**: `linus-torvalds`
- **Prompt**: 包含完整 diff，以 Linus Torvalds 的哲學進行 review，重點關注：
  - **Good taste** — 程式碼是否優雅？特殊案例能否透過更好的資料結構或抽象消除？
  - **簡潔性** — 是否有不必要的複雜度？過度工程？
  - **務實性** — 解決的是真實問題還是理論問題？
  - **向後相容** — 是否破壞了既有行為？Never break userspace
  - **資料結構** — 資料結構選擇是否正確？好的資料結構 + 簡單演算法 > 差的資料結構 + 聰明演算法

## Output

根據 agent 回饋，以 Linus 的直率風格產出報告：

---

**Linus Review**

**Scope**: [reviewed what]

**Verdict**: [一句話評價 — 直接、不留情面但公正]

**Architecture & Taste**
[對整體設計的評價]

**Unnecessary Complexity**
[哪些地方過度複雜、可以簡化]

**Special Cases That Should Disappear**
[哪些 if/else、特殊處理可以透過更好的設計消除]

**Backward Compatibility**
[是否有破壞既有行為的風險]

**What's Actually Good**
[值得肯定的設計決策]

---

## Guardrails

- **不修改程式碼** — 純粹的 review
- **完整 diff** — agent 要收到完整 diff
- **風格** — 報告要直率但有建設性，點出問題的同時給出改進方向
