# Finish Branch

Complete a development branch: verify, integrate, dispose.

**Read `~/.agent/reference/git-worktree-hazards.md` first.** Every mechanical
rule below rests on it — which directory each step belongs in, and why
`git branch -d` cannot tell you whether a branch merged. Do not restate those
from memory; the failures they prevent are all silent.

## Ground rules

- **Stop on first failure.** Each command is a separate gated step. If any
  fails (rebase conflict, `--ff-only` refused, anything), stop, report the
  state, and wait — do NOT run the remaining steps.
- **Dispose only after the merge is confirmed.** Branch and worktree disposal
  happens once the merge is verifiably on the base branch, or the user
  confirmed Discard. A half-finished sequence disposes of nothing.
- **Know where you stand.** Set `WORK`, `BRANCH`, `MAIN` and `LINKED` per the
  hazards file before anything else. Integration and disposal run in `$MAIN`;
  rebasing the feature branch is the one step that runs in `$WORK`.

## 1. Verify before anything

Run the project's verification commands and read their output. Do not offer
integration options on a red branch.

## 2. Ask how to integrate, then execute

Present once: **Merge locally** / **Push + PR** / **Keep branch as is** /
**Discard**.

### Merge locally

```bash
cd "$WORK" && git rebase main            # conflict → stop, resolve, rerun tests
cd "$MAIN" && git merge --ff-only "$BRANCH"   # refused → stop, report (main moved?)
# ── only continue once the merge above succeeded ──
[ "$LINKED" = yes ] && git worktree remove "$WORK"
git branch -d "$BRANCH"                  # safe here: you did the fast-forward yourself
git worktree prune
```

Use `git merge --no-ff "$BRANCH"` instead when the branch history is worth
keeping as a unit. Rebase rewrites hashes — update anything that recorded the
old ones.

### Push + PR

Push the branch and `gh pr create`. The branch and its worktree stay until the
PR merges — review fixes need the workspace.

When it merges, sync the base and confirm the work landed, from `$MAIN`:

```bash
cd "$MAIN" && git switch main && git pull --ff-only
```

Then run the scoped-diff check from the hazards file. Non-empty → stop and
report; something did not land. Only then dispose, still from `$MAIN`:

```bash
[ "$LINKED" = yes ] && git worktree remove "$WORK"
git branch -D "$BRANCH"
git worktree prune
```

The remote branch is already gone if the repo sets `delete_branch_on_merge`;
otherwise `git push origin --delete "$BRANCH"`.

### Keep branch as is

Leave the branch and worktree untouched. No disposal.

### Discard

Destroys unmerged commits — **confirm with the user before deleting**, then
from `$MAIN`:

```bash
cd "$MAIN"
[ "$LINKED" = yes ] && git worktree remove "$WORK"   # --force only if the tree
                                                    # is dirty AND user confirmed
git branch -D "$BRANCH"
git worktree prune
```

When `LINKED=no`, `git switch main` first — you cannot delete the branch you
are standing on.

## 3. Hand back

Report which option ran and the resulting state. If the repo runs a
development workflow that tracks work in flight, that workflow owns its own
bookkeeping and closes it out from here — this skill does not write to it.
