# Workflow — full 8-step procedure

Read this in full before executing step 1. The steps are ordered for a reason; don't reorder.

## Step 1 — Load conventions from project memory

Space coordinates (cloudId / spaceId / folder IDs / template IDs) are hardcoded in `SKILL.md` for `shoalteritbev` — no discovery needed.

But conventions vary per project, so read every `reference-*.md` and `feedback-*.md` in the project memory directory before doing anything else. Expected files:

- `feedback-confluence-title-prefix` — title format `[CATEGORY][Project] Subject`
- `feedback-confluence-page-uniqueness` — parenthetical disambiguation for duplicate names
- `feedback-doc-layering` — ARCH and RUNBOOK as separate pages
- `feedback-project-hub-update` — hub MUST be updated; not optional
- `reference-bev-projects` — project portfolio (Customer Chat / Support Chat / Cashback / etc.)
- `reference-<project>-docs` — per-project page ID registry from prior work in this space

If the project memory is missing these, the conventions still apply (they're the team's standing rules) — just be aware you don't have a per-project page-ID registry to consult yet.

## Step 2 — Classify the doc

Look at what the user wants to record. Categorize:

| Audience | Content type | Doc type |
|---|---|---|
| Developer / RD | Algorithm, data flow, code structure, Spring wiring, file paths | **ARCH** |
| Ops / PM | Change procedures, validation checklists, SOPs, contacts | **RUNBOOK** |
| Cross-team consumers | Endpoint specs, request/response schemas, error codes | **API spec** |
| Reference / how-it-works | Standalone explanations, FAQs | **KB** |

**Decision: PAIR or single?**

If the findings include BOTH technical content (how it works internally) AND operational content (how to maintain/change it), propose a PAIR — ARCH + RUNBOOK — via AskUserQuestion. Bundling them is the layering-violation failure mode.

Edge case: pure technical reference with no maintenance procedure → ARCH only. (If maintenance procedure later arises, the RUNBOOK can be added without restructuring the ARCH.)

## Step 3 — CQL collision search

Before suggesting a title, search the space for any conflicting page name. Confluence rejects duplicate page titles space-wide.

Use:
```
space = "<spaceKey>" AND (title ~ "<keyword1>" OR title ~ "<keyword2>" ...)
```

Pick keywords from the proposed subject (and translate Chinese ↔ English equivalents — search both). Examples:

```
space = "shoalteritbev" AND (title ~ "profanity" OR title ~ "sensitive" OR title ~ "mask")
```

If a same-name page exists:
- For PAGE-type collision → use `feedback-confluence-page-uniqueness` rule: append parenthetical category suffix to one of them, e.g. `Customer Chat (Runbooks)`.
- For NEW page proposed title collision → either pick a more specific subject, or add disambiguator.

Document the result before moving on.

## Step 4 — Confirm title and depth via AskUserQuestion

This is the LAST checkpoint before creating. Ask the user two questions in a single AskUserQuestion call:

1. **Title** — present 2-3 well-formed candidates following `[CATEGORY][Project] Subject` convention. Recommended option first, marked `(Recommended)`.
2. **Content depth** — typical options:
   - 完整版（含程式碼片段 + Mermaid 流程圖）
   - 中等版（架構說明 + 表格，不貼程式碼）
   - 精簡版（只放鏈式組成與檔案位置）

Do NOT skip this step. Even if you're confident, the user might prefer a different name or different depth.

For PAIR creation: ask depth ONCE; the ARCH and RUNBOOK have different structures but the user's depth preference applies to both proportionally.

## Step 5 — Create page(s)

For each page in the planned set (1 for single, 2 for ARCH+RUNBOOK pair):

1. Read the matching template from Confluence (template IDs from memory). Use it as the structural starting point.
2. Construct HTML body following `page-anatomy.md` §3 (ARCH) or §4 (RUNBOOK).
3. Call `mcp__atlassian__createConfluencePage` with:
   - `cloudId`, `spaceId` from memory
   - `parentId` from memory (the project sub-folder under the relevant category)
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

## Step 7 — Update project hub index (NON-SKIPPABLE)

This is the step that's easy to forget. Skipping it means the new docs are effectively invisible.

1. Read the project hub page (page ID from memory).
2. Identify the relevant section: "## Architecture", "## Runbooks (Operations)", "## APIs & Interfaces Spec", or "## Knowledge Base / Notes".
3. Add the new page(s) as nested bullets under the parent folder bullet (match existing indentation — usually 2-space).
4. Update via `mcp__atlassian__updateConfluencePage` with `contentFormat: "markdown"` (hubs are typically markdown-edited) and a clear `versionMessage`.

For ARCH+RUNBOOK pair: add BOTH entries (ARCH under Architecture section, RUNBOOK under Runbooks section).

After updating, re-read the hub to verify the entries are visible. Don't trust the update API silently — verify.

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
- [ ] Project hub now lists the new page(s) — open the hub URL and look
- [ ] Memory file written and `MEMORY.md` updated
- [ ] No `(待補)` placeholders in the new pages OR they're explicitly called out for follow-up

Report URLs of all new/updated pages to the user as part of the completion message.
