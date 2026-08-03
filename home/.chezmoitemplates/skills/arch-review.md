## Purpose

A whole-repo architecture checkup. Every other quality gate here reads a **diff** -- `review-*` sees the branch delta, `verify-done` runs the tests. Architectural entropy is a cross-change phenomenon: each diff looks reasonable on its own, and the damage is only visible when you step back. This skill is that step back.

It **diagnoses only**. The output is a ranked list of refactor candidates with evidence, written to a pickup-compatible document so you can resume and act on a chosen candidate in a fresh session.

## Principles

- **Never modify source.** Not a single edit, however obvious the fix looks. Diagnosis and surgery are separate decisions, and the second one is the user's.
- **Evidence or it doesn't ship.** Every candidate carries at least one concrete file path plus what was actually observed there. "The service layer feels bloated" is not a finding; "`src/services/` has 3 modules over 800 lines, and `OrderService`/`OrderManager`/`OrderHandler` all mutate the same table" is.
- **State the basis of judgement.** Module-boundary calls made from an inferred vocabulary are weaker than ones made from a documented glossary. Say which you used -- a reader cannot weigh an architectural verdict without knowing what it rests on.
- **Bounded cost.** Cheap inventory first, at most 5 deep-dive zones. A checkup that eats the whole context window will not get run twice.
- **No confirmation.** The user invoked you -- just run it.

## Establish the basis of judgement

Before scanning, resolve the vocabulary that defines module boundaries:

| Condition | Basis | Label it as |
|-----------|-------|-------------|
| `context/` bundle exists | Its glossary and recurring-principles concept files | **authoritative** (cite `context/`) |
| No `context/` bundle | Infer domain language from directory structure, type/class names, exported interfaces | **inferred, not authoritative** |

Never write to `context/`. That bundle is written only during sync/archive, and only for terms with shipped-implementation backing. If the checkup surfaces a term that looks evergreen, mention it under Next steps as something to promote later -- do not write it.

## Phase 1 -- inventory (do NOT read file contents)

Build a structural picture cheaply. Aim for signals, not understanding:

- Directory tree and where the mass sits (file counts, line counts per directory).
- Outlier files by size -- the tail is where responsibilities pile up.
- Dependency direction: which directories import which. Cycles and upward imports are the highest-value signal available at this price.
- Name collisions and near-collisions across directories (`User` / `Member` / `Account`; `*Service` / `*Manager` / `*Handler` for the same noun).
- Obvious duplication signals: same filename in several places, parallel directory shapes.

If the user passed a path argument (`/arch-review src/payment`), scope every phase to it.

Use cheap tools only: file enumeration (`git ls-files`), per-directory line counts, and pattern counts for import lines (`rg -l` / `rg --count-matches`). Do not open files to read logic in this phase.

Pick the counting tool from what the platform actually has -- `wc -l` on Linux/macOS, `Measure-Object -Line` on Windows PowerShell, or `rg --stats` anywhere `rg` is available. Never assume POSIX coreutils: this skill is deployed to Windows machines where `git` and `rg` exist but `wc` does not.

## Phase 2 -- deep dive (at most 5 zones)

Rank the Phase 1 signals by suspicion and pick **3-5 zones**. Never more than 5, whatever the repo size. Only now read actual contents, and only within the chosen zones.

Look for:

- **Duplicate implementations** -- the same logic reached by different paths.
- **Boundary violations** -- a module reaching past its neighbour's interface into internals.
- **Vocabulary drift** -- one concept with several names, or one name covering several concepts. Against the glossary if you have one.
- **Responsibility pile-up** -- a module that grew a second job nobody named.
- **Directional wrongness** -- low-level code depending on high-level code, cycles between packages.

If Phase 1 surfaced more than 5 candidate zones, say so in the report and name the ones you did not open. Silent truncation reads as "everything was covered".

## Compose the report

Write to `~/.agent/handoffs/<repo-slug>/<ID>.md`. This is the same location and convention `handoff` uses, so `pickup` can resume it.

- **Repo slug**: identical derivation to `handoff` -- take `git rev-parse --path-format=absolute --git-common-dir`, drop the last component, and replace every `:`, `\`, `/`, and `.` with `-`. Fall back to `$PWD` if the git command fails.
  - `/home/user/work/api/.git` becomes `-home-user-work-api`
  - `/home/user/work/api/.bare` becomes `-home-user-work-api` from **any** worktree of that repo
  - `D:\ws\github\dotfiles\.git` becomes `D--ws-github-dotfiles`

  Not `git rev-parse --show-toplevel`: under bare+worktree that returns the current worktree, so reports would land where `pickup` will not look from a sibling worktree.
- **ID**: `YYYY-MM-DD-HHMM__arch-review`, user's local time.
- Create the directory if missing. Never write inside a tool-specific dotdir (`.claude/`, `.codex/`) or into the repo.

Rank candidates by expected payoff over effort -- highest first.

```markdown
# Arch Review: <repo name> @ <ISO-8601 timestamp>

- Repo: <absolute path>
- Scope: <whole repo | the path argument>
- Basis of judgement: <`context/` glossary (authoritative) | inferred from codebase (NOT authoritative)>

## Inventory summary

<3-6 lines: where the mass sits, dependency shape, what stood out>

## Zones examined

- <zone> -- <why it was suspicious>

<if applicable:>
## Zones NOT examined

- <zone> -- <why it ranked below the cut>

## Candidates

### 1. <short title>

- **Problem**: <what is wrong, stated plainly>
- **Evidence**: <file paths + what was observed there>
- **Blast radius**: <what a fix would touch>
- **Suggested action**: <the smallest change that resolves it>

### 2. ...

## Suggested skills

<only skills that are safe to fire before a candidate has been chosen; usually none>

## Next steps

1. Pick a candidate to pursue -- nothing here is committed to yet
2. Run `dev-workflow` on the chosen candidate to turn it into a tracked change
3. <candidate-specific first move>
4. <if any evergreen vocabulary surfaced: propose promoting it into `context/` at the next sync/archive>

---

To resume in any future session, run:

    /pickup <ID> in <session language>
```

Append the session language the same way `handoff` does -- `in zh-tw` for a Chinese session, nothing at all for an English one.

### On the `## Suggested skills` section

`pickup` invokes everything listed there **immediately and without confirmation**, before it reads `## Next steps`. That makes the section a loaded gun:

- Do **not** list `dev-workflow` (or anything else that starts work on a candidate). It would launch the change lifecycle before the user has picked which candidate it is for -- exactly the decision this skill refuses to make on their behalf. It belongs in `## Next steps`, which pickup treats as instructions to follow, not as skills to fire.
- If nothing is safe to list, keep the heading and write a plain sentence: `No skills needed -- this review produced no candidates.` A bulleted `- None` is shaped exactly like a real entry and pickup will try to invoke it.

## Report to the user

Print only:

1. The absolute path of the report.
2. The copy-paste `/pickup <ID>` line.
3. A one-line-per-candidate ranked summary, so the user can decide without opening the file.

Do not print the whole report back -- it is on disk.

## Anti-patterns

- **Don't** edit source, create branches, or open an OpenSpec change. Diagnosis only.
- **Don't** report findings without a file path. Unevidenced architectural opinion is noise.
- **Don't** deep-dive more than 5 zones, and don't hide the ones you skipped.
- **Don't** read file contents in Phase 1 -- that defeats the cost control the two phases exist for.
- **Don't** present inferred vocabulary as authoritative when there is no `context/` bundle.
- **Don't** write to `context/`, ever.
- **Don't** re-run the whole scan when the user only asked about one module -- honour the path argument.
- **Don't** pad the candidate list. Three real findings beat ten padded ones; if the codebase is healthy, say so and stop.
- **Don't** put `dev-workflow` -- or anything that acts on a candidate -- under `## Suggested skills`. `pickup` fires that section without confirmation, ahead of `## Next steps`, so listing it there starts the change lifecycle before the user has chosen a candidate.
- **Don't** write `- None` as a bullet under `## Suggested skills`. It is indistinguishable from a real entry, and `pickup` invokes whatever is listed there. Use a plain sentence instead.
