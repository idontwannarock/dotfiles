---
name: git-commit
description: Smart commit — stage files individually, filter junk/sensitive files, auto-generate message
---

## Context

First, gather context by running these commands:

- `git status` — see all untracked and modified files
- `git diff HEAD` — see staged and unstaged changes
- `git branch --show-current` — current branch
- `git log --oneline -5` — recent commit style

## Task

Based on the above context, create a single git commit. Follow these rules strictly.

{{ template "skills/git-staging-rules.md" . }}
{{ template "skills/git-commit-format.md" . }}
## Execution

Call multiple tools in a single response when possible. Stage all files and create the commit efficiently. Do not run git status after the commit. Do not do anything else beyond the commit.
