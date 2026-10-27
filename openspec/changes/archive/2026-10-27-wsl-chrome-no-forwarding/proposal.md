## Why

The CDP port has no password. The old setup forwarded it from Windows into WSL with a portproxy and a firewall rule. Every program that reached the forward could use the logins in that Chrome. Earlier versions opened it to the whole network.

## What Changes

- Run the Windows `playwright-cli` from WSL through `node.exe`. It reaches Chrome on Windows loopback, so no forward, firewall rule, or UAC is needed.
- Move OS- and environment-specific commands into `references/<environment>.md`. The skill body keeps only environment-independent steps. Only `references/wsl.md` exists, because only that environment is verified.
- Launch Chrome with three flags that stop background throttling. Without them, `click` on a background window times out.
- Keep the cleanup of the old forwards and rules in the WSL reference.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `wsl-chrome-browser-session`: Replace forwarding with a loopback-only CDP port, and put environment-specific commands in reference files.

## Impact

Shared skill body, a new shared reference with two wrappers, both skill descriptions, and the Claude and Codex guides.
