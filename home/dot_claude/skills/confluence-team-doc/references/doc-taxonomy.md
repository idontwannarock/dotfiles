# Doc taxonomy & naming standard (canonical, local)

This file is the **authoritative** copy of the `shoalteritbev` document-classification and
naming standard. Apply it directly — do NOT fetch Confluence to look it up. The human-facing
mirror is the wiki page `📚 Team Confluence 使用指南` (page ID `5566693387`); when this file
changes, update that page too, but this file wins for tooling.

## Classification: ask two questions in order

**Q1 — Content, or just links?**
Only links / navigation → the project's **Project Hub** (folder 07). The hub explains nothing;
it is a table of contents. *Litmus: delete the hub — do you lose any knowledge? If yes, content
leaked in; move it to ARCH/KB.*

**Q2 — True only for this system, or reusable anywhere?**
- True only for *this* service (its structure, chosen values, file paths, wiring) → **ARCH**
  (folder 01). *Litmus: "would this sentence be false for a different service?" Yes → ARCH.*
- Reusable by any team regardless of our service (a mechanism, a technology's behaviour, a
  gotcha, a technique) → **KB** (folder 08). *Litmus: "would another team copy this verbatim
  without caring about our service?" Yes → KB.*

Two rules that stop drift:
- **Same topic often splits.** e.g. *how HTTP conditional caching + the Spring Security pitfall
  works* → KB; *service X uses `private, max-age=300` in class Y* → ARCH. They cross-link.
- **One fact, one home.** ARCH links to KB for the mechanism; the hub links to both; nobody
  re-explains. This is the whole defence against duplication/overlap.

## Naming grammar

```
[TYPE][Project] Subject
```

- **TYPE** — closed controlled vocabulary below, **ALL-CAPS**. To add a type, edit this file first.
- **[Project]** — product/project name. **Omit** when the doc is cross-project / general
  (general KB, team-wide GUIDELINE / SCHEDULE).
- **Subject** — zh-tw; keep technical terms in English.
- **Project Hub** — always `[PROJECT] <Name>` (e.g. `[PROJECT] Customer Chat`). The older
  `<Name> (Project Hub)` suffix is deprecated; migrate when touched.

## Controlled vocabulary (closed set)

| TYPE | Folder | Content/Index | Project-specific/General | Belongs here | Does NOT belong (goes to) |
|---|---|---|---|---|---|
| `[PROJECT]` | 07 | Index | Specific | A project's directory of all its docs, links only | Any explanatory content (→ARCH/KB) |
| `[ARCH]` | 01 | Content | Specific | How this system is built: structure, components, data flow, wiring, file paths, chosen values | General mechanism (→KB), procedures (→RUNBOOK) |
| `[API]` | 02 | Content | Specific (consumer-facing) | External contract: endpoints, req/res, error codes | Internal impl (→ARCH) |
| `[RUNBOOK]` | 03 | Content | Specific | How to operate/change: triggers, steps, validation, contacts | Principles (→ARCH/KB) |
| `[POSTMORTEM]` | 04 | Content | Specific | Incident root cause, timeline, impact, action items | Routine ops (→RUNBOOK), measurement runs (→REPORT) |
| `[REPORT]` | 07 | Content | Specific | Measurement record of a run (one or many): load test, benchmark, data-validation batch — results & findings | Incident root cause (→POSTMORTEM), option exploration (→POC) |
| `[DESIGN]` | 01/07 | Content | Specific | Decision record: why X was chosen, trade-offs, attack analysis — **snapshot, not updated** | Living current-state architecture (→ARCH) |
| `[POC]` | 07 | Content | Specific | Proof-of-concept exploration/experiment (may graduate to ARCH) | Shipped architecture (→ARCH) |
| `[ROADMAP]` | 07 | Content | Specific | Plans, milestones, measurement standards | — |
| `[KB]` | 08 | Content | **General** | Reusable by any team: mechanism, tech behaviour, gotcha, technique | Project-specific values/paths (→ARCH) |
| `[GUIDELINE]` | 00/06 | Content | General (team-wide) | Team operating conventions | Project rules (→that project's docs) |
| `[SCHEDULE]` | 06 | Content | General | Schedules | — |
| `Template` | 99 | Template | — | Blank templates per type | — |

Notes:
- **ARCH vs DESIGN** is the easiest confusion: DESIGN is a *decision snapshot* (why we chose it),
  frozen once written; ARCH is the *living* current-state doc, updated when code changes.
- **[REPORT]** records live in 07 as project working records; if a run yields a *reusable*
  conclusion, distil that into a `[KB]` and leave the record in 07.
