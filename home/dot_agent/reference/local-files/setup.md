---
type: Playbook
title: Local files install & setup
description: "One-time install of the global core.hooksPath dispatcher and the localfiles helper via chezmoi, plus migration notes for older bare+worktree repos."
---

# Local files — install & setup

How the local-files mechanism is installed. For the concept, store layout,
and the agent read-fallback rule see `store.md`. Tool-agnostic.

## What chezmoi installs

Everything is managed by the dotfiles repo and deployed by `chezmoi apply`:

- `~/.local/bin/localfiles` — the helper (POSIX sh, on `PATH`).
- `~/.config/git/hooks/post-checkout` — the global dispatcher (POSIX sh).
- `git config --global core.hooksPath ~/.config/git/hooks` — set by a
  `run_onchange_` script, idempotent, and **non-destructive**: if you already
  have a different `core.hooksPath`, it warns and leaves yours alone (set it
  to the target by hand if you want global restore).

## Why a global `core.hooksPath` + dispatcher

A global `core.hooksPath` makes one hooks directory apply to **every** repo on
the machine, immediately and without per-repo setup — it's a path, not a copy,
so updates take effect at once. The cost: it **replaces** each repo's
`.git/hooks`, and a repo that sets its **own** `core.hooksPath` overrides the
global one. So the dispatcher is a multiplexer:

1. runs `localfiles restore`, then
2. chains repo-local `<toplevel>/.githooks/post-checkout` and
   `<git-common-dir>/hooks/post-checkout` if present (realpath-guarded against
   invoking itself),

so it never silently swallows a repo's existing post-checkout hook.

## Verifying

```sh
command -v localfiles                      # resolves to ~/.local/bin/localfiles
git config --global core.hooksPath         # -> ~/.config/git/hooks
# in a throwaway repo:
printf 'X=1\n' > .env && localfiles backup
rm .env && git checkout -- . ; localfiles restore   # .env reappears
```

## Migrating an existing bare+worktree repo

Older bare setups set a per-repo `core.hooksPath` pointing at `.githooks`,
which **overrides** the global dispatcher and bypasses local-files restore.
Drop it so the repo falls back to the global dispatcher (which still chains
`.githooks/post-checkout`):

```sh
git --git-dir=.bare config --unset core.hooksPath
```

New layouts created per `../bare-worktree/setup.md` no longer set it.

## Windows notes

git hooks run under git-bash on Windows, so the POSIX dispatcher and helper
work there unchanged. To run `localfiles backup` by hand on Windows, invoke it
from a git-bash shell.
