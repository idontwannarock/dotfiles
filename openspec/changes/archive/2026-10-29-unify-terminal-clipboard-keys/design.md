## Context

The inspected Windows Terminal settings and chezmoi script bind Ctrl+C/V to terminal copy/paste. Windows Terminal's copy action forwards Ctrl+C when no terminal selection exists; the current binding does not disable interruption in all cases. The proposed change makes forwarding independent of selection.

Claude Code 2.1.312 on WSL binds Ctrl+V and Alt+V to image paste. Codex CLI 0.165.0 reserves Ctrl+V and Ctrl+Alt+V for image paste. No custom keymap was found in the inspected user configuration.

Ghostex's local guide and terminal-focused hotkey list already match the intended split: Ctrl+Shift+C/V perform terminal copy/paste. Ctrl+V sends clipboard images as links; otherwise it reaches the inner program. Ghostex manages its embedded terminal configuration separately from the standalone Ghostty application.

Herdr is normally launched inside Windows Terminal. Its forwarding behavior under the proposed configuration remains an end-to-end verification item. This session is outside Herdr, so it must not inspect or control another focused Herdr session.

## Goals / Non-Goals

**Goals:**

- Use Ctrl+Shift+C for terminal selection copy and Ctrl+Shift+V for text paste at both entry points.
- Let Ctrl+C reach the inner program in Windows Terminal, including when the outer terminal has a selection.
- Make Ctrl+V image paste usable with both CLIs in Windows Terminal through Herdr and in Ghostex.
- Preserve existing image integration, alternate image shortcuts, and unrelated settings.
- Verify live behavior before changing the deployed source of truth.

**Non-Goals:**

- Global Windows/WSL keyboard remapping or a new clipboard bridge.
- Matching attachment appearance or forcing Ghostex to use native CLI clipboard access.
- Replacing Herdr, Ghostex, or CLI keymaps without an observed conflict and separate scope approval.
- Changing macOS or Linux terminal configuration, managing additional terminal products, or repairing general X11 connectivity.

## Decisions

### 1. Change Windows Terminal, not the CLI bindings

Explicitly bind Ctrl+Shift+C/V to Windows Terminal's copy/paste actions. Explicitly unbind Ctrl+C/V at the Windows Terminal layer using its supported settings schema. Removing entries alone is insufficient because built-in defaults can restore them. Confirm the installed Windows Terminal schema before writing the candidate configuration.

Do not replace or rebind CLI image actions: Ctrl+V is already assigned to the desired action. Preserve Ghostex's image interception instead of forwarding every Ctrl+V blindly. Uniform user actions matter; identical implementations do not.

Alternative: retain Windows Terminal's selection-dependent Ctrl+C copy behavior. Rejected for this change because the agreed mapping separates copy from interruption. Document this behavior change so users do not mistake it for fixing a universally broken interrupt key.

### 2. Patch only the required shortcut entries

Back up the live Windows Terminal settings before editing. Replace entries for the four targeted chords and retain other shortcuts, action definitions, profiles, and settings. Check for legacy action entries containing the same chords before applying the patch; do not leave two conflicting definitions.

The current deployment script uses jq object multiplication, which replaces arrays. Before adding a regression test for preservation, account for this behavior: keep the existing managed non-clipboard settings, but merge keybindings by chord so unrelated machine-local shortcuts survive. Preserve unrelated action definitions by action ID if the existing actions patch would otherwise remove them. Limit this change to the arrays this script already manages; do not build a generic settings merger or change other deployment behavior.

Alternative: replace the entire live settings file or keybinding array. Rejected because the proposal requires preservation of unrelated settings.

### 3. Verify each input path separately

Use the following manual matrix after the live configuration change:

| Path | Text copy/paste | Ctrl+V image paste | Ctrl+C interruption |
| --- | --- | --- | --- |
| Windows Terminal -> PowerShell | Required | Not applicable | Required, with and without outer selection |
| Windows Terminal -> Herdr -> Claude Code | Required | Required | Required |
| Windows Terminal -> Herdr -> Codex CLI | Required | Required | Required |
| Ghostex -> Claude Code | Required | Required | Required |
| Ghostex -> Codex CLI | Required | Required | Required |

Copy a harmless URL and multiline text to test text paste. Use a non-sensitive image with a distinctive visible marker and ask each CLI to describe it without supplying the marker in the prompt. A displayed file path or attachment badge alone does not prove image access. Use a disposable foreground command or test conversation for interruption; do not cancel unrelated work.

The user performs GUI interactions that this session cannot safely automate. Record each result as passed, failed, or not tested. Do not infer a pass from existing bindings or from success in another path. Herdr selection and outer-terminal selection are separate; identify which one the copy test exercises.

### 4. Add focused automated regression checks

Before changing the source script, add a failing test for its clipboard configuration and merge behavior. Follow existing repository test conventions. Cover the four targeted chords, removal of obsolete managed bindings, preservation of unrelated shortcuts/actions/profiles, and byte-stable or structurally identical output on repeated application.

Render the Windows template and parse the resulting PowerShell script. Confirm non-Windows rendering remains empty. Run the focused tests and relevant repository template checks after implementation. Automated tests do not replace the manual matrix.

## Risks / Trade-offs

- [Windows Terminal defaults restore removed shortcuts] -> Use explicit unbinding and verify the effective behavior, not only JSON contents.
- [Legacy settings contain duplicate bindings] -> Inspect both actions and keybindings before changing the live file; normalize only targeted chords.
- [Herdr consumes Ctrl+V] -> Report the failed path and request scope approval before editing Herdr.
- [Native clipboard access fails despite correct key delivery] -> Keep that result separate from keymap correctness; do not claim the image workflow passes or overwrite Ghostex's working integration.
- [Copy from a multiplexer includes pane borders or other panes] -> Test and document outer selection separately from Herdr's own selection features.
- [Users expect Ctrl+C to copy selected text] -> Document Ctrl+Shift+C and the intentional change to Ctrl+C handling.
- [Live file changes during testing] -> Re-read it before writing. Roll back only this change if unrelated edits occurred after the backup.

## Migration Plan

1. Finish the spec and task artifacts. Confirm installed Windows Terminal syntax and inspect targeted binding conflicts.
2. Back up and minimally patch the live Windows Terminal settings with the required approval. Do not run a broad chezmoi apply.
3. Complete the manual matrix. If a path fails, record the evidence and resolve scope before proceeding.
4. After live behavior is verified, write the regression test, observe its failure, and update the source script and user documentation.
5. Run automated checks and compare the rendered configuration with the tested live behavior. Review the diff before integration.

Rollback: restore the live backup if there were no intervening changes; otherwise restore only the previous targeted bindings. If source changes have shipped, revert their clipboard changes as well so the next apply does not reintroduce them.

## Open Questions

- Does the installed Herdr forward Ctrl+V unchanged in both CLI sessions? Confirm through the manual matrix.
- Does the installed Windows Terminal accept the chosen explicit-unbind form, including any legacy entries in the live file? Resolve before editing.
- Which Windows Terminal/Herdr CLI launch paths use WSL versus native Windows binaries? Record the actual runtime versions during verification; the WSL inventory does not establish native Windows behavior.
