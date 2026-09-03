#!/usr/bin/env bash
# UserPromptSubmit hook — tier-based reminder to prune this repo's MEMORY.md index.
#
# The auto-memory index loads in full at every session start, so its size is a
# per-turn tax on every session in that repo, and past ~24KB Claude Code stops
# loading the tail — entries below the cut become invisible, which reads exactly
# like "there is no memory about this". Nothing in the repo surfaces that; the
# index only gets pruned when someone happens to look. This hook is the trigger:
# it measures the file and speaks up before the cliff.
#
# Thresholds are BYTES, not line count. The load limit is a byte budget, and one
# repo can carry 150 short hooks while another carries 40 long ones.
#   30KB → 🚨 past the ~24.4KB load limit: tail entries are invisible right now
#   24KB → ⚠️  at the cliff, prune before the next session
#   16KB → ⚠️  approaching, plan a prune
#
# The memory dir comes from `claude-memory-seed where`, the same resolver that
# writes autoMemoryDirectory, so this hook and the setting can never disagree.
# It prints a LITERAL tilde; expanding it by hand is load-bearing — bash does not
# expand a tilde that arrives inside a variable, so the unexpanded path would
# just fail the -f test and the hook would silently never fire.
#
# Fires once per (session, tier); sentinels live at
#   ~/.cache/claude-handoff/memory-index-<session_id>-<tier>
#
# Silent no-op on any error or missing data — this hook must never block prompts.

set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

INPUT="$(cat)"
SESSION_ID=$(jq -r '.session_id // empty' <<<"$INPUT" 2>/dev/null || echo "")
[ -n "$SESSION_ID" ] || exit 0

SEED="${HOME}/.local/bin/claude-memory-seed"
[ -x "$SEED" ] || [ -f "$SEED" ] || exit 0

MEM_DIR=$(bash "$SEED" where 2>/dev/null || echo "")
[ -n "$MEM_DIR" ] || exit 0
case "$MEM_DIR" in
    "~/"*) MEM_DIR="${HOME}/${MEM_DIR#\~/}" ;;
esac

INDEX="${MEM_DIR}/MEMORY.md"
[ -f "$INDEX" ] || exit 0

BYTES=$(wc -c <"$INDEX" 2>/dev/null | tr -d ' ')
case "$BYTES" in ''|*[!0-9]*) exit 0 ;; esac

if   [ "$BYTES" -ge 30000 ]; then TIER=30; LABEL="🚨 已截斷"
elif [ "$BYTES" -ge 24000 ]; then TIER=24; LABEL="⚠️  已到懸崖邊"
elif [ "$BYTES" -ge 16000 ]; then TIER=16; LABEL="⚠️  接近上限"
else exit 0
fi

SENTINEL_DIR="${HOME}/.cache/claude-handoff"
mkdir -p "$SENTINEL_DIR" 2>/dev/null || exit 0
SENTINEL="${SENTINEL_DIR}/memory-index-${SESSION_ID}-${TIER}"
[ -f "$SENTINEL" ] && exit 0
touch "$SENTINEL" 2>/dev/null || true

KB=$(( BYTES / 1024 ))
LINES=$(grep -c '^- \[' "$INDEX" 2>/dev/null || echo "?")

MSG="[memory-index-reminder] ${LABEL}：本 repo 的 \`${INDEX}\` 已達 ${KB}KB（${LINES} 條索引）。索引在每個 session 開場全量載入，超過約 24KB 尾端條目就不再載入，而「沒載入」與「沒這回事」在讀者那邊輸出相同。請主動告知使用者並提議整理，做法：(1) 先列舉全部索引行再分類，不要用預測式 grep；(2) 行文太長就改寫成一句話 hook；(3) 條數太多就退役過期的 memory 檔，不是把還在用的條目縮短；(4) 刪檔前先備份，事後索引與目錄要雙向對帳（0 缺檔、0 孤兒）。若使用者現在不想處理，忽略即可；下次跨越下個門檻才會再提醒。"

jq -nc --arg msg "$MSG" '{
    hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: $msg
    }
}'

exit 0
