# Terminal clipboard shortcuts

## Windows and WSL

| Shortcut | Windows Terminal | Ghostex terminal |
| --- | --- | --- |
| Ctrl+Shift+C | Copy terminal selection | Copy terminal selection |
| Ctrl+Shift+V | Paste clipboard text | Paste clipboard text |
| Ctrl+C | Forward to the inner program | Keep existing interruption behavior |
| Ctrl+V | Forward to the CLI image-paste handler | Paste clipboard images as links; otherwise forward the key |

Windows Terminal no longer uses Ctrl+C to copy selected text. Use Ctrl+Shift+C.
Ctrl+C reaches the inner program even when Windows Terminal has a selection.
The inner program determines how to handle it.

When Herdr handles mouse selection, hold Shift while dragging to select through
Windows Terminal. Then press Ctrl+Shift+C. Plain mouse selection can copy and
clear immediately; this change does not disable that existing behavior.

Claude Code on WSL already supports Ctrl+V and Alt+V for image paste. Codex CLI
already supports Ctrl+V and Ctrl+Alt+V. No CLI keymap change is required.
Ghostex uses its own image-link integration. Different attachment displays are
expected. A path alone does not prove that the CLI can read the image.

## Deployment

`home/run_onchange_configure-windows-terminal.ps1.tmpl` updates Windows Terminal
on Windows. It explicitly unbinds Ctrl+C/V so built-in defaults do not intercept
them. It merges managed shortcuts and action definitions while retaining
unrelated entries. The script does not configure Ghostex or Herdr.

Before applying on another machine, back up Windows Terminal's `settings.json`.
Test a URL and multiline text without submitting the prompt. Paste a
non-sensitive image and ask the CLI to describe a distinctive marker without
putting the marker in the prompt. Test interruption only on disposable work.
Do not treat an X11 clipboard failure as a keymap failure without checking which
layer received the key.

## Verified behavior

User-operated verification on 2026-10-29 used Windows Terminal 1.25.2733.0,
WSL Herdr 0.9.5, Ghostex 10.39.0, WSL Claude Code 2.1.312, and Codex CLI 0.165.0.

| Path | Text copy/paste | Ctrl+V image recognition | Ctrl+C interruption |
| --- | --- | --- | --- |
| Windows Terminal -> PowerShell | Passed | Not applicable | Passed, with and without selection |
| Windows Terminal -> WSL Herdr -> Claude Code | Passed | Passed | Passed |
| Windows Terminal -> WSL Herdr -> Codex CLI | Passed | Passed | Passed |
| Ghostex -> Claude Code | Passed | Passed | Passed |
| Ghostex -> Codex CLI | Passed | Passed | Passed |

Herdr copy verification used outer Windows Terminal selection with Shift-drag.
No Herdr or Ghostex configuration was changed. Other terminal products and
native Windows CLI binaries are not covered by these results.

## Rollback

Restore the settings backup only if no unrelated settings changed afterward.
Otherwise restore only the four prior shortcut entries. Revert the corresponding
deployment change too, or a later chezmoi apply will restore the new bindings.
No global Windows shortcuts or Linux/macOS terminal settings are changed.
