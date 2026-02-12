## Why

Superpowers skills require typing long names like `superpowers:systematic-debugging`. OpenSpec already has short aliases (`opsx:ff` for `openspec-ff-change`), but superpowers lacks equivalent shortcuts. Adding `sp:*` commands reduces friction and makes the workflow faster.

## What Changes

- Add `.claude/commands/sp/` directory with command files for each superpowers skill
- Each command file follows the same format as existing `opsx/*.md` commands
- Commands invoke the corresponding `superpowers:*` skill via the Skill tool

## Capabilities

### New Capabilities
- `sp-commands`: Short command aliases (`/sp:*`) for all superpowers skills, created as `.claude/commands/sp/*.md` files

### Modified Capabilities

_(none)_

## Impact

- New files: ~14 command `.md` files in `.claude/commands/sp/`
- No code changes, no API changes, no breaking changes
- Both project-level (dotfiles) and global (`~/.claude/commands/`) locations will have these commands after sync
