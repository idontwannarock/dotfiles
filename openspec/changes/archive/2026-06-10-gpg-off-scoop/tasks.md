## 1. Live-machine install + verify (test first, per project workflow)

- [x] 1.1 Resolve pinned GnuPG: version, build date, SHA-1 from gnupg.org (pinned 2.5.20_20260513 / sha1:6353C4A98C07B29250CE21BA0321E0D2ABD7D1CB)
- [x] 1.2 Download `gnupg-w32-<ver>_<date>.exe` to a temp path; verify SHA-1 matches the pin (VERIFIED OK)
- [x] 1.3 Confirm installer is NSIS and silent-install supports `/S /D=` (Nullsoft+NullsoftInst present)
- [x] 1.4 Silent-install into `~/.local/opt/gnupg/` via `& $installer /S /D=C:\Users\user\.local\opt\gnupg` (full suite, no gpgconf.ctl, gpg 2.5.20)
- [x] 1.5 Set user env `GNUPGHOME=%USERPROFILE%\.gnupg`; prepend `~/.local/opt/gnupg/bin` to PATH (User scope, for -NoProfile askpass inheritance)
- [x] 1.6 Verify: `gpgconf --list-dirs homedir` → `C:\Users\user\.gnupg`; no `bin\gpgconf.ctl`; `gpg --list-secret-keys` shows corp key
- [x] 1.7 `ssh dev-livekit` AUTHENTICATES ✓ (verified by user). Full fix chain required: GUI pinentry-w32 (gpg-agent.conf repoint), wipe stale `~/.gnupg/S.gpg-agent*` sockets (04-30), self-contained PATH/GNUPGHOME bootstrap in askpass.ps1, AND — the final blocker — removing an **orphaned clink cmd.exe AutoRun** (`HKCU\...\Command Processor\AutoRun` → deleted `clink.bat`) that broke the askpass cmd.exe→ssh stdout handoff. clink was already uninstalled; only the dead AutoRun remained (pre-existing, unrelated to gpg). Backed up to `~/.corp-ssh/autorun-backup.txt`.
- [x] 1.8 `scoop uninstall gpg` done; removed orphaned `scoop\shims\gpg.{exe,shim}` (was hijacked to git gpg); `gpg` → owned install

## 2. Encode into chezmoi source

- [x] 2.1 Created `run_onchange_install-gnupg.ps1.tmpl` (ASCII, no BOM needed): pinned version/date/SHA-1, idempotent version guard, download+SHA-1 verify, NSIS `/S /D=` install, User GNUPGHOME+PATH, gpg-agent.conf (GUI pinentry), checkver comment. Plus `run_once_after_migrate-scoop-wave8-gpg.ps1.tmpl` (scoop uninstall + orphaned shim/socket cleanup + orphaned clink AutoRun fix)
- [x] 2.2 Wired `GNUPGHOME` + PATH at **User env** scope inside the install script (not a profile.d fragment — askpass runs -NoProfile so a fragment wouldn't reach it). Added self-contained PATH/GNUPGHOME bootstrap to `dot_local/bin/corp-ssh-askpass.ps1`; fixed stale pinentry comment in `30-ssh-askpass.ps1`
- [x] 2.3 Removed `Install-ScoopPackage "gpg"` from `run_once_install-cli-tools.ps1.tmpl`, rewrote comment to point at the new scripts
- [x] 2.4 No `.chezmoiignore` needed — run scripts self-exclude via `{{ if eq .chezmoi.os "windows" }}` guard (repo convention); `.gitattributes` default handling fine for `.ps1.tmpl` (PowerShell parses LF/CRLF)

## 3. Verify encoded path reproduces working state

- [x] 3.1 Rendered + executed `run_onchange_install-gnupg` → idempotent no-op ("2.5.20 already installed, skipping"); avoided full `chezmoi apply` to not deploy unrelated in-flight claude-zai changes; targeted `chezmoi apply --force` synced askpass; 9/9 Pester tests pass
- [x] 3.2 `chezmoi execute-template` renders both new scripts with correct pinned values; askpass diff empty after sync

## 4. Docs + memory

- [x] 4.1 Updated `docs/corp-ssh-setup-windows.md` (prerequisites + A.3: gpg self-managed off scoop, homedir ~/.gnupg not %APPDATA%, GUI pinentry)
- [x] 4.2 Updated memory: `reference_scoop_gpg_gotchas.md` (SUPERSEDED banner), new `reference_corp_ssh_windows_askpass_chain.md` (5-layer chain incl. clink), MEMORY.md index (Wave 8 + new refs)
- [x] 4.3 7-Zip-off-scoop decision recorded in conversation/design (decoupled, NSIS `/S` needs no extractor); nvm remains the open archive-pattern candidate
