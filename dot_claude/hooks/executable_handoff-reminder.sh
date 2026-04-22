#!/usr/bin/env bash
# UserPromptSubmit hook — tier-based reminder to run /handoff skill.
#
# Reads transcript_path from stdin JSON, estimates context % from the latest
# assistant message's `usage` field, and emits a Chinese reminder when usage
# crosses 40% / 70% / 90% (aligned with statusline color tiers). Fires once
# per (session, tier); sentinels live at
#   ~/.cache/claude-handoff/reminded-<session_id>-<tier>
#
# Context window resolution order:
#   1. $CLAUDE_HANDOFF_CONTEXT_WINDOW env var (debug/override only)
#   2. ~/.cache/claude-handoff/session-<session_id>.cache (statusline-written,
#      primary source — mirrors the actual context_window_size Claude Code
#      pushes to the statusline command)
#   3. ~/.cache/claude-handoff/latest.cache (statusline-written, cross-session
#      fallback — covers the race window where SessionEnd just cleaned the
#      per-session cache and the new session's statusline hasn't rendered yet)
#   4. Model name mapping fallback (claude-opus-*/sonnet-*/haiku-* → 200000)
#   5. Fallback default 200000
#
# Silent no-op on any error or missing data — this hook must never block prompts.

set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

INPUT="$(cat)"
SESSION_ID=$(jq -r '.session_id // empty' <<<"$INPUT" 2>/dev/null || echo "")
TRANSCRIPT=$(jq -r '.transcript_path // empty' <<<"$INPUT" 2>/dev/null || echo "")

[ -n "$SESSION_ID" ] && [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0

# Find the latest assistant message that has usage info.
USAGE_JSON=$(jq -c 'select(.type == "assistant" and (.message.usage // false)) | .message | {model, usage}' "$TRANSCRIPT" 2>/dev/null | tail -1)
[ -n "$USAGE_JSON" ] || exit 0

USED=$(jq -r '(.usage.input_tokens // 0) + (.usage.cache_creation_input_tokens // 0) + (.usage.cache_read_input_tokens // 0)' <<<"$USAGE_JSON" 2>/dev/null || echo 0)
MODEL=$(jq -r '.model // empty' <<<"$USAGE_JSON" 2>/dev/null || echo "")

case "$USED" in ''|*[!0-9]*) exit 0 ;; esac
[ "$USED" -gt 0 ] || exit 0

read_cache_int() {
    local f="$1"
    [ -s "$f" ] || return 1
    local v
    v=$(cat "$f" 2>/dev/null)
    case "$v" in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ "$v" -gt 0 ] 2>/dev/null || return 1
    printf '%s\n' "$v"
}

CACHE_DIR="${HOME}/.cache/claude-handoff"
WINDOW="${CLAUDE_HANDOFF_CONTEXT_WINDOW:-}"
if [ -z "$WINDOW" ]; then
    WINDOW=$(read_cache_int "${CACHE_DIR}/session-${SESSION_ID}.cache") \
        || WINDOW=$(read_cache_int "${CACHE_DIR}/latest.cache") \
        || WINDOW=""
fi
if [ -z "$WINDOW" ]; then
    case "$MODEL" in
        claude-opus-*|claude-sonnet-*|claude-haiku-*) WINDOW=200000 ;;
        *) WINDOW=200000 ;;
    esac
fi

PCT=$(( USED * 100 / WINDOW ))

if   [ "$PCT" -ge 90 ]; then TIER=90; LABEL="🚨 緊急"
elif [ "$PCT" -ge 70 ]; then TIER=70; LABEL="⚠️  強烈建議"
elif [ "$PCT" -ge 40 ]; then TIER=40; LABEL="⚠️  注意"
else exit 0
fi

SENTINEL_DIR="${HOME}/.cache/claude-handoff"
mkdir -p "$SENTINEL_DIR" 2>/dev/null || exit 0
SENTINEL="${SENTINEL_DIR}/reminded-${SESSION_ID}-${TIER}"
[ -f "$SENTINEL" ] && exit 0
touch "$SENTINEL" 2>/dev/null || true

MSG="[handoff-reminder] ${LABEL}：Context 使用量約 ${PCT}%（剛跨越 ${TIER}% 門檻）。請主動告知使用者，並建議呼叫 /handoff skill 產生 resumption prompt，以便切到新 session 時無縫接續。若使用者不需要切 session，忽略即可；下次跨越下個門檻才會再提醒。"

jq -nc --arg msg "$MSG" '{
    hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: $msg
    }
}'

exit 0
