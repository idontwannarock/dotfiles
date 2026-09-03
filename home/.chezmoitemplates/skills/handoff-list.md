## Purpose

List the open handoffs for a repo. `~/.agent/handoffs/<repo-slug>/` is used as a todo list, and this is how you read it -- what is still outstanding, and roughly how much is left in each.

This skill reads and prints. It never moves, deletes, or rewrites anything. Archiving is `pickup`'s closing step, after the user confirms.

## Resolve the directory

Compute the **repo slug** the same way `handoff` and `pickup` do: take `git rev-parse --path-format=absolute --git-common-dir` minus its last component, falling back to `$PWD` if that fails, then replace every `:`, `\`, `/`, and `.` with `-`. Not `git rev-parse --show-toplevel` -- under bare+worktree that splits one repo across several directories.

The user may point at a different repo with `--repo <path>`; resolve its slug with `git -C <target> rev-parse --path-format=absolute --git-common-dir`. Keep `--path-format=absolute`: without it git prints a path relative to your own cwd and you get the current repo's slug instead. If the path does not exist or is not a git repo, report it and stop.

## List

Read `~/.agent/handoffs/<repo-slug>/*.md` -- top level only. Skip the `archive/` subdirectory; those are already closed.

For each file, print one row:

- **ID** -- the filename without `.md`
- **Date** -- from the ID prefix
- **Kind** -- `handoff_kind` from the file's YAML frontmatter. Print `task` when the key or the frontmatter is absent; that is what every consumer reads it as, and printing `—` would suggest a third state that does not exist. Report the value as written -- do not infer `succession` from same-slug neighbours.
- **Task** -- one line, taken from the `## Task` section (first sentence) or the `# Handoff:` heading if there is no Task section
- **Steps** -- the number of items under `## Next steps`

A `succession` row means a line of work whose earlier rounds were retired by `handoff` as each successor was written. Seeing exactly one open row per line is the expected state, not evidence that history was lost -- the earlier rounds are in `archive/`. Several open `succession` rows sharing a slug is the opposite: they predate this convention or a `supersedes` move failed. Say so; do not fix it.

Sort newest first. If a file is missing `## Next steps`, print `steps: —` and flag it as malformed: `pickup` cannot act on it, and it needs a human to say what was supposed to happen.

If that directory does not exist or holds no `.md` files, check the same legacy locations `pickup` falls back to, in order: `~/.local/state/handoffs/<repo-slug>/`, then `<repo>/.claude/handoffs/`. List whatever you find there, marked as legacy. Only after all three come up empty do you report that there are no open handoffs -- that is not an error, but a false "nothing to do" is the one output this skill must never produce, and `pickup` would still resume those files.

## Do not judge

- **Do not guess whether a handoff is finished.** Not from the slug, not from a related PR having merged, not from the topic looking familiar.
- **Do not flag "probably done" candidates**, even without acting on them. On 2026-08-03 a session ranked handoffs by how similar their slugs were to completed work, called five of them done, and deleted two that had never been started. Whoever reads this list is the only check on the archive decision -- a suggestive label corrupts exactly that check.
- **Do not touch any file.** No moves, no deletions, no edits, not even for entries that look obviously stale.

Determining that a handoff is complete requires walking its `## Next steps` against real evidence, which is `pickup`'s job with the user present.
