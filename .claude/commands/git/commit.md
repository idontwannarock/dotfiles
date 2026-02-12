---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(git rm:*)
description: Smart commit — stage files individually, filter junk/sensitive files, auto-generate message
---

## Context

- Status: !`git status`
- Changes: !`git diff HEAD`
- Branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -5`

## Task

Based on the above context, create a single git commit. Follow these rules strictly.

## Staging Rules

1. **Stage files individually** — NEVER use `git add -A`, `git add .`, or `git add --all`
2. **Junk/sensitive file handling** — If you see ANY of these files in untracked or modified files, do NOT stage them. Instead, use AskUserQuestion to ask the user whether to add them to `.gitignore`:
   - Junk: `nul`, `.DS_Store`, `Thumbs.db`, `desktop.ini`, `*.swp`, `*.swo`, `*~`
   - Sensitive: `.env`, `.env.*`, `credentials.*`, `*.pem`, `*.key`, `secrets.*`
   - If user says yes, add the pattern to `.gitignore` and stage the `.gitignore` change too
   - If user says no, just skip the file
3. **Uncertain files** — For any file you're unsure whether it should be committed (e.g., binary files, generated files, lock files you didn't expect), ask the user before staging

## Commit Message Rules

- Analyze all staged changes and write a concise commit message focusing on the "why"
- Follow the repository's existing commit message style (see recent commits above)
- Use a HEREDOC to pass the message:
  ```
  git commit -m "$(cat <<'EOF'
  message here

  Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
  EOF
  )"
  ```

## Execution

Call multiple tools in a single response when possible. Stage all files and create the commit efficiently. Do not run git status after the commit. Do not do anything else beyond the commit.
