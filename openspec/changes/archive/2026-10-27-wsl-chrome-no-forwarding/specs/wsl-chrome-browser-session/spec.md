## MODIFIED Requirements

### Requirement: Inspect before changing network exposure

The skill SHALL keep the CDP port on the loopback address of the machine that runs Chrome, and SHALL run `playwright-cli` on that machine. It SHALL NOT forward the port, add a firewall rule for it, or bind it to `0.0.0.0`. Removing leftovers of the old forwarding setup SHALL require the user's confirmation that no other session uses them.

#### Scenario: Agent runs in WSL and Chrome runs on Windows
- **WHEN** the agent needs to control the Windows Chrome
- **THEN** it runs the Windows `playwright-cli` from WSL and attaches to Windows `localhost`
- **AND** it creates no portproxy entry and no firewall rule

#### Scenario: Leftover forward found
- **WHEN** the inspection shows a port 9222 forward or a `WSL-CDP-*` rule
- **THEN** the agent lists each entry and removes them only after the user confirms that nothing uses them

## ADDED Requirements

### Requirement: Keep environment-specific commands in references

The skill body SHALL contain only environment-independent steps. Commands that depend on the OS or environment SHALL live in `references/<environment>.md`. The skill SHALL list only verified environments and SHALL tell the agent to stop for any other one.

#### Scenario: Unverified environment
- **WHEN** the agent runs in an environment with no reference file
- **THEN** it stops and tells the user instead of guessing commands
