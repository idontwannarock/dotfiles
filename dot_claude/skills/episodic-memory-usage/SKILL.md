---
name: episodic-memory-usage
description: Use whenever you are about to call any `episodic-memory` tool (`search`, `show`, `read`, or the `search-conversations` subagent) — including replies to "有沒有討論過 X", "之前聊過什麼", "找之前那個 conversation", or any request that benefits from past-conversation retrieval. Enforces the split between exploratory search (delegate to subagent to protect main context) and precise extraction (direct call allowed, but `show`/`read` must paginate).
---

# Episodic Memory Usage Rules

Rules for using the `episodic-memory` plugin without blowing up the main context.

## Decision Tree

| Intent | Tool | Why |
|--------|------|-----|
| Exploratory search (「有沒有討論過 X」) | `search-conversations` **subagent** | Offloads large result sets to subagent; only the digest returns to main context |
| Precise extraction (already know the conversation/section) | Direct `mcp__plugin_episodic-memory_episodic-memory__search` | Faster, but limit scope |
| Reading conversation content | `show` / `read` **with pagination** | Raw transcripts are huge |

## Hard Rules

- **Never** call `show` or `read` without `startLine` / `endLine`.
- **Single read ≤ 50 lines.** If you need more, page through — do not widen the window.
- If you do not yet know which lines matter, `search` first to locate the range, then page `show`/`read`.
- For open-ended "what did we talk about" questions, prefer the subagent even if you think the result is small — the subagent protects main context regardless of hit size.

## Example: Correct Flow

User: 「有沒有討論過 X 的設計？」
1. Dispatch `search-conversations` subagent with the topic — digest returns to main context.
2. If you need to quote the source, call `search` directly to locate the exact conversation + approximate line.
3. Then `show` with `startLine: 120, endLine: 160` (≤50 lines) to read the passage.

## Anti-Patterns

- Calling `show` on a full conversation to "just get the gist" — always paginate.
- Running multiple un-paginated `read` calls in a loop to reconstruct context — use `search` to narrow first.
- Using the direct tool for exploratory queries because it feels faster — the cost shows up as polluted context later.
