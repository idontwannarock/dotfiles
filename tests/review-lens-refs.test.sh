#!/bin/sh
# review-lens-refs.test.sh — keep the review flows and the lens files in sync.
#
# The review flows no longer name agents. They name FILES: a flow says to run
# `correctness.md`, and a reviewer reads it from
# ~/.agent/reference/review-lenses/. That indirection is why the lens bodies
# cost nothing per session -- but it also means a rename breaks the flow
# silently. Nothing resolves a lens name at render time, so chezmoi renders a
# dangling reference happily, and the flow only fails at review time, in a
# subagent, as "I could not find that file" buried in a report the user reads
# for its findings.
#
# Three checks, in both directions:
#
#   1. Every lens a flow names exists.
#   2. Every lens that exists is named by a flow -- an orphan lens is either a
#      flow that forgot it or a file nobody deleted, and both read as "the set
#      is complete" to the next person.
#   3. No review body names one of the retired review agents. Those seven definitions
#      were deleted; a body still naming `code-reviewer` or `linus-torvalds`
#      renders fine and dispatches to nothing.
#
# Check 2 is the one that earns its place. A missing lens announces itself the
# first time someone runs the flow; an extra one never does.
#
# usage: sh tests/review-lens-refs.test.sh

set -u

self_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_root=$(dirname "$self_dir")
bodies_dir="$repo_root/home/.chezmoitemplates/skills"
lens_dir="$repo_root/home/dot_agent/reference/review-lenses"

# Repo docs a lens or flow may legitimately name without being a lens.
not_a_lens="CLAUDE.md AGENTS.md CONTRIBUTING.md README.md index.md"

retired_agents="code-reviewer code-simplifier comment-analyzer pr-test-analyzer
silent-failure-hunter type-design-analyzer linus-torvalds"

failures=0
fail() { printf 'FAIL: %s\n' "$1" >&2; failures=$((failures + 1)); }

[ -d "$lens_dir" ] || { fail "no lens directory at $lens_dir"; exit 1; }

# A "lens-dispatching flow" is a body that pulls in code-review-dispatch.md --
# that fragment is what turns a backticked filename into a lens reference. Other
# review bodies name .md files of their own (review-cross-model hands its
# counterpart a findings file), and those are not lenses.
flows=$(grep -l 'skills/code-review-dispatch.md' "$bodies_dir"/*.md 2>/dev/null | sort)
[ -n "$flows" ] || { fail "no lens-dispatching flow bodies found in $bodies_dir"; exit 1; }

# --- 1. every referenced lens exists ------------------------------------------
referenced=""
for body in $flows; do
    rel=${body#"$repo_root"/}
    for ref in $(grep -ohE '`[A-Za-z0-9_.-]+\.md`' "$body" | tr -d '`' | sort -u); do
        case " $not_a_lens " in *" $ref "*) continue ;; esac
        referenced="$referenced $ref"
        [ -f "$lens_dir/$ref" ] || fail "$rel names lens '$ref', which does not exist in ${lens_dir#"$repo_root"/}"
    done
done

# --- 2. every lens is referenced ----------------------------------------------
for lens in "$lens_dir"/*.md; do
    name=$(basename "$lens")
    [ "$name" = "index.md" ] && continue
    case " $referenced " in
        *" $name "*) ;;
        *) fail "lens '$name' exists but no review flow names it — orphan" ;;
    esac
done

# --- 3. no retired agent names ------------------------------------------------
# Widened on purpose: check EVERY shared body, not just the dispatching flows.
# The names leaked into review-spec and the Codex bodies too, and a guard scoped
# to the population that happens to be clean is the shape of a false green.
for body in "$bodies_dir"/*.md; do
    rel=${body#"$repo_root"/}
    for agent in $retired_agents; do
        if grep -q -- "$agent" "$body"; then
            fail "$rel still names the retired agent '$agent'"
        fi
    done
done

lens_count=$(find "$lens_dir" -name '*.md' ! -name index.md | wc -l | tr -d ' ')
flow_count=$(printf '%s\n' "$flows" | wc -l | tr -d ' ')

if [ "$failures" -eq 0 ]; then
    printf 'ok: %s lenses, %s flow bodies, every reference resolves both ways\n' \
        "$lens_count" "$flow_count"
    exit 0
fi

printf '%d failure(s)\n' "$failures" >&2
exit 1
