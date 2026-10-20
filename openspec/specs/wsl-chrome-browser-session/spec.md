# WSL Chrome Browser Session Specification

## Purpose

Define safe connection setup, driver selection, verification, and teardown for an authenticated Windows Chrome used from WSL.

## Requirements

### Requirement: Separate connection setup from driver selection

The skill SHALL prefer authorized native browser MCP tools when available and retain `cdp.py` as a fallback that respects task restrictions. Before fallback, the agent SHALL confirm that the helper's fixed port 9222 matches the intended endpoint.

#### Scenario: Authenticated Windows Chrome is already running
- **WHEN** native MCP tools can attach to the intended Chrome session
- **THEN** the agent reuses that session rather than launching an empty headless profile or requiring `cdp.py`

#### Scenario: Intended endpoint uses a different port
- **WHEN** the intended Chrome endpoint is not on port 9222
- **THEN** the agent keeps an authorized MCP connection or reports the helper as unsuitable
- **AND** it does not run `cdp.py` against an unrelated 9222 endpoint

### Requirement: Diagnose execution boundaries separately

The skill SHALL distinguish Windows browser availability, ordinary WSL connectivity, agent-shell restrictions, and native MCP connectivity.

#### Scenario: Agent shell is restricted
- **WHEN** the agent shell reports a permission error but the user's WSL terminal reaches Chrome
- **THEN** the agent does not diagnose a broken WSL installation, reset the browser, or bypass restrictions
- **AND** it verifies an authorized native MCP independently if one is available

### Requirement: Scope MCP evaluation to the task project

The skill SHALL keep new MCP configuration project-scoped, start with page-reading and page-selection tools, and require successful page listing and a target-page snapshot before reporting readiness. It SHALL select the confirmed target ID before a snapshot, or pass that ID only when the loaded snapshot schema explicitly supports it.

#### Scenario: Evaluation fails
- **WHEN** a newly configured MCP is unsuitable or the user abandons evaluation
- **THEN** the agent removes only the settings introduced for that evaluation and preserves unrelated settings and shared package caches

#### Scenario: Target tab is not currently selected
- **WHEN** the browser has multiple tabs and the snapshot schema has no `pageId`
- **THEN** the agent selects the confirmed target with `select_page` before reading its snapshot
- **AND** it does not read the unrelated default-selected tab

### Requirement: Inspect before changing network exposure

The skill SHALL inspect the current listener and forwarding state before proposing an elevated network change. New forwarding and firewall rules SHALL use the required interface and WSL source range rather than unrestricted defaults.

#### Scenario: Existing forwarding is usable
- **WHEN** the intended endpoint is already reachable
- **THEN** the agent reuses it without creating duplicate rules or restarting Chrome

### Requirement: Preserve session ownership during teardown

The skill SHALL treat browser shutdown, forwarding removal, and profile deletion as separate operations. It SHALL honor explicit leave-open requests and avoid interrupting other users of the session.

#### Scenario: Another task is still using Chrome
- **WHEN** the current task ends while another task uses the same session
- **THEN** the agent leaves the browser, profile, and required connection intact and reports what remains open

### Requirement: Keep deployed skill variants aligned

The Codex and Claude wrappers SHALL render the same shared operational guidance without unresolved template tokens.

#### Scenario: Shared body changes
- **WHEN** the shared skill body is updated
- **THEN** both rendered wrappers pass skill validation and retain equivalent operational rules
