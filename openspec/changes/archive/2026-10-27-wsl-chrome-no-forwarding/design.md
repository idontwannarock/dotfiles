## Context

WSL in NAT mode cannot reach the Windows loopback address. WSL can start Windows programs, and Windows `node.exe` receives each argument unchanged. Windows Node already exists, and the Windows npm installer already installs `@playwright/cli`.

## Decisions

- `pw` calls Windows `node.exe` with the CLI script directly, not through `cmd.exe` or `powershell.exe`, which parse arguments again.
- One `powershell.exe` call resolves `node.exe`, the CLI script, and `%TEMP%`. The working directory is `%TEMP%`, because `node.exe` started from a WSL path gets a UNC directory.
- WSL mirrored networking was rejected: it changes the network for all of WSL.

## Risks / Trade-offs

- [Any local Windows program can still reach the CDP port while Chrome runs] → Inherent to CDP. The skill tells the agent to stop Chrome by PID and to warn the user when it stays open.
- [The agent shell may be denied Windows programs] → Report it; the project-scoped MCP fallback stays.

## Validation

Extract each command block from the rendered reference and run it: define `pw`, attach, `tab-list`, `goto`, `--raw eval` with a same-origin `fetch`, `detach`, stop Chrome by PID, launch Chrome. Confirm no portproxy entry and no `WSL-CDP-*` rule.
