---
name: switch-repo-workflow
description: "Use when one repo should run a different development workflow from the rest — swapping this machine's OpenSpec dev-workflow for a plugin's (wayfinder, or any other), turning a discipline skill off in one project only, or explaining why a skill is still firing after being disabled. Triggers include 「這個 repo 換流程」、「切換 skill」、「per-repo skill 設定」、「為什麼 tdd 還在跑」, or any request to make Claude Code behave differently in one repository than in another. Skip when choosing which workflow to adopt (that is a design discussion, not a switch) and when authoring a skill rather than routing one."
---

# Switch one repo to a different development workflow

## Order of work

1. Install the incoming plugin at project scope, and register its marketplace.
2. Disable the outgoing **plugin** skills — `enabledPlugins`, not `skillOverrides`.
3. Disable the outgoing **repo** skills in `.claude/settings.json`.
4. Disable the outgoing **personal** skills in `.claude/settings.local.json`.
5. Make `.gitignore` stop hiding step 3's file.
6. Edit the prose the switch made **false** — usually only `CLAUDE.md`.
7. Verify in a new session.

Each step is one section below.

## Steps 1–4: where each decision is written

The split is by **who owns the decision**, not by what is being disabled.

| Decision | File | Tracked by git? |
|---|---|---|
| Plugins, and skills in the repo's own `.claude/skills/` | `.claude/settings.json` | yes — a team decision |
| Skills in your personal `~/.claude/skills/` | `.claude/settings.local.json` | no — nobody else has them |

⚠️ **Layers merge per key, not per file.** A `skillOverrides` block in
`settings.local.json` does **not** replace the one in `settings.json`. This is the fact the
split depends on; without it the local file would silently wipe the tracked one. Verified:
entries in both files were in effect at the same time.

```jsonc
// .claude/settings.json          — travels with the repo
{
  "extraKnownMarketplaces": { /* see step 1 */ },
  "enabledPlugins": { "mattpocock-skills@claude-plugins-official": true },
  "skillOverrides": { "openspec-new-change": "off", "openspec-apply-change": "off" }
}
```

```jsonc
// .claude/settings.local.json    — yours alone
{ "skillOverrides": { "dev-workflow": "off", "tdd": "off", "grill": "off" } }
```

**Step 1.** `claude plugin install <plugin>@<marketplace> --scope project` writes
`enabledPlugins` in the repo's `.claude/settings.json` and nothing else. That is enough for
your machine but **not** for a teammate's clone: without the marketplace registered, Claude
Code reports the plugin as enabled-but-not-installed. The CLI's settings schema names
`extraKnownMarketplaces` as the repo-level key for exactly this — add it if the switch is
meant to travel. (Schema-sourced, unlike everything else here; not tested on a second
machine.)

**Step 2.** Turning a plugin skill off is a different mechanism — see below.

## Step 2: `skillOverrides` cannot touch plugin skills

`skillOverrides` states: `on` · `name-only` · `user-invocable-only` (hidden from the model,
still on the `/` menu) · `off`.

⚠️ **None of them apply to plugin skills.** The lookup returns `on` for anything whose
source is a plugin *before* it consults `skillOverrides` at all. So `{"tdd": "off"}`
disables `~/.claude/skills/tdd` while `mattpocock-skills:tdd` keeps running. Verified in a
fresh session.

Two consequences:

- A plugin skill colliding with one of yours needs **no rename**. Turn yours off and the
  plugin's takes the name.
- To disable a plugin skill you must disable **the plugin**:
  `"enabledPlugins": { "<plugin>@<marketplace>": false }`. Precedence runs
  user < project < local < flag < policy, so `settings.local.json` can switch off a plugin
  that `settings.json` enabled.

`skillOverrides` also cannot reach skill copies under `.agent/` or `.codex/` — other tools'
trees.

**A skill declaring `disable-model-invocation: true` is absent from the model's listing on
purpose**; it lives only in the `/` menu. Do not read that absence as a failed install.
Pocock's `wayfinder` / `to-spec` / `to-tickets` / `implement` are all of this kind — which
matters for step 7.

## Steps 5–6: the two traps settings cannot cover

**`.gitignore` hiding the tracked settings file.** A pattern like `/.claude/*` excludes
`settings.json` along with everything else, so the team decision silently stays local. Add
the negation:

```gitignore
/.claude/*
!/.claude/CLAUDE.md
!/.claude/settings.json
```

**Prose that steers the model.** Settings disable a *skill*; they cannot disable a
sentence. A line like "implementation tasks go through the OpenSpec flow" keeps steering
the model after every relevant skill is off.

⚠️ **Grepping for the old workflow's name finds far more than you must change, and
rewriting the surplus is the expensive mistake here.** A mature repo names its old workflow
in a glossary, an architecture overview, a spec tree, a README. None of that is an
instruction.

Apply one test to each hit — **is this sentence now false?**

| Hit | False after the switch? | Do |
|---|---|---|
| "implementation tasks go through the OpenSpec flow" | yes — no such flow runs here now | edit |
| "`openspec/specs/` holds the behaviour contracts" | no — the files are still there | leave |
| A glossary entry defining `dev-workflow` | no — the skill still exists | leave |
| "this repo also carries a home-grown workflow system" | no — it still does | leave |

Only sentences that became false are in scope, and they cluster in the files an agent
actually reads as instruction: `CLAUDE.md`, `.claude/CLAUDE.md`, `AGENTS.md`. **Leave
`README.md`, `docs/`, and any spec or context tree alone.** Those record what the repo
contains, and a routing change does not make a record wrong. Switching this dotfiles repo
turned up hits in four `context/` files, a README and a docs page — and under the test,
**not one of them needed editing**.

A spec tree that stops being maintained is a separate decision, taken later, on evidence
that the new workflow stuck. It is not part of flipping the routing.

## Step 7: verify in a new session

Do not trust the current session's listing — it was built from the settings as they were at
startup. Re-check in a fresh one.

**Pick a name that is model-invocable.** Querying the listing for `wayfinder` proves
nothing: it carries `disable-model-invocation: true`, so an empty answer is the expected
result either way. Query a name that should visibly change.

```bash
cd <the repo>
# should now be GONE — a user skill you turned off
claude -p "List the skills in your listing whose name contains 'openspec'. Names only."
# should still be THERE — the plugin's copy, surviving the override on your own
claude -p "List the skills in your listing whose name contains 'tdd'. Names only."
```

The second command is the check for step 2: a name that survives being switched `off` is
the plugin's copy, and that is what you want.
