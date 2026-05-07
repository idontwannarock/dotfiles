## Purpose

Capture the minimum state needed for a new session to continue the current work without re-exploring. Two outputs:
1. A markdown file at `<repo>/.claude/handoffs/<timestamp>__<slug>.md`
2. A resumption prompt -- copied to the user's clipboard and printed in the response -- designed to be pasted verbatim to boot the next session

The handoff directory is named `.claude/handoffs/` for historical reasons; any AI tool can write and read there -- it is not Claude-exclusive.

## Principles

- **ASCII-only output.** The handoff file body and resumption prompt MUST contain only ASCII characters (code points 0x20-0x7E plus newline). Clipboard tools on Windows (`clip.exe`) use the system ANSI codepage and corrupt UTF-8, producing mojibake when the prompt is pasted into a new session. Substitute em dashes and en dashes with `--` or `-`, math operators with their ASCII equivalents (e.g. less-than-or-equal becomes `<=`), and check marks with plain `OK`/`FAIL`. Transliterate or translate non-ASCII proper nouns. Paths are exempt in practice (paths on this system are ASCII), but if a path contains non-ASCII, describe it in English rather than embedding it.
- **References over duplication.** Link to project docs (CLAUDE.md, AGENTS.md, memory files, openspec changes, READMEs) instead of re-summarizing them.
- **Resumption prompt is the primary artifact.** The surrounding markdown is context for humans browsing later; the prompt is what boots the next session.
- **Lean.** Target <= 60 lines total. If it reads like a report, cut it.
- **No confirmation.** The user invoked you -- just do it.

## Gather

Run these before composing:

- `git rev-parse --show-toplevel` -- repo root (absolute)
- `git rev-parse --abbrev-ref HEAD` -- current branch
- `git status --porcelain` -- dirty files
- `git diff --shortstat` -- change magnitude
- `git log -3 --oneline` -- recent commits
- Current task/todo list snapshot (if any is active)
- What was being worked on in the last 2-3 turns

## Flow

### 1. Pick a slug

2-4 kebab-case words describing the current task. Examples: `handoff-skill-design`, `statusline-color-tier`, `auth-middleware-refactor`. Infer from the conversation topic, the most-edited file, or the top open todo.

### 2. Compose the handoff file

Write to `<repo>/.claude/handoffs/YYYY-MM-DD-HHMM__<slug>.md` using this exact shape. Omit empty sections rather than leaving placeholders.

```markdown
# Handoff: <slug> @ <ISO-8601 timestamp>

- Repo / cwd: <absolute path>
- Branch: <branch>  <worktree name if any>
- Tool: <your tool name, e.g. Claude Code, Codex CLI>

## Resumption Prompt (copy this into the new session)

We were working in `<absolute repo path>` on <one-sentence task description>, paused at <precise pause point>.

Key files:
- <absolute path> -- <one-line "why it matters">
- <absolute path> -- <...>

Next steps:
1. <step + success criterion>
2. <step>
3. <step>

References:
- <project doc path> -- <why>
- Files modified this session: <paste `git diff --shortstat` output>

Please continue from the next steps above. Do not re-summarize or confirm -- just proceed. Respond in zh-TW from now on (the user writes in Traditional Chinese).

## Decisions made this session (load-bearing only)

- <decision + 1-line rationale>

## Open / unresolved

- <if any>
```

### 3. Copy the Resumption Prompt to clipboard

Extract everything between `## Resumption Prompt ...` and the next `##` header, then pipe it to the first available clipboard tool:

```bash
if command -v clip.exe >/dev/null 2>&1; then copy=clip.exe                   # WSL / Git Bash
elif [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null 2>&1; then copy=wl-copy
elif command -v xclip >/dev/null 2>&1; then copy='xclip -selection clipboard'
elif command -v xsel >/dev/null 2>&1; then copy='xsel --clipboard --input'
elif command -v pbcopy >/dev/null 2>&1; then copy=pbcopy                     # macOS
else copy=''
fi
```

If no clipboard tool is available, skip silently -- the printed output is the fallback.

### 4. Ensure .gitignore covers the handoff dir

Check `<repo>/.gitignore` for any pattern that excludes `.claude/handoffs/` (e.g. `.claude/`, `.claude/handoffs/`, `.claude/handoffs/*`). If none match, append `.claude/handoffs/` on a new line.

### 5. Report to the user

Print, concisely:
1. Absolute path of the handoff file just written
2. Whether the clipboard copy succeeded (OK / FAIL)
3. The full Resumption Prompt inline, so the user can copy from the chat if the clipboard step failed

## Anti-patterns

- **Don't** duplicate content from project docs. Link with absolute path + one-line "why it matters".
- **Don't** dump the entire todo list. Keep the 2-3 items that matter for resumption.
- **Don't** list every file touched. Only files the next session must open immediately.
- **Don't** include commit SHAs or diff hunks inline -- they rot; `git log` / `git diff` are authoritative.
- **Don't** ask clarifying questions before writing. Infer from conversation; if genuinely blocked, pick a reasonable slug and note the ambiguity in "Open / unresolved".
- **Don't** restate what the file already contains at the end of your reply. Link + clipboard status + prompt inline is enough.
