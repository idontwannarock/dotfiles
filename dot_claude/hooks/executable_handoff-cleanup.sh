#!/usr/bin/env bash
# SessionEnd hook — clean up per-session handoff state.
#
# Removes:
#   ~/.cache/claude-handoff/session-<session_id>.cache   (statusline-written)
#   ~/.cache/claude-handoff/reminded-<session_id>-<tier> (reminder sentinels)
#
# Silent no-op on any error — this hook must never block session exit.

set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

SESSION_ID=$(jq -r '.session_id // empty' 2>/dev/null || echo "")
[ -n "$SESSION_ID" ] || exit 0

CACHE_DIR="${HOME}/.cache/claude-handoff"
[ -d "$CACHE_DIR" ] || exit 0

rm -f "${CACHE_DIR}/session-${SESSION_ID}.cache" 2>/dev/null
rm -f "${CACHE_DIR}/reminded-${SESSION_ID}"-* 2>/dev/null

exit 0
