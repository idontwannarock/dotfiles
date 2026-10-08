## Review Scope

Determine the diff to review based on arguments, in this order:

1. Argument is a number → `gh pr diff <number>`, also `gh pr view <number> --json title,author,baseRefName,headRefName,url`
2. Argument is a URL containing `/pull/` → `gh pr diff "<url>"`, also get PR info
3. Argument contains `..` → `git diff <argument>`
4. Argument is another string → `git diff <default branch>...<argument>`
5. No argument, staged changes exist → `git diff --cached`
6. No argument, unstaged changes exist → `git diff`
7. No argument, clean working tree → `git show HEAD`

Rules 1 and 2 need `gh`, and work only for GitHub. If `gh` is missing or not
logged in, or the remote is not GitHub, stop and tell the user. Ask for a
branch name or a commit range instead. Do not install `gh` yourself.

`<default branch>` in rule 4: run `git symbolic-ref --short refs/remotes/origin/HEAD`
and drop the `origin/` prefix. If that fails, use `main` when it exists, then
`master`. If neither exists, ask the user for the base branch. Never assume `main`.
