## Context

The facts this skill carries were all established by direct experiment during the
`shoalter-ai-toolkit` switchover (OpenSpec `dev-workflow` → Matt Pocock's wayfinder
plugin), not read out of documentation. They are:

1. `claude plugin install <p>@<marketplace> --scope project` writes only the repo's
   `.claude/settings.json` `enabledPlugins`.
2. `skillOverrides` has four states: `on`, `name-only`, `user-invocable-only`, `off`.
3. `skillOverrides` **does not reach plugin skills**. `{"tdd":"off"}` disables
   `~/.claude/skills/tdd` while `mattpocock-skills:tdd` stays live — so a name collision
   needs no rename. Verified in a fresh session.
4. Settings layers merge **per key**, not wholesale: `settings.json`'s `openspec-*` entries
   and `settings.local.json`'s `dev-workflow` entry were simultaneously in effect. This is
   the precondition that makes layering possible at all.
5. Layering rule: decisions belonging to the repo (plugins, the repo's own
   `.claude/skills/`) go in `.claude/settings.json`; decisions about the operator's
   personal `~/.claude/skills/` go in `.claude/settings.local.json`.
6. `.gitignore` trap: a pattern like `/.claude/*` swallows `settings.json` too. A
   `!/.claude/settings.json` negation is required for the workflow consensus to travel
   with the repo.
7. Settings can disable a skill; they cannot disable a **sentence in CLAUDE.md** that
   names the old workflow. That prose has to be edited too.
8. Verification: run `claude -p "…list skills whose name contains X…"` inside the repo.
   Only a **new** session loads changed settings; the current one never reloads.
9. A skill with `disable-model-invocation: true` is absent from the model's listing and
   present only in the `/` menu — not a sign of a failed install. Pocock's
   wayfinder/to-spec/to-tickets/implement are all of this kind.
10. Skill copies under `.agent/` and `.codex/` are outside Claude's `skillOverrides`
    reach entirely.

Without a carrier these live in one project's memory file, invisible to the next repo
that needs the same switchover.

## Goals / Non-Goals

**Goals:**
- One user-level skill that turns the ten facts above into an executable procedure.
- Auto-triggerable: the operator should not have to remember the skill's name.
- Reach every repo on every machine via chezmoi.

**Non-Goals:**
- Not a Codex skill. Every mechanism named is Claude Code-specific.
- Not a wayfinder tutorial, and not an endorsement of any particular target workflow —
  the skill covers the *switch*, whatever the destination.
- No automation: the skill instructs; it does not edit another repo's settings unattended.

## Decisions

**Skill, not slash command.** A slash command fires only when the operator types its
name. The realistic trigger here is oblique — "why is `tdd` still running in this repo",
"I want this repo on wayfinder" — which only a skill `description` can catch. A skill is
also still reachable as `/switch-repo-workflow`, so the command affordance is not lost.
Alternative considered: `~/.claude/commands/`; rejected because it gives up model
invocation for nothing.

**Name `switch-repo-workflow`, not `repo-skill-routing`.** The scene is what the operator
recalls; the mechanism is what they are trying to find out. Naming for the scene makes the
trigger phrases writable ("換流程", "切換 skill", "per-repo skill").

**Plain `SKILL.md`, not the shared-body template route.** `home/dot_claude/skills/` holds
both shapes: `wsl-chrome-cdp/SKILL.md` (Claude-only, plain file) and
`coordinate/SKILL.md.tmpl` (shared body under `.chezmoitemplates/skills/`, one wrapper per
tool). The shared route exists to keep two tools' copies from drifting. With no Codex
copy there is nothing to keep in sync, and the wrapper adds a render step and a name-map
key that can silently render `<no value>`. Follow `wsl-chrome-cdp`.

**Facts stated with their provenance.** Each mechanic in the skill says it was verified by
experiment, and the two that contradict a reasonable prior (plugin skills being out of
`skillOverrides` reach; per-key layer merging) say so explicitly. A skill that merely
asserts them invites the reader to re-test.

## Risks / Trade-offs

- **[Claude Code changes the `skillOverrides` contract]** → The skill cites the official
  docs page alongside each mechanic, so a reader who hits a contradiction knows where to
  check rather than assuming the skill is right.
- **[The skill drifts out of date silently]** → Accepted. It is a procedure document, not
  code; nothing tests it. Mitigation is the provenance note above, which tells a future
  reader the claims were empirical and therefore re-testable by the same commands.
- **[Trigger description too broad, skill loads when unwanted]** → The `description`
  carries an explicit skip clause (not for choosing *which* workflow to adopt, not for
  authoring a skill) the way `wsl-chrome-cdp`'s does.
