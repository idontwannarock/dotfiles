## MODIFIED Requirements

### Requirement: Separate connection setup from driver selection

The skill SHALL prefer authorized native browser MCP tools when available and retain `cdp.py` as a fallback that respects task restrictions. Before fallback, the agent SHALL confirm that the helper's fixed port 9222 matches the intended endpoint.

#### Scenario: Authenticated Windows Chrome is already running
- **WHEN** native MCP tools can attach to the intended Chrome session
- **THEN** the agent reuses that session rather than launching an empty headless profile or requiring `cdp.py`

#### Scenario: Intended endpoint uses a different port
- **WHEN** the intended Chrome endpoint is not on port 9222
- **THEN** the agent keeps an authorized MCP connection or reports the helper as unsuitable
- **AND** it does not run `cdp.py` against an unrelated 9222 endpoint

### Requirement: Scope MCP evaluation to the task project

The skill SHALL keep new MCP configuration project-scoped, start with page-reading and page-selection tools, and require successful page listing and a target-page snapshot before reporting readiness. It SHALL select the confirmed target ID before a snapshot, or pass that ID only when the loaded snapshot schema explicitly supports it.

#### Scenario: Evaluation fails
- **WHEN** a newly configured MCP is unsuitable or the user abandons evaluation
- **THEN** the agent removes only the settings introduced for that evaluation and preserves unrelated settings and shared package caches

#### Scenario: Target tab is not currently selected
- **WHEN** the browser has multiple tabs and the snapshot schema has no `pageId`
- **THEN** the agent selects the confirmed target with `select_page` before reading its snapshot
- **AND** it does not read the unrelated default-selected tab
