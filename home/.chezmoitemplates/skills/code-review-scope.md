## Review Scope

Determine the diff to review based on arguments, in this order:

1. Argument is a number → `gh pr diff <number>`, also `gh pr view <number> --json title,author,baseRefName,headRefName,url`
2. Argument is a URL containing `/pull/` → `gh pr diff "<url>"`, also get PR info
3. Argument contains `..` → `git diff <argument>`
4. Argument is another string → `git diff main...<argument>`
5. No argument, staged changes exist → `git diff --cached`
6. No argument, unstaged changes exist → `git diff`
7. No argument, clean working tree → `git show HEAD`
