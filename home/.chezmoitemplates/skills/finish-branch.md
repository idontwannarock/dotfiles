# Finish Branch

Complete a development branch: verify, integrate, dispose.

## Ground rules (apply to every option below)

- **Stop on first failure.** Each command is a separate gated step; if
  any fails (rebase conflict, `--ff-only` refused, anything), stop,
  report the state, and wait — do NOT run the remaining steps.
- **Dispose only after the merge is confirmed.** Worktree/branch
  disposal and `active_workflows.md` row removal happen only once the
  merge is verifiably on the base branch (or the user confirmed
  Discard). A half-finished sequence keeps the row.
- **Know where you stand** — see below. Every step here happens in one
  of two places, and picking the wrong one fails in ways that are not
  obvious.

## 0. Where you stand

Establish this once, before anything else:

```bash
WORK=$(git rev-parse --show-toplevel)          # this workflow's workspace
BRANCH=$(git branch --show-current)
MAIN=$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')
[ "$WORK" = "$MAIN" ] && LINKED=no || LINKED=yes
```

`MAIN` is the main checkout — the first row of `git worktree list` is
always the one holding `.git` itself. `LINKED=yes` means this branch
lives in a linked worktree, which constrains two things:

- **Integration runs in `$MAIN`, never in `$WORK`.** `git checkout main`
  inside a linked worktree fails outright — `fatal: 'main' is already
  checked out at <main>`. Rebasing the feature branch is the one step
  that belongs in `$WORK`; everything touching the base branch does not.
- **Disposal runs from `$MAIN`, never from inside `$WORK`.**
  `git worktree remove` does *not* refuse when your shell sits inside
  the directory it is deleting. It removes the tree, and every later
  command in that shell dies with `Unable to read current working
  directory`. `cd "$MAIN"` first — this is a hard ordering, not a
  preference.

When `LINKED=no` the branch shares the main checkout; there is no
worktree to remove and `$WORK` and `$MAIN` are the same place.

## 1. Verify before anything

Run the project's verification (tests / build / lint) and confirm
output. Do not offer integration options on a red branch.

## 2. Ask how to integrate, then execute

Present once: **Merge locally** / **Push + PR** / **Keep branch as is**
/ **Discard**.

### Merge locally

```bash
cd "$WORK" && git rebase main            # conflict → stop, resolve, rerun tests
cd "$MAIN" && git merge --ff-only "$BRANCH"   # refused → stop, report (main moved?)
# ── only continue once the merge above succeeded ──
[ "$LINKED" = yes ] && git worktree remove "$WORK"
git branch -d "$BRANCH"                  # -d is safe after a FF merge
git worktree prune
```

Use `git merge --no-ff "$BRANCH"` instead when the branch history is
worth keeping as a unit. Rebase rewrites hashes — update anything that
recorded the old ones. Never `rm -rf` a worktree directory; `worktree
remove` also clears the bookkeeping under `.git/worktrees/`.

Then remove the workflow's row from `active_workflows.md` (path per
`~/.agent/reference/repo-identity.md`, same derivation as the
`worktree` skill's Register step).

### Push + PR

Push the branch and `gh pr create`. The branch and its worktree stay
until the PR merges — review fixes need the workspace. Keep the
`active_workflows.md` row and update Current Step (e.g. `pr-open`);
dispose and remove the row only after the PR merges.

When it merges, sync the base and confirm the work landed — from
`$MAIN`:

```bash
cd "$MAIN" && git switch main && git pull --ff-only
paths=$(git diff --name-only "$(git merge-base main "$BRANCH")" "$BRANCH")
git diff main "$BRANCH" -- $paths        # MUST be empty
```

Scope the comparison to the paths the branch touched. An unscoped
`git diff main <branch>` is ambiguous: non-empty can mean the branch's
work never landed, or merely that the base moved on unrelated files
while the PR was open — one dependency bump merging ahead of you is
enough. Scoped, only the first reading survives. Still non-empty means
the base also moved on *these* paths; stop and look.

**`git branch -d` cannot gate this.** It tests whether the branch tip is
an ancestor of the base; squash and rebase merges rewrite the commit, so
it reports "not fully merged" for a merged branch and a genuinely
unmerged one alike — the guard stops discriminating, and reaching for
`-D` to silence it discards the question instead of answering it. Use
the test that still holds: `git diff main <branch>` empty means the
branch's tree is entirely on the base and nothing is lost. That holds
for merge-commit, squash, rebase, and cherry-pick alike. Non-empty →
stop and report; something did not land.

Only then dispose — still from `$MAIN`:

```bash
[ "$LINKED" = yes ] && git worktree remove "$WORK"
git branch -D "$BRANCH"
git worktree prune
```

The remote branch is already gone if the repo sets
`delete_branch_on_merge`; otherwise `git push origin --delete
"$BRANCH"`. Then remove the `active_workflows.md` row.

### Keep branch as is

Leave branch, worktree, and the `active_workflows.md` row untouched
(update Status/Current Step if the workflow is pausing). No disposal.

### Discard

Destroys unmerged commits — **confirm with the user before deleting**,
then, from `$MAIN`:

```bash
cd "$MAIN"
[ "$LINKED" = yes ] && git worktree remove "$WORK"   # --force only if the tree
                                                    # is dirty AND user confirmed
git branch -D "$BRANCH"
git worktree prune
```

When `LINKED=no`, `git switch main` first — you cannot delete the branch
you are standing on. Then remove the `active_workflows.md` row.
