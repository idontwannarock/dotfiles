#!/usr/bin/env bash
# Symlink the dev-workflow-required superpowers skills into ~/.codex/skills so Codex
# can invoke them by flat name. Symlinks (not copies) keep upstream plugin updates.
set -euo pipefail

CACHE_ROOT="$HOME/.claude/plugins/cache/claude-plugins-official/superpowers"
[ -d "$CACHE_ROOT" ] || { echo "ERROR: superpowers plugin cache not found at $CACHE_ROOT" >&2; exit 1; }

# Resolve highest installed version dir (e.g. 6.0.0)
VER_DIR=$(ls -d "$CACHE_ROOT"/*/ 2>/dev/null | sort -V | tail -1)
[ -n "$VER_DIR" ] || { echo "ERROR: no superpowers version under $CACHE_ROOT" >&2; exit 1; }
SKILLS_SRC="${VER_DIR%/}/skills"

NEEDED="brainstorming writing-plans verification-before-completion finishing-a-development-branch using-git-worktrees"
mkdir -p "$HOME/.codex/skills"
for s in $NEEDED; do
  [ -d "$SKILLS_SRC/$s" ] || { echo "ERROR: missing superpowers skill: $s" >&2; exit 1; }
  ln -sfn "$SKILLS_SRC/$s" "$HOME/.codex/skills/$s"
done
echo "[superpowers-codex] linked: $NEEDED"
