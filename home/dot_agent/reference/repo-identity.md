---
type: Reference
title: Repo identity for agent artifacts
description: "The one definition of a repo's slug — the key under which auto-memory, handoffs, and workflow state are filed — and why the obvious shortcuts name a different directory."
---

# Repo identity for agent artifacts

Anything filed per repo — auto-memory, handoffs, workflow state, the local-files
store — is keyed by the repo's **canonical slug**. There is exactly one
definition, and every mechanism must use it, or the same repo ends up filed
under two keys that cannot see each other.

## The definition

```
slug = replace(dirname(realpath(git rev-parse --git-common-dir)), [':', '\', '/', '.'] → '-')
```

Three steps, all load-bearing:

| Step | Why |
|---|---|
| `git rev-parse --git-common-dir` | shared across every worktree of a repo, unlike `--show-toplevel` |
| `realpath` | resolves symlinks and relative output (`--git-common-dir` often returns a bare `.git`) |
| `dirname` | strips the `.git` / `.bare` component — **the raw path is not the repo root** |

Then slugify: replace every `:`, `\`, `/`, and `.` with `-`.

Because the input is an absolute path, the result always begins with `-`.
`/home/me/ws/dotfiles` → `-home-me-ws-dotfiles`. On Windows,
`D:\ws\github\dotfiles` → `D--ws-github-dotfiles`.

If there is no git repo, fall back to `$PWD` (or `CLAUDE_PROJECT_DIR` where the
mechanism defines one) as the anchor and slugify that the same way.

## The two shortcuts that look right and are not

**Slugifying the raw `--git-common-dir` output.** It ends in `.git` or `.bare`,
so you get `-home-me-ws-dotfiles-git` — a directory name no other mechanism
will ever produce. Everything still works: you write a file, you read it back,
you simply never see what anything else wrote.

**Using `git rev-parse --show-toplevel`.** Identical under a normal checkout, so
it survives casual testing. Under bare+worktree it returns the *current
worktree*, so one repo's artifacts scatter across as many directories as it has
branches. `shoalter-ai-toolkit` once split into three handoff directories this
way.

Both failures are silent — nothing errors, nothing is missing, the answer is
just incomplete. They surface only when someone goes looking for something a
different worktree or a different tool wrote.

## Who uses this

`claude-memory-seed` (auto-memory + `autoMemoryDirectory`), `handoff` / `pickup`,
the local-files store, and the workflow registry with its `active_workflows.md`
index. When adding another per-repo artifact, use this key rather than inventing
one — two keys for one repo is the defect, not a style difference.
