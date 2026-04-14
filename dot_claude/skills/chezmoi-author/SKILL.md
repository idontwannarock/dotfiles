---
name: chezmoi-author
description: Use when authoring or modifying files in the dotfiles chezmoi source — install scripts (`run_*`, `run_once_*`, `run_after_*`), `modify_*` scripts, `.tmpl` templates, `.chezmoiignore.tmpl`, `.chezmoitemplates/` fragments, or any cross-platform (Windows/macOS/Linux) dotfiles plumbing. Loads chezmoi execution order, install script conventions, cross-platform gotchas, and template fragment map. Invoke before adding a new tool installer, renaming a script, touching interpreter-sensitive files, or debugging why `chezmoi apply` behaves differently across OSes.
---

# Chezmoi Author Guide

Reference for writing/modifying chezmoi source files in this dotfiles repo.
The repo is **source of truth** — changes here do not take effect until `chezmoi apply` runs on each machine.

## Chezmoi Execution Order

`chezmoi apply` runs scripts in phases; alphabetical order decides the sequence within a phase:

```
1. run_*_before_*       ← install-jq, patch-chezmoi-config
2. File writes + modify_*  ← settings.json (needs jq), codex config
3. run_* (no before)    ← install-01-runtimes → 02-npm-tools → 03-claude-config,
                           containers, cli-tools, fonts
4. run_after_*          ← modify-codex-config (Windows)
```

If a script depends on another script's output, ensure it sorts later alphabetically **or** lives in a later phase.

## Install Script Conventions

- **Ordered dependencies** use numeric prefixes: `01-runtimes` → `02-npm-tools` → `03-claude-config`.
- **Independent scripts** stay unnumbered: `containers`, `cli-tools`, `fonts`.
- Every tool installer must do an **idempotent check** (skip if already installed) — `run_once_` runs only once per hash, but `run_` reruns every apply.
- Platform file extensions:
  - **Windows** → `.ps1.tmpl` (scoop-based install).
  - **macOS** → `.sh.tmpl` (brew-based install).
  - **Linux/WSL** → `.sh.tmpl` (apt for general tools; brew only for version-managed tools like nvm targets).
- Unix npm-related scripts **must** start with `{{ template "scripts/load-nvm" }}` so `npm`/`npx` are on PATH.
- When adding a tool, double-check alphabetical ordering does not break dependency chains.

## Cross-Platform Gotchas

- **Windows sh interpreter** is pinned to `~/scoop/apps/git/current/bin/bash.exe` (scoop-installed git). Do not assume system bash.
- `modify_*` scripts on Windows rely on the extension for interpreter dispatch: `.sh.tmpl` works via `[interpreters.sh]` in chezmoi config; `.toml` and other non-script extensions do **not** — use a `run_after_` PowerShell shim instead (see codex config).
- **Codex config has two sources** — `dot_codex/modify_config.toml` (Unix) and `run_after_modify-codex-config.ps1.tmpl` (Windows). Keep them in sync when editing either.
- `.gitattributes` enforces `.sh.tmpl` → LF and `.ps1` → CRLF. Do not override.
- `.chezmoiignore.tmpl` patterns are **target paths** (e.g. `.bashrc`), not source filenames (`dot_bashrc.tmpl`). OS-conditional excludes live here (Windows skips `dot_codex/config.toml` for the ps1 shim; macOS skips `.bashrc`; non-macOS skips `.zshrc`).
- `scoop/scoopfile.json` is a hand-curated GUI app reference list, not a full `scoop export`. Auto-installed CLI tools belong in install scripts.

## Template Fragment Map

Entry files (`dot_bashrc.tmpl`, etc.) compose platform fragments via `{{ template "name" . }}`. Do **not** use `include` — chezmoi's `include` takes one arg and reads from source root, so it cannot reach `.chezmoitemplates/`.

| Template | Purpose |
|----------|---------|
| `scripts/load-nvm` | Source nvm in sh scripts so npm/npx work |
| `bashrc/*` | bashrc platform fragments (windows, linux) |
| `shell-common/*` | shell_common platform fragments (base, windows, linux, darwin) |
| `zshrc/*` | zshrc platform fragments (darwin) |

## Authoring Checklist

Before committing:

1. Did you add an idempotent guard to the installer?
2. Does the filename prefix keep dependency order intact?
3. If the file is platform-specific, is the counterpart (or ignore rule) updated?
4. For codex config changes: are both Unix and Windows sources in sync?
5. Does `.gitattributes` cover any new script extension?
