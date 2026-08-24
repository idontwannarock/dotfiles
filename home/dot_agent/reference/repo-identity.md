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

## The anchor — agreed by every mechanism

```
anchor = dirname(realpath(git rev-parse --path-format=absolute --git-common-dir))
```

Four parts, all load-bearing:

| Part | Why |
|---|---|
| `--git-common-dir` | shared across every worktree of a repo, unlike `--show-toplevel` |
| `--path-format=absolute` | without it the output is relative to **your** cwd, not the target's — so any `-C <path>` / `--repo <path>` invocation silently yields *your* repo's slug |
| `realpath` | resolves symlinks |
| `dirname` | strips the `.git` / `.bare` component — **the raw path is not the repo root** |

**The order is load-bearing too.** `--path-format` affects only the options that
follow it, so `--git-common-dir --path-format=absolute` is silently equivalent to
omitting the flag: `.git` from the repo root, `../.git` from a subdirectory, exit
code 0 either way. Put the flag first, always.

`realpath` stays regardless: it guards symlinks and `..`, not flag order. That it
also happens to mask a misordered flag is why this line went wrong for so long
without anyone noticing.

Both mistakes — the flag misordered, and the flag missing altogether — are caught
by `tests/path-format-flag-order.test.sh`. A grep for one of the two shapes is not
a check for this rule; that is how the missing-flag case shipped once already.

If there is no git repo, fall back to `$PWD` (or `CLAUDE_PROJECT_DIR` where the
mechanism defines one) and slugify that instead.

## The slugify step — currently NOT agreed

Every mechanism replaces `/` with `-`. On a POSIX path with no dots that is the
whole rule, and all of them agree:
`/home/me/ws/dotfiles` → `-home-me-ws-dotfiles`.

They diverge on the other characters:

| Mechanism | Replaces | Defined by |
|---|---|---|
| `claude-memory-seed`, local-files store | `/` only | `claude-memory-seed` / `local-files-store` specs |
| `handoff`, `pickup`, `handoff-list`, `arch-review` | `:` `\` `/` `.` | `session-handoff` spec |

`/home/me/ws/hktv.tw/api` therefore files auto-memory under
`-home-me-ws-hktv.tw-api` and handoffs under `-home-me-ws-hktv-tw-api`. **A repo
whose absolute path contains a dot splits in exactly the way this document
exists to prevent.** No repo on this machine currently has one, so the
divergence is latent, not observed — which is why it survived this long.

The four-character form exists to handle Windows paths (`D:\ws\dotfiles` →
`D--ws-github-dotfiles`); the `/`-only form predates that need. Neither camp is
obviously wrong, and reconciling them means migrating existing keys, so **this
is an open question, not a settled rule.** Until it is settled: a new mechanism
SHOULD follow the camp whose artifacts it needs to sit alongside, and SHOULD NOT
assume the two produce the same key.

Note the leading character is only guaranteed on POSIX: an absolute path starts
with `/`, so the slug starts with `-`. A Windows drive letter does not
(`D--ws-github-dotfiles`).

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

`claude-memory-seed` (auto-memory + `autoMemoryDirectory`), the local-files
store, `handoff` / `pickup` / `handoff-list`, `arch-review`, and the workflow
registry with its `active_workflows.md` index.

When adding another per-repo artifact, derive the anchor exactly as above rather
than inventing one — two anchors for one repo is a defect, not a style
difference. For the slugify step, see the open question above and say in your
spec which camp you joined.
