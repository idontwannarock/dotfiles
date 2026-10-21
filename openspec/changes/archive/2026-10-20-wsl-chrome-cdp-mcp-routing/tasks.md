## 1. Revise browser-session guidance

- [x] 1.1 Update setup, driver selection, scoped MCP evaluation, and ownership-aware teardown in the shared body; review each specification scenario.
- [x] 1.2 Align both wrapper descriptions and document the workflow in the existing Codex/Claude guides.

## 2. Verify and deploy

- [x] 2.1 Render both wrappers, validate the skill files, compare their guidance, and run the existing shell test suite and OpenSpec validation.
- [x] 2.2 Attempt a targeted deployment with scripts excluded; verify both deployed skill files or record the exact permission blocker.

## Verification record

- Both rendered skills pass `skill-creator/scripts/quick_validate.py` and compare byte-for-byte.
- No unresolved template tokens. `git diff --check` passes.
- All ten `tests/*.test.sh` suites pass under both `sh` and `bash`.
  The memory-seed suite reports 51 passed, 0 failed, and 1 skipped in each shell.
  The skip requires write access outside the allowed filesystem roots.
- `openspec validate wsl-chrome-cdp-mcp-routing --strict` passes.
- Targeted chezmoi apply excluded scripts and previewed only the two skill files.
  Claude's deployed file matches the render. Codex's file remains unchanged.
  Apply failed with `invalid cross-device link` while renaming the temporary file
  into the protected `~/.codex/skills/wsl-chrome-cdp/SKILL.md` destination.
- Codex deployment and remote Git synchronization remain pending. No browser,
  firewall, forwarding, or cleanup-project configuration was changed.
