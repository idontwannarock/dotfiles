## Staging Rules

1. **Stage files individually** — NEVER use `git add -A`, `git add .`, or `git add --all`
2. **Junk/sensitive file handling** — If you see ANY of these files in untracked or modified files, do NOT stage them. Instead, ask the user whether to add them to `.gitignore`:
   - Junk: `nul`, `.DS_Store`, `Thumbs.db`, `desktop.ini`, `*.swp`, `*.swo`, `*~`
   - Sensitive: `.env`, `.env.*`, `credentials.*`, `*.pem`, `*.key`, `secrets.*`
   - If user says yes, add the pattern to `.gitignore` and stage the `.gitignore` change too
   - If user says no, just skip the file
3. **Uncertain files** — For any file you're unsure whether it should be committed (e.g., binary files, generated files, lock files you didn't expect), ask the user before staging
