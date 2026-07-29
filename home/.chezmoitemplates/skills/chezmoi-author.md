---
name: chezmoi-author
description: Use when authoring or modifying files in the dotfiles chezmoi source — install scripts (`run_*`, `run_once_*`, `run_after_*`), `modify_*` scripts, `.tmpl` templates, `.chezmoiignore.tmpl`, `.chezmoitemplates/` fragments, or any cross-platform (Windows/macOS/Linux) dotfiles plumbing. Invoke before adding a new tool installer, renaming a script, touching interpreter-sensitive files, or debugging why `chezmoi apply` behaves differently across OSes.
---

# Chezmoi Author Guide

Reference for writing/modifying chezmoi source files in this dotfiles repo.
The repo is **source of truth** — changes here do not take effect until `chezmoi apply` runs on each machine.

**Source root is `home/`** (set by the repo-root `.chezmoiroot`). Every chezmoi source entry — `dot_*`, `run_*`, `.chezmoi*` config, `.chezmoitemplates/` — lives under `home/`, and every path named in this skill is relative to that root (which is also where `chezmoi cd` lands). Put new source files under `home/`, **not** the repo root: a `run_*`/`dot_*` left at the repo root is outside the source root, so chezmoi silently ignores it. The repo root holds only non-deployed infra (CI sources, `docs/`, `tests/`, `openspec/`), which is why they no longer need `.chezmoiignore` excludes.

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
- `.gitattributes` enforces CRLF on standalone `.ps1` and LF on everything else that ships as a script — `.sh`, `.sh.tmpl`, `.ps1.tmpl`, and all of `.chezmoitemplates/`. `.ps1.tmpl` is LF, unlike `.ps1`, because it inlines LF fragments and CRLF would render mixed endings. One carve-out: everything under `home/dot_local/bin/` is LF regardless of extension (that rule sits later in the file and last match wins), so `.ps1` helpers living there are LF — pwsh 7 reads them fine. Do not override.

## Script Logging Contract

Every `run_*` script MUST be readable from the `chezmoi apply` output alone: which
script is running, what the current step is *for*, and whether it finished.

**`modify_*` scripts are exempt** — their stdout *is* the target file's content, so
any banner corrupts the file. Never add logging to one.

Load the fragment, then use these six verbs. Output is byte-identical across both
interpreters:

| bash | PowerShell | Output | Use for |
|------|-----------|--------|---------|
| `log_begin "<title>"` | `Log-Begin "<title>"` | `=== BEGIN <title> ===` | Once, at the top |
| `log_section "<purpose>"` | `Log-Section "<purpose>"` | `--- <purpose>` | Each logical section |
| `log_step "<msg>"` | `Log-Step "<msg>"` | `    <msg>` | Work actually being done |
| `log_skip "<msg>"` | `Log-Skip "<msg>"` | `    <msg> (skipped)` | An idempotent guard hit |
| `log_warn "<msg>"` | `Log-Warn "<msg>"` | `    !! <msg>` | Non-fatal problem |
| `log_end` | `Log-End` | `=== END <title> (ok\|FAILED rc=N) ===` | Closing banner |

Rules:

- **`log_end` takes no title.** It reuses what `log_begin` stored. Never pass one —
  a second place to write the title is how the old scripts ended up saying
  `=== Wave 6: Scoop cleanup ===` at the top and `=== Migration complete. ===` at
  the bottom.
- **`log_section` states a purpose, not a label.** `--- remove scoop docker: CLI now
  comes from ~/.local/bin` is useful; `--- (2)` or `--- Docker` is not. If a section
  exists because of some non-obvious constraint, that constraint *is* the purpose —
  put it here rather than in a comment nobody reads at apply time.
- **The closing banner must survive every exit path**, including early returns and
  failures. Each language gets the mechanism that is hardest to get wrong:

  ```bash
  {{`{{ template "scripts/log.sh" }}`}}
  log_begin "npm global tools"      # installs an EXIT trap; nothing else to do
  ...
  exit 0                            # early exit still prints the banner
  ```

  ```powershell
  {{`{{ template "scripts/log.ps1" }}`}}
  Log-Begin "npm global tools"
  try {
      ...
      return                        # early exit -- NEVER `exit`, it skips finally
  } catch {
      Log-End -ErrorRecord $_
      throw
  } finally {
      Log-End
  }
  ```

  `Log-End` is idempotent, and `catch` runs before `finally`, so a failure reports
  `FAILED` and the `finally` call is a no-op. In bash, do **not** install your own
  `EXIT` trap — it would replace the one `log_begin` set.

## Shared Fragment Extraction

Two distinct moves, with distinct triggers. Get them the wrong way round and you
either duplicate logic or fuse scripts that should stay apart.

**Extract a fragment** when the same logic appears **twice or more** within one
interpreter. Put it in `.chezmoitemplates/scripts/` and pull it in with
`{{`{{ template }}`}}`. This is render-time inlining, not a runtime import, so
there is no deployment-order hazard and no dependency on the target machine.

**Merge whole scripts** when their control flow is byte-identical once the varying
data is lifted into a table. Test: after extracting the differences into a table,
is the remaining code identical? If yes, merge and drive it from the table. If
merging would force you to reintroduce a flag or an `if` to tell the cases apart,
do **not** merge — keep the scripts and share a fragment instead.

When you do merge, give the table a reason/purpose column and feed it to
`log_section`. That converts file-header archaeology into apply-time output —
which is the whole point.

Fragment naming: bare name when there is only ever one interpreter
(`load-nvm`); `.sh` / `.ps1` suffix once both exist (`log.sh` / `log.ps1`).

A fragment that branches on template data needs the context passed explicitly —
note the trailing dot, and that omitting it fails at render time, not silently:

```
{{`{{ template "scripts/pkg-install.sh" . }}`}}
```

## Template Fragment Map

| Template | Purpose |
|----------|---------|
| `scripts/log.sh` / `scripts/log.ps1` | The six logging verbs; `log.sh` also installs the EXIT trap |
| `scripts/npm-install.sh` / `.ps1` | Idempotent npm global-install guard |
| `scripts/pkg-install.sh` | Idempotent apt/brew install guard (needs `.` context) |
| `scripts/brew-cask-install.sh` | Idempotent Homebrew cask guard (macOS) |
| `scripts/scoop-uninstall.ps1` | `Remove-ScoopPackage`; `-Reason` prints as the section purpose |
| `scripts/load-nvm` | Source nvm in sh scripts so npm/npx work |
| `scripts/load-sdkman` | Source sdkman so the `sdk` command works |
| `bashrc/*` | bashrc platform fragments (windows, linux) |
| `shell-common/*` | shell_common platform fragments (base, windows, linux, darwin) |
| `zshrc/*` | zshrc platform fragments (darwin) |

## Authoring Checklist

Before committing:

1. Did you add an idempotent guard to the installer?
2. Does every `run_*` script open with `log_begin`/`Log-Begin` and close on **every**
   path — including early returns and failures? (bash: no competing `EXIT` trap;
   PowerShell: `try/catch/finally`, and `return` rather than `exit`.) Did you leave
   `modify_*` scripts banner-free?
3. Does every section print its *purpose* at runtime, not just carry a comment? Would
   the apply output alone tell you where a failure happened?
4. Is any logic that now appears twice in one interpreter extracted to
   `.chezmoitemplates/scripts/`? Are any scripts now byte-identical apart from data,
   and therefore mergeable into one table-driven script?
5. Does the filename prefix keep dependency order intact?
6. If the file is platform-specific, is the counterpart (or ignore rule) updated?
7. Does `.gitattributes` cover any new script extension?
8. If you deleted or renamed a source file, did you add the old **target path** to `.chezmoiremove` so the deployed copy is pruned across machines? (`run_*` scripts are never deployed, so deleting one needs no `.chezmoiremove` entry.)
9. Platform-specific checks: did you also walk the checklist in the matching `references/*.md`?
10. If you touched a shared skill body (`.chezmoitemplates/skills/*.md`) or a wrapper name-map: render EVERY affected wrapper and grep for silent misses — Go templates render a missing map key as a literal no-value marker without erroring:
   `for f in home/dot_{claude,codex}/skills/*/SKILL.md.tmpl; do chezmoi execute-template < "$f" | grep -H --label="$f" '<no'' value>'; done` (any output = a token missing from a name-map; the split-quote pattern keeps this checklist itself from matching).
