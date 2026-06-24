## Purpose

Capture the minimum state needed for a new session to continue the current work without re-exploring. The output is a single markdown file at `~/.agent/handoffs/<repo-slug>/<id>.md` whose last block prints the exact `/pickup <id>` command to revive it from any future session.

The location is user-level and AI-agnostic on purpose: a handoff produced by Claude Code can be picked up by Codex CLI (or any other tool that follows this convention) without the file living inside a tool-specific dotdir.

## Principles

- **References over duplication.** Do not re-summarize content already captured in other artifacts -- PRDs, plans, ADRs, issues, commits, diffs, memory files, READMEs. List them by absolute path or URL with a one-line "why it matters". Re-summarizing wastes tokens both now (writing) and later (reading) when the next session could just open the source.
- **Lean.** Target <= 50 lines total. If it reads like a report, cut it.
- **Args-driven tailoring.** If the user passed arguments, treat them as the description of what the next session will focus on -- they override or refine the first item in "Next steps".
- **Redact secrets.** Replace API keys, passwords, TOTP codes, corp identifiers with placeholders. Note in "Open / unresolved" if redaction loses information the next session needs.
- **No confirmation.** The user invoked you -- just do it.

## Gather

Run these before composing:

- Repo root: `git rev-parse --show-toplevel` (if it fails OR the result is not a prefix of `$PWD`, fall back to `$PWD` -- a slug derived from a non-repo dir is fine; writing to the wrong repo is not).
- Branch: `git rev-parse --abbrev-ref HEAD` (skip if non-git).
- Dirty state: `git status --porcelain` and `git diff --shortstat`.
- Recent commits: `git log -3 --oneline`.
- Current task/todo list snapshot (if any is active).
- What was being worked on in the last 2-3 turns.

## Flow

### 1. Pick a slug

2-4 kebab-case words describing the current task. Examples: `phone-ssh-shortcuts`, `statusline-color-tier`, `auth-middleware-refactor`. Infer from the conversation topic, the most-edited file, or the top open todo.

### 2. Compose the ID, repo slug, and path

- **ID**: `YYYY-MM-DD-HHMM__<slug>` (no extension). Use the user's local time.
- **Repo slug**: the absolute repo path with every `:`, `\`, `/`, and `.` replaced by `-`. Examples:
  - `D:\ws\github\dotfiles` becomes `D--ws-github-dotfiles`
  - `/home/user/work/api` becomes `-home-user-work-api`
  - `\\wsl.localhost\Ubuntu\home\me\proj` becomes `--wsl-localhost-Ubuntu-home-me-proj`
  (This matches the existing convention used by `~/.claude/projects/<slug>/` so users can mentally align handoff and memory layouts.)
- **Path**: `~/.agent/handoffs/<repo-slug>/<ID>.md`. Create the directory if missing.

### 3. Compose the file

Use this shape. Omit empty sections rather than leaving placeholders. Non-ASCII (Chinese, em-dash, check marks) is fine -- this file is read, not pasted through a clipboard.

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

    /pickup <ID>
```

### 4. Report to the user

Print, concisely:

1. Absolute path of the handoff file just written.
2. The exact `/pickup <ID>` line the user can copy.

Do not re-print the file content -- it is on disk.

## Anti-patterns

- **Don't** duplicate content from project docs. Link with absolute path + one-line "why it matters".
- **Don't** dump the entire todo list. Keep the 2-3 items that matter for resumption.
- **Don't** list every file touched. Only files the next session must open immediately.
- **Don't** include commit SHAs or diff hunks inline -- `git log` / `git diff` are authoritative.
- **Don't** ask clarifying questions before writing. Infer from conversation; if genuinely blocked, pick a reasonable slug and note the ambiguity in "Open / unresolved".
- **Don't** write a "Resumption Prompt" section -- the file itself is the resumption artifact and `/pickup` reads it.
- **Don't** write inside any tool-specific dotdir (`.claude/`, `.codex/`, etc.). The handoff must be tool-agnostic so any AI tool can pick it up.
