## Context

- Status: !`git status`
- Changes: !`git diff HEAD`
- Branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -5`

## Task

Based on the above context, create a single git commit. Follow these rules strictly.

## Staging Rules

1. **Stage files individually** — NEVER use `git add -A`, `git add .`, or `git add --all`
2. **Junk/sensitive file handling** — If you see ANY of these files in untracked or modified files, do NOT stage them. Instead, ask the user whether to add them to `.gitignore`:
   - Junk: `nul`, `.DS_Store`, `Thumbs.db`, `desktop.ini`, `*.swp`, `*.swo`, `*~`
   - Sensitive: `.env`, `.env.*`, `credentials.*`, `*.pem`, `*.key`, `secrets.*`
   - If user says yes, add the pattern to `.gitignore` and stage the `.gitignore` change too
   - If user says no, just skip the file
3. **Uncertain files** — For any file you're unsure whether it should be committed (e.g., binary files, generated files, lock files you didn't expect), ask the user before staging

## Commit Message Rules

- Analyze all staged changes and write a concise commit message focusing on the "why"
- Follow the repository's existing commit message style (check `git log --oneline -5`)
- Use a HEREDOC to pass the message:
  ```
  git commit -m "$(cat <<'EOF'
  message here

  Co-Authored-By: <current model name> <noreply@anthropic.com>
  EOF
  )"
  ```
  Use the name of the model you are actually running as — do not copy a version
  from this file or from an earlier commit. Pinning a literal here turns whatever
  model happened to be current when it was written into a requirement, and it
  silently goes stale every time the model changes.

## Execution

Call multiple tools in a single response when possible. Stage all files and create the commit efficiently. Do not run git status after the commit. Do not do anything else beyond the commit.
