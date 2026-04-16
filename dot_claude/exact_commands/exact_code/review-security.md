---
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git show:*), Bash(gh pr:*), Bash(git branch:*)
description: 安全性 review — 靜默失敗偵測、錯誤處理、安全漏洞
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

取得 diff 後，使用 **Task tool** 平行啟動以下 2 個 agent。每個 agent 的 prompt 都必須包含完整 diff。

| Agent | subagent_type | Prompt 重點 |
|-------|--------------|-------------|
| Silent Failure Hunter | `silent-failure-hunter` | 靜默失敗、錯誤處理不當、被吞掉的例外、不適當的 fallback、可能導致資料遺失的路徑 |
| Code Reviewer (Security) | `code-reviewer` | 以安全性為重點：注入攻擊（SQL/command/XSS）、認證/授權漏洞、敏感資料洩露、OWASP Top 10、不安全的加密或隨機數使用 |

## Output

彙整回饋產出以下格式報告：

---

**Security Review**

**Scope**: [reviewed what]
**Diff size**: [N files changed, +X/-Y lines]

**Risk Level**: [🔴 High / 🟡 Medium / 🟢 Low]

🔴 **Security Vulnerabilities**
- [vulnerability description, impact, remediation] — _source: [agent]_

🟡 **Error Handling Issues**
- [silent failure / swallowed exception / bad fallback] — _source: [agent]_

🟢 **Secure Practices**
- [positive security observation]

**Details**

_Security_ (code-reviewer)
...

_Error Handling_ (silent-failure-hunter)
...

---

## Guardrails

- **不修改程式碼** — 純粹的 review
- **完整 diff** — 每個 agent 都要收到完整 diff
- **安全漏洞優先** — Critical/High 等級的安全問題要放在最前面
