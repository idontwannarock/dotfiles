## 1. Write the skill

- [x] 1.1 Create `home/dot_claude/skills/switch-repo-workflow/SKILL.md` as a plain
  `SKILL.md` modelled on `home/dot_claude/skills/wsl-chrome-cdp/SKILL.md`: frontmatter with
  `name` + a quoted `description` carrying Chinese and English trigger phrases and an
  explicit skip clause; body covering the layering rules, the four `skillOverrides` states
  and their limits, the two traps (`.gitignore`, `CLAUDE.md` prose), and the fresh-session
  verification command.
  Verify: `chezmoi diff` shows exactly one new file and no other hunk; the frontmatter
  `description` is a quoted scalar; `home/dot_codex/skills/` gains no directory.

## 2. Deploy and confirm

- [x] 2.1 Apply only this subtree: `chezmoi apply ~/.claude/skills/switch-repo-workflow`.
  Verify: `~/.claude/skills/switch-repo-workflow/SKILL.md` exists and matches the source.
- [x] 2.2 Confirm the skill is visible to a new session.
  Verify: `claude -p "list skills whose name contains switch-repo"` names it.
