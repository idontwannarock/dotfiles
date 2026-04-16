## Commit Message Rules

- Analyze all staged changes and write a concise commit message focusing on the "why"
- Follow the repository's existing commit message style (check `git log --oneline -5`)
- Use a HEREDOC to pass the message:
  ```
  git commit -m "$(cat <<'EOF'
  message here

  Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
  EOF
  )"
  ```
