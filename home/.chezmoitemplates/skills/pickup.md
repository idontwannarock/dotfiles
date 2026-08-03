## Purpose

Boot a new session from a previously saved handoff file. Reads the file, invokes any suggested skills, then proceeds with the next steps -- no summarizing, no confirmation.

## Resolve the handoff file

Compute the **repo slug** from the current working repo: take `dirname(realpath(git rev-parse --git-common-dir))` (falling back to `$PWD` if that fails) and replace every `:`, `\`, `/`, and `.` with `-`. Example: `D:\ws\github\dotfiles` becomes `D--ws-github-dotfiles`.

Use `git-common-dir`, **not** `git rev-parse --show-toplevel` -- under a bare+worktree layout the latter returns the current worktree path, which would make handoffs written from a sibling worktree unreachable. `handoff` derives its slug the same way; the two must agree.

Then look in `~/.agent/handoffs/<repo-slug>/`. Resolution order, given the user's argument:

1. **Exact ID** (with or without `.md`): `<id>.md` -- single file match.
2. **Slug only** (e.g. `phone-ssh-shortcuts`): glob `*__<slug>.md`. If exactly one match, use it. If multiple, list them with mtime and ask the user which.
3. **Date prefix** (e.g. `2026-05-26` or `2026-05-26-1430`): glob `<prefix>*.md`. Same disambiguation rule as slug.
4. **No argument**: pick the file with the latest mtime.

If nothing matches in `~/.agent/handoffs/<repo-slug>/`, check the legacy locations once, in order: `~/.local/state/handoffs/<repo-slug>/` (the pre-`~/.agent` location), then `<repo>/.claude/handoffs/` (files written before 2026-05-26). If still nothing, report the absolute paths searched and stop -- do not invent a file.

## Apply

1. Read the resolved file in full.
2. Invoke each skill listed under `## Suggested skills` (use the Skill tool / equivalent on Codex). If a listed skill is not available, note it briefly and continue.
3. If the args end with `in <language>` (the suffix `handoff` puts on the resume line), conduct this session in that language and drop it from the args -- it is a directive to you, not a refinement of the work.
4. Proceed with the items under `## Next steps`. Treat any remaining user-supplied args (beyond the ID) as additional context that supersedes or refines the first next-step item.
5. Do not summarize the handoff content back to the user. Do not ask for confirmation. Just continue working.

## Close out

`~/.agent/handoffs/<repo-slug>/` doubles as a todo list, so a finished handoff has to leave it. This is the only step in `pickup` that asks the user anything.

Once **every** item under `## Next steps` has met its success criterion:

1. List the items with the evidence for each -- the merged PR, the passing command and its output, the file that now exists. Evidence, not recollection.
2. Ask whether to archive this handoff.
3. If the user agrees, `mv` the file to `~/.agent/handoffs/<repo-slug>/archive/<ID>.md`, creating the directory if missing. This is the destination even when the file was resolved from one of the legacy locations -- archiving doubles as the migration out of them.

Hard rules:

- **Never `rm` a handoff.** Archiving is a move. In 2026-08-03 a session judged five handoffs "done" by how similar their slugs looked to finished work and deleted them; two had never been started. `~/.agent/handoffs/` is not under version control, so a wrong call there is unrecoverable, while a wrongly archived file costs one `mv` to bring back.
- **Never decide "done" yourself.** Unmet or unverifiable criteria mean not done. If you cannot point at evidence for an item, say so and leave the file where it is.
- **Never move a handoff the user did not agree to move** -- including ones you noticed in the same directory while working.
- **Say nothing about archiving while any item is outstanding.** A partially finished handoff is still live.

The archive lives in a subdirectory on purpose: resolution above only globs `<repo-slug>/*.md`, so archived files drop out of every lookup with no change to the matching logic.

This step belongs to `handoff`/`pickup` alone. It is deliberately not wired into `finish-branch`: plenty of handoffs -- cross-repo cleanups, `arch-review` reports -- correspond to no branch at all, and tying the two lifecycles together would leave those permanently unarchivable.

## Anti-patterns

- **Don't** print the entire handoff file back to the user -- they wrote it; they know what's in it.
- **Don't** re-fetch references unless a next-step requires them. The handoff lists references so future-you knows they exist, not so you load them eagerly.
- **Don't** skip the suggested skills -- they were chosen at handoff time precisely because the next steps need them.
