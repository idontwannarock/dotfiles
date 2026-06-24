## Purpose

Boot a new session from a previously saved handoff file. Reads the file, invokes any suggested skills, then proceeds with the next steps -- no summarizing, no confirmation.

## Resolve the handoff file

Compute the **repo slug** from the current working repo: take the absolute path (`git rev-parse --show-toplevel` falling back to `$PWD`) and replace every `:`, `\`, `/`, and `.` with `-`. Example: `D:\ws\github\dotfiles` becomes `D--ws-github-dotfiles`.

Then look in `~/.agent/handoffs/<repo-slug>/`. Resolution order, given the user's argument:

1. **Exact ID** (with or without `.md`): `<id>.md` -- single file match.
2. **Slug only** (e.g. `phone-ssh-shortcuts`): glob `*__<slug>.md`. If exactly one match, use it. If multiple, list them with mtime and ask the user which.
3. **Date prefix** (e.g. `2026-05-26` or `2026-05-26-1430`): glob `<prefix>*.md`. Same disambiguation rule as slug.
4. **No argument**: pick the file with the latest mtime.

If nothing matches in `~/.agent/handoffs/<repo-slug>/`, check the legacy locations once, in order: `~/.local/state/handoffs/<repo-slug>/` (the pre-`~/.agent` location), then `<repo>/.claude/handoffs/` (files written before 2026-05-26). If still nothing, report the absolute paths searched and stop -- do not invent a file.

## Apply

1. Read the resolved file in full.
2. Invoke each skill listed under `## Suggested skills` (use the Skill tool / equivalent on Codex). If a listed skill is not available, note it briefly and continue.
3. Proceed with the items under `## Next steps`. Treat any user-supplied args (beyond the ID) as additional context that supersedes or refines the first next-step item.
4. Do not summarize the handoff content back to the user. Do not ask for confirmation. Just continue working.

## Anti-patterns

- **Don't** print the entire handoff file back to the user -- they wrote it; they know what's in it.
- **Don't** re-fetch references unless a next-step requires them. The handoff lists references so future-you knows they exist, not so you load them eagerly.
- **Don't** skip the suggested skills -- they were chosen at handoff time precisely because the next steps need them.
