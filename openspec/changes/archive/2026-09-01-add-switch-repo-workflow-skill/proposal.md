## Why

Switching a repo from one development-workflow skill set to another (e.g. this repo's
OpenSpec `dev-workflow` → Matt Pocock's wayfinder plugin) turns out to depend on a set of
Claude Code routing mechanics that are neither obvious nor documented in one place:
`skillOverrides` has four states and silently does nothing to plugin skills, settings
layers merge per key rather than wholesale, and a `.gitignore` glob can quietly keep the
repo-level decision out of version control. These facts were established by hands-on
testing during the `shoalter-ai-toolkit` switchover; without a carrier they live only in
that session's memory and the next switchover re-discovers them by trial and error.

## What Changes

- Add a user-level, Claude-only skill `switch-repo-workflow` under
  `home/dot_claude/skills/switch-repo-workflow/SKILL.md` (plain `SKILL.md`, not a
  `.chezmoitemplates/skills/*.md` + wrapper pair, since no Codex counterpart exists).
- The skill records the routing mechanics as procedure: which settings file each decision
  belongs in, what `skillOverrides` can and cannot reach, the `.gitignore` trap, the
  CLAUDE.md prose that settings cannot override, and the new-session verification command.
- No Codex copy: the content is entirely Claude Code-specific (`skillOverrides`, plugin
  scope) and has no Codex equivalent.

## Capabilities

### New Capabilities
- `repo-workflow-switching`: the procedure and layering rules for changing which
  development-workflow skills are active in a given repo.

### Modified Capabilities

(none — no existing spec's requirements change)

## Impact

- New source file under `home/dot_claude/skills/`; deployed to `~/.claude/skills/` on apply.
- No script, template fragment, or `.chezmoiignore` change: the existing
  `home/dot_claude/skills/*` handling already covers a new plain-`SKILL.md` directory.
- No `.chezmoiremove` entry (nothing retired).
- Affects only Claude Code sessions; Codex and `.agent/` copies untouched.
