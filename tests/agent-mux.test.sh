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
# .err goes to stderr and makes the fake exit 1, as herdr does on an error. A
# file with suffix .sh runs instead, with the call log as its argument, for a
# reply that depends on earlier calls.
for fake in herdr ghostex; do
    cat > "$work/bin/$fake" <<EOF
#!/bin/sh
printf '%s %s\n' "$fake" "\$*" >> "$log"
key="$fake-\${1:-}_\${2:-}"
if [ -f "$work/replies/\$key.sh" ]; then exec sh "$work/replies/\$key.sh" "$log"; fi
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
terminal=T1'
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
terminal=T1'
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
    reply ghostex-read-text_S1:P1:G1 '{"ok":true}'
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
reply ghostex-read-text_S1:P1:G1 '{"ok":true}'
reply ghostex-agents_send.err 'Message delivery failed or is uncertain: Update Codex?. Answer it in chat before sending.'
out=$(mux bash "$SCRIPT" prompt rev "$work/prompt.txt" 2>/dev/null); rc=$?
[ "$rc:$out" = "1:blocked" ] && pass "prompt (Ghostex): a refused send is blocked" \
    || fail "prompt (Ghostex): a refused send gave rc=$rc: $out"

# --- close ----------------------------------------------------------------------

# The snapshot lists the terminal until pane close has been called on it.
snapshot_until_closed() {
    cat > "$work/replies/herdr-api_snapshot.sh" <<EOF
if grep -q 'herdr pane close $1' "\$1"; then
    echo '{"result":{"snapshot":{"panes":[{"pane_id":"w1:p1","terminal_id":"T0"}]}}}'
else
    echo '{"result":{"snapshot":{"panes":[{"pane_id":"w1:p1","terminal_id":"T0"},{"pane_id":"$1","terminal_id":"T1"}]}}}'
fi
EOF
}

reset
started rev 'backend=herdr
terminal=T1'
snapshot_until_closed w1:p2
reply herdr-pane_close '{"result":{"type":"ok"}}'
reply herdr-agent_list '{"result":{"agents":[],"type":"agent_list"}}'
out=$(mux bash "$SCRIPT" close rev 2>&1); rc=$?
if [ "$rc:$out" = "0:closed" ] && grep -q 'herdr pane close w1:p2' "$log" && [ ! -e "$work/state/rev.env" ]; then
    pass "close (herdr): closes the recorded pane and confirms"
else
    fail "close (herdr): rc=$rc: $out; calls: $(tr '\n' ';' < "$log")"
fi

# A pane move changes the pane id. close finds the pane through the terminal id.
reset
started rev 'backend=herdr
terminal=T1'
snapshot_until_closed w2:p5
reply herdr-pane_close '{"result":{"type":"ok"}}'
reply herdr-agent_list '{"result":{"agents":[],"type":"agent_list"}}'
out=$(mux bash "$SCRIPT" close rev 2>&1); rc=$?
if [ "$rc:$out" = "0:closed" ] && grep -q 'herdr pane close w2:p5' "$log"; then
    pass "close (herdr): a moved pane is found by its terminal id"
else
    fail "close (herdr): moved pane gave rc=$rc: $out; calls: $(tr '\n' ';' < "$log")"
fi

# A failed pane close leaves a shell open. close must fail, keep the state file.
reset
started rev 'backend=herdr
terminal=T1'
snapshot_until_closed w9:p9
reply herdr-pane_close.err '{"error":{"code":"io","message":"broken pipe"}}'
reply herdr-agent_list '{"result":{"agents":[],"type":"agent_list"}}'
out=$(mux bash "$SCRIPT" close rev 2>&1); rc=$?
case "$rc:$out" in
    1:*"cannot confirm the close"*"broken pipe"*)
        if [ -e "$work/state/rev.env" ]; then pass "close (herdr): a failed pane close is reported"
        else fail "close (herdr): a failed pane close deleted the state file"; fi ;;
    *) fail "close (herdr): a failed pane close gave rc=$rc: $out" ;;
esac

# A pane close that answers ok but leaves the terminal open is reported too.
reset
started rev 'backend=herdr
terminal=T1'
reply herdr-api_snapshot '{"result":{"snapshot":{"panes":[{"pane_id":"w1:p2","terminal_id":"T1"}]}}}'
reply herdr-pane_close '{"result":{"type":"ok"}}'
reply herdr-agent_list '{"result":{"agents":[],"type":"agent_list"}}'
out=$(mux bash "$SCRIPT" close rev 2>&1); rc=$?
case "$rc:$out" in
    1:*"still open in pane w1:p2"*) pass "close (herdr): a terminal that stays open is reported" ;;
    *) fail "close (herdr): a terminal that stays gave rc=$rc: $out" ;;
esac

# A failed list must not read as "the agent is gone".
reset
started rev 'backend=herdr
terminal=T1'
reply herdr-api_snapshot '{"result":{"snapshot":{"panes":[]}}}'
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

# --- exit: Escape first, on every backend ------------------------------------

# herdr reports a Codex update or trust dialog as idle or done, so exit cannot
# wait for "blocked" before it sends Escape.
reset
started rev 'backend=herdr
terminal=T1'
cat > "$work/replies/herdr-agent_get.sh" <<'EOF'
if grep -q 'agent prompt rev /exit' "$1"; then
    echo '{"error":{"code":"agent_not_found"}}' >&2; exit 1
fi
echo '{"result":{"agent":{"agent":"codex","agent_status":"idle"}}}'
EOF
out=$(mux bash "$SCRIPT" exit rev /exit 2>&1); rc=$?
order=$(grep -n -e 'send-keys rev esc' -e 'agent prompt rev /exit' "$log" | cut -d: -f1 | tr '\n' ' ')
esc_line=$(grep -n 'send-keys rev esc' "$log" | cut -d: -f1)
cmd_line=$(grep -n 'agent prompt rev /exit' "$log" | cut -d: -f1)
if [ "$rc:$out" = "0:exited" ] && [ -n "$esc_line" ] && [ -n "$cmd_line" ] && [ "$esc_line" -lt "$cmd_line" ]; then
    pass "exit (herdr): Escape goes before the exit command while idle"
else
    fail "exit (herdr): rc=$rc: $out; esc/exit lines: $order"
fi

reset
started rev 'backend=ghostex
ref=S1:P1:G1'
# The session list lags behind the terminal (it keeps "exists"); the
# terminal itself says "does not exist" once the agent has quit.
reply ghostex-sessions_--json '{"ok":true,"sessions":[{"globalRef":"S1:P1:G1","providerSessionState":"exists","activity":"idle"}]}'
cat > "$work/replies/ghostex-read-text_S1:P1:G1.sh" <<'EOF'
if grep -q 'send-enter S1:P1:G1' "$1"; then
    echo '{"ok":false,"error":"error: session \"S1-P1-G1\" does not exist"}'; exit 1
fi
echo '{"ok":true}'
EOF
out=$(mux bash "$SCRIPT" exit rev /exit 2>&1); rc=$?
esc_line=$(grep -n 'send-key S1:P1:G1 escape' "$log" | cut -d: -f1)
cmd_line=$(grep -n 'send-text S1:P1:G1 /exit' "$log" | cut -d: -f1)
if [ "$rc:$out" = "0:exited" ] && [ -n "$esc_line" ] && [ -n "$cmd_line" ] && [ "$esc_line" -lt "$cmd_line" ]; then
    pass "exit (Ghostex): Escape goes before the exit command"
else
    fail "exit (Ghostex): rc=$rc: $out; calls: $(tr '\n' ';' < "$log")"
fi

# --- a Ghostex query that fails is not "gone" ---------------------------------

reset
started rev 'backend=ghostex
ref=S1:P1:G1'
reply ghostex-sessions_--json '{"ok":false,"error":"gxserver did not answer"}'
out=$(mux bash "$SCRIPT" prompt rev "$work/prompt.txt" 2>&1); rc=$?
case "$rc:$out" in
    1:*"gxserver did not answer"*failed) pass "prompt (Ghostex): a failed query is failed, not gone" ;;
    *) fail "prompt (Ghostex): a failed query gave rc=$rc: $out" ;;
esac
out=$(mux bash "$SCRIPT" exit rev /exit 2>/dev/null); rc=$?
[ "$rc:$out" = "1:unknown" ] && pass "exit (Ghostex): a failed query is unknown, not exited" \
    || fail "exit (Ghostex): a failed query gave rc=$rc: $out"
out=$(mux bash "$SCRIPT" state rev 2>/dev/null)
[ "$out" = unknown ] && pass "state (Ghostex): a failed query is unknown" \
    || fail "state (Ghostex): a failed query gave $out"
out=$(mux bash "$SCRIPT" alive rev 2>/dev/null); rc=$?
[ "$rc:$out" = "2:unknown" ] && pass "alive (Ghostex): a failed query is unknown (exit 2)" \
    || fail "alive (Ghostex): a failed query gave rc=$rc: $out"

# A terminal that does not answer for another reason is unknown, not gone.
reset
started rev 'backend=ghostex
ref=S1:P1:G1'
reply ghostex-sessions_--json '{"ok":true,"sessions":[{"globalRef":"S1:P1:G1","providerSessionState":"exists"}]}'
reply ghostex-read-text_S1:P1:G1.err '{"ok":false,"error":"gxserver did not answer"}'
out=$(mux bash "$SCRIPT" alive rev 2>/dev/null); rc=$?
[ "$rc:$out" = "2:unknown" ] && pass "alive (Ghostex): a terminal probe that fails is unknown" \
    || fail "alive (Ghostex): a failed terminal probe gave rc=$rc: $out"

# A session missing from the list is gone.
reset
started rev 'backend=ghostex
ref=S1:P1:G1'
reply ghostex-sessions_--json '{"ok":true,"sessions":[]}'
out=$(mux bash "$SCRIPT" alive rev 2>/dev/null); rc=$?
[ "$rc:$out" = "1:gone" ] && pass "alive (Ghostex): an unlisted session is gone" \
    || fail "alive (Ghostex): an unlisted session gave rc=$rc: $out"

# --- prompt: unknown is settled ---------------------------------------------------

herdr_prompt_case unknown '' '{"result":{"agent":{"agent":"codex","agent_status":"unknown"}}}' "settled unknown"
reset
started rev 'backend=herdr
terminal=T1'
reply herdr-agent_get '{"result":{"agent":{"agent":"codex","agent_status":"idle"}}}'
reply herdr-agent_prompt '{"result":{"agent":{"agent":"codex","agent_status":"unknown"}}}'
mux bash "$SCRIPT" prompt rev "$work/prompt.txt" >/dev/null 2>&1; rc=$?
[ "$rc" = 0 ] && pass "prompt: unknown exits 0, so the caller reads the findings file" \
    || fail "prompt: unknown exited $rc"

# --- a bad state file is refused by name --------------------------------------------

reset
started rev 'backend=tmux'
out=$(mux bash "$SCRIPT" alive rev 2>&1); rc=$?
case "$rc:$out" in
    1:*"backend is 'tmux', not herdr or ghostex"*) pass "load: an unknown backend is refused" ;;
    *) fail "load: an unknown backend gave rc=$rc: $out" ;;
esac

# --- Ghostex start from a linked worktree ---------------------------------------------

# A linked worktree has its own path, so a path match misses it. The project is
# the one whose path shares the worktree's git common directory.
if command -v git >/dev/null 2>&1; then
    reset
    main="$work/main"; wt="$work/wt"
    git init -q "$main" && git -C "$main" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init \
        && git -C "$main" worktree add -q "$wt" -b wt 2>/dev/null
    main=$(cd "$main" && pwd -P); wt=$(cd "$wt" && pwd -P)
    reply ghostex-agents_list '{"ok":true,"sessions":[{"globalRef":"S1:P9:G1","agentId":"codex"}]}'
    reply ghostex-state_ "{\"ok\":true,\"projects\":[{\"projectId\":\"P8\",\"path\":\"/nowhere\"},{\"projectId\":\"P9\",\"path\":\"$main\"}]}"
    reply ghostex-agents_types '{"ok":true,"agents":[{"agentId":"codex","command":"codex"}]}'
    reply ghostex-create-session_rev '{"ok":true,"session":{"globalRef":"S1:P9:G1"}}'
    reply ghostex-sessions_--json '{"ok":true,"sessions":[{"globalRef":"S1:P9:G1","providerSessionState":"exists"}]}'
    reply ghostex-read-text_S1:P9:G1 '{"ok":true}'
    out=$(mux GHOSTEX_SESSION_ID=S1-P1-G0 PATH="$work/bin:$(dirname "$(command -v git)"):$tool_path" \
        bash "$SCRIPT" start rev codex "$wt" -- --sandbox workspace-write 2>&1); rc=$?
    if [ "$rc:$out" = "0:ghostex" ] && grep -q -- "--project-id P9 --cwd $wt" "$log"; then
        pass "start (Ghostex): a linked worktree finds its project and keeps its own cwd"
    else
        fail "start (Ghostex): linked worktree gave rc=$rc: $out; calls: $(tr '\n' ';' < "$log")"
    fi
fi

# --- re-review fixes ------------------------------------------------------------

# attention without a program status is settled but unclassified. The wait
# must end on it after the grace period, not spin until the timeout.
reset
started rev 'backend=ghostex
ref=S1:P1:G1'
reply ghostex-sessions_--json '{"ok":true,"sessions":[{"globalRef":"S1:P1:G1","providerSessionState":"exists","activity":"attention"}]}'
reply ghostex-read-text_S1:P1:G1 '{"ok":true}'
reply ghostex-agents_send '{"ok":true,"status":"delivered"}'
out=$(mux bash "$SCRIPT" prompt rev "$work/prompt.txt" --timeout 30 2>&1); rc=$?
[ "$rc:$out" = "0:unknown" ] && pass "prompt (Ghostex): attention without program status settles as unknown" \
    || fail "prompt (Ghostex): attention without program status gave rc=$rc: $out"

# herdr start stores only the terminal id. A stored pane id goes stale on a
# pane move, and nothing reads it after start.
reset
reply herdr-agent_list '{"result":{"agents":[],"type":"agent_list"}}'
reply herdr-pane_split '{"result":{"pane":{"pane_id":"w1:p2","terminal_id":"T1"}}}'
reply herdr-agent_start '{"result":{"agent":{"agent":"codex"}}}'
out=$(mux HERDR_ENV=1 bash "$SCRIPT" start rev codex "$work" 2>&1); rc=$?
if [ "$rc:$out" = "0:herdr" ] && grep -qx 'terminal=T1' "$work/state/rev.env" \
   && ! grep -q '^pane=' "$work/state/rev.env" && grep -q 'agent start rev --kind codex --pane w1:p2' "$log"; then
    pass "start (herdr): the state file holds the terminal id and no pane id"
else
    fail "start (herdr): rc=$rc: $out; state: $(tr '\n' ';' < "$work/state/rev.env" 2>/dev/null)"
fi

# A failed ghostex state is reported as that, not as "not in a Ghostex project".
reset
reply ghostex-agents_list '{"ok":true,"sessions":[]}'
reply ghostex-state_ '{"ok":false,"error":"gxserver did not answer"}'
out=$(mux GHOSTEX_SESSION_ID=S1-P1-G0 bash "$SCRIPT" start rev codex "$work" 2>&1); rc=$?
case "$rc:$out" in
    *"not in a Ghostex project"*) fail "start (Ghostex): a failed state query also said: $out" ;;
    1:*"ghostex state failed: gxserver did not answer"*) pass "start (Ghostex): a failed state query names its own error only" ;;
    *) fail "start (Ghostex): a failed state query gave rc=$rc: $out" ;;
esac

if [ "$failures" -eq 0 ]; then
    printf 'all agent-mux tests passed\n'
    exit 0
fi
printf '%d failure(s)\n' "$failures" >&2
exit 1
