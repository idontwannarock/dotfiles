#!/bin/sh
# Black-box tests for home/run_after_workspaces.sh.tmpl.
#
# Real git (local bare repos stand in for GitHub) and the real chezmoi for
# rendering and TOML parsing; the nested `chezmoi init --apply` is a stub that
# only records its arguments, because what it does is chezmoi's own business.

set -u

self_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_root=$(dirname "$self_dir")
template="$repo_root/home/run_after_workspaces.sh.tmpl"

for tool in bash git jq chezmoi; do
    command -v "$tool" >/dev/null 2>&1 || {
        printf 'FATAL: %s is required\n' "$tool" >&2
        exit 1
    }
done
real_cz=$(command -v chezmoi)

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM
: >"$tmp/empty.toml"
script="$tmp/ws.sh"
chezmoi execute-template --source "$repo_root/home" -c "$tmp/empty.toml" <"$template" >"$script" || {
    printf 'FAIL: cannot render %s\n' "$template" >&2
    exit 1
}
bash -n "$script" || exit 1

cat >"$tmp/cz-stub" <<STUB
#!/bin/sh
case "\$1" in
    execute-template) exec "$real_cz" "\$@" ;;
    init|apply) printf '%s\n' "\$*" >>"\$CZ_STUB_LOG" ;;
    state) case "\$2" in
        dump) printf '%s\n' "\${CZ_STUB_STATE:-{\}}" ;;
        delete) printf '%s\n' "\$*" >>"\$CZ_STUB_LOG" ;;
        esac ;;
    *) exit 64 ;;
esac
STUB
chmod +x "$tmp/cz-stub"

git_quiet() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=main "$@" >/dev/null 2>&1; }

# A bare repo holding workspaces.toml with the given body.
make_list() {
    rm -rf "$tmp/list.git" "$tmp/list-work"
    git_quiet init --bare "$tmp/list.git"
    git_quiet init "$tmp/list-work"
    printf '%s\n' "$1" >"$tmp/list-work/workspaces.toml"
    git_quiet -C "$tmp/list-work" add -A
    git_quiet -C "$tmp/list-work" commit -m list
    git_quiet -C "$tmp/list-work" push "$tmp/list.git" HEAD:main
}

rm -rf "$tmp/ws.git" "$tmp/ws-work"
git_quiet init --bare "$tmp/ws.git"
git_quiet init "$tmp/ws-work"
echo hello >"$tmp/ws-work/dot_hello"
git_quiet -C "$tmp/ws-work" add -A
git_quiet -C "$tmp/ws-work" commit -m ws
git_quiet -C "$tmp/ws-work" push "$tmp/ws.git" HEAD:main

entry() { # id name retired
    printf '[%s]\nname = "%s"\ndesc = "test workspace"\nurl = "%s"\nretired = %s\n' \
        "$1" "$2" "$tmp/ws.git" "$3"
}

failures=0
fail() { printf 'FAIL: %s\n' "$1" >&2; failures=$((failures + 1)); }

# run <case> <command> <interactive> [stdin]
run() {
    case_dir="$tmp/case-$1"
    mkdir -p "$case_dir/home" "$case_dir/ws/dotfiles"
    : >"$case_dir/init.log"
    printf '%s' "${4:-}" | HOME="$case_dir/home" CHEZMOI_OS=linux CHEZMOI_COMMAND="$2" \
        CHEZMOI_WORKING_TREE="$case_dir/ws/dotfiles" CHEZMOI_EXECUTABLE="$tmp/cz-stub" \
        CZ_STUB_LOG="$case_dir/init.log" DOTFILES_WS_INTERACTIVE="$3" \
        bash "$script" >"$case_dir/out" 2>&1
    rc=$?
    state="$case_dir/home/.config/chezmoi/workspaces.json"
}
seed() { mkdir -p "$tmp/case-$1/home/.config/chezmoi"; printf '%s\n' "$2" >"$tmp/case-$1/home/.config/chezmoi/workspaces.json"; }
jqs() { jq -r "$1" "$state"; }

list_ok="schema = 2
$(entry w1 private false)"
make_list "$list_ok"

# 1. No TTY and no saved list repo: nothing is asked and nothing is written.
run no-tty update 0
[ "$rc" -eq 0 ] || fail "no-tty: rc=$rc"
[ "$(jqs 'has("listRepo")')" = false ] || fail "no-tty: listRepo was saved without asking"

# 2. First interactive update: saves the list repo, asks, clones, applies.
run first update 1 "$tmp/list.git
y
"
[ "$rc" -eq 0 ] || fail "first: rc=$rc $(cat "$case_dir/out")"
[ "$(jqs '.listRepo')" = "$tmp/list.git" ] || fail "first: listRepo not saved"
[ "$(jqs '.answers.w1.enabled')" = true ] || fail "first: w1 not enabled"
[ -f "$case_dir/ws/dotfiles-private/dot_hello" ] || fail "first: workspace not cloned beside the public repo"
grep -q -- "--source $case_dir/ws/dotfiles-private" "$case_dir/init.log" || fail "first: nested chezmoi not run on the clone"
grep -q -- "--persistent-state $case_dir/home/.config/chezmoi/workspaces/w1/chezmoistate.boltdb" "$case_dir/init.log" ||
    fail "first: nested chezmoi does not use its own state"

# 3. Empty answer: this machine uses no workspaces, and is not asked again.
run none update 1 "
"
[ "$(jqs '.listRepo')" = "" ] || fail "none: empty listRepo not saved"
[ -s "$case_dir/init.log" ] && fail "none: applied a workspace"

# 4. Declined: saved as false, with no name or url kept; nothing cloned.
run decline update 1 "$tmp/list.git
n
"
[ "$(jqs '.answers.w1')" = '{
  "enabled": false
}' ] || fail "decline: answer is $(jqs -c '.answers.w1')"
[ -d "$case_dir/ws/dotfiles-private" ] && fail "decline: cloned anyway"

# 5. A new workspace without a TTY is left unanswered, so it is asked next time.
seed newid "{\"listRepo\": \"$tmp/list.git\", \"answers\": {}}"
run newid update 0
[ "$(jqs '.answers | has("w1")')" = false ] || fail "newid: answered without a TTY"

# 6. apply never touches the network: the saved clone is applied as is.
seed apply "{\"listRepo\": \"$tmp/missing.git\", \"answers\": {\"w1\": {\"enabled\": true, \"name\": \"private\", \"url\": \"$tmp/ws.git\", \"desc\": \"d\", \"retired\": false}}}"
mkdir -p "$tmp/case-apply/ws/dotfiles-private"
run apply apply 0
[ "$rc" -eq 0 ] || fail "apply: rc=$rc"
grep -q 'cannot reach' "$case_dir/out" && fail "apply: tried to fetch the list"
[ -s "$case_dir/init.log" ] || fail "apply: did not apply the clone"

# 7. Offline update: warns, keeps the answers, still applies.
seed offline "{\"listRepo\": \"$tmp/missing.git\", \"answers\": {\"w1\": {\"enabled\": true, \"name\": \"private\", \"url\": \"$tmp/ws.git\", \"desc\": \"d\", \"retired\": false}}}"
run offline update 0
[ "$rc" -eq 0 ] || fail "offline: rc=$rc"
grep -q 'cannot reach the workspace list' "$case_dir/out" || fail "offline: no warning"
[ "$(jqs '.answers.w1.enabled')" = true ] || fail "offline: lost the saved answer"
[ -s "$case_dir/init.log" ] || fail "offline: did not apply"

# 8. A field left out is an error, not a default.
make_list "schema = 2
[w1]
name = \"private\"
desc = \"d\"
url = \"$tmp/ws.git\"
retired_typo = false"
seed missing "{\"listRepo\": \"$tmp/list.git\"}"
run missing update 1
[ "$rc" -ne 0 ] || fail "missing field: rc=0"
grep -q 'fields must be exactly' "$case_dir/out" || fail "missing field: no message"

# 9. A newer schema says to update the public repo.
make_list "schema = 3
$(entry w1 private false)"
seed schema "{\"listRepo\": \"$tmp/list.git\"}"
run schema update 1
[ "$rc" -ne 0 ] || fail "schema: rc=0"
grep -q 'update the public dotfiles repo' "$case_dir/out" || fail "schema: no update hint"

# 10. A schema 1 list (it had os fields) says how to migrate it.
make_list "schema = 1
$(entry w1 private false)
os = [\"linux\"]"
seed oldschema "{\"listRepo\": \"$tmp/list.git\"}"
run oldschema update 1
[ "$rc" -ne 0 ] || fail "old schema: rc=0"
grep -q 'remove every os field' "$case_dir/out" || fail "old schema: no migration hint"

# 11. Answers saved under schema 1 still carry os; they are applied and refreshed.
make_list "$list_ok"
seed oldanswer "{\"listRepo\": \"$tmp/list.git\", \"answers\": {\"w1\": {\"enabled\": true, \"name\": \"private\", \"url\": \"$tmp/ws.git\", \"desc\": \"d\", \"os\": [\"windows\"], \"retired\": false}}}"
run oldanswer update 0
[ "$rc" -eq 0 ] || fail "old answer: rc=$rc"
[ -s "$case_dir/init.log" ] || fail "old answer: not applied"
[ "$(jqs '.answers.w1 | has("os")')" = false ] || fail "old answer: os not dropped on refresh"

# 12. Retiring an enabled workspace stops applying it and leaves the clone.
make_list "schema = 2
$(entry w1 private true)"
seed retired "{\"listRepo\": \"$tmp/list.git\", \"answers\": {\"w1\": {\"enabled\": true, \"name\": \"private\", \"url\": \"$tmp/ws.git\", \"desc\": \"d\", \"retired\": false}}}"
mkdir -p "$tmp/case-retired/ws/dotfiles-private"
run retired update 0
[ "$rc" -eq 0 ] || fail "retired: rc=$rc"
grep -q 'is retired' "$case_dir/out" || fail "retired: no warning"
[ -s "$case_dir/init.log" ] && fail "retired: still applied"
[ -d "$case_dir/ws/dotfiles-private" ] || fail "retired: clone removed"

# 13. The list copy is deleted: no clone of the list repo survives a run.
make_list "$list_ok"
seed cleanup "{\"listRepo\": \"$tmp/list.git\"}"
probe="$tmp/probe-tmp"; mkdir -p "$probe"
old_tmpdir=${TMPDIR:-}
export TMPDIR="$probe"
run cleanup update 0
if [ -n "$old_tmpdir" ]; then TMPDIR=$old_tmpdir; else unset TMPDIR; fi
[ -z "$(ls -A "$probe")" ] || fail "cleanup: left $(ls -A "$probe") in TMPDIR"

# 14. jq.exe on Windows writes \r\n. Ids read in a loop must not keep the \r.
mkdir -p "$tmp/crlf-bin"
cat >"$tmp/crlf-bin/jq" <<STUB
#!/bin/bash
"$(command -v jq)" "\$@" | sed 's/\$/\r/'
exit "\${PIPESTATUS[0]}"
STUB
chmod +x "$tmp/crlf-bin/jq"
make_list "schema = 2
$(entry w1 private false)
$(entry w2 work false)"
seed crlf "{\"listRepo\": \"$tmp/list.git\", \"answers\": {\"w1\": {\"enabled\": true, \"name\": \"private\", \"url\": \"$tmp/ws.git\", \"desc\": \"d\", \"retired\": false}}}"
old_path=$PATH
PATH="$tmp/crlf-bin:$PATH"
run crlf update 1 "y
"
PATH=$old_path
[ "$rc" -eq 0 ] || fail "crlf: rc=$rc $(cat "$case_dir/out")"
[ "$(jq -c '.answers | keys' "$state")" = '["w1","w2"]' ] || fail "crlf: answers are $(jq -c '.answers | keys' "$state")"
[ "$(jqs '.answers.w2.name')" = work ] || fail "crlf: w2 saved without its entry"
grep -q 'no longer in the list' "$case_dir/out" && fail "crlf: saved ids not matched to the list"
[ "$(wc -l <"$case_dir/init.log")" -eq 2 ] || fail "crlf: applied $(wc -l <"$case_dir/init.log") workspaces, want 2"

# 15. Without a TTY, a workspace is applied, not init-ed: init would ask its
#     questions. One that has questions and no saved answers waits for a TTY.
make_list "$list_ok"
ws_seed='{"enabled": true, "name": "private", "url": "'"$tmp/ws.git"'", "desc": "d", "retired": false}'
seed notty-apply "{\"listRepo\": \"$tmp/missing.git\", \"answers\": {\"w1\": $ws_seed}}"
mkdir -p "$tmp/case-notty-apply/ws/dotfiles-private"
run notty-apply apply 0
grep -q '^apply ' "$case_dir/init.log" || fail "notty: did not apply a workspace with no questions: $(cat "$case_dir/init.log")"
grep -q '^init' "$case_dir/init.log" && fail "notty: ran init without a TTY"

seed notty-ask "{\"listRepo\": \"$tmp/missing.git\", \"answers\": {\"w1\": $ws_seed}}"
mkdir -p "$tmp/case-notty-ask/ws/dotfiles-private/home"
echo home >"$tmp/case-notty-ask/ws/dotfiles-private/.chezmoiroot"
: >"$tmp/case-notty-ask/ws/dotfiles-private/home/.chezmoi.toml.tmpl"
run notty-ask apply 0
[ -s "$case_dir/init.log" ] && fail "notty: applied a workspace whose questions are not answered"
grep -q 'asks questions' "$case_dir/out" || fail "notty: no warning about the unanswered questions"

mkdir -p "$case_dir/home/.config/chezmoi/workspaces/w1"
: >"$case_dir/home/.config/chezmoi/workspaces/w1/chezmoi.toml"
run notty-ask apply 0
grep -q '^apply ' "$case_dir/init.log" || fail "notty: did not apply once answers are saved"

# 16. Before applying, state entries for targets that are gone are deleted,
#     and entries for targets that exist are kept.
seed prune "{\"listRepo\": \"$tmp/missing.git\", \"answers\": {\"w1\": $ws_seed}}"
mkdir -p "$tmp/case-prune/ws/dotfiles-private" "$tmp/case-prune/home/.config/chezmoi/workspaces/w1"
: >"$tmp/case-prune/home/.config/chezmoi/workspaces/w1/chezmoistate.boltdb"
: >"$tmp/case-prune/kept"
CZ_STUB_STATE="{\"entryState\": {\"$tmp/case-prune/kept\": {}, \"$tmp/case-prune/gone\": {}}}"
export CZ_STUB_STATE
run prune apply 0
unset CZ_STUB_STATE
grep -q "^state delete --bucket entryState --key $tmp/case-prune/gone " "$case_dir/init.log" ||
    fail "prune: did not forget a target that is gone: $(cat "$case_dir/init.log")"
grep -q -- "--key $tmp/case-prune/kept " "$case_dir/init.log" && fail "prune: forgot a target that exists"
[ "$(grep -n '^state delete' "$case_dir/init.log" | cut -d: -f1)" -lt "$(grep -n '^apply ' "$case_dir/init.log" | cut -d: -f1)" ] ||
    fail "prune: forgot after apply, not before"

if [ "$failures" -gt 0 ]; then
    printf '%d failure(s)\n' "$failures" >&2
    exit 1
fi
printf 'workspaces: all cases passed\n'
