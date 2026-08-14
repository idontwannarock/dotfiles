---
name: confluence-team-doc
description: Use when the user asks to record technical findings, architecture/design notes, or operational procedures into the team Confluence space — triggers include 「記錄到 Confluence」、「寫成文件」、「put this on the wiki」、「document this」、「建一個 ARCH 頁」、「建 RUNBOOK」, or any request to create/update pages in a Confluence space that hosts several sibling projects under shared category folders. Skip for code comments, README edits, in-line docs, repos with no associated team Confluence space, or trivial single-page notes that don't need cross-linking.
---

# Confluence Team Doc

Orchestrate Confluence page creation in the team space — placement, title convention, ARCH/RUNBOOK split, cross-linking, project-hub indexing, and memory recording, in the correct order.

**Which space, and its page IDs, live in `.local/space.md` — a machine-local file that is deliberately not in version control** (this skill ships in a public dotfiles repo; site host, `cloudId`, space key and the folder map are internal topology). Read it first. If it is absent, this machine has not been configured: ask the user for the space, then write the file — never inline the coordinates back into this skill or its references.

The canonical **document-classification and naming standard** (the closed type vocabulary, the ARCH/KB/Hub decision rule, the `[TYPE][Project] Subject` grammar) lives locally in `references/doc-taxonomy.md` — apply it directly, never fetch Confluence to look it up. Per-project page-ID registries and any project-specific overrides are stored as `reference-*` / `feedback-*` memory files. This skill orchestrates the **order of operations** that uses those conventions correctly — especially the step every fresh agent forgets: **updating the index** (the project hub for project docs, the KB index page for general KB).

## When to use

| Signal | Action |
|---|---|
| User asks to record/document findings to wiki/Confluence | **Use** |
| User asks 「建一個 ARCH 頁」/「建 RUNBOOK」/ create a page on team Confluence | **Use** |
| Recording related to a project that already has a hub in the team space | **Use** |
| Code comments / README / inline docs | Skip |
| A Confluence space other than the one in `.local/space.md` | Skip — the conventions here assume that space's folder taxonomy |
| Single ad-hoc note, no naming convention, no hub | Skip |

## Space coordinates

Everything site-specific — `cloudId`, space key, `spaceId`, homepage ID, the 00–99 category folder
IDs, the KB index page, the template page IDs, and the cached per-project container IDs — lives in
**`.local/space.md`**, next to this file. Read it at step 1.

Why it is separate: this skill is published in a public dotfiles repo. The coordinates are a valid
tenant identifier plus a map of internal systems, so they stay machine-local and untracked
(`.chezmoiignore.tmpl` excludes the path, so `chezmoi add` on it is refused). Keep it that way —
if you find yourself pasting a page ID or the site host into this file or `references/*`, stop.

**Page IDs drift.** The cached container IDs are a convenience, not the source of truth: a single
reorganisation on 2026-08-11 invalidated four of them, and nothing warns you — a stale ID either
404s or, worse, resolves to a trashed page. Resolve by title with CQL whenever a lookup surprises
you, and write the corrected ID back to `.local/space.md`:

```
space = "<key from .local/space.md>" AND title = "[PROJECT] <Name>"
```

Most projects in the space already have a hub and category containers — search before assuming one
is absent. Only for a genuinely new project (no pages yet) confirm with the user where to place it
and create the container pattern.

## The orchestration

```
1. Load conventions          — read `.local/space.md` for coordinates + doc-taxonomy/page-anatomy/workflow for rules
2. Classify doc type         — apply doc-taxonomy.md (2-question rule + closed vocab); decide PAIR vs single
3. Search for collisions     — CQL against the space (uniqueness rule)
4. Confirm with user         — title + content depth via AskUserQuestion
5. Create page(s)            — use the template page from `.local/space.md` as starting structure
6. Cross-link the pair       — ARCH ↔ RUNBOOK info panels (if pair)
7. Update the index          — project hub OR KB index. NON-SKIPPABLE. The recurring failure mode.
8. Record in memory          — page IDs + URLs as a reference-* memory file
```

**Read `references/workflow.md` before executing step 1.** It contains the concrete CQL queries, AskUserQuestion templates, and verification checks for each step.

## Required reading by phase

| Phase | Read first |
|---|---|
| Steps 2 & 4 (classify + title) — closed type vocabulary, ARCH/KB/Hub decision rule, naming grammar | `references/doc-taxonomy.md` |
| Step 5 (page creation) — ARCH/RUNBOOK section structure & Confluence HTML quirks | `references/page-anatomy.md` |
| Steps 6-7 (cross-link + hub) — bidirectional and hub-update checklist | `references/workflow.md` §6-7 |

## Common mistakes

| Mistake | Why it happens | Fix |
|---|---|---|
| Forgetting to update project hub | Hub lives in a separate category folder; easy to miss after "page created" notification | Step 7 is non-skippable. Open the hub page and verify the new doc is listed before declaring done. |
| Creating a general `[KB]` without registering it on the KB index | Step 7 reads as "project hub", and a general KB has no project — so the step gets silently skipped | The KB index page (ID in `.local/space.md`) IS the hub for general KB. Add the link under the matching `[Topic]` `<h2>` (create the `<h2>` if absent), then re-read to verify. Not done until it's listed. |
| Bundling ARCH+RUNBOOK into one page | Feels economical | Re-read `page-anatomy.md` §1 for the layering rationale; almost always two pages is correct. |
| Omitting the project on a project-scoped sub-topic doc (`[ARCH] Profanity Filter`) | Works on single-project spaces, fails on team spaces | Project-scoped types (ARCH/API/RUNBOOK/DESIGN/POC/ROADMAP/REPORT/POSTMORTEM) MUST include project: `[ARCH][Order Service] Profanity Filter`. Exception: the project-level umbrella doc, where the subject IS the project (`[ARCH] Order Service`). General types (KB/GUIDELINE/SCHEDULE) OMIT project — see doc-taxonomy.md. |
| Inventing a prefix or mixing case (`[Postmortem]`, `[Report]`) | No canonical list in view | Vocabulary is closed & ALL-CAPS; pick from doc-taxonomy.md. Add a new type by editing that file first. |
| Creating page then discovering title collision | Skipped step 3 | Always CQL-search before AskUserQuestion. |
| Treating hub update as conditional ("if it exists") | Baseline agents phrase this defensively | Hub exists if memory says it exists. If memory says it exists, update it — full stop. |

## Red flags — STOP and re-orient

- "I'll skip the hub update, it's just an index" → **NO.** THE recurring failure mode. Update the hub.
- "User said one page, so I'll bundle ARCH+RUNBOOK" → If content has algorithm AND procedure, propose the split via AskUserQuestion.
- "I'll skip CQL search, the title looks unique" → Confluence enforces space-wide uniqueness. Always search.
- "I'll create the page first then add cross-links" → Order is fixed: create → cross-link → hub → memory. None optional.

## Prerequisites

Requires Atlassian MCP server (`mcp__atlassian__*` tools). If unavailable, stop and tell the user.
