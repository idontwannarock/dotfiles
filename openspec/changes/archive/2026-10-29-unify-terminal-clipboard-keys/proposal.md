## Why

Windows Terminal intercepts Ctrl+V for terminal paste, while Ghostex distinguishes text paste from image paste. Users need consistent text and image shortcuts without replacing working clipboard integrations or overriding CLI bindings.

## What Changes

- Define Ctrl+Shift+C as terminal selection copy and Ctrl+Shift+V as text paste for the Windows/WSL entry points.
- **BREAKING**: Stop Windows Terminal from handling Ctrl+C as selection copy and Ctrl+V as terminal paste. Forward those keys to the inner program. Use Ctrl+Shift+C/V for terminal copy/paste instead.
- Preserve Ghostex's current clipboard behavior. Its terminal-focused shortcuts already use Ctrl+Shift+C/V. It handles clipboard images on Ctrl+V as image links and forwards Ctrl+V to the program when the clipboard does not contain an image.
- Preserve Claude Code and Codex CLI bindings. The inspected WSL versions already bind Ctrl+V to image paste. Keep Claude Code's Alt+V alternative.
- Treat Herdr as a verification path, not a configuration target. Change its keymap only if verification finds a conflict and the user approves the additional scope.
- Test the live Windows Terminal configuration before syncing the change into chezmoi source. Document the shortcuts and verification results.
- Verify text paste, image recognition, and interruption through Windows Terminal with Herdr and through Ghostex, using both CLIs. Image attachment formatting may differ. Do not count receipt of a path string alone as successful image recognition.

## Capabilities

### New Capabilities

- `terminal-clipboard-shortcuts`: Define text copy/paste and image-paste behavior across Windows Terminal and Ghostex, including Herdr passthrough and preservation of CLI bindings.

### Modified Capabilities

None.

## Impact

- Expected source change: `home/run_onchange_configure-windows-terminal.ps1.tmpl`, with focused regression tests and user documentation.
- Live configuration target: Windows Terminal settings. Back up the file before editing and preserve unrelated settings.
- No planned changes to Ghostex, Herdr, Claude Code, or Codex configuration. No global Windows/WSL key remapping or new dependency.
- Windows Terminal changes apply only on Windows. Do not alter Linux or macOS terminal configuration without a verified need.
- Existing evidence: Claude Code 2.1.312 and Codex CLI 0.165.0 expose Ctrl+V image bindings; no custom keymap was found in the inspected user configuration. Ghostex's local hotkey list and guide describe the existing image-link path. Windows Terminal's live settings bind Ctrl+C/V to copy/paste.
- The user reports successful image paste in both entry points. End-to-end verification of the proposed shortcuts, including Herdr forwarding, remains pending. This change does not assume that remapping keys repairs X11 clipboard access.
