---
name: confluence-team-doc
description: Use when the user asks to record technical findings, architecture/design notes, or operational procedures into the team Confluence space `shoalteritbev` — triggers include 「記錄到 Confluence」、「寫成文件」、「put this on the wiki」、「document this」、「建一個 ARCH 頁」、「建 RUNBOOK」, or any request to create/update pages in a Confluence space that hosts multiple sibling projects (Customer Chat / Support Chat / Cashback / etc.). Skip for code comments, README edits, in-line docs, repos with no associated team Confluence space, or trivial single-page notes that don't need cross-linking.
---

# Confluence Team Doc

Orchestrate Confluence page creation in the `shoalteritbev` team space — placement, title convention, ARCH/RUNBOOK split, cross-linking, project-hub indexing, and memory recording, in the correct order.

The canonical **document-classification and naming standard** (the closed type vocabulary, the ARCH/KB/Hub decision rule, the `[TYPE][Project] Subject` grammar) lives locally in `references/doc-taxonomy.md` — apply it directly, never fetch Confluence to look it up. Per-project page-ID registries and any project-specific overrides are stored as `reference-*` / `feedback-*` memory files. This skill orchestrates the **order of operations** that uses those conventions correctly — especially the step every fresh agent forgets: **updating the project hub index**.

## When to use

| Signal | Action |
|---|---|
| User asks to record/document findings to wiki/Confluence | **Use** |
| User asks 「建一個 ARCH 頁」/「建 RUNBOOK」/ create a page on team Confluence | **Use** |
| Recording related to `shoalteritbev` space (mms_chat_api, customer chat, support chat, cashback, etc.) | **Use** |
| Code comments / README / inline docs | Skip |
| Different Confluence space (not shoalteritbev) | Skip — this skill is hardcoded to shoalteritbev; generalize first |
| Single ad-hoc note, no naming convention, no hub | Skip |

## Hardcoded coordinates (`shoalteritbev`)

| Item | Value |
|---|---|
| `cloudId` | `3819c19c-0ec7-4434-a6d6-63c237693b8f` |
| `spaceId` | `5552898162` |
| `space key` | `shoalteritbev` |
| Homepage page ID | `5552898496` |

Folder taxonomy (under homepage, all `type=folder`):

| Page ID | Title |
|---|---|
| `5554667689` | 00 - 📌 Start Here |
| `5553913939` | 01 - 🏗 Architecture |
| `5554307156` | 02 - 📡 APIs & Interfaces Spec |
| `5553684539` | 03 - ⚙️ Runbooks (Operations) |
| `5554438238` | 04 - 🚨 Incident / Postmortem |
| `5553586309` | 05 - 📝 Meeting Notes |
| `5554536553` | 06 - 🛠 Admin Work |
| `5553717348` | 07 - 📂 Projects |
| `5552996508` | 08 - 🧠 Knowledge Base |
| `5554667686` | 09 - 👨‍💻 Onboarding |
| `5554405442` | 99 - 📄 Template |

Customer Chat sub-folders / hub / templates (currently the only fully-wired project):

| Page ID | Page |
|---|---|
| `5730795637` | Customer Chat (under 01 - Architecture) |
| `5731713084` | Customer Chat (Runbooks) (under 03 - Runbooks) |
| `5731549244` | Customer Chat (Project Hub) (under 07 - Projects) † |
| `5730042127` | Template - Architecture documentation (under 99 - Template) |
| `5731090541` | Template - Runbook (under 99 - Template) |
| `5732237314` | Template - Project hub (under 99 - Template) |

† Title uses the deprecated `<Name> (Project Hub)` suffix. Per `doc-taxonomy.md` the current grammar is `[PROJECT] <Name>` (e.g. `[PROJECT] Customer Chat`) — migrate when next touched.

For other projects (Support Chat / Cashback / etc.), confirm with user where to place; the sub-folder pattern may not yet exist.

## The orchestration

```
1. Read project memory       — load all reference-* and feedback-* files
2. Classify doc type         — apply doc-taxonomy.md (2-question rule + closed vocab); decide PAIR vs single
3. Search for collisions     — CQL against shoalteritbev (uniqueness rule)
4. Confirm with user         — title + content depth via AskUserQuestion
5. Create page(s)            — use template page (see table above) as starting structure
6. Cross-link the pair       — ARCH ↔ RUNBOOK info panels (if pair)
7. Update project hub index  — NON-SKIPPABLE. The recurring failure mode.
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
| Bundling ARCH+RUNBOOK into one page | Feels economical | Re-read `page-anatomy.md` §1 for the layering rationale; almost always two pages is correct. |
| Omitting the project on a project-scoped doc (`[ARCH] X`) | Works on single-project spaces, fails on team spaces | Project-scoped types (ARCH/API/RUNBOOK/DESIGN/POC/ROADMAP/REPORT/POSTMORTEM) MUST include project: `[ARCH][Customer Chat] X`. General types (KB/GUIDELINE/SCHEDULE) OMIT it — see doc-taxonomy.md. |
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
