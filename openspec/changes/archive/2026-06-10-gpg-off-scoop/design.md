## Context

The Scoop `gpg` 2.5.20 manifest's installer runs `New-Item bin\gpgconf.ctl`, which puts GnuPG into portable mode: homedir is forced to `scoop\apps\gpg\current\home` (a scoop-persisted but empty junction) and `GNUPGHOME` is **ignored** (the `gpgconf.ctl` marker outranks the env var in GnuPG's precedence: `--homedir` > `gpgconf.ctl` > `GNUPGHOME` > default). The corp-ssh keyring lives in `~/.gnupg`, so gpg can't decrypt → gopass `rc=11` → `corp-ssh-askpass` fails. The marker is recreated on every `scoop update gpg`, so neutralizing it post-hoc is not durable.

`run_once_install-cli-tools.ps1.tmpl` previously kept gpg on Scoop with a comment citing "multi-binary suite + installer side-effects (gpgconf.ctl…)". That side-effect is now the bug, so the rationale is inverted.

## Goals / Non-Goals

**Goals:**
- Own the GnuPG install via chezmoi so `gpgconf.ctl` is never created and homedir is `~/.gnupg`.
- Keep the install self-contained under `~/.local/opt/` (no admin, consistent with the chezmoi-external tool philosophy).
- Restore `corp-ssh-askpass` decryption; survive future GnuPG version bumps via a pinned-version flow.

**Non-Goals:**
- Migrating 7-Zip off Scoop (decoupled; NSIS `/S` needs no extractor).
- Changing Linux/WSL or macOS gpg (they use apt/brew and are unaffected).
- Changing gopass (already a chezmoi-external since Wave 3).
- Re-keying or moving the existing `~/.gnupg` keyring.

## Decisions

**D1 — Install via NSIS silent install (`/S /D=`), not 7z extraction.**
The gnupg.org "simple installer" is NSIS (proven by Scoop's `Remove-Item $dir\$PLUGINSDIR` step — `$PLUGINSDIR` is an NSIS-only artifact). NSIS natively supports `/S` (silent) and `/D=<dir>` (target, must be the last arg and unquoted). This installs the full suite into a chosen folder with zero extraction tooling.
- *Alternative (7z extract):* mirrors Scoop exactly but requires a full `7z.exe`+`7z.dll` (NSIS parsing isn't in `7zr.exe`/most `7za.exe`), which itself needs bootstrapping — strictly more complexity for no benefit here. Rejected.
- *Caveat:* `/D=` cannot contain spaces. `C:\Users\user\.local\opt\gnupg` is space-free; if a future username has spaces, revisit the 7z path.

**D2 — Install location `~/.local/opt/gnupg/`, PATH-front its `bin`.**
GnuPG is a suite (gpg, gpg-agent, gpgconf, keyboxd, scdaemon, dirmngr, pinentry, DLLs, share/), so it gets its own opt dir rather than polluting `~/.local/bin`. Its `bin` is prepended to PATH ahead of any leftover Scoop shim so `gpg` resolves to the owned install.

**D3 — Set `GNUPGHOME=%USERPROFILE%\.gnupg`.**
Vanilla GnuPG defaults to `%APPDATA%\gnupg`; the keyring is in `~/.gnupg`. Setting `GNUPGHOME` (honored now that no `gpgconf.ctl` exists) unifies the homedir for both the owned gpg and Git Bash's bundled gpg. Verified empirically: scoop gpg 2.5.20 with `--homedir C:\Users\user\.gnupg` finds the secret key with no path-mangling (the old 2.5.19 `%3a`-encoding bug is gone).

**D4 — `run_onchange_install-gnupg.ps1.tmpl`, version-pinned.**
`run_onchange_` reruns only when the rendered script changes, matching version-pin semantics (cf. `$gopassVersion`). Pin version + build date + SHA-1; idempotent guard compares `gpg.exe --version` to the pin and exits early when equal. `.ps1.tmpl` + UTF-8 BOM (PS5 parser requirement) per chezmoi-author Windows rules. `.chezmoiignore.tmpl` excludes it on non-Windows.

**D5 — Test on the live machine first, then encode (project workflow §1-2).**
Do the install + `GNUPGHOME` + uninstall-scoop-gpg manually on this machine and confirm `ssh dev-livekit` works before committing the chezmoi source, so the encoded scripts reflect verified-working steps.

## Risks / Trade-offs

- **[Self-update lost]** Scoop auto-bumped gpg; now bumps are manual (edit the pin). → Mitigate: document the bump procedure in `reference_chezmoi_external_cli_tools.md` and a `checkver`-style comment (gnupg.org regex) in the script header.
- **[NSIS `/D=` + spaces]** Breaks on spaced usernames. → Mitigate: D1 caveat noted; space-free on target machine; 7z extract is the documented fallback.
- **[Stale Scoop shim wins PATH]** A leftover `~/scoop/shims/gpg.exe` could shadow the new gpg. → Mitigate: D2 PATH precedence + uninstall scoop gpg; verify with `Get-Command gpg`.
- **[gpg-agent socket/version churn]** Two gpg builds (owned 2.5.x + Git Bash 2.4.x) sharing `~/.gnupg` could clash on agent. → Mitigate: single `GNUPGHOME`; agent is started by whichever runs first and both are 2.x-compatible; observed working with `--homedir` test.
- **[Lockout during cutover]** Removing scoop gpg before the new one works could block corp-ssh. → Mitigate: install + verify decryption FIRST, uninstall scoop gpg LAST; keep `~/.gnupg` untouched as the constant.

## Migration Plan

1. Manually install gnupg-w32 (pinned) via `/S /D=~/.local/opt/gnupg`; set `GNUPGHOME`; PATH-front bin.
2. Verify: `gpgconf --list-dirs homedir` → `~/.gnupg`; `gpg --list-secret-keys` shows corp key; warm cache; `ssh dev-livekit` succeeds.
3. `scoop uninstall gpg`; re-verify `Get-Command gpg` → owned install and ssh still works.
4. Encode verified steps into `run_onchange_install-gnupg.ps1.tmpl`, remove scoop gpg line/comment, env wiring, `.chezmoiignore.tmpl`.
5. `chezmoi apply` on this machine to confirm the encoded path reproduces the working state.
6. Update docs + memory.

**Rollback:** `scoop install gpg; scoop reset gpg` restores the previous (buggy-but-known) state; `~/.gnupg` is never modified, so no key loss.
