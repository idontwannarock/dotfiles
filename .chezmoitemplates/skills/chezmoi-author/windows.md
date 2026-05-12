# Chezmoi Author — Windows Reference

Read this when editing `.ps1`/`.ps1.tmpl`, `Documents/`, `scoop/`, `bashrc/windows`, `run_after_modify-codex-config.ps1.tmpl`, or anything else that touches Scoop / Git Bash on Windows. Cross-platform conventions live in the main `SKILL.md`.

## Install Scripts

- File extension: `.ps1.tmpl`
- Tool source: Scoop (`scoop install <pkg>`)
- `scoop/scoopfile.json` is a hand-curated **GUI app** reference list, not a full `scoop export`. Auto-installed CLI tools belong in install scripts, not in scoopfile.json.

## sh Interpreter Pinning

Windows `sh` interpreter must be pinned to `~/scoop/apps/git/current/bin/bash.exe` (scoop-installed git). Do not assume system bash — `bash` on PATH from PowerShell 7 may resolve to `C:\Windows\System32\bash.exe` (WSL bash), which cannot handle the Windows tmp paths chezmoi passes.

Use `bin/bash.exe`, NOT `usr/bin/bash.exe`:
- `bin/bash.exe` is a wrapper that sets `MSYSTEM` then exec's the real bash; works when invoked from a non-MSYS parent (PowerShell, chezmoi)
- `usr/bin/bash.exe` is the real bash directly — coreutils DLLs fail to load from a non-MSYS parent

The pin is in `.chezmoi.toml.tmpl` under `[interpreters.sh]`.

## `modify_*` Scripts — Extension Dispatch

On Windows, `modify_*` scripts dispatch by file extension:
- `.sh.tmpl` works via `[interpreters.sh]` in chezmoi config
- `.toml` and other non-script extensions do **not** dispatch — use a `run_after_` PowerShell shim instead

Example: codex config is rendered by `dot_codex/modify_config.toml` (Unix) AND `run_after_modify-codex-config.ps1.tmpl` (Windows shim). When editing one, mirror the change in the other. `.chezmoiignore.tmpl` excludes `dot_codex/config.toml` on Windows so the shim is the sole writer there.

## PowerShell `.ps1` Files — UTF-8 BOM Required for Non-ASCII

**`.ps1` files containing non-ASCII MUST start with a UTF-8 BOM (`EF BB BF`).**

Why: PowerShell 5.1's parser falls back to the system ANSI codepage (e.g. cp950 on zh-TW Windows) for files without BOM. UTF-8 multi-byte Chinese sequences mojibake; some decode into PS special tokens (eating closing quotes/parens) which cascade into parser errors on unrelated lines like `[CmdletBinding()]`.

PowerShell 7 handles BOM transparently, so adding it is safe cross-version.

**Critical gotcha:** `00-encoding.ps1`-style runtime setup (`[Console]::OutputEncoding = UTF8`, `chcp 65001`) only affects console I/O — it CANNOT change how the parser decodes a dot-sourced script. The parser reads the file before any setup runs.

**Defense-in-depth:** add BOM to currently-ASCII fragments that might later grow non-ASCII, especially `Documents/_shared-profile.d/*.ps1` (dot-sourced by both PS5 and PS7 profile loaders).

Add BOM to an existing file via Git Bash:
```bash
printf '\xef\xbb\xbf' | cat - file.ps1 > tmp && mv tmp file.ps1
```

Verify:
```bash
head -c 3 file.ps1 | xxd -p   # should print: efbbbf
```

## File Encodings

`.gitattributes` enforces `.ps1` → CRLF (working tree) / LF (git index). EOL normalization is independent of BOM (BOM is at byte 0, before any newline) — the two coexist fine.

## Windows-Specific Checklist

When changing Windows files, also verify:

1. (`.ps1` with non-ASCII) Does the source start with `EF BB BF`?
2. (`modify_*.toml` or other non-`.sh` Windows config) Is there a matching `run_after_*.ps1.tmpl` shim?
3. (Codex config) Did you mirror the change to both `dot_codex/modify_config.toml` AND `run_after_modify-codex-config.ps1.tmpl`?
4. (New tool) Is the Scoop install command idempotent (e.g. `scoop list <pkg>` guard)?
