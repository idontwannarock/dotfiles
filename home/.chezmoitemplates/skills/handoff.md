## Purpose

Capture the minimum state needed for a new session to continue the current work without re-exploring. The output is a single markdown file at `~/.agent/handoffs/<repo-slug>/<id>.md` whose last block prints the exact `/pickup <id>` command to revive it from any future session.

The location is user-level and AI-agnostic on purpose: a handoff produced by Claude Code can be picked up by Codex CLI (or any other tool that follows this convention) without the file living inside a tool-specific dotdir.

## Principles

- **References over duplication.** Do not re-summarize content already captured in other artifacts -- PRDs, plans, ADRs, issues, commits, diffs, memory files, READMEs. List them by absolute path or URL with a one-line "why it matters". Re-summarizing wastes tokens both now (writing) and later (reading) when the next session could just open the source.
- **Lean.** Target <= 50 lines total. If it reads like a report, cut it.
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

## Flow

### 1. Pick a slug

2-4 kebab-case words describing the current task. Examples: `phone-ssh-shortcuts`, `statusline-color-tier`, `auth-middleware-refactor`. Infer from the conversation topic, the most-edited file, or the top open todo.

### 2. Compose the ID, repo slug, and path

- **ID**: `YYYY-MM-DD-HHMM__<slug>` (no extension). Use the user's local time.
- **Repo slug**: take the repo identity path from Gather and replace every `:`, `\`, `/`, and `.` with `-`. Examples:
  - normal layout: git-common-dir is `/home/user/work/api/.git`, so the identity path is `/home/user/work/api` and the slug is `-home-user-work-api`
  - bare+worktree layout: git-common-dir is `/home/user/work/api/.bare` from **any** worktree, so every worktree of that repo yields the same slug `-home-user-work-api`
  - `D:\ws\github\dotfiles` becomes `D--ws-github-dotfiles`
  - `\\wsl.localhost\Ubuntu\home\me\proj` becomes `--wsl-localhost-Ubuntu-home-me-proj`

  Use `git-common-dir`, **not** `git rev-parse --show-toplevel`. Under bare+worktree the latter returns the current worktree path, so handoffs written from different worktrees of one repo land in different directories and become invisible to each other. This slug rule is the same one Claude auto-memory uses for `~/.claude/memory/<id>/`, so both systems agree on what "the same repo" means.
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

### 3. Compose the file

Use this shape. Non-ASCII (Chinese, em-dash, check marks) is fine -- this file is read, not pasted through a clipboard.

**Two sections are mandatory; every other section is optional and free-form.**

- `## Next steps` -- the only load-bearing section. `pickup` proceeds with the items under it; without it the next session opens a complete-looking file and finds nothing to do. Each item MUST carry a verifiable success criterion, because `pickup`'s closing step has to cite evidence per item before offering to archive the handoff. "Finish the refactor" is not a criterion; "grep returns no hits and `chezmoi diff` shows only the expected hunk" is.
- `## Suggested skills` -- skills the next session should invoke before starting. If there is nothing to suggest, write it as a plain sentence (`No skills needed.`), **never** as a bullet such as `- None`: a bullet is indistinguishable from a real entry and `pickup` will try to invoke it.

Omit the other sections rather than leaving placeholders.

```markdown
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

Verify all three, and fix before writing -- never write a file that fails any of them:

1. `## Next steps` exists and is non-empty.
2. Every item under it carries a verifiable success criterion.
3. `## Suggested skills` exists, and if it has no entries it is a plain sentence rather than a `- None` bullet.

These failures are silent: the file gets written, `pickup` finds it, it reads as complete, and only the session that picks it up discovers there is nothing actionable -- by which point the original context is gone.

### 5. Report to the user

Print, concisely:

1. Absolute path of the handoff file just written.
2. The exact resume line the user can copy -- identical to the one in the file, language suffix included.

Do not re-print the file content -- it is on disk.

## Anti-patterns

- **Don't** duplicate content from project docs. Link with absolute path + one-line "why it matters".
- **Don't** dump the entire todo list. Keep the 2-3 items that matter for resumption.
- **Don't** list every file touched. Only files the next session must open immediately.
- **Don't** include commit SHAs or diff hunks inline -- `git log` / `git diff` are authoritative.
- **Don't** ask clarifying questions before writing. Infer from conversation; if genuinely blocked, pick a reasonable slug and note the ambiguity in "Open / unresolved".
- **Don't** write a "Resumption Prompt" section -- the file itself is the resumption artifact and `/pickup` reads it.
- **Don't** write inside any tool-specific dotdir (`.claude/`, `.codex/`, etc.). The handoff must be tool-agnostic so any AI tool can pick it up.
