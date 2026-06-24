---
name: chezmoi-author
description: Use when authoring or modifying files in the dotfiles chezmoi source — install scripts (`run_*`, `run_once_*`, `run_after_*`), `modify_*` scripts, `.tmpl` templates, `.chezmoiignore.tmpl`, `.chezmoitemplates/` fragments, or any cross-platform (Windows/macOS/Linux) dotfiles plumbing. Invoke before adding a new tool installer, renaming a script, touching interpreter-sensitive files, or debugging why `chezmoi apply` behaves differently across OSes.
---

# Chezmoi Author Guide

Reference for writing/modifying chezmoi source files in this dotfiles repo.
The repo is **source of truth** — changes here do not take effect until `chezmoi apply` runs on each machine.

## Routing — Read Only What Applies

Touch a file → read the matching reference. Skip the others.

| Editing... | Then read |
|------------|-----------|
| Windows-only files (`.ps1`/`.ps1.tmpl`, `Documents/`, `bashrc/windows`, `run_after_modify-codex-config.ps1.tmpl`, anything that touches Scoop or Git Bash) | `references/windows.md` |
| Linux/WSL files (apt installers, `bashrc/linux`, `shell-common/linux`, anything using `load-nvm`) | `references/linux.md` |
| macOS files (`.zshrc*`, brew installers, `shell-common/darwin`, `zshrc/darwin`) | `references/macos.md` |
| Cross-platform plumbing only (chezmoi config, template fragments, `.chezmoiignore.tmpl`) | (this file alone is enough) |

## Chezmoi Execution Order

`chezmoi apply` runs scripts in phases; alphabetical order decides the sequence within a phase:

```
1. run_*_before_*       ← install-prereqs, patch-chezmoi-config
2. File writes + modify_*  ← settings.json (needs jq), codex config
3. run_* (no before)    ← install-01-runtimes → 02-npm-tools → 03-claude-config,
                           containers, cli-tools, fonts
4. run_after_*          ← modify-codex-config (Windows)
```

If a script depends on another script's output, ensure it sorts later alphabetically **or** lives in a later phase.

## Cross-Platform Conventions

- **Ordered dependencies** use numeric prefixes: `01-runtimes` → `02-npm-tools` → `03-claude-config`. Independent scripts stay unnumbered: `containers`, `cli-tools`, `fonts`.
- Every tool installer must do an **idempotent check** (skip if already installed). `run_once_` runs once per hash; `run_` reruns every apply.
- `.chezmoiignore.tmpl` patterns are **target paths** (e.g. `.bashrc`), not source filenames (`dot_bashrc.tmpl`). OS-conditional excludes live here (Windows skips `dot_codex/config.toml` for the ps1 shim; macOS skips `.bashrc`; non-macOS skips `.zshrc`).
- **Retiring a deployed file** needs `.chezmoiremove`, not just deleting the source. Deleting a source file (or `git rm`) only stops chezmoi *managing* the target — the already-deployed copy lingers on every machine. List its **target path** in `.chezmoiremove` (e.g. `.claude/skills/foo`, no `dot_` prefix, no leading `~`) to prune it everywhere; directories are removed recursively. A target that was modified since chezmoi last wrote it prompts for confirmation, so use `chezmoi apply --force` in non-interactive shells.
- Entry files (`dot_bashrc.tmpl`, etc.) compose platform fragments via `{{`{{ template "name" . }}`}}`. Do **not** use `include` — chezmoi's `include` takes one arg and reads from source root, so it cannot reach `.chezmoitemplates/`.
- `.gitattributes` enforces `.sh.tmpl` → LF and `.ps1` → CRLF. Do not override.

## Template Fragment Map

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
4. Does `.gitattributes` cover any new script extension?
5. If you deleted or renamed a source file, did you add the old **target path** to `.chezmoiremove` so the deployed copy is pruned across machines?
6. Platform-specific checks: did you also walk the checklist in the matching `references/*.md`?
