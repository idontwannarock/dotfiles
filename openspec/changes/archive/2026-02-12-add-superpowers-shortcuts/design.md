## Context

The dotfiles project manages cross-platform config files, including `.claude/commands/` for Claude Code command shortcuts. The existing `opsx:*` shortcuts demonstrate the pattern: `.claude/commands/<prefix>/<name>.md` files become `/prefix:name` commands.

Superpowers is an official Claude Code plugin providing 14 skills with long names (e.g., `superpowers:test-driven-development`). These need shorter aliases.

## Goals / Non-Goals

**Goals:**
- Create `/sp:*` shortcut commands for all superpowers skills
- Follow the same command file format used by `opsx:*`
- Keep command files minimal — they delegate to the superpowers skill, not duplicate its content

**Non-Goals:**
- Modifying the superpowers plugin itself
- Creating custom skill logic beyond delegation
- Handling superpowers version changes or skill discovery

## Decisions

**Prefix: `sp`**
Short, memorable, unambiguous. Mirrors `opsx` pattern. Alternative `super` considered but too long.

**Command content: Skill tool delegation**
Each command file instructs Claude to invoke the corresponding `superpowers:*` skill using the Skill tool, passing through any arguments. This avoids duplicating skill content and stays in sync with plugin updates.

**Naming mapping:**
| Command | Skill |
|---------|-------|
| `sp:brainstorm` | `superpowers:brainstorming` |
| `sp:tdd` | `superpowers:test-driven-development` |
| `sp:debug` | `superpowers:systematic-debugging` |
| `sp:plan` | `superpowers:writing-plans` |
| `sp:exec` | `superpowers:executing-plans` |
| `sp:worktree` | `superpowers:using-git-worktrees` |
| `sp:subagent` | `superpowers:subagent-driven-development` |
| `sp:parallel` | `superpowers:dispatching-parallel-agents` |
| `sp:review` | `superpowers:requesting-code-review` |
| `sp:recv-review` | `superpowers:receiving-code-review` |
| `sp:finish` | `superpowers:finishing-a-development-branch` |
| `sp:verify` | `superpowers:verification-before-completion` |
| `sp:write-skill` | `superpowers:writing-skills` |
| `sp:init` | `superpowers:using-superpowers` |

## Risks / Trade-offs

**[Skill name changes in future plugin versions]** → Command files reference skill names by string; if the plugin renames a skill, the command breaks. Mitigation: superpowers is stable; fix when it happens.

**[Duplicate listings in skill menu]** → Both `sp:tdd` and `superpowers:test-driven-development` will appear. Acceptable trade-off for convenience.

**[Windows `skill.md` 命名衝突]** → 在 Windows 上 `skill.md` 等同 `SKILL.md`（大小寫不敏感），Claude Code 會將含有 `SKILL.md` 的目錄視為 skill 定義而非 command 群組，導致該目錄下所有 command 無法被發現。已將 `skill.md` 改名為 `write-skill.md` 解決。
