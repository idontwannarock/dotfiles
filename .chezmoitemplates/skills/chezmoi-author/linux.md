# Chezmoi Author — Linux / WSL Reference

Read this when editing apt installers, `bashrc/linux`, `shell-common/linux`, or any `.sh.tmpl` running on Linux or WSL. Cross-platform conventions live in the main `SKILL.md`.

## Install Scripts

- File extension: `.sh.tmpl`
- Tool source:
  - **apt** for general system tools (git, jq, build-essential, etc.)
  - **brew** ONLY for version-managed tools (and even then, prefer **sdkman** for JDK/Maven/Gradle, **nvm** for Node)
  - Do not mix brew with apt for the same tool — pick one source per tool
- Unix npm-related scripts **must** start with `{{`{{ template "scripts/load-nvm" }}`}}` so `npm`/`npx` are on PATH (npm scripts run in fresh subshells without nvm sourced)

## WSL vs Native Linux

WSL is detected via the `isWSL` template variable (set in `.chezmoi.toml.tmpl` from `uname -r` containing `microsoft`). Use it sparingly — most Linux config is identical on both.

WSL-specific concerns (when they come up):
- Windows-side paths under `/mnt/c/...` are visible but cross-FS — avoid hard-coding in shared dotfiles
- Scoop binaries on the Windows host are NOT on WSL's PATH by default; if you need them, use explicit absolute paths
- Performance: WSL filesystem ops on `/mnt/c/` are slow — prefer `$HOME` (WSL ext4) for working directories

## Fragments

- `bashrc/linux` — bashrc fragment loaded on Linux + WSL (not macOS)
- `shell-common/linux` — shared shell fragment for Linux/WSL

## File Encodings

`.gitattributes` enforces `.sh.tmpl` → LF. Shebang `#!/usr/bin/env bash` recommended for portability.

## Linux/WSL Checklist

When changing Linux/WSL files, also verify:

1. (npm-related script) Does it start with `{{`{{ template "scripts/load-nvm" }}`}}`?
2. (New tool) Did you pick apt over brew where possible? Reserved brew for version-managed runtimes only?
3. (WSL-only logic) Did you gate it behind the `isWSL` template variable instead of duplicating files?
4. (Cross-shell behavior) If the script is sourced by both `.bashrc` and `.zshrc`, did you test in both?
