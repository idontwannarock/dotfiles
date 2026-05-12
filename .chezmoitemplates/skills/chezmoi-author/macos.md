# Chezmoi Author — macOS Reference

Read this when editing `.zshrc*`, brew installers, `shell-common/darwin`, or `zshrc/darwin`. Cross-platform conventions live in the main `SKILL.md`.

## Install Scripts

- File extension: `.sh.tmpl`
- Tool source: **brew** (Homebrew) for general tools
- For version-managed runtimes (Java/JDK/Node), prefer **sdkman**/**nvm** over brew where applicable (matches the Linux preference for consistency)

## Shell Setup

macOS uses **zsh** as login shell, not bash:
- `.zshrc` is deployed; `.bashrc` is NOT (`.chezmoiignore.tmpl` excludes `.bashrc` on macOS via `{{`{{- if eq .chezmoi.os "darwin" }}`}}` blocks)
- `dot_zshrc.tmpl` composes `zshrc/darwin` and `shell-common/darwin` fragments

If you need behavior shared across bash and zsh, put it in `shell-common/*` and source it from both entry files.

## Fragments

- `shell-common/darwin` — shared shell fragment for macOS
- `zshrc/darwin` — zshrc-specific fragment (Starship init, completions, etc.)

## File Encodings

`.gitattributes` enforces `.sh.tmpl` → LF. PS5 BOM concerns don't apply (no PowerShell on macOS by default).

## macOS Checklist

When changing macOS files, also verify:

1. (Shared shell behavior) Does the change belong in `shell-common/*` rather than `zshrc/darwin` (so Linux/WSL bash gets it too)?
2. (New tool) Did you pick sdkman/nvm over brew for version-managed runtimes?
3. (`.bashrc`-like code) Did you remember `.bashrc` is excluded on macOS — so don't expect bash entry-file logic to fire here?
4. (zsh-specific syntax) Tested as zsh, not bash? `[[` and array indexing differ.
