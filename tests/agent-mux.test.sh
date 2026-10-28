#!/bin/sh
# agent-mux.test.sh -- the guarantees that agent-mux holds for its callers.
#
# Fake herdr and ghostex binaries stand in for the real ones. Each test sets
# the reply a fake gives, runs agent-mux, and checks the result word and the
# calls the fake received. The live round trips against a real herdr and a
# real Ghostex are in docs/user-scripts.md; this file covers the decisions.
#
# usage: sh tests/agent-mux.test.sh

set -u

for tool in jq bash; do
    command -v "$tool" >/dev/null 2>&1 || {
        printf 'FATAL: %s is required\n' "$tool" >&2
        exit 1
    }
done

# The fakes must shadow any real herdr or ghostex, so PATH in the tests is the
# fakes plus the directories of the tools agent-mux needs, and nothing else.
tool_path="$(dirname "$(command -v jq)"):$(dirname "$(command -v bash)"):/usr/bin:/bin"

self_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
SCRIPT="$(dirname "$self_dir")/home/dot_local/bin/executable_agent-mux"
[ -f "$SCRIPT" ] || { printf 'FATAL: script not found: %s\n' "$SCRIPT" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/replies"
log="$work/calls.log"

# Each fake logs its arguments, then prints the reply file named after its
# first two arguments ("agent_list", "sessions_--json"). A file with suffix
# .err goes to stderr and makes the fake exit 1, as herdr does on an error.
for fake in herdr ghostex; do
    cat > "$work/bin/$fake" <<EOF
#!/bin/sh
printf '%s %s\n' "$fake" "\$*" >> "$log"
key="$fake-\${1:-}_\${2:-}"
if [ -f "$work/replies/\$key.err" ]; then cat "$work/replies/\$key.err" >&2; exit 1; fi
[ -f "$work/replies/\$key" ] && cat "$work/replies/\$key"
exit 0
EOF
    chmod +x "$work/bin/$fake"
done

reply() { printf '%s\n' "$2" > "$work/replies/$1"; }
reset() { rm -f "$work/replies/"* "$log"; rm -rf "$work/state"; : > "$log"; }

failures=0
fail() { printf 'FAIL: %s\n' "$1" >&2; failures=$((failures + 1)); }
pass() { printf 'ok: %s\n' "$1"; }

# Run agent-mux with only the fakes and the system tools on PATH, and with
# neither multiplexer's environment unless the test sets it.
mux() {
    env -u HERDR_ENV -u HERDR_PANE_ID -u GHOSTEX_SESSION_ID \
        PATH="$work/bin:$tool_path" AGENT_MUX_STATE_DIR="$work/state" \
        "$@"
}

# Write a state file as start would, so a test can begin from a started agent.
started() {
    mkdir -p "$work/state"
    printf '%s\n' "$2" > "$work/state/$1.env"
}

# --- detect ----------------------------------------------------------------

# The bug this script fixes: under the Codex sandbox HERDR_ENV=1 is set and
# every herdr call fails. detect must not report herdr then.
reset
reply herdr-agent_list.err '{"error":{"code":"io","message":"PermissionDenied"}}'
out=$(mux HERDR_ENV=1 bash "$SCRIPT" detect 2>&1); rc=$?
case "$rc:$out" in
    1:*"herdr is set but unreachable: PermissionDenied"*"not running inside Ghostex"*)
        pass "detect: HERDR_ENV=1 with a failing herdr is not herdr" ;;
    *) fail "detect: HERDR_ENV=1 with a failing herdr gave rc=$rc: $out" ;;
esac

reset
reply herdr-agent_list '{"result":{"agents":[],"type":"agent_list"}}'
out=$(mux HERDR_ENV=1 bash "$SCRIPT" detect 2>&1); rc=$?
[ "$rc:$out" = "0:herdr" ] && pass "detect: a reachable herdr is herdr" \
    || fail "detect: a reachable herdr gave rc=$rc: $out"

reset
reply ghostex-agents_list '{"ok":true,"sessions":[]}'
out=$(mux bash "$SCRIPT" detect 2>&1); rc=$?
case "$rc:$out" in
    1:*"not running inside herdr"*"not running inside Ghostex"*)
        pass "detect: a ghostex binary alone is not Ghostex" ;;
    *) fail "detect: outside both multiplexers gave rc=$rc: $out" ;;
esac

reset
reply ghostex-agents_list '{"ok":true,"sessions":[]}'
out=$(mux GHOSTEX_SESSION_ID=S1-P1-G1 bash "$SCRIPT" detect 2>&1); rc=$?
[ "$rc:$out" = "0:ghostex" ] && pass "detect: a reachable Ghostex is ghostex" \
    || fail "detect: a reachable Ghostex gave rc=$rc: $out"

reset
reply ghostex-agents_list '{"ok":false,"error":"gxserver did not answer"}'
out=$(mux GHOSTEX_SESSION_ID=S1-P1-G1 bash "$SCRIPT" detect 2>&1); rc=$?
case "$rc:$out" in
    1:*"Ghostex is set but unreachable: gxserver did not answer"*)
        pass "detect: GHOSTEX_SESSION_ID with a failing ghostex is not Ghostex" ;;
    *) fail "detect: a failing Ghostex gave rc=$rc: $out" ;;
esac

# --- prompt refuses to type when the agent is gone --------------------------

# herdr drops an agent that quit; agent get then fails on stderr.
reset
started rev 'backend=herdr
pane=w1:p2'
reply herdr-agent_get.err '{"error":{"code":"agent_not_found"}}'
printf 'review\n' > "$work/prompt.txt"
out=$(mux bash "$SCRIPT" prompt rev "$work/prompt.txt" 2>&1); rc=$?
if [ "$rc:$out" = "1:gone" ] && ! grep -q 'agent prompt' "$log"; then
    pass "prompt (herdr): a gone agent gets no text"
else
    fail "prompt (herdr): gone agent gave rc=$rc: $out; calls: $(tr '\n' ';' < "$log")"
fi

# Ghostex: the agent runs under exec, so its terminal ends with it.
reset
started rev 'backend=ghostex
ref=S1:P1:G1'
reply ghostex-sessions_--json '{"ok":true,"sessions":[{"globalRef":"S1:P1:G1","providerSessionState":"missing","activity":"idle"}]}'
out=$(mux bash "$SCRIPT" prompt rev "$work/prompt.txt" 2>&1); rc=$?
if [ "$rc:$out" = "1:gone" ] && ! grep -q 'agents send' "$log"; then
    pass "prompt (Ghostex): a gone agent gets no text"
else
    fail "prompt (Ghostex): gone agent gave rc=$rc: $out; calls: $(tr '\n' ';' < "$log")"
fi

# --- herdr prompt results -----------------------------------------------------

herdr_prompt_case() {
    reset
    started rev 'backend=herdr
pane=w1:p2'
    reply herdr-agent_get '{"result":{"agent":{"agent":"codex","agent_status":"idle"}}}'
    if [ -n "$2" ]; then reply herdr-agent_prompt.err "$2"; else reply herdr-agent_prompt "$3"; fi
    out=$(mux bash "$SCRIPT" prompt rev "$work/prompt.txt" 2>/dev/null); rc=$?
    [ "$out" = "$1" ] && pass "prompt (herdr): $4 -> $1" \
        || fail "prompt (herdr): $4 gave rc=$rc: $out (want $1)"
}
herdr_prompt_case done '' '{"result":{"agent":{"agent":"codex","agent_status":"done"}}}' "settled done"
herdr_prompt_case blocked '' '{"result":{"agent":{"agent":"codex","agent_status":"blocked"}}}' "settled blocked"
herdr_prompt_case blocked '{"error":{"code":"agent_blocked"}}' '' "agent_blocked"
herdr_prompt_case timeout '{"error":{"code":"agent_prompt_stalled"}}' '' "agent_prompt_stalled"
herdr_prompt_case timeout '{"error":{"code":"timeout"}}' '' "timeout"

# --- Ghostex state ------------------------------------------------------------

# "attention" covers both a waiting dialog and a finished, unseen turn. The
# agent's own program status tells them apart.
ghostex_state_case() {
    reset
    started rev 'backend=ghostex
ref=S1:P1:G1'
    reply ghostex-sessions_--json "{\"ok\":true,\"sessions\":[{\"globalRef\":\"S1:P1:G1\",\"providerSessionState\":\"exists\",$2}]}"
    out=$(mux bash "$SCRIPT" state rev 2>&1)
    [ "$out" = "$1" ] && pass "state (Ghostex): $3 -> $1" \
        || fail "state (Ghostex): $3 gave $out (want $1)"
}
ghostex_state_case blocked '"activity":"attention","programStatus":{"state":"blocked"}' "attention + blocked"
ghostex_state_case done '"activity":"attention","programStatus":{"state":"done"}' "attention + done"
ghostex_state_case unknown '"activity":"attention"' "attention, no program status"
ghostex_state_case working '"activity":"working"' "working"
ghostex_state_case idle '"activity":"idle"' "idle"

# A dialog in the input box makes agents send fail while the agent still runs.
reset
started rev 'backend=ghostex
ref=S1:P1:G1'
reply ghostex-sessions_--json '{"ok":true,"sessions":[{"globalRef":"S1:P1:G1","providerSessionState":"exists","activity":"idle"}]}'
reply ghostex-agents_send.err 'Message delivery failed or is uncertain: Update Codex?. Answer it in chat before sending.'
out=$(mux bash "$SCRIPT" prompt rev "$work/prompt.txt" 2>/dev/null); rc=$?
[ "$rc:$out" = "1:blocked" ] && pass "prompt (Ghostex): a refused send is blocked" \
    || fail "prompt (Ghostex): a refused send gave rc=$rc: $out"

# --- close ----------------------------------------------------------------------

reset
started rev 'backend=herdr
pane=w1:p2'
reply herdr-agent_list '{"result":{"agents":[],"type":"agent_list"}}'
out=$(mux bash "$SCRIPT" close rev 2>&1); rc=$?
if [ "$rc:$out" = "0:closed" ] && grep -q 'herdr pane close w1:p2' "$log" && [ ! -e "$work/state/rev.env" ]; then
    pass "close (herdr): closes the recorded pane and confirms"
else
    fail "close (herdr): rc=$rc: $out; calls: $(tr '\n' ';' < "$log")"
fi

# A failed list must not read as "the agent is gone".
reset
started rev 'backend=herdr
pane=w1:p2'
reply herdr-agent_list.err '{"error":{"code":"io","message":"PermissionDenied"}}'
out=$(mux bash "$SCRIPT" close rev 2>&1); rc=$?
case "$rc:$out" in
    1:*"cannot confirm the close"*) pass "close (herdr): a failed list is not a confirmation" ;;
    *) fail "close (herdr): a failed list gave rc=$rc: $out" ;;
esac

reset
started rev 'backend=ghostex
ref=S1:P1:G1'
reply ghostex-sessions_--json '{"ok":true,"sessions":[{"globalRef":"S1:P1:G1"}]}'
out=$(mux bash "$SCRIPT" close rev 2>&1); rc=$?
case "$rc:$out" in
    1:*"still in ghostex sessions"*) pass "close (Ghostex): a session that stays is reported" ;;
    *) fail "close (Ghostex): a session that stays gave rc=$rc: $out" ;;
esac

if [ "$failures" -eq 0 ]; then
    printf 'all agent-mux tests passed\n'
    exit 0
fi
printf '%d failure(s)\n' "$failures" >&2
exit 1
