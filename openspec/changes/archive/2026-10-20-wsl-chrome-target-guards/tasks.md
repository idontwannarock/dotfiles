## 1. Target guards

- [x] 1.1 Require confirmed native target selection in the shared skill and Codex guide; verify against the installed MCP schema.
- [x] 1.2 Document and enforce the helper's fixed 9222 endpoint in the shared skill and Codex guide; verify against helper source. Independent of 1.1.

## 2. Verification

- [x] 2.1 After 1.1 and 1.2, validate both rendered skills, run existing shell tests, and validate the OpenSpec change. Record deployment limitations.

## Verification results

- Both rendered skills passed validation and matched byte-for-byte.
- All 10 shell suites passed under both sh and bash. The memory-seed suite reported 51 passed, 0 failed, and 1 root-write-dependent skip per shell.
- Strict OpenSpec validation passed. Source inspection confirmed `select_page`, conditional snapshot routing, and the helper's fixed 9222 port.
- The Claude target matches the new render. The protected Codex target remains unchanged; deployment is pending outside this sandbox.
- No browser actions or cleanup-project changes were made.
