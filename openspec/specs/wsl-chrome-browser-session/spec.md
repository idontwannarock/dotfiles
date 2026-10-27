# WSL Chrome Browser Session Specification

## Purpose

Define safe connection setup, driver selection, verification, and teardown for an authenticated Windows Chrome used from WSL.
## Requirements
### Requirement: Separate connection setup from driver selection

The skill SHALL use `playwright-cli` attached over CDP as the default browser driver. It SHALL NOT start a new profile to control the browser. It SHALL select and confirm the intended tab before it reads or acts. It SHALL end control with `detach` and SHALL NOT close, kill, or clear data of the attached browser.

#### Scenario: Authenticated Windows Chrome is already running
- **WHEN** `playwright-cli` can attach to the intended Chrome endpoint
- **THEN** the agent reuses that session rather than launching an empty headless profile

#### Scenario: Task ends
- **WHEN** the agent no longer needs browser control
- **THEN** it runs `detach` and leaves Chrome and its login intact

### Requirement: Diagnose execution boundaries separately

The skill SHALL distinguish Windows browser availability, ordinary WSL connectivity, agent-shell restrictions, and `playwright-cli` connectivity.

#### Scenario: Agent shell is restricted
- **WHEN** the agent shell reports a permission error but the user's WSL terminal reaches Chrome
- **THEN** the agent does not diagnose a broken WSL installation, reset the browser, or bypass restrictions
- **AND** it reports that `playwright-cli` cannot work from that shell

### Requirement: Scope MCP evaluation to the task project

The skill SHALL use a browser MCP only when the agent shell cannot reach Chrome and the user agrees. That MCP SHALL be project-scoped and SHALL be removed when the task ends.

#### Scenario: Evaluation fails
- **WHEN** a newly configured MCP is unsuitable or the user abandons evaluation
- **THEN** the agent removes only the settings introduced for that evaluation and preserves unrelated settings and shared package caches

### Requirement: Inspect before changing network exposure

The skill SHALL keep the CDP port on the loopback address of the machine that runs Chrome, and SHALL run `playwright-cli` on that machine. It SHALL NOT forward the port, add a firewall rule for it, or bind it to `0.0.0.0`. Removing leftovers of the old forwarding setup SHALL require the user's confirmation that no other session uses them.

#### Scenario: Agent runs in WSL and Chrome runs on Windows
- **WHEN** the agent needs to control the Windows Chrome
- **THEN** it runs the Windows `playwright-cli` from WSL and attaches to Windows `localhost`
- **AND** it creates no portproxy entry and no firewall rule

#### Scenario: Leftover forward found
- **WHEN** the inspection shows a port 9222 forward or a `WSL-CDP-*` rule
- **THEN** the agent lists each entry and removes them only after the user confirms that nothing uses them

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

### Requirement: Keep environment-specific commands in references

The skill body SHALL contain only environment-independent steps. Commands that depend on the OS or environment SHALL live in `references/<environment>.md`. The skill SHALL list only verified environments and SHALL tell the agent to stop for any other one.

#### Scenario: Unverified environment
- **WHEN** the agent runs in an environment with no reference file
- **THEN** it stops and tells the user instead of guessing commands
