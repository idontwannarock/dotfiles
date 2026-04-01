---
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git show:*), Bash(gh pr:*), Bash(git branch:*)
description: Codex code review — 使用 OpenAI Codex 進行 code review（標準或對抗式）
---

## Context

- Status: !`git status --short`
- Branch: !`git branch --show-current`

## Arguments

解析 `$ARGUMENTS`：

- 第一個詞是 `adversarial` 或 `adv` → 對抗式模式，移除該詞，剩餘作為 codex 引數
- 其他情況 → 標準模式

轉換引數格式（Codex review 使用 `--base` 和 `--scope`，不支援 PR number 直接輸入）：

1. 純數字（PR number）→ 加上 `--base main`（review 當前 working tree 相對於 main 的變更）
2. 包含 `..` 的 range → 取 `..` 前面的 ref 作為 `--base <ref>`
3. 分支名 → `--base main`
4. 無引數 → 不加額外引數（Codex 預設 review working tree）
5. 已有 `--base` 或 `--scope` → 原樣保留

所有情況都追加 `--wait`（除非已有 `--wait` 或 `--background`）。

## Task

使用 **Skill tool** 呼叫對應的 Codex review skill：

- **標準模式** → `skill: "codex:review", args: "<轉換後的引數>"`
- **對抗模式** → `skill: "codex:adversarial-review", args: "<轉換後的引數>"`

## Output

Codex review 的輸出會直接呈現。不做額外摘要或評論。

如果 Codex review 是在背景執行，提示使用者可用 `/codex:status` 查看進度、`/codex:result` 查看結果。

## Guardrails

- **不修改程式碼** — 純粹的 review
- **引數轉換** — Codex 不直接支援 PR diff，只能 review working tree 或 branch diff
- **PR review 限制** — 如果是 PR number，提醒使用者 Codex 是 review 當前 working tree/branch 的變更，不是直接讀 PR diff
