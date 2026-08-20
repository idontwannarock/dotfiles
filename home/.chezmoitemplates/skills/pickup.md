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

**When the file has no `## Next steps`.** `handoff` guarantees the section, but nothing stops a session from writing a file into `~/.agent/handoffs/` by hand, and report-shaped ones routinely skip it. Steps 2 and 4 above and the whole of `Close out` then have nothing to bind to. Do not invent a list, and do not proceed silently: **name the section you are treating as next steps in your first message** -- "this file has no `## Next steps`; I am taking the open questions in the last section as the list" -- so the user can overrule the choice before any work happens. If no section can stand in, stop and ask rather than starting. A missing `## Suggested skills` reads the same way: invoke nothing, and say so.

## Close out

`~/.agent/handoffs/<repo-slug>/` doubles as a todo list, so a finished handoff has to leave it. Apart from a handoff with no nameable next steps, this is the only step in `pickup` that asks the user anything.

Once **every** item under `## Next steps` has met its success criterion:

1. List the items with the evidence for each -- the merged PR, the passing command and its output, the file that now exists. Evidence, not recollection.
2. Move out whatever has to outlive the lookup. Archiving discards nothing, but only while something still points back:
   - **Decisions belong in memory, not in the handoff.** A ruling reached during the work -- an interface shape, a scope call, a question deliberately left open -- vanishes from every lookup the moment the file moves. Write it to `~/.claude/memory/<repo-slug>/` first, then archive.
   - **Durable reference material gets cited by its post-archive path.** Half a finished handoff is spent todos; the other half can be an inventory, a dependency map, a batch plan that the next several sessions still need. Have a living artifact -- the successor handoff, a memory file -- name it as `~/.agent/handoffs/<repo-slug>/archive/<ID>.md`, the path it will hold **after** the move, never the one it holds now. A citation written against the current path breaks in the same step that creates it.
3. Ask whether to archive this handoff -- unless the user has a standing instruction to archive without asking (a per-repo memory, or something they said earlier in this session). A standing instruction replaces the question, never the evidence in step 1.
4. If the user agrees, `mv` the file to `~/.agent/handoffs/<repo-slug>/archive/<ID>.md`, creating the directory if missing. This is the destination even when the file was resolved from one of the legacy locations -- archiving doubles as the migration out of them.

Hard rules:

- **Never `rm` a handoff.** Archiving is a move. In 2026-08-03 a session judged five handoffs "done" by how similar their slugs looked to finished work and deleted them; two had never been started. `~/.agent/handoffs/` is not under version control, so a wrong call there is unrecoverable, while a wrongly archived file costs one `mv` to bring back.
- **Never decide "done" yourself.** Unmet or unverifiable criteria mean not done. If you cannot point at evidence for an item, say so and leave the file where it is.
- **Never move a handoff the user did not agree to move** -- including ones you noticed in the same directory while working. A standing instruction is agreement, and it covers only the handoff you just finished; it never reaches the neighbours.
- **Say nothing about archiving while any item is outstanding.** A partially finished handoff is still live.

The archive lives in a subdirectory on purpose: resolution above only globs `<repo-slug>/*.md`, so archived files drop out of every lookup with no change to the matching logic. That is also why step 2 exists -- dropping out of every lookup is exactly what makes an unmoved decision unfindable.

This step belongs to `handoff`/`pickup` alone. It is deliberately not wired into `finish-branch`: plenty of handoffs -- cross-repo cleanups, `arch-review` reports -- correspond to no branch at all, and tying the two lifecycles together would leave those permanently unarchivable.

## Anti-patterns

- **Don't** print the entire handoff file back to the user -- they wrote it; they know what's in it.
- **Don't** re-fetch references unless a next-step requires them. The handoff lists references so future-you knows they exist, not so you load them eagerly.
- **Don't** skip the suggested skills -- they were chosen at handoff time precisely because the next steps need them.
