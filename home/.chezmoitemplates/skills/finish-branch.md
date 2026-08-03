# Finish Branch

Complete a development branch: verify, integrate, dispose. Both repo
architectures are handled natively — no external overrides.

## Ground rules (apply to every option below)

- **Stop on first failure.** Each command is a separate gated step; if
  any fails (rebase conflict, `--ff-only` refused, anything), stop,
  report the state, and wait — do NOT run the remaining steps.
- **Dispose only after the merge is confirmed.** Worktree/branch
  disposal and `active_workflows.md` row removal happen only once the
  merge commit is verifiably on the base branch (or the user confirmed
  Discard). A half-finished sequence keeps the row.

## 1. Verify before anything

Run the project's verification (tests / build / lint) and confirm
output. Do not offer integration options on a red branch.

## 2. Detect architecture

```bash
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
case "$(basename "$GIT_COMMON")" in
  .bare) ARCH=bare-worktree ;;
  *)     ARCH=normal ;;
esac
```

## 3. Ask how to integrate, then execute per option × ARCH

Present once: **Merge locally** / **Push + PR** / **Keep branch as is**
/ **Discard**.

### Merge locally

- `normal`: rebase on up-to-date main (pause on conflict) →
  `git checkout main && git merge <branch>` → after the merge is
  confirmed, delete the branch; if the work was in a linked worktree,
  `git worktree remove <path>` first.
- `bare-worktree`: never checkout the base inside the feature worktree.
  ```bash
  cd <repo>/<branch> && git rebase main     # conflict → stop, resolve, rerun tests
  cd <repo>/main && git merge --ff-only <branch>   # refused → stop, report (main moved?)
  # ── only continue once the merge above succeeded ──
  git --git-dir=<repo>/.bare worktree remove <branch>
  git -C <repo>/main branch -d <branch>     # -d is safe after FF merge. NOT
                                            # --git-dir=.bare: the bare repo's own
                                            # HEAD is often a dangling symref (it
                                            # points at whatever branch was last
                                            # deleted), and -d needs HEAD to run its
                                            # merged check.
  git --git-dir=<repo>/.bare worktree prune
  ```
  Alternative `git merge --no-ff <branch>` from `main/` when the branch
  history is worth keeping as a unit. Rebase rewrites hashes — update
  anything that recorded old ones. Run disposal from `main/` or the
  container, never from inside the worktree being removed. Never
  `rm -rf` a worktree directory.
- Then remove the workflow's row from `active_workflows.md` — resolve its
  path per ARCH first (normal: auto-derived slug; bare-worktree: registry
  lookup via `autoMemoryDirectory` key, auto-derivation is wrong there —
  same dispatch as the `worktree` skill's Register step).

### Push + PR

Both ARCHes: push the branch, `gh pr create`. The branch — and under
bare-worktree the worktree — stays until the PR merges (review fixes
need the workspace). Keep the `active_workflows.md` row, update Current
Step (e.g. `pr-open`); dispose + remove the row only after the PR
merges.

When it merges, sync the base then dispose — run from the base worktree
(`normal`: the repo itself; `bare-worktree`: `<repo>/main`):

```bash
git switch main && git pull --ff-only   # bare-worktree: cd <repo>/main first
paths=$(git diff --name-only "$(git merge-base main <branch>)" <branch>)
git diff main <branch> -- $paths        # MUST be empty
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

Only then dispose: `git branch -D <branch>`; under `bare-worktree`,
`git --git-dir=<repo>/.bare worktree remove <branch>` first, then
`branch -D` from `main/`, then `worktree prune`. The remote branch is
already gone if the repo sets `delete_branch_on_merge`; otherwise
`git push origin --delete <branch>`. Then remove the
`active_workflows.md` row.

### Keep branch as is

Leave branch, worktree, and the `active_workflows.md` row untouched
(update Status/Current Step if the workflow is pausing). No disposal.

### Discard

Destroys unmerged commits — **confirm with the user before deleting**,
then:
- `normal`: `git checkout main`, remove the linked worktree if any,
  `git branch -D <branch>`.
- `bare-worktree`: `git --git-dir=<repo>/.bare worktree remove
  <branch>` (add `--force` only if the tree is dirty and the user
  confirmed), `git --git-dir=<repo>/.bare branch -D <branch>`,
  `worktree prune`.
- Then remove the `active_workflows.md` row.
