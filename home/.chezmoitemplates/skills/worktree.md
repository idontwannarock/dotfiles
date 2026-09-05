# Worktree

Create an isolated workspace for a workflow. Read
`~/.agent/reference/dev-workflow-isolation.md` first when deciding
whether isolation is required (any active/paused row in
`active_workflows.md` → yes).

## Create the workspace

Ensure `main` is up to date first (fetch/pull in the main checkout),
then, **from the main checkout**:

```bash
git worktree add ../<repo>-<branch> -b <branch> main
```

The explicit `main` start-point matters. Without it the worktree
branches from current HEAD — likely another workflow's feature branch.

- If the target directory or branch name already exists, stop and pick
  another name (or resume the existing workflow) — do not force.
- Never `git checkout` another branch inside an existing worktree to
  "reuse" it — one workflow, one workspace.

## Move into it

`git worktree add` does not move you. The new directory is where every
later command for this workflow belongs, so `cd` there before doing
anything else, and confirm it:

```bash
cd ../<repo>-<branch> && git rev-parse --show-toplevel && git branch --show-current
```

Both must name the new workspace. Editing the main checkout while
believing you are in the worktree is the failure this step exists to
prevent — it puts the work on the wrong branch, and nothing complains.

## Register

Auto-derive the canonical repo slug per
`~/.agent/reference/repo-identity.md` — read it rather than restating the
anchor here — then open
`~/.agent/workflows/<slug>/active_workflows.md`.

`mkdir -p` the directory if this is the repo's first workflow, then add
a row (`Change | Branch | Path | Type | Current Step | Status | Last
Updated`) with Type=`worktree`, Path=the worktree directory. Keep
Current Step tool-neutral (no tool-specific skill tokens). Register
only after the worktree was actually created — a failed `worktree add`
must not leave an orphan row.
