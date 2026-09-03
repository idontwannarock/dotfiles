## Purpose

Capture the minimum state needed for a new session to continue the current work without re-exploring. The output is a single markdown file at `~/.agent/handoffs/<repo-slug>/<id>.md` whose last block prints the exact `/pickup <id>` command to revive it from any future session.

The location is user-level and AI-agnostic on purpose: a handoff produced by Claude Code can be picked up by Codex CLI (or any other tool that follows this convention) without the file living inside a tool-specific dotdir.

## Principles

- **References over duplication.** Do not re-summarize content already captured in other artifacts -- PRDs, plans, ADRs, issues, commits, diffs, memory files, READMEs. List them by absolute path or URL with a one-line "why it matters". Re-summarizing wastes tokens both now (writing) and later (reading) when the next session could just open the source.
- **Lean.** Target <= 50 lines total. If it reads like a report, cut it.
- **A handoff carries the handover, not the knowledge.** What the next session must *do*, and where to *find* what it needs -- nothing else. Everything durable belongs in one of four homes, chosen by two axes (does it follow the *user* or the *project*; does it follow *every* machine or only *this* one):

  | | global (version-controlled, travels) | machine (this box only) |
  |---|---|---|
  | user | dotfiles repo -> `home/dot_agent/reference/` | `~/.agent/local/` |
  | project | the project repo -> `context/`, `docs/` | `~/.agent/memory/<repo-slug>/` |

  Write it to its home **first**, then leave a breadcrumb -- an absolute path plus a one-line "why it matters". A handoff is a transient artifact that leaves every lookup the moment it is archived; anything that has to be findable later must not depend on someone opening an old handoff to find it.
- **Args-driven tailoring.** If the user passed arguments, treat them as the description of what the next session will focus on -- they override or refine the first item in "Next steps".
- **Redact secrets.** Replace API keys, passwords, TOTP codes, corp identifiers with placeholders. Note in "Open / unresolved" if redaction loses information the next session needs.
- **No confirmation.** The user invoked you -- just do it. The one exception is the cross-repo suggestion below, which is a question, not a confirmation of work you were already told to do.
- **The user picks the target repo, never you.** The handoff lands in the current repo unless the user names a different one. Inferring the target from conversation content is forbidden: a wrong inference writes a file that exists, parses, and reads fine but that nobody will ever find -- and no error is raised at any point.

## Gather

Run these before composing:

- Repo identity: `git rev-parse --path-format=absolute --git-common-dir`, minus its last component. If the command fails (not a git dir), fall back to `$PWD` -- a slug derived from a non-repo dir is fine. Always pass `--path-format=absolute`: without it git prints a path relative to the current directory, which resolves to the wrong repo the moment you use `-C`.
- Branch: `git rev-parse --abbrev-ref HEAD` (skip if non-git).
- Dirty state: `git status --porcelain` and `git diff --shortstat`.
- Recent commits: `git log -3 --oneline`.
- Current task/todo list snapshot (if any is active).
- What was being worked on in the last 2-3 turns.
- Session language: the language this conversation has been conducted in (e.g. `zh-tw`, `ja`, `en`). It goes into the resume line so the next session starts in the same language instead of guessing.

All of this is a snapshot, and composing the file takes many more turns. A parallel session can merge a branch, archive a handoff you cite, or add a worktree in between -- so step 4 re-reads the volatile ones before the file is written. Phrase them as snapshots too ("at the time of writing HEAD was X; re-check before starting") rather than as bare assertions: the reader cannot tell a stale fact from a current one, and a confidently wrong base commit costs more than an admitted uncertainty.

## Flow

### 1. Pick a slug

2-4 kebab-case words describing the current task. Examples: `phone-ssh-shortcuts`, `statusline-color-tier`, `auth-middleware-refactor`. Infer from the conversation topic, the most-edited file, or the top open todo.

### 2. Compose the ID, repo slug, and path

- **ID**: `YYYY-MM-DD-HHMM__<slug>` (no extension). Use the user's local time. The minute is not a unique key -- two parallel sessions handing off in the same minute share a prefix, which has happened -- so the slug must identify the work on its own. A full ID always resolves; a date-prefix lookup will make the user choose between them.
- **Repo slug**: take the repo identity path from Gather and replace every `:`, `\`, `/`, and `.` with `-`. Examples:
  - normal layout: git-common-dir is `/home/user/work/api/.git`, so the identity path is `/home/user/work/api` and the slug is `-home-user-work-api`
  - bare+worktree layout: git-common-dir is `/home/user/work/api/.bare` from **any** worktree, so every worktree of that repo yields the same slug `-home-user-work-api`
  - `D:\ws\github\dotfiles` becomes `D--ws-github-dotfiles`
  - `\\wsl.localhost\Ubuntu\home\me\proj` becomes `--wsl-localhost-Ubuntu-home-me-proj`

  Use `git-common-dir`, **not** `git rev-parse --show-toplevel`. Under bare+worktree the latter returns the current worktree path, so handoffs written from different worktrees of one repo land in different directories and become invisible to each other. This slug rule is the same one Claude auto-memory uses for `~/.agent/memory/<id>/`, so both systems agree on what "the same repo" means.
- **Path**: `~/.agent/handoffs/<repo-slug>/<ID>.md`. Create the directory if missing.

**Handing off to a different repo.** Working in repo A and finding something that belongs to repo B is normal, and the handoff belongs in B's directory. This only happens when the user names the target -- `--repo <path>` in the wrapper, or plainly saying so in the args. The target is always a path: if the user gives a bare repo name, ask which path they mean rather than searching for it.

- Resolve the target's identity path with `git -C <target> rev-parse --path-format=absolute --git-common-dir`, minus its last component, then apply the same slug rule as above. `--path-format=absolute` is not optional here: plain `--git-common-dir` prints a path relative to **your** cwd, not the target's, so dropping it silently produces the current repo's slug and files the handoff where nobody will look for it. If the path does not exist or is not a git repo, stop and report it -- do not fall back to the current repo or guess another location.
- Do **not** consult `~/.agent/workflow-registry.md` for this. It is a per-machine, partially populated file whose path column mixes several unrelated conventions; deriving the slug from git directly is both authoritative and complete.
- If the work clearly belongs to another repo but the user did not say so, you may **ask**. Until they answer, the target stays the current repo.

### 2b. Cross-repo header

When the target is not the current repo, the reader needs to know which repo each field describes -- `- Branch:` records the *source* branch, which is meaningless to whoever picks this up in the target. Replace **both** the `- Repo / cwd:` and `- Branch:` lines of the template below with these two, leaving no unqualified branch line behind:

```markdown
- Target repo: <absolute path of the repo this handoff is for>
- Written from: <absolute path> (branch: <branch>) -- source context only
```

The resume line at the foot of the file needs the same qualifier. `/pickup <ID>` resolves against the slug of whatever repo the next session happens to open in, so a bare resume line on a cross-repo handoff points the reader at a directory that does not hold the file -- and the session that follows it is, by definition, the one sitting in the wrong repo. Write the line as `cd <target repo absolute path> && {{ .n.cli }} "/pickup <ID> in <lang>"`, and report that same line to the user in step 5. Same-repo handoffs keep the short form.

### 2c. Classify the kind

Every handoff declares which of two kinds it is. The kind decides its lifecycle, and it is a declaration by the session writing the file -- never an inference from the filename by whoever reads it later.

- **`succession`** -- the same line of work continues; you are handing off because this session's context ran out, not because the work changed. Set `supersedes:` to the ID of the handoff this session was picked up from.
- **`task`** -- a distinct piece of outstanding work. Anything not resumed from a prior handoff is `task`. So is work that started from one but has since changed subject: the predecessor's next steps are still owed by somebody, and calling that succession would retire them.

Derive it mechanically: if this session started with `/pickup <ID>` **and** the next steps you are about to write continue that file's next steps, it is `succession` with `supersedes: <ID>`. Otherwise it is `task` with no `supersedes`.

### 3. Compose the file

Use this shape. Non-ASCII (Chinese, em-dash, check marks) is fine -- this file is read, not pasted through a clipboard.

**The frontmatter and two sections are mandatory; every other section is optional and free-form.**

- The YAML frontmatter carries `handoff_kind` from step 2c. A file without it is read as `task` by every consumer, which is the safe reading: `task` is never archived automatically.

- `## Next steps` -- the only load-bearing section. `pickup` proceeds with the items under it; without it the next session opens a complete-looking file and finds nothing to do. Each item MUST carry a verifiable success criterion, because `pickup`'s closing step has to cite evidence per item before offering to archive the handoff. "Finish the refactor" is not a criterion; "grep returns no hits and `chezmoi diff` shows only the expected hunk" is.
- `## Suggested skills` -- skills the next session should invoke before starting. If there is nothing to suggest, write it as a plain sentence (`No skills needed.`), **never** as a bullet such as `- None`: a bullet is indistinguishable from a real entry and `pickup` will try to invoke it.

Omit the other sections rather than leaving placeholders.

```markdown
---
okf_version: "0.2"
handoff_kind: succession | task
supersedes: <predecessor ID, succession only -- omit the key entirely for task>
---

# Handoff: <slug> @ <ISO-8601 timestamp>

- Repo / cwd: <absolute path>
- Branch: <branch>  <worktree name if any>
- Tool: <Claude Code | Codex CLI | ...>

## Task

<one sentence: what we were doing, paused at what precise point>

## Next steps

1. <step + success criterion>
2. <step>
3. <step>

## Key files (open these first)

- <absolute path> -- <one-line why it matters>
- <absolute path> -- <...>

## Suggested skills

- `<skill name>` -- <why this skill applies to the next steps>
- `<skill name>` -- <...>

## References (do NOT re-read; just know they exist)

- <PRD / plan / ADR / issue URL> -- <relevance>
- <memory file absolute path> -- <relevance>
- Recent commits: <`git log -3 --oneline` output>
- This session diff: <`git diff --shortstat` output>

## Decisions made this session (load-bearing only)

- <decision + 1-line rationale>

## Open / unresolved

- <if any>

---

To resume in any future session (Claude Code or Codex CLI), run:

    /pickup <ID> in <session language>
```

The resume line carries the session language so the next session continues in it without being told: a `zh-tw` session writes `/pickup <ID> in zh-tw`, a `ja` session writes `in ja`. An English session writes plain `/pickup <ID>` with no suffix.

### 4. Self-check before writing

Verify all four, and fix before writing -- never write a file that fails any of them:

1. `## Next steps` exists and is non-empty.
2. Every item under it carries a verifiable success criterion.
3. `## Suggested skills` exists, and if it has no entries it is a plain sentence rather than a `- None` bullet.
4. `handoff_kind` is present, and `supersedes` is present if and only if the kind is `succession`. A `succession` with no predecessor archives nothing and reads as a claim about a file that does not exist.
5. Nothing in the body is the only copy of a decision, a recurring principle, or an inventory. Each of those went to its home from Principles above and is cited here by absolute path.
6. The volatile facts are re-read rather than remembered. Re-run `git rev-parse --short HEAD`, `ls` the target handoff directory, and `git worktree list`, then reconcile the draft against what they now say. On 2026-08-20 a handoff was picked up naming a base commit two merges stale, and while its successor was being drafted a parallel session archived one of the files that draft cited.

These failures are silent: the file gets written, `pickup` finds it, it reads as complete, and only the session that picks it up discovers there is nothing actionable -- or acts on a fact that expired before the file was saved -- by which point the original context is gone.

### 4b. Retire the predecessor (succession only)

After the new file is on disk -- never before -- `mv` the file named by `supersedes` into `~/.agent/handoffs/<repo-slug>/archive/<ID>.md`, creating the directory if missing. Do not ask; the kind you declared in step 2c is the decision.

Order matters and is the whole point of doing this here rather than in `pickup`. The successor exists before the predecessor leaves the list, so the work is never absent from `~/.agent/handoffs/<repo-slug>/` -- not for one command, not if the session dies in between. Archiving at pickup time would open exactly that window.

Three constraints:

- It is a `mv`, never an `rm`. A wrong call costs one `mv` to undo, and `~/.agent/` has no version control to undo it any other way.
- Archive **only** the file named in `supersedes`. Same-slug neighbours are not yours to touch, however obviously superseded they look.
- The destination is the directory the predecessor was **resolved from**, which for a cross-repo pickup is not the current repo's slug.

If the `supersedes` file is not where you expect -- already archived, renamed, never existed -- say so and leave it. The new handoff stands on its own either way.

### 5. Report to the user

Print, concisely:

1. Absolute path of the handoff file just written.
2. The exact resume line the user can copy -- identical to the one in the file, language suffix included.
3. For a `succession`, the predecessor you archived and where it went. It left the todo list on your say-so; that has to be visible in the same breath, not discoverable later.

Do not re-print the file content -- it is on disk.

## Anti-patterns

- **Don't** duplicate content from project docs. Link with absolute path + one-line "why it matters".
- **Don't** dump the entire todo list. Keep the 2-3 items that matter for resumption.
- **Don't** list every file touched. Only files the next session must open immediately.
- **Don't** include commit SHAs or diff hunks inline -- `git log` / `git diff` are authoritative.
- **Don't** ask clarifying questions before writing. Infer from conversation; if genuinely blocked, pick a reasonable slug and note the ambiguity in "Open / unresolved".
- **Don't** write a "Resumption Prompt" section -- the file itself is the resumption artifact and `/pickup` reads it.
- **Don't** mark a handoff `succession` because the slug matches, the topic feels continuous, or the directory is cluttered. The test is narrow: this session was picked up from that file and is still doing what that file asked.
- **Don't** leave an inventory (endpoint tables, dependency maps, batch plans) sitting in a `succession` handoff to be cited by its post-archive path. That trick works for a `task`, which is archived once with a human present; a `succession` is archived every round, and one round forgetting the citation loses it silently. Give it a real home first.
- **Don't** write inside any tool-specific dotdir (`.claude/`, `.codex/`, etc.). The handoff must be tool-agnostic so any AI tool can pick it up.
