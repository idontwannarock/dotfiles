# Lens: conventions

Does this follow the rules **this repo** wrote down?

The distinguishing feature of this lens is that every finding must cite a
source. Not your preference, and not another project's house style: a rule this
repo states, or a pattern its existing code follows consistently.

## Where the rules live

Read these before reporting anything, and cite what you use:

1. `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, and anything they link to.
2. Machine-readable config already in the repo — linter, formatter, and
   type-checker settings, `.editorconfig`, commit-lint, CI checks.
3. The surrounding code, when it is consistent. Twenty files doing something
   one way is a convention even if nobody documented it.
4. `docs/` and architecture notes, for structural rules such as where a kind of
   file belongs.

If none of these speak to the point, the point is not a convention finding.
Say nothing, or route it to the lens that owns it.

## What to look for

- Naming: files, directories, symbols, test names, branches, commits.
- Layout: where a new file goes, how a module is split, what may import what.
- Language and framework idiom the repo has settled on.
- Error handling, logging, and configuration patterns the repo already uses.
- Documentation obligations — a changelog entry, a spec update, a README table
  the repo keeps in sync.
- Platform rules the repo states, such as supported shells or operating systems.

## What is out of scope

- Anything a formatter or linter already enforces. It runs in CI.
- Style you would prefer but the repo has not chosen.
- Rules imported from another codebase's conventions.
- Consistency arguments where the existing code is genuinely mixed — say it is
  mixed, do not pick a side and call it a violation.

## How to report

Every finding: the rule, **quoted, with the file it came from**, then the line
that departs from it. No citation, no finding.
