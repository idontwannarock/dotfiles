# Workflow — full 8-step procedure

Read this in full before executing step 1. The steps are ordered for a reason; don't reorder.

## Step 1 — Load the conventions (+ any page-ID cache)

Space coordinates (cloudId / space key / spaceId / folder IDs / template IDs) live in `.local/space.md` next to `SKILL.md` — machine-local and untracked, because this skill ships in a public repo. Read it now. If it is missing, stop and ask the user for the space rather than guessing or inlining the values into a tracked file.

**The conventions themselves are bundled in this skill** — you don't read memory to learn them:

- Title grammar `[TYPE][Project] Subject` + closed vocab + ARCH/KB/Hub rule → `references/doc-taxonomy.md`
- ARCH/RUNBOOK split, cross-link pattern, section anatomy → `references/page-anatomy.md`
- Page uniqueness + hub-update-is-mandatory → this file, steps 3 & 7

What memory (if present) adds is only a **per-project page-ID cache and any project overrides** from prior work — a convenience, not a prerequisite. Read every `reference-*.md` / `feedback-*.md` in the project memory directory if it exists; expected files:

- `reference-bev-projects` — the team's project portfolio
- `reference-<project>-docs` — per-project page ID registry from prior work in this space
- `feedback-*` — any project-specific override to the bundled conventions

If memory is missing or empty, proceed anyway: the conventions above still apply, and any page ID you'd have cached is discoverable at runtime via CQL (step 3).

## Step 2 — Classify the doc

**Canonical rule: `references/doc-taxonomy.md`** — the 2-question decision rule (content vs index; project-specific vs general) and the closed type vocabulary. The table below is a quick audience-based shortcut; when it's ambiguous, the two litmus questions in doc-taxonomy.md decide.

Look at what the user wants to record. Categorize:

| Audience | Content type | Doc type |
|---|---|---|
| Developer / RD | Algorithm, data flow, code structure, Spring wiring, file paths | **ARCH** |
| Ops / PM | Change procedures, validation checklists, SOPs, contacts | **RUNBOOK** |
| Cross-team consumers | Endpoint specs, request/response schemas, error codes | **API spec** |
| Reference / how-it-works | Standalone explanations, FAQs | **KB** |

**Decision: PAIR or single?**

If the findings include BOTH technical content (how it works internally) AND operational content (how to maintain/change it), propose a PAIR — ARCH + RUNBOOK — via AskUserQuestion. Bundling them is the layering-violation failure mode.

**General KB routes to a different index.** A `[KB]` that passes the KB litmus (reusable by any team, names no single project) is always a single page, and its step-7 index target is the **KB index page** (ID in `.local/space.md`) — not a project hub. Decide this here, at classify time, so step 7 doesn't get skipped for want of a hub. A project-specific KB (title carries the project, or the knowledge only holds for that service) stays with its project hub.

Edge case: pure technical reference with no maintenance procedure → ARCH only. (If maintenance procedure later arises, the RUNBOOK can be added without restructuring the ARCH.)

## Step 3 — CQL collision search

Before suggesting a title, search the space for any conflicting page name. Confluence rejects duplicate page titles space-wide.

Use:
```
space = "<spaceKey>" AND (title ~ "<keyword1>" OR title ~ "<keyword2>" ...)
```

Pick keywords from the proposed subject (and translate Chinese ↔ English equivalents — search both). Examples:

```
space = "<key from .local/space.md>" AND (title ~ "profanity" OR title ~ "sensitive" OR title ~ "mask")
```

If a same-name page exists:
- For PAGE-type collision → prefer making one title more specific under the `[TYPE][Project] Subject` grammar; the prefix normally resolves the clash on its own. The old workaround of appending a parenthetical category suffix (`<Project> (Runbooks)`) is deprecated — see `doc-taxonomy.md`.
- For NEW page proposed title collision → either pick a more specific subject, or add disambiguator.

Document the result before moving on.

## Step 4 — Confirm title and depth via AskUserQuestion

This is the LAST checkpoint before creating. Ask the user two questions in a single AskUserQuestion call:

1. **Title** — present 2-3 well-formed candidates following the `[TYPE][Project] Subject` grammar in `doc-taxonomy.md`: TYPE is ALL-CAPS from the closed vocabulary; `[Project]` is included for project-scoped types and OMITTED for general types (KB/GUIDELINE/SCHEDULE); Subject in zh-tw with English technical terms. Recommended option first, marked `(Recommended)`.
2. **Content depth** — typical options:
   - 完整版（含程式碼片段 + Mermaid 流程圖）
   - 中等版（架構說明 + 表格，不貼程式碼）
   - 精簡版（只放鏈式組成與檔案位置）

Do NOT skip this step. Even if you're confident, the user might prefer a different name or different depth.

For PAIR creation: ask depth ONCE; the ARCH and RUNBOOK have different structures but the user's depth preference applies to both proportionally.

## Step 5 — Create page(s)

For each page in the planned set (1 for single, 2 for ARCH+RUNBOOK pair):

1. Read the matching template from Confluence (template IDs are in `.local/space.md`; the space-wide templates under folder 99 apply to every project). Use it as the structural starting point.
2. Construct HTML body following `page-anatomy.md` §3 (ARCH) or §4 (RUNBOOK).
3. Call `mcp__atlassian__createConfluencePage` with:
   - `cloudId`, `spaceId` from `.local/space.md`
   - `parentId` — the project's container under the relevant category; from the cache in `.local/space.md` if listed, else the `reference-<project>-docs` memory, else CQL discovery (step 3). If a cached ID 404s or resolves to an unexpected title, re-resolve by title and correct `.local/space.md`.
   - `title` from step 4
   - `contentFormat: "html"`
   - `body` — the constructed HTML
4. Capture the returned page ID.

Create ARCH FIRST, then RUNBOOK — that way the RUNBOOK can link to the ARCH from the start (only ARCH needs a v2 update to add the RUNBOOK link, instead of both needing updates).

## Step 6 — Cross-link the pair (if pair)

If you created only one page → skip to step 7.

If you created ARCH + RUNBOOK (pair):

1. RUNBOOK already has a top info panel pointing to ARCH (constructed in step 5).
2. Update the ARCH page (v2) to add a top info panel pointing to RUNBOOK. Use `mcp__atlassian__updateConfluencePage` with `versionMessage: "Add cross-link to <RUNBOOK title>"`.
3. Verify both panels exist by re-reading both pages.

The cross-link pattern (per `feedback-doc-layering`):
- ARCH page top panel: "**How to maintain:** see [RUNBOOK ...]"
- RUNBOOK page top panel: "**Technical principles:** see [ARCH ...]"

## Step 7 — Update the index: project hub OR KB index (NON-SKIPPABLE)

This is the step that's easy to forget. Skipping it means the new docs are effectively invisible.

**Which index?** Every page created lands in exactly one of these — there is no "no index applies" case:

| Doc | Index target |
|---|---|
| Project doc (ARCH / RUNBOOK / API / DESIGN / POC / REPORT / ROADMAP / POSTMORTEM) or **project-specific KB** | That project's hub (folder 07) → §7a |
| **General `[KB]`** (passes the KB litmus, names no single project) | KB index page (ID in `.local/space.md`) (folder 08) → §7b |

Both branches are equally non-skippable. A general KB with no project hub is NOT an excuse to skip — it has an index, just a different one.

### §7a — Project hub

1. Read the project hub page (page ID from the cache in `.local/space.md`, else memory, else CQL from step 3).
2. Identify the relevant section by the doc's TYPE (see `doc-taxonomy.md`):
   - `[ARCH]` / `[DESIGN]` → "## Architecture"
   - `[RUNBOOK]` → "## Runbooks (Operations)"
   - `[API]` → "## APIs & Interfaces Spec"
   - `[KB]` **that is project-specific** → "## Knowledge Base / Notes" (general KB does not come here — see §7b)
   - `[REPORT]` / `[POC]` / `[ROADMAP]` / `[POSTMORTEM]` → the project's working-records section (e.g. "## Reports & Records", "## Roadmap", "## Incidents"); if the hub has no matching section yet, **add one** rather than dropping the entry.
3. Add the new page(s) as nested bullets under the parent folder bullet (match existing indentation — usually 2-space).
4. Update via `mcp__atlassian__updateConfluencePage` with `contentFormat: "markdown"` (hubs are typically markdown-edited) and a clear `versionMessage`.

For ARCH+RUNBOOK pair: add BOTH entries (ARCH under Architecture section, RUNBOOK under Runbooks section).

### §7b — KB index page (general KB)

1. Read the KB index page (ID in `.local/space.md`) (`🧠 Knowledge Base 索引`).
2. Find the `<h2>` matching the page's `[Topic]` bracket — the bracket IS the grouping key (see `doc-taxonomy.md`). `[KB][LiveKit] ICE/STUN 機制` goes under the `LiveKit` `<h2>`.
3. If no `<h2>` for that `[Topic]` exists yet, **add one** — don't drop the entry into an unrelated section, and don't skip.
4. Add the page as a link bullet under that `<h2>`. Layout per `page-anatomy.md` §9.
5. Update via `mcp__atlassian__updateConfluencePage` with a clear `versionMessage`.

After updating — either branch — re-read the index page to verify the entries are visible. Don't trust the update API silently — verify.

## Step 8 — Record in memory

Create a `reference-<topic>-doc.md` memory file capturing:

- Page title(s)
- Page ID(s)
- URL(s)
- Parent folder for each
- Brief subsystem description (what the doc covers, what it doesn't)
- Any non-obvious facts learned during research that aren't in the doc itself
- Pending TODOs left in the docs (e.g. owner names still `(待補)`)
- `Related:` links to other relevant memories using `[[name]]` syntax

Add a one-line entry to `MEMORY.md` index.

If during this session you uncovered a NEW convention or NEW failure mode worth preserving (not just a one-off page reference) → also create a `feedback-*.md` memory. Example: the existence of `feedback-project-hub-update.md` exists because Howard caught the assistant skipping step 7 once.

## Verification before declaring done

Before reporting completion, verify:

- [ ] Each created page is reachable via its URL
- [ ] Cross-links between ARCH and RUNBOOK both render correctly (if pair)
- [ ] The index now lists the new page(s) — open the project hub URL (or, for general KB, the KB index page (ID in `.local/space.md`)) and look
- [ ] Memory file written and `MEMORY.md` updated
- [ ] No `(待補)` placeholders in the new pages OR they're explicitly called out for follow-up

Report URLs of all new/updated pages to the user as part of the completion message.
