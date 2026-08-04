#!/bin/sh
# claude-memory-seed.test.sh — black-box tests for
# home/dot_local/bin/executable_claude-memory-seed
#
# Hand-rolled POSIX assertions rather than Pester (which the repo's other three
# test files use) because the subject is a POSIX sh script: this way the local
# run and the CI run are the same shell, the same jq, and the same filesystem
# semantics. The dev machine (WSL) has no native pwsh at all, so a Pester file
# would have no local red/green loop — see design.md D6.
#
# Each case runs in its own sandbox with HOME redirected, so the developer's
# real ~/.claude is never touched.
#
# The SessionStart hook invokes the script with `bash`, the post-checkout hook
# with whatever /bin/sh is, so both interpreters are production paths. SEED_SH
# selects which one drives the subject; the CI job runs the suite once per shell.
#
# usage: sh tests/claude-memory-seed.test.sh
#        SEED_SH=bash sh tests/claude-memory-seed.test.sh

set -u

self_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_root=$(dirname "$self_dir")
SCRIPT="$repo_root/home/dot_local/bin/executable_claude-memory-seed"
SEED_SH=${SEED_SH:-sh}

# ---------------------------------------------------------------- preconditions
#
# The script silently no-ops when jq is missing. Without this gate a toolless
# runner would report every case as passing while asserting nothing — the worst
# possible false green.
for tool in jq git "$SEED_SH"; do
    command -v "$tool" >/dev/null 2>&1 || {
        printf 'FATAL: %s is required to run these tests\n' "$tool" >&2
        exit 1
    }
done
[ -f "$SCRIPT" ] || { printf 'FATAL: script not found: %s\n' "$SCRIPT" >&2; exit 1; }

# Sandboxes live under the real HOME, NOT under /tmp: the script refuses to seed
# anything beneath /tmp, so a /tmp sandbox would make every case vacuously pass.
# The /tmp guard case creates its own sandbox there deliberately.
SANDBOX_BASE="$HOME/.cache/claude-memory-seed-tests"
rm -rf "$SANDBOX_BASE"
mkdir -p "$SANDBOX_BASE"

# A sandbox that is itself inside a git repo would turn every "non-git" case into
# a git case without any visible failure.
( CDPATH= cd -- "$SANDBOX_BASE" && git rev-parse --show-toplevel >/dev/null 2>&1 ) && {
    printf 'FATAL: sandbox base %s is inside a git repo\n' "$SANDBOX_BASE" >&2
    exit 1
}

trap 'rm -rf "$SANDBOX_BASE" "${TMP_SANDBOX:-}"' EXIT INT TERM

# ---------------------------------------------------------------- assertions
passed=0
failed=0
current=""

describe() { current=$1; }

ok() { passed=$((passed + 1)); printf '  ok    %s — %s\n' "$current" "$1"; }

ng() {
    failed=$((failed + 1))
    printf '  FAIL  %s — %s\n' "$current" "$1"
    shift
    for line in "$@"; do printf '          %s\n' "$line"; done
}

assert_eq() { # expected actual message
    if [ "$1" = "$2" ]; then ok "$3"; else ng "$3" "expected: $1" "actual:   $2"; fi
}

assert_absent() { # path message
    if [ -e "$1" ]; then ng "$2" "unexpectedly exists: $1"; else ok "$2"; fi
}

assert_exists() { # path message
    if [ -e "$1" ]; then ok "$2"; else ng "$2" "missing: $1"; fi
}

# assert_rc / assert_silent — read $RC and $ERR, published by the last run_apply.
# The script's central promise is that it never fails its caller, so the exit
# code needs assertions of its own: asserting only on files left behind cannot
# distinguish "the guard refused" from "the write blew up".
assert_rc() { # expected message
    if [ "$RC" = "$1" ]; then ok "$2"; else ng "$2" "expected rc: $1" "actual rc:   $RC" "stderr:      $ERR"; fi
}

assert_silent() { # message
    if [ -z "$ERR" ]; then ok "$1"; else ng "$1" "unexpected stderr: $ERR"; fi
}

assert_noisy() { # message
    if [ -n "$ERR" ]; then ok "$1"; else ng "$1" "expected a diagnostic on stderr, got none"; fi
}

# skip — tallied separately and NEVER as a pass. A skip counted as ok is the same
# false green this suite exists to prevent: the summary would claim coverage the
# run never exercised.
skipped=0
skip() { skipped=$((skipped + 1)); printf '  skip  %s — %s\n' "$current" "$1"; }

# ---------------------------------------------------------------- fixtures
sandbox_n=0

# new_sandbox — fresh dir with an isolated HOME, published as $s and $h.
# Deliberately NOT `s=$(new_sandbox)`: command substitution runs the function in
# a subshell, so the counter increment would be discarded and every case would
# silently share one directory.
new_sandbox() {
    sandbox_n=$((sandbox_n + 1))
    s="$SANDBOX_BASE/s$sandbox_n"
    h="$s/home"
    mkdir -p "$h"
}

# run_apply <cwd> <home> [CLAUDE_PROJECT_DIR] — drives the script under test and
# publishes $RC and $ERR for assert_rc / assert_silent / assert_noisy.
# CLAUDE_PROJECT_DIR is always set explicitly — empty unless passed — because the
# test process may well have inherited one from the Claude session running it.
# One branch suffices: the script reads it as ${CLAUDE_PROJECT_DIR:-.}, so empty
# and unset behave identically.
RC=0
ERR=""
run_apply() {
    _err="$SANDBOX_BASE/.stderr"
    ( CDPATH= cd -- "$1" && HOME="$2" CLAUDE_PROJECT_DIR="${3:-}" \
        "$SEED_SH" "$SCRIPT" apply 2>"$_err" )
    RC=$?
    ERR=$(cat "$_err" 2>/dev/null)
}

run_where() {
    _cwd=$1 _home=$2
    ( CDPATH= cd -- "$_cwd" && HOME="$_home" CLAUDE_PROJECT_DIR= \
        "$SEED_SH" "$SCRIPT" where 2>/dev/null )
}

# id_of <dir> — the <id> the script is specified to derive: the resolved
# physical path with '/' -> '-'. Resolved because sandboxes sit under
# $HOME/.cache, which may itself be reached through a symlink.
id_of() { ( CDPATH= cd -- "$1" && pwd -P ) | tr '/' '-'; }

# amd — reads .autoMemoryDirectory out of a settings file ("" when absent).
amd() { jq -r '.autoMemoryDirectory // ""' "$1" 2>/dev/null; }

make_repo() { # dir — a git repo with one commit (worktree add needs a commit)
    mkdir -p "$1"
    git -C "$1" init -q
    git -C "$1" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
}

# ================================================================ CURRENT BEHAVIOUR
# These lock in what the script does today, so the refactor that splits the id
# anchor from the settings location cannot silently change it.

describe 'normal repo'
new_sandbox; repo="$s/proj"
make_repo "$repo"
id=$(id_of "$repo")
assert_eq "~/.claude/memory/$id" "$(run_where "$repo" "$h")" 'where prints the path-slug target'
run_apply "$repo" "$h"
assert_eq "~/.claude/memory/$id" "$(amd "$repo/.claude/settings.local.json")" \
    'apply writes autoMemoryDirectory into the repo toplevel'

describe 'worktree shares the id but keeps its own settings file'
new_sandbox; repo="$s/proj"; wt="$s/proj-feature"
make_repo "$repo"
git -C "$repo" worktree add -q -b feature "$wt" 2>/dev/null
id=$(id_of "$repo")
# Both sides asserted against the expected literal, never against each other:
# `where` prints `~/.claude/memory/-` and exits 0 when the anchor cannot be
# resolved, so comparing two invocations stays green even if id derivation is
# completely broken.
assert_eq "~/.claude/memory/$id" "$(run_where "$repo" "$h")" 'main checkout resolves to the id'
assert_eq "~/.claude/memory/$id" "$(run_where "$wt" "$h")" 'the worktree resolves to the same id'
run_apply "$wt" "$h"
assert_eq "~/.claude/memory/$id" "$(amd "$wt/.claude/settings.local.json")" \
    'worktree settings point at the shared id'
assert_absent "$repo/.claude/settings.local.json" \
    'applying in the worktree does not write into the main checkout'

describe 'overwrite policy'
new_sandbox; repo="$s/proj"
make_repo "$repo"
mkdir -p "$repo/.claude"
printf '{"autoMemoryDirectory":"~/somewhere/custom"}' >"$repo/.claude/settings.local.json"
run_apply "$repo" "$h"
assert_eq '~/somewhere/custom' "$(amd "$repo/.claude/settings.local.json")" \
    'a value outside the managed roots is left alone'

describe 'unrelated keys survive'
new_sandbox; repo="$s/proj"
make_repo "$repo"
mkdir -p "$repo/.claude"
printf '{"permissions":{"allow":["WebSearch"]}}' >"$repo/.claude/settings.local.json"
run_apply "$repo" "$h"
assert_eq 'WebSearch' \
    "$(jq -r '.permissions.allow[0]' "$repo/.claude/settings.local.json")" \
    'existing keys are preserved by the jq merge'

describe 'idempotent'
new_sandbox; repo="$s/proj"
make_repo "$repo"
run_apply "$repo" "$h"
first=$(cat "$repo/.claude/settings.local.json")
run_apply "$repo" "$h"
assert_eq "$first" "$(cat "$repo/.claude/settings.local.json")" \
    'a second apply changes nothing'

describe 'migration from the Claude default location'
new_sandbox; repo="$s/proj"
make_repo "$repo"
id=$(id_of "$repo")
mkdir -p "$h/.claude/projects/$id/memory"
printf 'remembered\n' >"$h/.claude/projects/$id/memory/MEMORY.md"
printf 'transcript\n' >"$h/.claude/projects/$id/session.jsonl"
run_apply "$repo" "$h"
assert_exists "$h/.claude/memory/$id/MEMORY.md" 'memory/ is moved to the shared home'
assert_exists "$h/.claude/projects/$id/session.jsonl" 'transcripts stay behind'

describe 'populated target is never clobbered'
new_sandbox; repo="$s/proj"
make_repo "$repo"
id=$(id_of "$repo")
mkdir -p "$h/.claude/memory/$id" "$h/.claude/projects/$id/memory"
printf 'new\n' >"$h/.claude/memory/$id/MEMORY.md"
printf 'old\n' >"$h/.claude/projects/$id/memory/MEMORY.md"
run_apply "$repo" "$h"
assert_eq 'new' "$(cat "$h/.claude/memory/$id/MEMORY.md")" \
    'existing memory wins over the migration source'

describe 'bare+worktree layout'
new_sandbox; seed="$s/seed"; box="$s/container"
make_repo "$seed"
branch=$(git -C "$seed" branch --show-current)
mkdir -p "$box"
git clone --bare -q "$seed" "$box/.bare"
git --git-dir="$box/.bare" worktree add -q "$box/$branch" "$branch" 2>/dev/null
id=$(id_of "$box")
assert_eq "~/.claude/memory/$id" "$(run_where "$box/$branch" "$h")" \
    'the id is the container path, not the worktree path'

describe 'legacy basename dir is upgraded'
new_sandbox; repo="$s/proj"
make_repo "$repo"
id=$(id_of "$repo")
mkdir -p "$h/.claude/memory/proj"
printf 'remembered\n' >"$h/.claude/memory/proj/MEMORY.md"
run_apply "$repo" "$h"
assert_exists "$h/.claude/memory/$id/MEMORY.md" \
    'the retired basename dir is renamed to the path slug'
assert_absent "$h/.claude/memory/proj" 'nothing is left behind at the old name'

describe 'symlinked project dir'
new_sandbox; repo="$s/real"; link="$s/link"
make_repo "$repo"
ln -s "$repo" "$link"
id=$(id_of "$repo")
assert_eq "~/.claude/memory/$id" "$(run_where "$link" "$h")" \
    'reaching a repo through a symlink resolves to the real path id'

# ================================================================ GUARDS
# Three locations must never receive a settings file. The $HOME one is the only
# genuinely destructive failure mode in this script: ~/.claude/settings.local.json
# is Claude's USER-level settings, so an autoMemoryDirectory written there would
# collapse every project's memory into one bucket.

describe 'guard: $HOME'
new_sandbox
run_apply "$h" "$h"
assert_absent "$h/.claude/settings.local.json" \
    'a plain $HOME is refused'
assert_rc 0 'and exits cleanly'

describe 'guard: $HOME that is itself a git repo'
new_sandbox
make_repo "$h"
run_apply "$h" "$h"
assert_absent "$h/.claude/settings.local.json" \
    'a yadm-style $HOME repo is refused too'
assert_rc 0 'and exits cleanly'

describe 'guard: /tmp'
new_sandbox
TMP_SANDBOX="/tmp/cms-test-$$"
rm -rf "$TMP_SANDBOX"
mkdir -p "$TMP_SANDBOX/plain"
make_repo "$TMP_SANDBOX/repo"
run_apply "$TMP_SANDBOX/repo" "$h"
assert_absent "$TMP_SANDBOX/repo/.claude/settings.local.json" \
    'a git repo under /tmp is refused'
run_apply "$TMP_SANDBOX/plain" "$h"
assert_absent "$TMP_SANDBOX/plain/.claude/settings.local.json" \
    'a non-git dir under /tmp is refused'
assert_rc 0 'and exits cleanly'

describe 'guard: /'
new_sandbox
run_apply / "$h"
# NOT assert_absent: an unprivileged user cannot write to / anyway, so that
# assertion passes with the guard deleted. A guard-less run fails on
# `mkdir: Permission denied`, which is exactly what rc + silence catch.
assert_rc 0 'the filesystem root is refused without failing'
assert_silent 'refusing / produces no diagnostic'

# ================================================================ NON-GIT PROJECTS
# A non-git dir has no worktrees to reconcile, so both anchors collapse onto the
# project dir itself — which is also exactly how Claude buckets it under
# projects/, keeping the migration lookup a straight match.

describe 'non-git project dir'
new_sandbox; proj="$s/devops"
mkdir -p "$proj"
id=$(id_of "$proj")
assert_eq "~/.claude/memory/$id" "$(run_where "$proj" "$h")" \
    'where derives the id from the project dir itself'
run_apply "$proj" "$h"
assert_eq "~/.claude/memory/$id" "$(amd "$proj/.claude/settings.local.json")" \
    'apply seeds a non-git project dir'

describe 'CLAUDE_PROJECT_DIR wins over cwd'
new_sandbox; proj="$s/devops"
mkdir -p "$proj/sub"
id=$(id_of "$proj")
run_apply "$proj/sub" "$h" "$proj"
assert_eq "~/.claude/memory/$id" "$(amd "$proj/.claude/settings.local.json")" \
    'settings land on the project root, not the subdir'
assert_absent "$proj/sub/.claude/settings.local.json" \
    'the subdir gets nothing'

describe 'CLAUDE_PROJECT_DIR unset falls back to cwd'
new_sandbox; proj="$s/devops"
mkdir -p "$proj"
id=$(id_of "$proj")
run_apply "$proj" "$h"
assert_eq "~/.claude/memory/$id" "$(amd "$proj/.claude/settings.local.json")" \
    'a missing CLAUDE_PROJECT_DIR is not an error'

describe 'symlinked non-git project dir'
new_sandbox; proj="$s/real"; link="$s/link"
mkdir -p "$proj"
ln -s "$proj" "$link"
id=$(id_of "$proj")
assert_eq "~/.claude/memory/$id" "$(run_where "$link" "$h")" \
    'the symlink resolves to the real path bucket'

describe 'non-git migration from the Claude default location'
new_sandbox; proj="$s/devops"
mkdir -p "$proj"
id=$(id_of "$proj")
mkdir -p "$h/.claude/projects/$id/memory"
printf 'remembered\n' >"$h/.claude/projects/$id/memory/MEMORY.md"
run_apply "$proj" "$h"
assert_exists "$h/.claude/memory/$id/MEMORY.md" \
    'a non-git project migrates like a repo does'

# ================================================================ MIGRATION LOOKUP
# Claude's projects/ bucket name is NOT our slug: it folds '_' to '-' as well
# (observed: cashback_api -> ...-cashback-api). String-building the source path
# therefore misses every project whose path contains an underscore.

# claude_bucket — what Claude would have named the bucket for our <id>. Folding
# both '_' and '.' models a rule we cannot fully observe; the point of the
# normalised comparison is that it does not need to be exact.
claude_bucket() { printf '%s' "$1" | tr '_.' '--'; }

describe 'migration source with an underscore in the path'
new_sandbox; proj="$s/cashback_api"
mkdir -p "$proj"
id=$(id_of "$proj")
bucket=$(claude_bucket "$id")
[ "$bucket" = "$id" ] && ng 'fixture' 'the fixture path must differ once folded'
mkdir -p "$h/.claude/projects/$bucket/memory"
printf 'remembered\n' >"$h/.claude/projects/$bucket/memory/MEMORY.md"
run_apply "$proj" "$h"
assert_exists "$h/.claude/memory/$id/MEMORY.md" \
    "a '-' bucket is matched against our '_' id"

describe 'missing projects dir'
new_sandbox; proj="$s/devops"
mkdir -p "$proj"
id=$(id_of "$proj")
run_apply "$proj" "$h"
assert_eq "~/.claude/memory/$id" "$(amd "$proj/.claude/settings.local.json")" \
    'an absent ~/.claude/projects is not an error'

describe 'folded match still respects a populated target'
new_sandbox; proj="$s/mms_chat_api"
mkdir -p "$proj"
id=$(id_of "$proj")
bucket=$(claude_bucket "$id")
mkdir -p "$h/.claude/memory/$id" "$h/.claude/projects/$bucket/memory"
printf 'new\n' >"$h/.claude/memory/$id/MEMORY.md"
printf 'old\n' >"$h/.claude/projects/$bucket/memory/MEMORY.md"
run_apply "$proj" "$h"
assert_eq 'new' "$(cat "$h/.claude/memory/$id/MEMORY.md")" \
    'the folded lookup does not bypass the never-clobber rule'

# ================================================================ HARDENING
# settings_root arrives via `pwd -P`, so every value it is compared against has
# to be resolved too. A one-sided comparison is silently never equal.

describe 'guard: $HOME reached through a symlink'
new_sandbox
mkdir -p "$s/realhome"; ln -s "$s/realhome" "$s/linkhome"
run_apply "$s/linkhome" "$s/linkhome"
assert_rc 0 'exits cleanly'
assert_absent "$s/realhome/.claude/settings.local.json" \
    'a symlinked $HOME is refused at its real path'

describe 'guard: $HOME with a trailing slash'
new_sandbox
run_apply "$h" "$h/"
assert_absent "$h/.claude/settings.local.json" \
    'a trailing slash does not defeat the comparison'

describe 'guard does not over-reach'
new_sandbox; proj="$s/sub/proj"
mkdir -p "$proj"
run_apply "$proj" "$h"
assert_exists "$proj/.claude/settings.local.json" \
    'a directory under $HOME is still seeded'
TMP_SANDBOX2="/tmpfoo-cms-$$"
if mkdir -p "$TMP_SANDBOX2" 2>/dev/null; then
    run_apply "$TMP_SANDBOX2" "$h"
    assert_exists "$TMP_SANDBOX2/.claude/settings.local.json" \
        '/tmpfoo shares a prefix with /tmp but is not under it'
    rm -rf "$TMP_SANDBOX2"
else
    skip 'no write access to / — the /tmp-prefix half of over-reach is unpinned here'
fi

describe 'a malformed settings file is never truncated'
new_sandbox; proj="$s/proj"
mkdir -p "$proj/.claude"
printf '{"permissions":{"allow":["WebSearch"]},}' >"$proj/.claude/settings.local.json"
before=$(cat "$proj/.claude/settings.local.json")
run_apply "$proj" "$h"
assert_rc 0 'exits cleanly despite the parse failure'
assert_eq "$before" "$(cat "$proj/.claude/settings.local.json")" \
    'the unparseable file keeps its contents'

describe 'no temp file is left behind'
new_sandbox; proj="$s/proj"
mkdir -p "$proj"
run_apply "$proj" "$h"
leftovers=$(find "$proj/.claude" -name '*.tmp*' 2>/dev/null | wc -l)
assert_eq 0 "$leftovers" 'a successful write leaves no scratch file'

describe 'an unwritable project dir never fails the caller'
new_sandbox; proj="$s/readonly"
mkdir -p "$proj"; chmod 500 "$proj"
run_apply "$proj" "$h"
chmod 700 "$proj"
assert_rc 0 'the hook is not broken by a failed write'
assert_noisy 'the failure is still reported on stderr'

describe 'a failed migration is neither reported nor swallowed'
new_sandbox; proj="$s/proj"
mkdir -p "$proj" "$h/.claude/memory/proj" "$h/.claude/projects/-bucket/memory"
printf 'legacy\n' >"$h/.claude/memory/proj/M.md"
printf 'claude\n' >"$h/.claude/projects/-bucket/memory/M.md"
chmod 500 "$h/.claude/memory"          # the legacy source cannot be renamed
run_apply "$proj" "$h"
chmod 700 "$h/.claude/memory"
assert_rc 0 'exits cleanly'
case $ERR in
    *migrated*) ng 'no false success' "stderr claims a migration happened: $ERR" ;;
    *)          ok 'no false success' ;;
esac
assert_exists "$h/.claude/memory/proj/M.md" 'the source that could not move is left intact'

describe 'HOME unset does not kill the hook'
new_sandbox; proj="$s/proj"
mkdir -p "$proj"
# `|| true` at the call site cannot catch this: under `set -u` an unbound
# expansion terminates the shell before any AND-OR list is reached.
( CDPATH= cd -- "$proj" && env -u HOME -u CLAUDE_PROJECT_DIR "$SEED_SH" "$SCRIPT" apply ) 2>/dev/null
RC=$?; ERR=""
assert_rc 0 'an unset HOME still exits 0'

# ---------------------------------------------------------------- summary
printf '\n[%s] %d passed, %d failed, %d skipped\n' "$SEED_SH" "$passed" "$failed" "$skipped"
[ "$failed" -eq 0 ] || exit 1
