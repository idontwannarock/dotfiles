## Context

The installed Chrome DevTools MCP 1.6.0 marks `select_page` read-only. Its default snapshot schema has no `pageId`; that field requires experimental routing. The repository's `cdp.py` builds its endpoint with a fixed 9222 port.

## Goals / Non-Goals

**Goals:** Keep every read on the intended tab and endpoint.

**Non-Goals:** Change helper code, enable experimental routing, modify the live cleanup's allowlist, or alter execution permissions.

## Decisions

Add `select_page` to the initial native tool set. Inspect loaded schemas rather than assuming `pageId` support. Do not bring a tab to the foreground unless needed.

Keep the helper unchanged. Document its fixed port and reject fallback for other ports. Do not invent an unsupported port environment variable.

## Risks / Trade-offs

- [Native schemas change] → Recheck the loaded schema before constructing arguments.
- [A second controller changes selection] → Retain the existing single-controller rule.
- [Protected Codex destination remains unavailable] → Validate both renders and leave deployment pending without retrying a denied write route.

## Validation

Review both trigger scenarios against the installed MCP and helper source. Render and validate both wrappers, run the existing shell suite, and perform another correctness/design review. No new executable seam exists, so no TDD test or live browser action is needed.
