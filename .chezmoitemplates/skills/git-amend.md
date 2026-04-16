---
name: git-amend
description: Amend the last commit with current changes
---

## Context

First, gather context by running these commands:

- `git log -1 --format="%H %s"` — last commit
- `git status` — working tree state
- `git diff --cached` — staged changes
- `git diff` — unstaged changes

## Task

Amend the last commit.

1. If there are unstaged changes, stage them individually (same rules as `git-commit` skill — see below)
2. Run `git commit --amend --no-edit` to amend without changing the message
3. If the user provided a new message as argument, use `git commit --amend -m "<message>"` instead

**Safety:**
- NEVER amend if the last commit has already been pushed (check if `git log @{u}..HEAD --oneline` is empty — if empty, the commit is already on remote, STOP and warn the user)
- Do not do anything else beyond the amend

{{ template "skills/git-staging-rules.md" . }}
