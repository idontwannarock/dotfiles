#!/bin/sh
# path-format-flag-order.test.sh — guard for a failure that exits 0.
#
# `git rev-parse --path-format=absolute --git-common-dir` prints an absolute
# path. Move the flag after the option it modifies and git prints a RELATIVE one
# — `.git` from the repo root, `../.git` from a subdirectory — with exit code 0
# and nothing on stderr. Every downstream consumer then keys the same repo under
# a second slug, or resolves `-C <other repo>` to the caller's own.
#
# WHAT WENT WRONG, ACCURATELY. On 2026-08-24 the canonical file
# (home/dot_agent/reference/repo-identity.md) carried the flag MISORDERED. The
# fix for it shipped with a verification of `grep -- "--git-common-dir
# --path-format"`, which assumes the defect is transposition — and on that same
# branch `pickup.md`, one of the skill bodies the rule names, had the flag
# OMITTED ENTIRELY. The grep is structurally blind to omission, and the task was
# marked done on its strength. Two shapes, one rule: hence a check over call
# sites rather than over one wrong string.
#
# TWO FORMS ARE CORRECT, not one:
#
#   a. `--path-format=absolute` before `--git-common-dir`
#   b. the output wrapped in an idiom that normalizes it regardless —
#      `cd "$(...)" && pwd -P`, or `basename "$(...)"`, which wants only the last
#      component and gets the same answer from `.git` and `../.git`
#
# Form (b) is in live use at four call sites inside the scanned tree
# (finish-branch.md, worktree.md, dev-workflow.md, bare-worktree/scope.md). A
# guard demanding form (a) everywhere would fire on all four on day one, and a
# guard that is wrong on its first run gets switched off — leaving something
# worse than no guard: a red light nobody reads.
#
# A CALL SITE IS AN INVOCATION, AND THE UNIT OF JUDGEMENT IS THE INVOCATION, NOT
# THE LINE. Prose that names `--git-common-dir` to talk ABOUT the flag carries no
# `rev-parse` and is skipped. Where a line does invoke, each `--git-common-dir`
# on it is judged inside its own window — from the nearest preceding `rev-parse`
# up to that occurrence — because these files are full of markdown tables and
# recipes that put several commands on one row. Judging the whole line let all
# three of these pass green before 2026-08-24:
#
#   `git rev-parse --path-format=absolute --git-common-dir` then `git rev-parse --git-common-dir`
#   `git rev-parse --path-format=absolute --show-toplevel; git rev-parse --git-common-dir`
#   | `basename "$(git rev-parse --show-toplevel)"` | `git rev-parse --git-common-dir` |
#
# — the first because only the first occurrence was examined, the second because
# a flag bound to another option counted, the third because one cell's idiom
# absolved every other cell on the row.
#
# EXEMPTIONS ARE EXPLICIT, never inferred. Deliberate counter-examples showing
# the broken form have to be skipped. The tempting shortcut is a heuristic ("skip
# lines inside a table", "skip lines with CJK"), but a heuristic re-decides itself
# whenever the prose is reworded, and rewording is exactly when this drift
# happens. So an exempt line says so, in a marker invisible in rendered markdown
# that fits on a table row, placed AT THE END OF THE LINE and carrying a reason:
#
#     <!-- flag-order: <why this line is not a call site> -->
#
# Three constraints, and each closes a different hole: the marker is only
# consulted AFTER a line is known to invoke (so a line holding both a real call
# and a marker cannot hide behind it); the reason must be non-empty (an empty
# marker is a mute button); and it must sit at end of line (otherwise a document
# QUOTING the marker disarms the guard on that line — including, before this was
# fixed, the suggestion this very script prints when it fails).
#
# WHAT THIS DOES NOT CHECK.
#
# 1. Semantics. This is a check on SHAPE — where the flag sits within one
#    invocation. An algorithm with a perfectly ordered flag that then takes
#    `basename` instead of `dirname`, or compares a common dir against a worktree
#    path, stays green. There is no mechanical source of truth for that.
#
# 2. Executable code. The population is markdown under the two scan roots below.
#    Three real call sites live outside it and are deliberately not scanned:
#    home/dot_local/bin/executable_claude-memory-seed,
#    home/dot_local/bin/executable_localfiles, and
#    home/dot_config/git/hooks/executable_post-checkout. All three capture the
#    raw output into a variable and normalize it — or rely on a cwd the caller
#    controls — on a LATER line, so a same-line check would fire on all three
#    while they are in fact safe. Measured, not assumed: git runs hooks with cwd
#    set to the top level of the working tree, where the relative form resolves
#    correctly, and in every worktree layout `--git-common-dir` returns an
#    absolute path with or without the flag.
#
# Both are stated rather than left implied for the same reason: a green light
# with no declared population reads to the next person as "this family is
# handled".
#
# usage: sh tests/path-format-flag-order.test.sh

set -u

self_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_root=$(dirname "$self_dir")

# Scan roots, written once. The CI filter in .github/workflows/test-shell.yml
# must list the same directories; the header above explains why a guard that
# does not run when its subjects change is equivalent to no guard.
# Each root carries a floor: the number of matched LINES below which the scan is
# assumed to have lost part of its population rather than to have found a
# cleaner repo. Floors, not equalities — adding files must never turn this red,
# and a deliberate removal that drops below one is a one-line edit here with the
# reason in the commit.
#
# Set just under the counts measured on 2026-08-24 (17 and 6). A global "> 0"
# would only tell total collapse apart from everything else: 14 of 16 call sites
# can vanish and still satisfy it, which is the shape a rename, a
# `.chezmoiignore` change, or a half-finished checkout produces.
# Written as `<root>:<floor>` so a root and its floor cannot drift apart, and so
# adding a root is one edit here plus one in the CI filter — nowhere else.
scan_roots='home/.chezmoitemplates/skills:15 home/dot_agent/reference:5'

failures=0
call_sites=0
exempt=0
files_seen=0

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

finish() {
    if [ "$failures" -eq 0 ]; then
        printf 'ok: %d --git-common-dir call sites in a correct form across %d files, %d exempt\n' \
            "$call_sites" "$files_seen" "$exempt"
        exit 0
    fi
    printf '%d failure(s)\n' "$failures" >&2
    exit 1
}

roots_abs=''
for entry in $scan_roots; do
    root=${entry%:*}
    if [ -d "$repo_root/$root" ]; then
        roots_abs="$roots_abs $repo_root/$root"
    else
        fail "scan root missing: $root"
    fi
done
[ "$failures" -eq 0 ] || finish

# stderr is captured, never discarded: "could not read it" must not become
# "nothing wrong in it". A CI runner with an odd umask, an unreadable directory,
# or a broken symlink would otherwise silently shrink the population.
err_file=$(mktemp) || { fail "cannot create temp file"; finish; }
# shellcheck disable=SC2086
matches=$(find $roots_abs -type f \( -name '*.md' -o -name '*.md.tmpl' \) \
    -exec grep -Hn -- '--git-common-dir' {} + 2>"$err_file")
grep_status=$?

if [ -s "$err_file" ]; then
    fail "find/grep wrote to stderr — the scan is incomplete, so its verdict means nothing:"
    sed 's/^/  /' "$err_file" >&2
fi
# grep exits 1 for "no matches", which the population floors below judge.
# Anything above that is a real error.
[ "$grep_status" -le 1 ] || fail "grep exited $grep_status — the scan is incomplete"
rm -f "$err_file"

files_seen=$(find $roots_abs -type f \( -name '*.md' -o -name '*.md.tmpl' \) 2>/dev/null | wc -l)
files_seen=$((files_seen))

# Judge one occurrence of `--git-common-dir`, given the segment of the line that
# runs from the END OF THE PREVIOUS OCCURRENCE (or the line start) up to this
# one. Bounding the window at the previous occurrence rather than at the line
# start is what stops one real invocation from vouching for a later mention of
# the flag in the same sentence — handoff.md:50 is exactly that shape.
#
# Returns 0 for a correct form, 1 for misordered, 2 for missing, 3 for "not an
# invocation" (no `rev-parse` in the segment, so this occurrence is prose).
judge_segment() {
    seg=$1
    case "$seg" in
        *rev-parse*) ;;
        *) return 3 ;;
    esac
    # Everything before the last `rev-parse` — used to ask what wraps THIS call.
    pre=${seg%rev-parse*}
    # ...and everything after it: the option list this occurrence belongs to.
    inv=${seg##*rev-parse}

    # Form (b): the normalizing idiom must open IMMEDIATELY around this
    # invocation. Testing the whole segment instead would let a table row like
    #   | `basename "$(git rev-parse --show-toplevel)"` | `git rev-parse --git-common-dir` |
    # absolve its neighbouring cell, which is one of the holes this rewrite
    # closes. `-C <path>` may sit between `git` and `rev-parse`.
    case "$pre" in
        *'cd "$(git '*|*'cd -- "$(git '*|*'basename "$(git '*)
            case ${pre##*\$\(} in
                'git '|'git -C '*) return 0 ;;
            esac
            ;;
    esac

    case "$inv" in
        *--path-format=absolute*) return 0 ;;
        *--path-format*) return 1 ;;
        *) return 2 ;;
    esac
}

while IFS= read -r record; do
    [ -n "$record" ] || continue
    file=${record%%:*}
    rest=${record#*:}
    lineno=${rest%%:*}
    text=${rest#*:}
    rel=${file#"$repo_root"/}

    # Walk EVERY occurrence on the line, not just the first.
    #
    # Pure string operations, never index arithmetic: `${#var}` counts characters
    # in bash and bytes in dash, and `cut -c` differs the same way, so any
    # offset-based slice disagrees between the two interpreters the moment a line
    # contains non-ASCII — and these files are half Chinese.
    tail_text=$text
    line_flagged=0
    while :; do
        case "$tail_text" in
            *--git-common-dir*) ;;
            *) break ;;
        esac
        segment=${tail_text%%--git-common-dir*}
        # Advance past this occurrence; the next segment starts here.
        tail_text=${tail_text#*--git-common-dir}

        judge_segment "$segment"
        case $? in
            0) call_sites=$((call_sites + 1)); continue ;;
            3) continue ;;
        esac
        verdict=$?

        # Only now does the exemption marker get a say: this occurrence is a
        # real invocation in a wrong form. The marker must close, carry a
        # non-empty reason, and end the line.
        # Anchored at end of line, allowing only a markdown table's closing `|`
        # after it: the anchor exists so a marker QUOTED mid-sentence cannot
        # disarm the guard, and a trailing cell delimiter is not content. Putting
        # the marker after that pipe instead would add a cell the header row does
        # not have, and leave correct rendering to the renderer's overflow rules.
        case "$text" in
            *'<!-- flag-order: '*' -->'|*'<!-- flag-order: '*' --> |')
                marker=${text##*<!-- flag-order: }
                reason=${marker% -->}
                reason=${reason% --> |}
                if [ -n "$reason" ]; then
                    [ "$line_flagged" -eq 1 ] || exempt=$((exempt + 1))
                    line_flagged=1
                    continue
                fi
                ;;
        esac

        if [ "$verdict" -eq 1 ]; then
            fail "$rel:$lineno places --path-format after --git-common-dir (silently ineffective, exit 0):"
        else
            fail "$rel:$lineno invokes --git-common-dir with no --path-format=absolute:"
        fi
        printf '  %s\n' "$text" >&2
        printf '  Fix the invocation, or — if this line is a deliberate counter-example —\n' >&2
        printf '  end the line with a flag-order marker carrying a reason.\n' >&2
    done
done <<EOF
$matches
EOF

# Per-root floors. A global "> 0" only tells total collapse apart from
# everything else: 14 of 16 call sites can vanish and still pass it.
for entry in $scan_roots; do
    root=${entry%:*}
    floor=${entry##*:}
    found=$(printf '%s\n' "$matches" | grep -c "^$repo_root/$root/") || found=0
    [ "$found" -ge "$floor" ] || \
        fail "only $found matches under $root (floor $floor) — the scan lost part of its population"
done

finish
