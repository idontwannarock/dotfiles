---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*)
description: Amend the last commit with current changes
---

## Context

- Last commit: !`git log -1 --format="%H %s"`
- Status: !`git status`
- Staged changes: !`git diff --cached`
- Unstaged changes: !`git diff`

## Task

Amend the last commit.

1. If there are unstaged changes, stage them individually (same rules as `/git:commit` — never `git add -A`, skip junk/sensitive files)
2. Run `git commit --amend --no-edit` to amend without changing the message
3. If the user provided a new message as argument, use `git commit --amend -m "<message>"` instead

**Safety:**
- NEVER amend if the last commit has already been pushed (check if `git log @{u}..HEAD --oneline` is empty — if empty, the commit is already on remote, STOP and warn the user)
- Do not do anything else beyond the amend
