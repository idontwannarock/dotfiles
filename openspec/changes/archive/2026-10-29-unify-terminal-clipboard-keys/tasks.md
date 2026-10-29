## 1. Verify the live Windows Terminal change

- [x] 1.1 Confirm the installed Windows Terminal version and supported explicit-unbind syntax. Inspect current actions and keybindings for the four targeted chords. Record actual native Windows or WSL launch paths and versions for both CLI test sessions, plus Ghostex and Herdr versions. Resolve the design's syntax and runtime questions without changing settings.
- [x] 1.2 (Blocked by 1.1) Back up the live Windows Terminal settings, re-read them to detect intervening changes, and apply only the four-chord candidate with the required filesystem approval. Verify valid configuration, preservation of unrelated settings, and PowerShell copy/paste and Ctrl+C behavior with and without outer selection. Record the backup location and rollback procedure; do not run broad chezmoi apply.
- [x] 1.3 (Blocked by 1.2) Have the user verify Windows Terminal -> Herdr -> Claude Code and Windows Terminal -> Herdr -> Codex CLI. Check selection copy, URL paste, multiline paste without submission, Ctrl+V image recognition, and safe interruption. Record each outcome and selection owner. Do not control a focused Herdr session from outside Herdr; request scope approval if a Herdr conflict requires configuration changes.
- [x] 1.4 (Blocked by 1.2) Verify the same operations in Ghostex with each CLI without changing Ghostex settings. Confirm Ctrl+V image links remain readable by each CLI. Record actual outcomes rather than treating the earlier image-paste report as a full regression pass.

## 2. Sync the verified behavior with regression tests

The source implementation is gated on successful live checks in 1.2 through 1.4. A failed or unperformed check stays open; it is not a reason to bypass this gate.

- [x] 2.1 (Blocked by 1.2, 1.3, 1.4) Add a focused failing test for the four-chord configuration in the Windows Terminal deployment template. Observe the expected failure, implement the verified bindings, and rerun the test to pass. Preserve the Windows-only guard and existing logging behavior.
- [x] 2.2 (Blocked by 2.1) Add a failing fixture for unrelated shortcuts, action definitions, and profiles. Observe the array-replacement failure, implement the smallest required merge change in the existing script, and verify preservation and the expected managed settings together.
- [x] 2.3 (Blocked by 2.2) Test conflicting legacy/current definitions and shared chord entries. Confirm targeted chords have no competing definitions and unrelated chords survive. For any failing case, observe red before changing the merge, then rerun to green. Test repeated application for structural idempotence and duplicate-free output.

## 3. Verify and document the deliverable

- [x] 3.1 (Blocked by 2.3) Run the focused regression tests and relevant repository template checks. Render the Windows script and check PowerShell parsing; verify Linux and macOS rendering produces no executable changes. Compare generated bindings with the live-tested candidate. Record commands, exit statuses, and any unavailable checks.
- [x] 3.2 (Blocked by 3.1) Add user documentation for text/image shortcuts, the Ctrl+C behavior change, preserved Ghostex and CLI integrations, Herdr verification, and safe rollback. Include the completed verification matrix without private clipboard contents or machine-local backup data in public documentation.
- [x] 3.3 (Blocked by 3.2) Run strict OpenSpec validation and final diff checks. Verify all required manual and automated outcomes are recorded. Review the change through the Small workflow before integration; do not report completion while required checks remain failed or not tested.

## Execution evidence

- 2026-10-29: Task 1.1 complete. Windows Terminal 1.25.2733.0; WSL Herdr 0.9.5; Ghostex desktop/server 10.39.0; WSL Claude Code 2.1.312; WSL Codex CLI 0.165.0. User confirmed the Herdr path runs on Ubuntu/WSL. Microsoft actions documentation supports `id: "unbound"`. The live file has separate actions/keybindings and no legacy binding conflicts for the four chords.
- 2026-10-29: Task 1.2 partially executed with approval. Created an adjacent timestamped settings backup, checked the original had not changed, and applied the four-chord candidate. JSON parsing and byte comparison with the candidate passed. Structural comparison confirmed all non-keybinding settings unchanged; the diff showed only the intended chord replacements/additions and a final newline. No Ghostex, Herdr, CLI, or deployed-source configuration changed.
- User confirmed PowerShell checks passed, completing task 1.2. Restore the adjacent backup only if no subsequent settings edits occurred; otherwise restore only the four prior chord definitions.
- User confirmed Ctrl+Shift+C copies the outer Windows Terminal selection while Herdr runs when Shift is held during mouse selection. Plain mouse selection copied immediately and cleared the selection; its owner has not been independently established. Preserve that existing behavior.
- User confirmed URL/multiline text paste and Ctrl+V image recognition passed for both Claude Code and Codex CLI through WSL Herdr. Task 1.3 remains open only for explicit safe-interruption confirmation in both CLI sessions; PowerShell interruption does not establish CLI interruption. Task 1.4 Ghostex regression checks remain pending.

- User confirmed safe interruption in both Herdr CLI sessions and all Ghostex checks in both CLIs. Tasks 1.3 and 1.4 are complete. The live-verification gate is satisfied.
- Source TDD: observed exit 1 for missing four-chord bindings, then green after updating the patch. Observed exit 1 for discarded local settings, then green after keyed merging. Observed exit 1 for legacy conflicts, then green after chord normalization and shared-entry filtering.
- Surgical review (correctness and design) found that replacing a managed action ID discarded its unrelated legacy keys. Added a failing same-ID fixture, preserved filtered action properties during the merge, and reran sh/bash tests successfully. Both reviewers confirmed the finding resolved. Other comprehensive-review lenses were not run.
- Final candidate renders: Windows script generated successfully; Linux and macOS outputs are empty. PowerShell 7 parser diagnostics are empty. Executed the rendered script twice against an isolated settings directory; both runs exited successfully and the second output was byte-identical. Generated clipboard bindings match the live-tested candidate. No live settings were changed by these tests.
- Linux repository template gate (`chezmoi apply --dry-run --exclude=externals --source="$PWD"`) exited 0. Full native Windows/macOS repository CI was not run; the affected template was rendered for all three OS values.

- Final full shell suite passed under sh and bash (exit 0). The first sandboxed attempt failed because existing tests write under ~/.cache; rerun with approval succeeded. Strict OpenSpec validation and diff whitespace checks passed. All ten implementation tasks are complete; spec sync, archive, commit, and branch integration remain workflow steps.
