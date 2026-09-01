---
name: switch-repo-workflow
description: "Use when one repo should run a different development workflow from the rest — swapping this machine's OpenSpec dev-workflow for a plugin's (wayfinder, or any other), turning a discipline skill off in one project only, or explaining why a skill is still firing after being disabled. Triggers include 「這個 repo 換流程」、「切換 skill」、「per-repo skill 設定」、「為什麼 tdd 還在跑」, or any request to make Claude Code behave differently in one repository than in another. Skip when choosing which workflow to adopt (that is a design discussion, not a switch) and when authoring a skill rather than routing one."
---

# Switch one repo to a different development workflow

Claude Code decides which skills are live per repo through two settings files and a plugin
scope. This skill is the procedure for driving that, plus the mechanics that are not
obvious from the docs.

Every mechanic below was established by direct experiment during the `shoalter-ai-toolkit`
switchover (OpenSpec `dev-workflow` → the `mattpocock-skills` plugin), not read off a
reference page. Two of them contradict a reasonable prior and are flagged where they
appear. Official reference: <https://code.claude.com/docs/en/skills>.

## The layering rule

Two settings files, and the split is by **who owns the decision**, not by what is being
disabled.

| Decision | File | Tracked by git? |
|---|---|---|
| Which plugins this repo uses | `.claude/settings.json` | yes — it is a team decision |
| Skills living in the repo's own `.claude/skills/` | `.claude/settings.json` | yes |
| Skills living in your personal `~/.claude/skills/` | `.claude/settings.local.json` | no — nobody else has them |

**Layers merge per key, not per file.** This is the fact the split depends on: a
`skillOverrides` block in `settings.local.json` does **not** replace the one in
`settings.json`. Verified — ten `openspec-*` entries in the tracked file and five personal
entries in the local file were simultaneously in effect.

Working example:

```jsonc
// .claude/settings.json          — travels with the repo
{
  "enabledPlugins": { "mattpocock-skills@claude-plugins-official": true },
  "skillOverrides": { "openspec-new-change": "off", "openspec-apply-change": "off" }
}
```

```jsonc
// .claude/settings.local.json    — yours alone
{ "skillOverrides": { "dev-workflow": "off", "tdd": "off", "grill": "off" } }
```

Install a plugin at repo scope with:

```
claude plugin install <plugin>@<marketplace> --scope project
```

That writes `enabledPlugins` in the repo's `.claude/settings.json` and nothing else.

## `skillOverrides`: four states, and what it cannot reach

States: `on` · `name-only` · `user-invocable-only` · `off`.

**It does not apply to plugin skills.** ⚠️ This is the one that surprises people. Setting
`{"tdd": "off"}` disables `~/.claude/skills/tdd`; `mattpocock-skills:tdd` keeps running.
The upside: a plugin skill colliding with one of yours needs **no rename** — turn yours
off and the plugin's takes over the name. Verified in a fresh session.

It also cannot reach skill copies under `.agent/` or `.codex/`. Those are other tools'
trees; Claude's overrides never touch them.

**A skill with `disable-model-invocation: true` is absent from the model's skill listing
on purpose** — it lives only in the `/` menu. Do not read that absence as a failed
install. All four of Pocock's `wayfinder` / `to-spec` / `to-tickets` / `implement` are of
this kind.

## Two traps settings cannot cover

**1. `.gitignore` swallowing the tracked settings file.** A pattern like `/.claude/*`
excludes `settings.json` along with everything else, so the workflow decision silently
stays local. Add the negation:

```gitignore
/.claude/*
!/.claude/CLAUDE.md
!/.claude/settings.json
```

**2. `CLAUDE.md` prose naming the old workflow.** Settings disable a *skill*; they cannot
disable a sentence. A line like "implementation tasks go through the OpenSpec flow" keeps
steering the model after every relevant skill is off. Grep the repo's `CLAUDE.md` (and
`.claude/CLAUDE.md`) for the old workflow's name and edit it as part of the switch.

## Verify — in a **new** session

Changed settings load at session start. The session that made the edits will never reflect
them, no matter how long you wait.

```bash
cd <the repo>
claude -p "List the skills in your listing whose name contains 'wayfinder'."
```

Run it twice if needed — once for what should now be present, once for what should now be
gone. Absence of a `disable-model-invocation: true` skill is expected, not a failure.

## Order of work

1. Install the target plugin at project scope (if the new workflow is a plugin).
2. Turn off the outgoing repo-level and plugin-level skills in `.claude/settings.json`.
3. Turn off the outgoing personal skills in `.claude/settings.local.json`.
4. Fix `.gitignore` so step 2's file is tracked.
5. Edit `CLAUDE.md` prose that names the old workflow.
6. Verify in a new session.
