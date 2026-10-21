## Context

One chezmoi body supplies the Codex and Claude skills. The current body conflates browser launch, network access, and driver availability. It also closes the shared browser and deletes its profile unconditionally.

## Goals / Non-Goals

**Goals:** Correct driver routing, preserve authenticated sessions, distinguish permission boundaries, and document project-scoped MCP evaluation.

**Non-Goals:** Add a browser driver, install MCP packages, modify the running cleanup, change agent permissions, or automate firewall changes.

## Decisions

- Keep one shared body and aligned descriptions. Separate setup, driver selection, and teardown within the body instead of adding another skill.
- Prefer an authorized native MCP. Keep the existing `cdp.py` interface for tasks that allow it. Neither option overrides task restrictions or execution permissions.
- Replace the all-interface firewall example with a procedure based on observed listener and WSL addresses. Do not publish a runnable command with guessed network values.
- Use dated observations for past failures. Do not encode one machine's failure as a platform restriction.
- Verify documentation with rendered skill validation, existing shell tests, and scenario review. This change has no new executable seam, so no wording-matching test or live browser action is required.

## Risks / Trade-offs

- [MCP configuration examples age] → Inspect the installed CLI and native tool schemas; keep host addresses and package paths out of the shared skill.
- [Cleanup interrupts another session] → Track ownership and check active users before teardown; honor explicit leave-open requests.
- [A deployment runs unrelated installers] → Render first and apply only the two skill targets with scripts excluded.
- [Protected Codex destination prevents deployment] → Report the failure and retain validated source; do not bypass filesystem restrictions.

## Migration Plan

Render and validate both wrappers. Apply only those skill files when permitted. Compare deployed content with the render. Revert the shared body and descriptions to roll back; do not touch browser state.
