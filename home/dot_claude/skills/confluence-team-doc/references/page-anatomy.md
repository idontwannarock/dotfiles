# Page anatomy

Section-by-section structure for ARCH and RUNBOOK pages, plus the rationale for keeping them as separate pages.

## §1 — Why ARCH and RUNBOOK are separate

The two pages serve two audiences with disjoint reading paths:

| | ARCH | RUNBOOK |
|---|---|---|
| Audience | RD (developers) | PM / Ops / on-call |
| When opened | Onboarding new dev, designing a related feature, debugging | Adding/removing a config entry, handling an incident |
| Content | Algorithms, class diagrams, data flow, Spring wiring | When to change, who approves, validation checklist, contacts |
| Updated when | Code changes (refactor, new component) | Process changes (new approver, new env), incidents |

Bundling them means:
- PM/Ops scrolls past algorithm details to find the change procedure
- RD wades through approval flows to find class names
- The page becomes a graveyard of unrelated edits

Always split unless content is genuinely either pure-RD or pure-Ops with no counterpart.

## §2 — Cross-link pattern

Each page has an info panel at the top of the body pointing to its sibling:

**ARCH page top panel:**
```html
<div data-type="panel-info">
  <p><strong>Scope:</strong> ...</p>
  <p><strong>Status:</strong> <span data-type="status" data-color="green">Active</span></p>
  <p><strong>How to maintain (add/remove ...):</strong>
     see <a href="<RUNBOOK URL>">[RUNBOOK][Project] ...</a></p>
</div>
```

**RUNBOOK page top panel:**
```html
<div data-type="panel-info">
  <p><strong>Scope:</strong> ...</p>
  <p><strong>Status:</strong> <span data-type="status" data-color="green">Active</span></p>
  <p><strong>Owner:</strong> (待補)</p>
  <p>技術原理 ... 請見 <strong>01 - Architecture → <Project> → </strong>
     <a href="<ARCH URL>">[ARCH][Project] ...</a>。本頁聚焦在「要 X 時，該怎麼做」。</p>
</div>
```

Also include both as bullets in each page's "References" section at the bottom.

## §3 — ARCH page sections

Typical structure (adjust depth per user's choice in workflow step 4):

```
Top info panel (Scope / Status / Cross-link / Sibling docs)

1. Overview
   1.1 Goal — what the subsystem does in 2-3 sentences
   1.2 Related subsystems — what's adjacent and what this is NOT

2. Architecture
   2.1 High-level diagram (Mermaid flowchart preferred)
   2.2 Common abstraction / core interface
   2.3 Variants / strategies

3. Key Components
   3.x One subsection per major class/module with brief code snippet

4. Configuration / Wiring
   4.1 Composition root (Spring @Bean / DI / entrypoint)
   4.2 External inputs (config files, env vars, DB tables)
   4.3 Use-case integration points

5. Execution flow at runtime (Mermaid sequence diagram preferred)
   5.x Entry points and downstream calls

6. <Operational concerns>
   Brief description + pointer to RUNBOOK for procedures

7. Testing — test class paths, key test cases

8. Limitations & design notes — known gaps, intentional non-goals

9. File reference — table mapping file paths to roles

10. References — RUNBOOK link, sibling subsystems, external concepts
```

For lighter depth, collapse Key Components into a single table, remove sequence diagram, keep only the flowchart.

## §4 — RUNBOOK page sections

```
Top info panel (Scope / Status / Owner / Cross-link to ARCH)

1. 何時需要更新 / When to act
   Concrete triggers — "if X happens, follow this runbook"

2. Source of Truth
   Single authoritative location. If multiple sources exist, identify the master and mark others as mirrors.
   Use a `panel-warning` if multiple sources are temporarily out of sync.

3. 現行內容 / Current state
   Snapshot table with a date. Helps detect drift between docs and reality.

4. 變更流程 / Change procedure
   If multiple scenarios (per-env override vs full deploy), label them §4.1 / §4.2 with "適合：..." preamble.
   Number every step.

5. 驗證 Checklist / Validation
   Use Confluence task-list elements (interactive checkboxes).
   Include edge-case validations (regression for adjacent features).

6. 常見陷阱 / Common traps
   Concrete failure modes with examples.
   For features with conditional behavior (e.g. trailing slash, word-boundary differences), show before/after table.

7. 聯絡與升級流程 / Contacts & escalation
   Roles table. Mark unknowns as `(待補)` rather than guessing.

References — ARCH link, sibling RUNBOOKs, code paths
```

## §5 — Starting from Confluence templates

Confluence templates in the space provide a baseline structure. Locate them via the SKILL.md hardcoded coordinates table (e.g. `Template - Architecture documentation` page ID `5730042127`, `Template - Runbook` page ID `5731090541` in shoalteritbev).

Read the template page body, copy the structure, replace placeholders. Don't blindly preserve template comments or "fill me in" placeholders in the published page — they look unfinished.

## §6 — Mermaid in Confluence

Confluence Cloud renders `<pre><code class="language-mermaid">...</code></pre>` blocks as native Mermaid diagrams (the extension auto-converts). Use this for:

- ARCH §2.1 high-level flowcharts (`flowchart LR`)
- ARCH §5 execution sequences (`sequenceDiagram`)
- RUNBOOK rarely needs diagrams; if used, prefer a simple decision tree

Avoid raw images — they don't render in HTML format updates.

## §7 — Status lozenge colors

`<span data-type="status" data-color="<color>">Label</span>`:

| Color | When to use |
|---|---|
| `green` | Active / shipping in production |
| `blue` | Stable / in design / proposed |
| `yellow` | Beta / partially rolled out |
| `red` | Deprecated / known-broken |
| `purple` | Experimental |
| `neutral` | Archived / informational |

## §8 — Panel types

`<div data-type="panel-<type>">...</div>`:

| Type | Use for |
|---|---|
| `panel-info` | Top-of-page scope/status panel, cross-links, neutral context |
| `panel-warning` | "Watch out" — likely failure modes, gotchas |
| `panel-note` | Asides / supplementary explanations |
| `panel-success` | "Single source of truth" / confirmed facts |
| `panel-error` | Known broken behavior, do-not-do warnings |

Avoid stacking 3+ panels in a row — they lose visual emphasis.

## §9 — KB 索引頁 anatomy

The KB index page (`🧠 Knowledge Base 索引`, page ID `5922357414`) is the hub for general `[KB]`.
It is an **index, not content** — same rule as a project hub: delete it and no knowledge is lost.

```
Top panel-info — maintenance rules
  何時登記（每建一頁通用 KB）、[Topic] 為分組鍵、~5 頁升級子資料夾的門檻

<h2> per [Topic]        e.g. "LiveKit", "HTTP", "MySQL"
  - link bullet per page, one line each
  - a short trailing clause when the title alone doesn't say what's inside

<h2> 未分類 / 待整理  (trailing panel-note)
  Pages under folder 08 not yet classified or renamed to the grammar — the migration
  backlog, visible rather than silently lost.
```

Notes:
- One `<h2>` per `[Topic]` bracket, nothing else — the heading text matches the bracket verbatim
  so the mapping stays mechanical (workflow step 7b relies on this).
- Keep bullets to a link plus at most one clause. Anything longer belongs in the KB page itself.
- Don't create a `<h2>` speculatively; add it when the first page of that topic lands.
