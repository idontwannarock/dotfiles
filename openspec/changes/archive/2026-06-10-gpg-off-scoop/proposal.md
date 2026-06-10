## Why

Scoop's `gpg` package (2.5.20) ships an empty `bin\gpgconf.ctl` on every install/update, forcing GnuPG into "portable mode" with an empty `scoop\apps\gpg\current\home` directory and **ignoring `GNUPGHOME`**. Since the real keyring lives in `~/.gnupg`, gpg can no longer find the corp-ssh secret key — decryption fails (gopass `rc=11`), breaking `corp-ssh-askpass` and locking the user out of corp SSH hosts. The defect re-appears on every `scoop update gpg`, so a patch-the-output workaround is not durable. Owning the install removes the side-effect at its source.

## What Changes

- Provision the GnuPG suite on Windows from the **official gnupg.org NSIS installer** via a chezmoi `run_onchange_` PowerShell script, installed into an independent folder `~/.local/opt/gnupg/` using NSIS silent install (`/S /D=`).
- **Do NOT** create `gpgconf.ctl` — vanilla GnuPG defaults to honoring `GNUPGHOME`; we set `GNUPGHOME=%USERPROFILE%\.gnupg` so Scoop-era keyring and Git Bash gpg share one home.
- Add `~/.local/opt/gnupg/bin` to PATH ahead of the Scoop shim.
- **BREAKING (local machine state):** remove `Install-ScoopPackage "gpg"` from `run_once_install-cli-tools.ps1.tmpl` and uninstall the Scoop gpg package; update the accompanying comment that previously justified keeping gpg on Scoop.
- Version-pin (version + build date + SHA-1) following the existing `$gopassVersion` external pattern; document the bump procedure.
- 7-Zip is **out of scope** — NSIS `/S` needs no extractor, so no extraction-tool dependency is introduced.

## Capabilities

### New Capabilities
- `gpg-provisioning`: how the GnuPG suite is installed and configured on Windows (source, install method, homedir resolution, PATH, version pinning) so it consistently uses `~/.gnupg` and never enters portable mode.

### Modified Capabilities
<!-- none: no existing specs -->

## Impact

- **New file:** `run_onchange_install-gnupg.ps1.tmpl` (Windows installer).
- **Modified:** `run_once_install-cli-tools.ps1.tmpl` (remove scoop gpg line + comment), possibly a `*_shared-profile.d/*.ps1` for `GNUPGHOME`/PATH env, `.chezmoiignore.tmpl` if non-Windows must skip the new script.
- **Machine state:** Scoop gpg uninstalled; new gpg under `~/.local/opt/gnupg`; user env var `GNUPGHOME` set.
- **Downstream:** `corp-ssh-askpass.ps1` → gopass → gpg decryption restored.
- **Docs/memory:** `docs/corp-ssh-setup-windows.md`, `reference_scoop_gpg_gotchas.md`, `reference_chezmoi_external_cli_tools.md`, and the scoop→external migration roadmap memory updated.
