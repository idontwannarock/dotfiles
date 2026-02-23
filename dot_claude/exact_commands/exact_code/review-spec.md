---
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git show:*), Bash(gh pr:*), Bash(git branch:*), Bash(openspec:*)
description: 需求導向 code review — 帶著 OpenSpec artifacts 上下文，檢查實作與需求的對齊程度
---

## Context

- Status: !`git status --short`
- Branch: !`git branch --show-current`

## Step 1: Select OpenSpec Change

依照以下順序決定使用哪個 change：

1. **`$ARGUMENTS` 的第一個詞是 change 名稱** → 直接使用
2. **對話上下文有提到 change** → 推斷使用
3. **只有一個 active change** → 自動選取
4. **多個 change 或無法判斷** → 執行 `openspec list --json`，用 **AskUserQuestion** 讓使用者選

選定後宣告：「Using change: \<name\>」

## Step 2: Load Artifacts

```bash
openspec instructions apply --change "<name>" --json
```

讀取 `contextFiles` 列出的所有 artifact 檔案（proposal、specs、design、tasks 等）。
如果某些 artifact 不存在，記錄下來並在報告中標注。

## Step 3: Get Implementation Diff

取得完整 diff，依照以下順序判斷（`$ARGUMENTS` 扣除 change 名稱後的部分）：

1. 剩餘引數是數字 → `gh pr diff <number>`
2. 剩餘引數是 URL → `gh pr diff "<url>"`
3. 剩餘引數包含 `..` → `git diff <range>`
4. 剩餘引數是分支名 → `git diff main...<branch>`
5. 無剩餘引數，有 staged → `git diff --cached`
6. 無剩餘引數，有 unstaged → `git diff`
7. 無剩餘引數，clean → `git show HEAD`

## Step 4: Dispatch Agents

使用 **Task tool** 平行啟動 3 個 agent。每個 agent 的 prompt 都必須包含：
- 完整 diff
- 所有已載入的 artifact 內容（proposal、specs、design、tasks）

| Agent | subagent_type | Prompt 重點 |
|-------|--------------|-------------|
| Spec Alignment Reviewer | `pr-review-toolkit:code-reviewer` | 帶著 spec 上下文審查：(1) 每個 requirement 是否被正確實作 (2) spec 中的 edge case/scenario 是否有對應處理 (3) 實作是否偏離需求意圖 (4) 是否有需求範圍外的多餘實作 |
| Architecture Reviewer | `linus-torvalds` | 帶著 design 上下文審查：(1) 實作是否遵循 design 文件的架構決策 (2) 相對需求範圍是否 over-engineering 或 under-engineering (3) 複雜度是否與需求複雜度匹配 (4) 是否有更簡單的方式滿足相同需求 |
| Scenario Coverage Analyzer | `pr-review-toolkit:pr-test-analyzer` | 帶著 spec scenarios 上下文審查：(1) spec 中定義的每個 scenario 是否有對應測試 (2) spec 中的邊界條件是否被測試覆蓋 (3) 哪些 scenario 缺少測試 (4) 測試是否真正驗證了 spec 的預期行為 |

## Output

彙整所有 agent 回饋，產出以下格式報告：

---

**Spec-Aware Code Review**

**Change**: \<change-name\>
**Artifacts loaded**: proposal / specs / design / tasks（標注哪些存在、哪些缺少）
**Scope**: [reviewed what — staged / PR / branch diff]
**Diff size**: [N files changed, +X/-Y lines]

**Requirement Alignment**

| Requirement | Status | Notes |
|-------------|--------|-------|
| Req 1 | Implemented / Partial / Missing / Over-scoped | details |

🔴 **Gaps** (spec 要求但未實作或實作不完整)
- [gap description, which requirement, recommendation]

🟡 **Divergences** (實作偏離 spec 意圖)
- [divergence description, spec says X but code does Y]

🟠 **Over-scope** (超出 spec 範圍的實作)
- [what was added beyond spec, whether it should be kept or removed]

**Architecture vs Design**
- [design decision] → [followed / diverged / improved]

**Scenario Test Coverage**

| Scenario | Test Exists | Covers Intent |
|----------|------------|---------------|
| Scenario 1 | Yes/No | Yes/Partial/No |

🟢 **Well Aligned** (值得肯定的 spec-code 對齊)
- [positive observations]

---

## Guardrails

- **不修改程式碼** — 純粹的 review
- **完整 context** — 每個 agent 都要收到完整 diff + 完整 artifacts
- **Artifact 缺失時** — 跳過對應的檢查維度，在報告中標注
- **無 OpenSpec change 時** — 如果當前專案沒有 OpenSpec 或沒有 active change，提示使用者改用 `/code:review-full`
- **聚焦 spec 對齊** — 不重複一般 code review 的程式碼品質檢查，專注在需求對齊、範圍適當性、scenario 覆蓋
