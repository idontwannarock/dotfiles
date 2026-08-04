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

# ---------------------------------------------------------------- fixtures
sandbox_n=0

# new_sandbox — fresh dir with an isolated HOME, published as $SANDBOX.
# Deliberately NOT `s=$(new_sandbox)`: command substitution runs the function in
# a subshell, so the counter increment would be discarded and every case would
# silently share one directory.
new_sandbox() {
    sandbox_n=$((sandbox_n + 1))
    SANDBOX="$SANDBOX_BASE/s$sandbox_n"
    mkdir -p "$SANDBOX/home"
}

# run_apply <cwd> <home> [CLAUDE_PROJECT_DIR] — drives the script under test.
# CLAUDE_PROJECT_DIR is explicitly cleared unless passed, because the test
# process may well have inherited one from the Claude session running it.
run_apply() {
    _cwd=$1 _home=$2 _pd=${3:-}
    if [ -n "$_pd" ]; then
        ( CDPATH= cd -- "$_cwd" && HOME="$_home" CLAUDE_PROJECT_DIR="$_pd" \
            "$SEED_SH" "$SCRIPT" apply 2>/dev/null )
    else
        ( CDPATH= cd -- "$_cwd" && HOME="$_home" CLAUDE_PROJECT_DIR= \
            "$SEED_SH" "$SCRIPT" apply 2>/dev/null )
    fi
}

run_where() {
    _cwd=$1 _home=$2
    ( CDPATH= cd -- "$_cwd" && HOME="$_home" CLAUDE_PROJECT_DIR= \
        "$SEED_SH" "$SCRIPT" where 2>/dev/null )
}

# slug — the id derivation the script is specified to use: '/' -> '-'.
slug() { printf '%s' "$1" | tr '/' '-'; }

# physical_of — the resolved path the script will anchor on. Sandboxes sit under
# $HOME/.cache, which may itself be reached through a symlink on some machines.
physical_of() { ( CDPATH= cd -- "$1" && pwd -P ); }

# amd — reads .autoMemoryDirectory out of a settings file ("" when absent).
amd() { jq -r '.autoMemoryDirectory // ""' "$1" 2>/dev/null || printf ''; }

make_repo() { # dir — a git repo with one commit (worktree add needs a commit)
    mkdir -p "$1"
    git -C "$1" init -q
    git -C "$1" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
}

# ================================================================ CURRENT BEHAVIOUR
# These lock in what the script does today, so the refactor that splits the id
# anchor from the settings location cannot silently change it.

describe 'normal repo'
new_sandbox; s="$SANDBOX"; h="$s/home"; repo="$s/proj"
make_repo "$repo"
repo_p=$(CDPATH= cd -- "$repo" && pwd -P)
id=$(slug "$repo_p")
assert_eq "~/.claude/memory/$id" "$(run_where "$repo" "$h")" 'where prints the path-slug target'
run_apply "$repo" "$h"
assert_eq "~/.claude/memory/$id" "$(amd "$repo/.claude/settings.local.json")" \
    'apply writes autoMemoryDirectory into the repo toplevel'

describe 'worktree shares the id but keeps its own settings file'
new_sandbox; s="$SANDBOX"; h="$s/home"; repo="$s/proj"; wt="$s/proj-feature"
make_repo "$repo"
git -C "$repo" worktree add -q -b feature "$wt" 2>/dev/null
repo_p=$(CDPATH= cd -- "$repo" && pwd -P)
id=$(slug "$repo_p")
assert_eq "$(run_where "$repo" "$h")" "$(run_where "$wt" "$h")" \
    'main checkout and worktree resolve to the same id'
run_apply "$wt" "$h"
assert_eq "~/.claude/memory/$id" "$(amd "$wt/.claude/settings.local.json")" \
    'worktree settings point at the shared id'
assert_absent "$repo/.claude/settings.local.json" \
    'applying in the worktree does not write into the main checkout'

describe 'overwrite policy'
new_sandbox; s="$SANDBOX"; h="$s/home"; repo="$s/proj"
make_repo "$repo"
mkdir -p "$repo/.claude"
printf '{"autoMemoryDirectory":"~/somewhere/custom"}' >"$repo/.claude/settings.local.json"
run_apply "$repo" "$h"
assert_eq '~/somewhere/custom' "$(amd "$repo/.claude/settings.local.json")" \
    'a value outside the managed roots is left alone'

describe 'unrelated keys survive'
new_sandbox; s="$SANDBOX"; h="$s/home"; repo="$s/proj"
make_repo "$repo"
mkdir -p "$repo/.claude"
printf '{"permissions":{"allow":["WebSearch"]}}' >"$repo/.claude/settings.local.json"
run_apply "$repo" "$h"
assert_eq 'WebSearch' \
    "$(jq -r '.permissions.allow[0]' "$repo/.claude/settings.local.json")" \
    'existing keys are preserved by the jq merge'

describe 'idempotent'
new_sandbox; s="$SANDBOX"; h="$s/home"; repo="$s/proj"
make_repo "$repo"
run_apply "$repo" "$h"
first=$(cat "$repo/.claude/settings.local.json")
run_apply "$repo" "$h"
assert_eq "$first" "$(cat "$repo/.claude/settings.local.json")" \
    'a second apply changes nothing'

describe 'migration from the Claude default location'
new_sandbox; s="$SANDBOX"; h="$s/home"; repo="$s/proj"
make_repo "$repo"
repo_p=$(CDPATH= cd -- "$repo" && pwd -P)
id=$(slug "$repo_p")
mkdir -p "$h/.claude/projects/$id/memory"
printf 'remembered\n' >"$h/.claude/projects/$id/memory/MEMORY.md"
printf 'transcript\n' >"$h/.claude/projects/$id/session.jsonl"
run_apply "$repo" "$h"
assert_exists "$h/.claude/memory/$id/MEMORY.md" 'memory/ is moved to the shared home'
assert_exists "$h/.claude/projects/$id/session.jsonl" 'transcripts stay behind'

describe 'populated target is never clobbered'
new_sandbox; s="$SANDBOX"; h="$s/home"; repo="$s/proj"
make_repo "$repo"
repo_p=$(CDPATH= cd -- "$repo" && pwd -P)
id=$(slug "$repo_p")
mkdir -p "$h/.claude/memory/$id" "$h/.claude/projects/$id/memory"
printf 'new\n' >"$h/.claude/memory/$id/MEMORY.md"
printf 'old\n' >"$h/.claude/projects/$id/memory/MEMORY.md"
run_apply "$repo" "$h"
assert_eq 'new' "$(cat "$h/.claude/memory/$id/MEMORY.md")" \
    'existing memory wins over the migration source'

describe 'bare+worktree layout'
new_sandbox; s="$SANDBOX"; h="$s/home"; seed="$s/seed"; box="$s/container"
make_repo "$seed"
branch=$(git -C "$seed" branch --show-current)
mkdir -p "$box"
git clone --bare -q "$seed" "$box/.bare"
git --git-dir="$box/.bare" worktree add -q "$box/$branch" "$branch" 2>/dev/null
box_p=$(physical_of "$box"); id=$(slug "$box_p")
assert_eq "~/.claude/memory/$id" "$(run_where "$box/$branch" "$h")" \
    'the id is the container path, not the worktree path'

describe 'legacy basename dir is upgraded'
new_sandbox; s="$SANDBOX"; h="$s/home"; repo="$s/proj"
make_repo "$repo"
repo_p=$(physical_of "$repo"); id=$(slug "$repo_p")
mkdir -p "$h/.claude/memory/proj"
printf 'remembered\n' >"$h/.claude/memory/proj/MEMORY.md"
run_apply "$repo" "$h"
assert_exists "$h/.claude/memory/$id/MEMORY.md" \
    'the retired basename dir is renamed to the path slug'
assert_absent "$h/.claude/memory/proj" 'nothing is left behind at the old name'

describe 'symlinked project dir'
new_sandbox; s="$SANDBOX"; h="$s/home"; repo="$s/real"; link="$s/link"
make_repo "$repo"
ln -s "$repo" "$link"
assert_eq "$(run_where "$repo" "$h")" "$(run_where "$link" "$h")" \
    'reaching a repo through a symlink resolves to the same id'

# ================================================================ GUARDS
# Three locations must never receive a settings file. The $HOME one is the only
# genuinely destructive failure mode in this script: ~/.claude/settings.local.json
# is Claude's USER-level settings, so an autoMemoryDirectory written there would
# collapse every project's memory into one bucket.

describe 'guard: $HOME'
new_sandbox; s="$SANDBOX"; h="$s/home"
run_apply "$h" "$h"
assert_absent "$h/.claude/settings.local.json" \
    'a plain $HOME is refused'

describe 'guard: $HOME that is itself a git repo'
new_sandbox; s="$SANDBOX"; h="$s/home"
make_repo "$h"
run_apply "$h" "$h"
assert_absent "$h/.claude/settings.local.json" \
    'a yadm-style $HOME repo is refused too'

describe 'guard: /tmp'
new_sandbox; h="$SANDBOX/home"
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

describe 'guard: /'
new_sandbox; h="$SANDBOX/home"
run_apply / "$h"
assert_absent /.claude/settings.local.json 'the filesystem root is refused'

# ================================================================ NON-GIT PROJECTS
# A non-git dir has no worktrees to reconcile, so both anchors collapse onto the
# project dir itself — which is also exactly how Claude buckets it under
# projects/, keeping the migration lookup a straight match.

describe 'non-git project dir'
new_sandbox; s="$SANDBOX"; h="$s/home"; proj="$s/devops"
mkdir -p "$proj"
proj_p=$(physical_of "$proj"); id=$(slug "$proj_p")
assert_eq "~/.claude/memory/$id" "$(run_where "$proj" "$h")" \
    'where derives the id from the project dir itself'
run_apply "$proj" "$h"
assert_eq "~/.claude/memory/$id" "$(amd "$proj/.claude/settings.local.json")" \
    'apply seeds a non-git project dir'

describe 'CLAUDE_PROJECT_DIR wins over cwd'
new_sandbox; s="$SANDBOX"; h="$s/home"; proj="$s/devops"
mkdir -p "$proj/sub"
proj_p=$(physical_of "$proj"); id=$(slug "$proj_p")
run_apply "$proj/sub" "$h" "$proj"
assert_eq "~/.claude/memory/$id" "$(amd "$proj/.claude/settings.local.json")" \
    'settings land on the project root, not the subdir'
assert_absent "$proj/sub/.claude/settings.local.json" \
    'the subdir gets nothing'

describe 'CLAUDE_PROJECT_DIR unset falls back to cwd'
new_sandbox; s="$SANDBOX"; h="$s/home"; proj="$s/devops"
mkdir -p "$proj"
proj_p=$(physical_of "$proj"); id=$(slug "$proj_p")
run_apply "$proj" "$h"
assert_eq "~/.claude/memory/$id" "$(amd "$proj/.claude/settings.local.json")" \
    'a missing CLAUDE_PROJECT_DIR is not an error'

describe 'symlinked non-git project dir'
new_sandbox; s="$SANDBOX"; h="$s/home"; proj="$s/real"; link="$s/link"
mkdir -p "$proj"
ln -s "$proj" "$link"
assert_eq "$(run_where "$proj" "$h")" "$(run_where "$link" "$h")" \
    'the symlink resolves to the real path bucket'

describe 'non-git migration from the Claude default location'
new_sandbox; s="$SANDBOX"; h="$s/home"; proj="$s/devops"
mkdir -p "$proj"
proj_p=$(physical_of "$proj"); id=$(slug "$proj_p")
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
new_sandbox; s="$SANDBOX"; h="$s/home"; proj="$s/cashback_api"
mkdir -p "$proj"
proj_p=$(physical_of "$proj"); id=$(slug "$proj_p")
bucket=$(claude_bucket "$id")
[ "$bucket" = "$id" ] && ng 'fixture' 'the fixture path must differ once folded'
mkdir -p "$h/.claude/projects/$bucket/memory"
printf 'remembered\n' >"$h/.claude/projects/$bucket/memory/MEMORY.md"
run_apply "$proj" "$h"
assert_exists "$h/.claude/memory/$id/MEMORY.md" \
    "a '-' bucket is matched against our '_' id"

describe 'missing projects dir'
new_sandbox; s="$SANDBOX"; h="$s/home"; proj="$s/devops"
mkdir -p "$proj"
proj_p=$(physical_of "$proj"); id=$(slug "$proj_p")
run_apply "$proj" "$h"
assert_eq "~/.claude/memory/$id" "$(amd "$proj/.claude/settings.local.json")" \
    'an absent ~/.claude/projects is not an error'

describe 'folded match still respects a populated target'
new_sandbox; s="$SANDBOX"; h="$s/home"; proj="$s/mms_chat_api"
mkdir -p "$proj"
proj_p=$(physical_of "$proj"); id=$(slug "$proj_p")
bucket=$(claude_bucket "$id")
mkdir -p "$h/.claude/memory/$id" "$h/.claude/projects/$bucket/memory"
printf 'new\n' >"$h/.claude/memory/$id/MEMORY.md"
printf 'old\n' >"$h/.claude/projects/$bucket/memory/MEMORY.md"
run_apply "$proj" "$h"
assert_eq 'new' "$(cat "$h/.claude/memory/$id/MEMORY.md")" \
    'the folded lookup does not bypass the never-clobber rule'

# ---------------------------------------------------------------- summary
printf '\n[%s] %d passed, %d failed\n' "$SEED_SH" "$passed" "$failed"
[ "$failed" -eq 0 ] || exit 1
