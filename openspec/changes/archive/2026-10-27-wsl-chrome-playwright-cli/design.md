## Context

`playwright-cli` 0.1.22 has `attach --cdp=<url>`, `tab-list`, `tab-select`, `goto`, `snapshot`, `click`, `fill`, `eval`, `screenshot`, and `detach`. `--raw` prints only the result. Snapshots are written to `./.playwright-cli/` in the current directory.

## Decisions

- Every command uses one named session, `-s=cdp`, so a script and the agent address the same attachment.
- Run from a temporary directory, so snapshot files do not land in a repository.
- End with `detach`. Forbid `close`, `close-all`, `kill-all`, `delete-data`, and the storage commands on the attached browser: the browser and its login belong to the user.
- Write a script only for a fixed flow with several steps. Until then, the command table and the verified endpoints are the reference.

## Risks / Trade-offs

- [The agent shell is sandboxed] → `playwright-cli` cannot connect. Report it; a project-scoped MCP runs outside the shell and is the documented fallback.
- [CLI commands change between releases] → The skill tells the agent to read the installed `--help` before using a command that is not in the table.

## Validation

Attach to a local headless Chromium over CDP and run each command in the table. Then attach through the Windows portproxy to the authenticated Chrome and call one Grafana API with `eval` and `fetch`. Retire `cdp.py` only after that call returns data.
