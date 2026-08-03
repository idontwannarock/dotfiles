## Purpose

List the open handoffs for a repo. `~/.agent/handoffs/<repo-slug>/` is used as a todo list, and this is how you read it -- what is still outstanding, and roughly how much is left in each.

This skill reads and prints. It never moves, deletes, or rewrites anything. Archiving is `pickup`'s closing step, after the user confirms.

## Resolve the directory

Compute the **repo slug** the same way `handoff` and `pickup` do: `dirname(realpath(git rev-parse --git-common-dir))`, falling back to `$PWD` if that fails, with every `:`, `\`, `/`, and `.` replaced by `-`. Not `git rev-parse --show-toplevel` -- under bare+worktree that splits one repo across several directories.

The user may name a different repo (`--repo <path|name>`); resolve its slug with `git -C <target> rev-parse --git-common-dir`. If the path does not exist or is not a git repo, report it and stop.

## List

Read `~/.agent/handoffs/<repo-slug>/*.md` -- top level only. Skip the `archive/` subdirectory; those are already closed.

For each file, print one row:

- **ID** -- the filename without `.md`
- **Date** -- from the ID prefix
- **Task** -- one line, taken from the `## Task` section (first sentence) or the `# Handoff:` heading if there is no Task section
- **Steps** -- the number of items under `## Next steps`

Sort newest first. If a file is missing `## Next steps`, print `steps: —` and flag it as malformed: `pickup` cannot act on it, and it needs a human to say what was supposed to happen.

If the directory does not exist or holds no `.md` files, say there are no open handoffs and stop. That is not an error.

## Do not judge

- **Do not guess whether a handoff is finished.** Not from the slug, not from a related PR having merged, not from the topic looking familiar.
- **Do not flag "probably done" candidates**, even without acting on them. On 2026-08-03 a session ranked handoffs by how similar their slugs were to completed work, called five of them done, and deleted two that had never been started. Whoever reads this list is the only check on the archive decision -- a suggestive label corrupts exactly that check.
- **Do not touch any file.** No moves, no deletions, no edits, not even for entries that look obviously stale.

Determining that a handoff is complete requires walking its `## Next steps` against real evidence, which is `pickup`'s job with the user present.
