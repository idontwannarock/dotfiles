# repo-workflow-switching Specification

## Purpose
TBD - created by archiving change add-switch-repo-workflow-skill. Update Purpose after archive.
## Requirements
### Requirement: A user-level skill covers switching a repo's development workflow

The dotfiles source SHALL provide a Claude-only, user-level skill at
`home/dot_claude/skills/switch-repo-workflow/SKILL.md` that documents the procedure for
changing which development-workflow skills are active in a given repository. The skill
SHALL be a plain `SKILL.md`, not a `.chezmoitemplates/skills/*.md` body plus wrapper, and
SHALL have no Codex counterpart under `home/dot_codex/skills/`.

#### Scenario: Skill deploys to the user skills directory

- **WHEN** `chezmoi apply` runs on any machine
- **THEN** `~/.claude/skills/switch-repo-workflow/SKILL.md` exists
- **AND** no directory `~/.codex/skills/switch-repo-workflow` is created

#### Scenario: Skill is model-invocable by topic

- **WHEN** a new Claude Code session lists its available skills
- **THEN** `switch-repo-workflow` appears in that listing with a `description` naming both
  Chinese and English trigger phrases for switching a repo's workflow

### Requirement: The skill records the settings-layering rules

The skill SHALL state where each kind of decision is written: repo-scoped decisions
(installed plugins, the repo's own `.claude/skills/`) in `.claude/settings.json`, and
decisions about the operator's personal `~/.claude/skills/` in
`.claude/settings.local.json`. It SHALL state that settings layers merge per key rather
than one layer replacing another, and SHALL name that per-key merge as the precondition
that makes the split viable.

#### Scenario: Reader needs to place a decision

- **WHEN** a reader must decide which settings file disables a personal `~/.claude/skills/`
  entry
- **THEN** the skill directs them to `.claude/settings.local.json` and explains that the
  repo-tracked `settings.json` entries stay in effect alongside it

### Requirement: The skill records what `skillOverrides` cannot reach

The skill SHALL enumerate the four `skillOverrides` states (`on`, `name-only`,
`user-invocable-only`, `off`), and SHALL state that `skillOverrides` has no effect on
plugin skills, so a plugin skill sharing a name with a user skill needs no rename. It
SHALL also state that skill copies under `.agent/` and `.codex/` are outside its reach,
and that a skill declaring `disable-model-invocation: true` is absent from the model's
listing while still present in the `/` menu.

#### Scenario: Name collision between a user skill and a plugin skill

- **WHEN** a reader has a `~/.claude/skills/tdd` and installs a plugin providing `tdd`
- **THEN** the skill tells them `{"tdd": "off"}` disables only the user copy and the plugin
  copy stays live, and that renaming either is unnecessary

#### Scenario: A newly installed plugin skill is missing from the listing

- **WHEN** a reader cannot see an installed plugin skill in the model's skill listing
- **THEN** the skill tells them to check for `disable-model-invocation: true` before
  concluding the install failed

### Requirement: The skill records the two traps that settings cannot cover

The skill SHALL warn that a `.gitignore` pattern such as `/.claude/*` also excludes
`.claude/settings.json`, and that a `!/.claude/settings.json` negation is needed for the
repo-scoped decision to be version-controlled. It SHALL also state that settings cannot
override prose in `CLAUDE.md` naming the old workflow, and that such prose must be edited
as part of the switch.

#### Scenario: Repo ignores its own settings file

- **WHEN** a reader's repo has `/.claude/*` in `.gitignore`
- **THEN** the skill tells them to add `!/.claude/settings.json` so the workflow decision
  travels with the repo

### Requirement: The skill prescribes a verification step in a fresh session

The skill SHALL state that changed settings take effect only in a new session, and SHALL
give a concrete verification command of the form
`claude -p "<ask for the skill listing filtered by name>"` run inside the target repo.

#### Scenario: Reader verifies a completed switch

- **WHEN** the reader has finished editing settings and `CLAUDE.md`
- **THEN** the skill directs them to run the verification command in a new session, and
  warns that the session that made the edits will never reflect them

