Clean up local branches whose upstream remote branch has been deleted ("gone").

**Steps**

1. Prune stale remote-tracking refs: `git fetch --all --prune`
2. List local branches whose upstream is gone:
   `git branch -vv | awk '/: gone\]/{print $1}'`
3. Show the candidate branches to the user and confirm before deleting anything.
4. Delete each confirmed branch: `git branch -D <branch>`

**Guardrails**
- Always confirm with the user before deleting.
- Never delete the current branch or the default branch (`main`/`master`), even if listed.
- If no branches are gone, say so and stop.
