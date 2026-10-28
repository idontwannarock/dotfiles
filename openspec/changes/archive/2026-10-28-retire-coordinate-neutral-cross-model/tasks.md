## 1. Retire coordinate

- [x] 1.1 Delete the shared body, both wrappers, and the two coordinate-only tests
- [x] 1.2 Delete the coordinated-mode section of dev-workflow and the `coordinate` name-map key
- [x] 1.3 Add both deployed paths to `home/.chezmoiremove`
- [x] 1.4 Reword live docs and comments; leave history alone

## 2. agent-mux

- [x] 2.1 Write `home/dot_local/bin/executable_agent-mux` with the herdr and Ghostex backends
- [x] 2.2 Write `tests/agent-mux.test.sh` with fake binaries; check that it goes red on the detect bug
- [x] 2.3 Live round trip on herdr (isolated named session) and on Ghostex

## 3. review-cross-model

- [x] 3.1 Rewrite the body to use only agent-mux
- [x] 3.2 Update both wrapper descriptions and the counterpart reference

## 4. Close

- [x] 4.1 Spec deltas; `openspec validate`
- [x] 4.2 Docs: user-scripts.md, README
- [x] 4.3 Shell tests and template render
