#!/bin/sh
# skill-name-map-axis.test.sh — guard for the one defect that keeps coming back
# in the shared skill bodies: a conditional branching on the WRONG AXIS.
#
# A shared body renders once per tool through a name-map, so `{{ if eq .n.tool
# "claude" }}` asks "which agent is READING this file". That is the right
# question only when the content is about the reader itself. When the content is
# about some OTHER agent — the pane a coordinator drives, the line it dispatches
# — the branch silently hands each reader an answer about the wrong agent, and
# nothing turns red: both renders are self-consistent and read as plausible.
#
# It has happened three times (dotfiles #107, and twice more found by counting
# rather than by remembering). Two of the three sat within ten lines of prose
# stating the correct axis, so "be careful" demonstrably does not hold here.
#
# The rule this enforces: content that depends on ANOTHER agent's kind must be a
# TABLE covering the kinds, never a branch — the other agent's kind is a runtime
# value, and render time cannot know it. A branch is therefore legitimate only
# for facts about the reader, and every such branch must say so on the line
# above:
#
#     {{/* axis: reader — <why this is a property of the reader itself> */}}
#     {{ if eq .n.tool "claude" -}}
#
# usage: sh tests/skill-name-map-axis.test.sh

set -u

self_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_root=$(dirname "$self_dir")
bodies_dir="$repo_root/home/.chezmoitemplates/skills"

failures=0
checked=0

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

[ -d "$bodies_dir" ] || { fail "no shared skill bodies at $bodies_dir"; exit 1; }

for body in "$bodies_dir"/*.md; do
    [ -f "$body" ] || continue
    rel=${body#"$repo_root"/}

    # Every line opening a conditional on .n.tool must carry the axis marker on
    # the line directly above it. awk keeps the previous line so the check is a
    # count, not a judgement.
    unmarked=$(awk '
        /\{\{-? *if .*\.n\.tool/ {
            if (prev !~ /axis: reader/) print NR ": " $0
        }
        { prev = $0 }
    ' "$body")

    if [ -n "$unmarked" ]; then
        fail "$rel has a .n.tool branch with no 'axis: reader' marker above it:"
        printf '%s\n' "$unmarked" >&2
        printf '  A branch is only correct when the content is about the READER.\n' >&2
        printf '  Content about another agent (a pane, a dispatched line) must be a\n' >&2
        printf '  table covering the kinds — that kind is a runtime value.\n' >&2
    fi
    checked=$((checked + 1))
done

[ "$checked" -gt 0 ] || fail "no skill bodies were checked — glob matched nothing"

if [ "$failures" -eq 0 ]; then
    printf 'ok: %d shared skill bodies, every .n.tool branch declares its axis\n' "$checked"
    exit 0
fi

printf '%d failure(s)\n' "$failures" >&2
exit 1
