## Purpose

A second opinion from a **different model**. Every other review gate here runs on one model family: the lenses differ by prompt, but the priors, the blind spots, and the evidence -- which you selected and handed over -- are shared. That structure catches *misjudgements* and misses *omissions*.

This skill dispatches an agent of a **different kind** into its own pane, gives it nothing but a branch name and a repo path, and lets it gather its own evidence. Then both sides trade findings and each gets exactly one round to refute the other.

It is **read-only on both sides**. Nothing here edits code, runs tests, or creates worktrees.

## Principles

- **The counterpart's evidence must not pass through you.** Hand it a branch, not a diff. The moment you curate what it sees, you have re-imported your own framing and the only remaining value is "a different model read my summary".
- **The pane is a trigger, never a data channel.** Findings travel by file. Terminal reads fail silently to an empty string, and an empty findings list is indistinguishable from "no issues found".
- **Disagreement is the output.** Two models will not converge, and you must not make them. One round, then hand the splits to the user.
- **Degrade loudly.** If the cross-model leg did not run, the report says so and why. A silent skip reads as "this was cross-verified".
- **Never leave residue.** Every exit path closes the pane it opened and removes the scratch directory -- especially the failure paths, which are exactly the ones nobody watches.
- **The repo is protected by detection, not prevention.** No tested agent kind can be writable in one subdirectory and read-only in the rest, so the boundary is a before/after comparison of the working tree. This is proportionate only because the target is version-controlled: the check is cheap and any deviation is fully recoverable. Do not carry the reasoning to a target that is not under version control.

## Step 0 -- preconditions

Check, in order. Any failure means **degrade** (see the last section) -- never block, never retry:

| Check | Failure reason to report |
|-------|--------------------------|
| `HERDR_ENV` is `1` | `herdr unavailable — not running inside herdr` |
| `herdr` is executable | `herdr unavailable — binary not found` |
| A counterpart kind of a different kind exists | `no counterpart agent available` |
| That kind's readiness probe passes | `counterpart not authenticated` |

**Choosing the counterpart kind.** Two requirements, both hard:

1. **Different from the tool you are running as.** You know which one you are -- if you are Claude, do not start `claude`; if you are Codex, do not start `codex`. A same-kind counterpart provides none of the diversity this gate exists for, at the same cost.
2. **Ready to work.** Run its readiness probe from `~/.agent/reference/cross-model-counterparts.md` before splitting a pane. An unauthenticated CLI starts fine, reports ready, and then sits on a login screen -- which surfaces as `blocked`, a reason that points at the wrong problem entirely.

**Prefer a kind whose writes are confined to the repo**, per the same table. The tree comparison in Step 6 only sees the repo, so an unconfined counterpart is unchecked exactly where nothing is recoverable: `~/.claude`, other repositories, shell configuration.

This is a preference, not a veto. The realistic failure is a counterpart that edits the thing it was reading -- which lands inside the repo, where the comparison catches it. Refusing to run at all would trade a low-probability risk for the certain loss of the whole gate on any tool that has no confined counterpart available, and a quality gate that cannot run protects nothing. **If you use an unconfined counterpart, say so in the report**: `counterpart writes were not confined — only the repository was verified`. Never let that omission pass silently.

`herdr agent start --kind` accepts `pi, claude, codex, gemini, cursor, devin, agy, cline, omp, mastracode, opencode, copilot, kimi, kiro, droid, amp, grok, hermes, kilo, qodercli, maki`.

If no kind is both different and ready, degrade with `no counterpart agent available`. Do not fall back to your own kind.

## Step 1 -- gather your own side, and check the scope is visible

You need your own findings before dispatching, so both sides are produced independently.

If invoked right after `review-comprehensive`, reuse its findings **after** its confidence filter -- the filter is the noise gate, and noise sent to the counterpart just dilutes the exchange. If invoked standalone, produce findings for the scope yourself first.

Record the scope precisely: branch name, or commit range. You will hand over exactly this and nothing more.

**Then verify the counterpart will actually see it.** You can review uncommitted work; the counterpart cannot, because all it receives is a ref. If `git diff <base>...<branch>` is empty, a compliant counterpart correctly reports nothing, and that reads downstream as agreement. Check the range is non-empty before dispatching, and degrade with reason `scope not visible to counterpart — nothing committed on the branch` if it is not.

## Step 2 -- prepare the scratch dir and snapshot the tree

The counterpart works **inside the repo**, and writes into a scratch directory there:

```
<repo>/.cross-model-review/<run id>/
```

Inside the repo, not under `~`, for one reason: an agent's session record is filed under its working directory. Park the counterpart in a throwaway path and its transcript is archived against a directory that will not exist tomorrow -- recorded, but unfindable from the repo it was reviewing. Working inside the repo keeps the review conversation attached to the project it belongs to.

`.cross-model-review/` is gitignored. `<run id>` MUST be filesystem-safe: replace every character outside `[A-Za-z0-9._-]` in the scope label. Branch names routinely contain `/`, and interpolating one raw produces a nested path that the `mkdir` did not create -- the counterpart's write then fails and the run degrades blaming a missing findings file.

Two files live there, one per direction:

| File | Written by |
|------|-----------|
| `counterpart-findings.md` | the counterpart, in Step 3 |
| `counterpart-rebuttal.md` | the counterpart, in Step 5 |

**Keep the scratch dir out of the target repo's status.** `.cross-model-review/` is gitignored in this dotfiles repo only; the skill runs against arbitrary repos that have never heard of it. Add the entry to the target's `.git/info/exclude` -- local, uncommitted, and effective in any repo -- and remove it during teardown. Without this, the scratch files show up as untracked in the user's repo for the length of the run, where a concurrent `git add -A` can stage them.

**Snapshot the working tree before dispatching**: `git status --porcelain`, plus content hashes of **every** tracked file and every non-ignored untracked file -- not just the files in the review scope. A counterpart that edits an already-dirty file outside the diff leaves the porcelain output identical, so a scope-limited snapshot cannot see it; untracked files that are never hashed cannot be checked at all.

The snapshot **detects**; it does not restore. A hash proves a file changed and gives no way to reconstruct what it held before, so there is no honest recovery path for uncommitted content -- see Step 6.

## Step 3 -- dispatch

```
herdr pane split --current --direction right --cwd "<repo path>" --no-focus
```

Take the pane id from `.result.pane.pane_id`. **Never derive or guess an id** -- ids are not reused and change on `pane move`. Use `--no-focus` so you do not steal the user's focus, and a unique agent name so later commands cannot hit somebody else's pane.

A freshly split pane is not immediately at a shell prompt, and `agent start` refuses one that is not (`agent_pane_busy`). Confirm the pane is at its prompt before starting, and retry rather than treating the first refusal as fatal.

Look the counterpart's kind up in `~/.agent/reference/cross-model-counterparts.md` for its launch arguments and exit command. Pre-authorization matters: the protocol requires the counterpart to write, and under a default sandbox that write is the most likely thing to raise an approval prompt -- which surfaces as `blocked`, i.e. a failed run.

Where a sandbox exists, the launch arguments confine the counterpart to the repo. That is a real boundary against the rest of the disk, but it is **not** a read-only boundary on the repo itself: no tested kind can be both writable in one subdirectory and read-only in the rest. The repo's own contents are protected by the Step 6 comparison instead.

```
herdr agent start <name> --kind <kind> --pane <pane id> -- <launch arguments>
```

If the kind has no row there, dispatch with defaults and do not guess flags.

Then prompt it. The prompt MUST contain:

- the repo path and the branch or commit range,
- an instruction to review that change independently and form its own view,
- the **read-only boundary**: do not modify files, do not run tests or builds, do not create branches or worktrees -- stating that the findings file is the sole permitted write,
- the path to `counterpart-findings.md`,
- a request for one finding per entry with file, line, what is wrong, and why it matters.

The prompt MUST NOT contain your diff, your summary of the change, your findings, or a pointer to the spec artifacts. Let it decide what to read.

```
herdr agent prompt <name> "<prompt>" --wait --timeout <ms>
```

**Confirm a live agent still occupies the pane before every submission.** `herdr agent get <name>` must report the agent present. If the counterpart has exited -- a CLI that self-updates on launch will do exactly this -- the pane falls back to a shell prompt, and submitted prompt text is typed into that shell and executed line by line. Review prompts are arbitrary text in the repo's working directory; that is not a failure to shrug at. An absent agent is a degradation path, never a resubmission.

**A converged state is not proof the prompt arrived.** A first prompt submitted just after startup can be swallowed by the agent's own startup notices, and `--wait` still reports a settled state -- observed on both kinds tested. The findings file is the only evidence work happened. If it is absent, resubmit the prompt **once** before degrading.

## Step 4 -- confirm it actually finished

`--wait` settles on `idle`, `done`, **or `blocked`** -- and `blocked` means it stopped at a permission prompt or a clarifying question with the work unfinished. Treat only `idle` and `done` as success.

| Final state | Action |
|-------------|--------|
| `idle` / `done`, **and** the findings file exists | Read the findings file |
| `done`, but the pane is sitting on the counterpart's own trust / authorization / directory-confirmation prompt | Degrade -- reason: `counterpart blocked on input` |
| `blocked` | Degrade -- reason: `counterpart blocked on input` |
| timeout / `agent_prompt_stalled` | Degrade -- reason: `counterpart timed out` |

The second row is not a corner case: a counterpart CLI that opens a trust prompt on first launch in a new directory is reported by herdr as `done`, because herdr cannot tell that prompt apart from an agent idling after finishing. Observed once this round.

**What herdr reports is the state of the pane, not the state of the work.** `herdr agent get` still returns `idle` for an agent that has already exited -- also observed once this round -- so no settled state, on its own, is evidence that anything ran. The findings file is the only evidence.

Then read the findings **file**. If it is missing or empty, degrade with reason `counterpart produced no findings file`. Do **not** read it as "no issues found" -- that conflation is the whole reason the file channel exists.

`herdr agent read` is for diagnosing a failure, never for harvesting results.

## Step 5 -- one round of rebuttal, each way

Score the counterpart's findings through the same confidence filter your own side passed, so the two sets are comparable. Then, exactly once each way:

- Give the counterpart your findings and ask it to refute them, **writing its rebuttal to `counterpart-rebuttal.md`**. Its rebuttal is a result, so it travels by file like every other result -- `agent read` is still not a data channel. Wait and confirm as in Step 4; a missing rebuttal file means that half of the exchange did not happen, and the report says so rather than silently grading as if it had.
- Refute the counterpart's findings yourself, honestly -- you are looking for the ones you missed, not defending your first pass.

Stop there. Do not open a second round, and do not extend on the grounds that "there is still something to say". Two models can disagree indefinitely; the splits are for the user.

## Step 6 -- tear down

Always, on every path -- success, timeout, blocked, error:

1. **Courtesy exit, time-boxed.** Send the exit command from the counterpart's profile in `~/.agent/reference/cross-model-counterparts.md`, so a kind that runs session-end hooks gets to run them. If it is `blocked`, send `esc` first. If its kind has no row there, skip this step -- do not guess a command string.

   Do not expect more of it than that. Measured on codex: a hard close truncates nothing (the transcript is written as it goes) and orphans nothing. The step is kept because it is cheap and because hook-bearing kinds exist, not because the transcript needs it.
2. **Guaranteed close.** `herdr pane close <pane id>` -- unconditionally, whether or not step 1 worked. Never retry step 1, never let it block this one.
3. **Verify the agent is gone.** `herdr agent list` -- the name must not appear.
4. **Compare the tree against the Step 2 snapshot.** Anything that changed outside `.cross-model-review/` was written by the counterpart against its instructions. **Report those paths. Do not restore them.**

   Restoring means taking content from git, and for a file the user had edited but not committed, that destroys their work to undo the counterpart's -- trading a known problem for a worse one. The snapshot can tell you *what* changed; nothing here can tell you what it held before. List the paths, say the counterpart wrote outside its boundary, and let the user decide. Their findings are also suspect now, so say that too rather than folding the result in quietly.

5. **Remove the scratch directory** once both files have been read, and drop the `.git/info/exclude` entry added in Step 2.

Close only the pane you opened. Never `herdr server stop`, never touch a pane you did not create.

Steps 4 and 5 run on the failure paths too. A degraded run still leaves a scratch directory and still had a counterpart with write access.

## Report

Merge into the review output. Grading comes from the exchange, not from the confidence score:

| Outcome | Grade |
|---------|-------|
| Both sides raised it, or one raised it and the rebuttal failed | **Critical** |
| Successfully refuted | Downgrade or drop -- state the refutation |
| Raised by one side only, uncontested | **Split** -- list it, present both positions, let the user decide |

Never resolve a split yourself.

## Degrading

When any precondition or step fails, produce the review **without** the cross-model leg and mark it prominently:

> **Cross-model rebuttal: not run — `<reason>`**

Never omit that line, and never soften it into an absence. The report has to be readable as what it is: a single-model review.

The reasons, and where each is raised:

| Reason | Raised at |
|--------|-----------|
| `herdr unavailable — not running inside herdr` | Step 0 |
| `herdr unavailable — binary not found` | Step 0 |
| `no counterpart agent available` | Step 0 |
| `counterpart not authenticated` | Step 0, before any pane is created |
| `scope not visible to counterpart — nothing committed on the branch` | Step 1 |
| `counterpart failed to start` | Step 3 |
| `counterpart no longer present` | Step 3, before any submission |
| `counterpart blocked on input` | Step 4 |
| `counterpart timed out` | Step 4 |
| `counterpart produced no findings file` | Step 4, after one resubmission |
| `rebuttal exchange incomplete` | Step 5 |

Report the reason you actually hit. Several of these look alike from the outside and mean very different things -- a counterpart that blocked on a permission prompt is a fixable configuration problem, while one that produced no file after a resubmission is not. Collapsing them into "cross-model review failed" throws away the only information that would let anyone fix it.

Degrading still runs the teardown in Step 6 for anything already created.
