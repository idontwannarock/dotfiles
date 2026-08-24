#!/bin/sh
# path-format-flag-order.test.sh — guard for a failure that exits 0.
#
# `git rev-parse --path-format=absolute --git-common-dir` prints an absolute
# path. Move the flag after the option it modifies and git prints a RELATIVE one
# — `.git` from the repo root, `../.git` from a subdirectory — with exit code 0
# and nothing on stderr. Every downstream consumer then keys the same repo under
# a second slug, or resolves `-C <other repo>` to the caller's own.
#
# On 2026-08-24 the canonical file (home/dot_agent/reference/repo-identity.md)
# carried the misordered form while all five skill bodies that copied it were
# correct. The verification that shipped alongside the fix was
# `grep -- "--git-common-dir --path-format"`, which assumes the defect is
# TRANSPOSITION. `pickup.md` had OMITTED the flag entirely; that grep is
# structurally blind to omission, and the task was marked done on its strength.
# Two shapes, one rule — so the check has to be over call sites, not over one
# wrong string.
#
# TWO FORMS ARE CORRECT, not one. This matters more than it looks:
#
#   a. `--path-format=absolute` before `--git-common-dir`
#   b. the raw output wrapped in an idiom that normalizes it regardless —
#      `cd "$(...)" && pwd -P`, or `basename "$(...)"`, which wants only the last
#      component and gets the same answer from `.git` and `../.git`
#
# Form (b) is in live use at seven call sites (finish-branch, worktree,
# dev-workflow, bare-worktree/scope, and three real scripts). A guard demanding
# form (a) everywhere would fire on all seven on day one, and a guard that is
# wrong on its first run gets switched off — leaving something worse than no
# guard: a red light nobody reads.
#
# A CALL SITE IS A LINE THAT INVOKES THE COMMAND — it carries `rev-parse`. Prose
# that names `--git-common-dir` to talk ABOUT the flag is not a call site and is
# skipped without needing a marker. That is a rule about shape, not a guess about
# which sentences look like documentation.
#
# EXEMPTIONS ARE EXPLICIT, never inferred. Prose that merely names the flag, and
# deliberate counter-examples showing the broken form, both have to be skipped.
# The tempting shortcut is a heuristic ("skip lines inside a table", "skip lines
# with CJK"), but a heuristic re-decides itself whenever the prose is reworded,
# and rewording is exactly when this drift happens. So an exempt line says so,
# in a marker that is invisible in rendered markdown and fits on a table row:
#
#     <!-- flag-order: <why this line is not a call site> -->
#
# WHAT THIS DOES NOT CHECK. It is a check on SHAPE — where the flag sits at a
# call site. It cannot tell whether the resulting path is used correctly: an
# algorithm with a perfectly ordered flag that then takes `basename` instead of
# `dirname`, or compares a common dir against a worktree path, stays green.
# There is no mechanical source of truth for that, and no guard is proposed for
# it. Saying so here rather than leaving it implied: a green light with no
# stated population reads to the next person as "this family is handled".
#
# usage: sh tests/path-format-flag-order.test.sh

set -u

self_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_root=$(dirname "$self_dir")

failures=0
call_sites=0
exempt=0

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

scanned=0
for dir in "$repo_root/home/.chezmoitemplates/skills" "$repo_root/home/dot_agent/reference"; do
    [ -d "$dir" ] || { fail "scan target missing: $dir"; continue; }
    scanned=$((scanned + 1))
done
[ "$scanned" -eq 2 ] || exit 1

# One record per matching line: <path>:<lineno>:<text>
matches=$(
    find "$repo_root/home/.chezmoitemplates/skills" "$repo_root/home/dot_agent/reference" \
        -type f -name '*.md' -exec grep -Hn -- '--git-common-dir' {} + 2>/dev/null
)

[ -n "$matches" ] || fail "no --git-common-dir occurrences found — the glob or the scan roots are wrong"

# `while read` in a pipeline runs in a subshell in some shells, so counters set
# inside it would be lost. Feed it by here-doc instead.
while IFS= read -r record; do
    [ -n "$record" ] || continue
    file=${record%%:*}
    rest=${record#*:}
    lineno=${rest%%:*}
    text=${rest#*:}
    rel=${file#"$repo_root"/}

    case "$text" in
        *'<!-- flag-order:'*)
            exempt=$((exempt + 1))
            continue
            ;;
    esac

    # Not an invocation — prose naming the flag rather than calling it.
    case "$text" in
        *rev-parse*) ;;
        *) continue ;;
    esac

    # Form (b): the output is normalized by the surrounding idiom, so a relative
    # path reaches the consumer as the same value an absolute one would.
    case "$text" in
        *'cd "$(git'*|*'cd -- "$(git'*|*'basename "$(git'*)
            call_sites=$((call_sites + 1))
            continue
            ;;
    esac

    # Form (a): the flag precedes the option it modifies, on the same line.
    before=${text%%--git-common-dir*}
    case "$before" in
        *'--path-format=absolute'*)
            call_sites=$((call_sites + 1))
            continue
            ;;
    esac

    case "$text" in
        *'--path-format'*)
            fail "$rel:$lineno places --path-format after --git-common-dir (silently ineffective, exit 0):"
            ;;
        *)
            fail "$rel:$lineno uses --git-common-dir with no --path-format=absolute:"
            ;;
    esac
    printf '  %s\n' "$text" >&2
    printf '  Fix it, or mark it exempt on the same line with:\n' >&2
    printf '    <!-- flag-order: why this line is not a call site -->\n' >&2
done <<EOF
$matches
EOF

[ "$call_sites" -gt 0 ] || fail "no call sites were checked — every line was exempt, which defeats the guard"

if [ "$failures" -eq 0 ]; then
    printf 'ok: %d --git-common-dir call sites in a correct form, %d exempt lines declared\n' \
        "$call_sites" "$exempt"
    exit 0
fi

printf '%d failure(s)\n' "$failures" >&2
exit 1
