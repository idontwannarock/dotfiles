# Corp SSH Phase 2: Windows Native Port

**Status**: Design approved 2026-04-30. Implementation pending.
**Target platform**: Windows 11 with native OpenSSH ≥ 9.0 (verified on `OpenSSH_for_Windows_9.5p2`).
**Builds on**: [`2026-04-24-corp-ssh-redesign.md`](2026-04-24-corp-ssh-redesign.md) — Phase 1 (WSL/Linux), shipped commit `5a35758`.

## Problem

Phase 1 made corp ssh zero-input from WSL/Ubuntu via `ControlMaster` + `SSH_ASKPASS` driving `pass`/`pass-otp` against a local GPG-encrypted vault. The same developer also works from Windows-native PowerShell sessions (Windows Terminal, IDE-integrated terminals, scheduled tasks), where every corp ssh still requires manual password+OTP entry.

Phase 2 ports the Phase 1 architecture to Windows native, sharing the same GPG key and `~/.password-store/` so secrets do not need to be re-provisioned per platform.

## Goals

- **G1**. Phase 1's two-layer architecture (`ControlMaster` for connection reuse, `SSH_ASKPASS` for credential automation) works from Windows-native PowerShell with no manual input after initial setup.
- **G2**. Single source of truth for secrets: the GPG private key (fingerprint `24FC3F9C15EE7FB843F0DBBD405E281250CD6367`, ed25519+cv25519) and `~/.password-store/` directory are imported from WSL once; both platforms share the same encrypted vault format. Cross-platform sync is by manual dual-write at rotation time (acceptable for the current usage pattern).
- **G3**. PowerShell (5.1 and 7) is the primary shell. `cmd.exe` is out of scope — running `ssh.exe` directly from `cmd.exe` will not benefit from this automation.
- **G4**. No new sensitive data in this public repo. All corp-specific state (`hosts.yaml`, vault files, GPG keys, agent config) stays local under `%USERPROFILE%`.

## Non-Goals

- **macOS**. Phase 3+. Same architecture should port (`gopass` Homebrew, `pinentry-mac`); deferred.
- **Automated cross-platform vault sync**. `gopass git init` + private remote could replace dual-write. Deferred to Future Work; will reconsider once dual-write friction is observed.
- **Automated rotation**. Manual rotation, same as Phase 1 — when corp AD password changes the user runs `gopass insert -f corp/password` on each platform.
- **Re-evaluating cloud Bitwarden**. The Phase 1 spec's "Why local `pass` over cloud Bitwarden" reasoning still holds; not revisiting.

## Decision 4 Verification (2026-04-30)

Empirical findings on the user's Windows 11 box, recorded so future readers know what was actually verified vs. assumed:

| Check | Command | Result |
|---|---|---|
| `ssh.exe` source | `where.exe ssh` | `C:\Windows\System32\OpenSSH\ssh.exe` (Windows Optional Feature) |
| Version | `ssh -V` | `OpenSSH_for_Windows_9.5p2, LibreSSL 3.8.2` |
| ControlMaster parser support | `ssh -G localhost \| Select-String controlmaster` | `controlmaster false` (option recognized; default off because not yet configured) |

`SSH_ASKPASS_REQUIRE=force` behaviour and ControlMaster named-pipe runtime correctness are **assumed-pending-test**: not verified on this version until end-to-end smoke test in deployment phase. Per Decision 4-B (layered scope), Layer 2 (SSH_ASKPASS automation) is required; Layer 1 (ControlMaster) is best-effort — if the named-pipe implementation misbehaves on 9.5p2, every ssh first-auth re-runs askpass (still zero-input, just slower).

## Architecture

Identical two-layer model as Phase 1; only the mechanism changes per platform.

```
caller (PowerShell / VS Code terminal / scheduled task)
      │
      ▼
ssh.exe (C:\Windows\System32\OpenSSH\)
      │  reads %USERPROFILE%\.ssh\config:
      │    Host <corp-host-pattern>
      │      ControlMaster auto
      │      ControlPath ~/.ssh/cm/%C
      │      ControlPersist 8h
      │
      ├─ named-pipe socket live → reuse, 0 prompts (Layer 1, best-effort)
      │
      └─ no socket / expired / unsupported → need interactive auth
             │  SSH_ASKPASS_REQUIRE=force → invoke helper instead of TTY
             ▼
        %USERPROFILE%\.local\bin\corp-ssh-askpass.cmd  (3-line shim)
             │  → forwards to corp-ssh-askpass.ps1 via pwsh/powershell
             ▼
        corp-ssh-askpass.ps1  (~50 LOC PowerShell)
             │  1. parse hostname from prompt
             │  2. allowlist check against ~/.corp-ssh/hosts.yaml
             │  3. if known: gopass show -o $passPath/password
             │              | gopass otp $passPath/totp
             │     (gopass.exe → gpg.exe → gpg-agent.exe cache)
             │  4. unknown / malformed: exit 1
             ▼
        credential on stdout (bare LF, no BOM) → ssh.exe submits
        → master socket established (Layer 1) for next 8h
```

**Cold-cache path (passphrase prompt)**: When `gpg-agent.exe` has no cached passphrase, `gpg.exe` invokes `pinentry-basic.exe` (bundled with Scoop's `gpg` package) which displays a small Win32 dialog. User types passphrase once; cache lives 8h (`default-cache-ttl 28800` in `gpg-agent.conf`). The askpass helper itself is GUI-free; only the GPG-passphrase entry triggers a dialog, and only when the cache is cold.

## Components

### Repo files (chezmoi-managed, public-safe)

| Path | Purpose |
|---|---|
| `dot_local/bin/corp-ssh-askpass.ps1` | PowerShell helper, 1:1 logical port of `executable_corp-ssh-askpass` (bash). |
| `dot_local/bin/corp-ssh-askpass.cmd` | 3-line `.cmd` shim. Required because `ssh.exe`'s `CreateProcess(SSH_ASKPASS)` cannot launch `.ps1` directly. Prefers `pwsh.exe` (PS7, faster cold start), falls back to `powershell.exe` (PS5.1, always present). |
| `Documents/exact__shared-profile.d/30-ssh-askpass.ps1` | PowerShell profile fragment. Sets `$env:SSH_ASKPASS` and `$env:SSH_ASKPASS_REQUIRE='force'` if helper is installed. Loaded by both PS5 and PS7 profiles via the existing shared-fragment loader. |
| `.chezmoiignore.tmpl` (modified) | Per-platform exclusions: bash helper for non-Linux; ps1+cmd helpers for non-Windows; profile fragment for non-Windows. |
| `run_once_install-cli-tools.ps1.tmpl` (modified) | Add `Install-ScoopPackage "gpg"` and `Install-ScoopPackage "gopass"`. |
| `docs/corp-ssh-setup-windows.md` | New Windows-side setup guide, ~250 lines. Mirrors `docs/corp-ssh-setup.md` structure with Windows specifics. |
| `docs/corp-ssh-setup.md` (cross-ref edit) | Add link to Windows guide; update "Known limitations" to drop "WSL/Ubuntu only for now". |
| `docs/superpowers/specs/2026-04-24-corp-ssh-redesign.md` (cross-ref edit) | "Future Work → Windows OpenSSH port" bullet links here. |

### Local, not in repo, not chezmoi-managed

| Path | Purpose | How it gets there |
|---|---|---|
| `%APPDATA%\gnupg\gpg-agent.conf` | 8h cache TTL (`default-cache-ttl 28800` / `max-cache-ttl 28800`) | Manual setup step. Not chezmoi-managed so user can adjust without merge churn. |
| `%APPDATA%\gnupg\` (private keyring) | GPG private key import target | `gpg --import` against the user's existing key backup. |
| `%USERPROFILE%\.password-store\` | Encrypted vault | One-time copy from `\\wsl$\Ubuntu\home\<user>\.password-store\`. Maintained by dual-write at rotation. |
| `%USERPROFILE%\.corp-ssh\hosts.yaml` | Allowlist + `pass_path` prefix | Copy from WSL or hand-create from template. |
| `%USERPROFILE%\.ssh\config` (additions) | `Host` block with ControlMaster | Manual edit; same block as Phase 1 (`%C` ControlPath, 8h `ControlPersist`). |
| `%USERPROFILE%\.ssh\cm\` | ControlMaster named-pipe socket directory | `New-Item -ItemType Directory`. |

## Detailed Design

### `corp-ssh-askpass.ps1` (helper)

PowerShell 5.1+ compatible. ~50 LOC excluding header. Mirrors the bash version's logic step-for-step: prompt-parse, allowlist check, `pass_path` resolution, prompt-content dispatch (OTP branch first to defeat substring-swallow), post-hoc validation with stderr hint.

Key implementation decisions:

- **`$args[0]`** for prompt input. `ssh.exe` invokes the helper with the prompt text as argv[1].
- **`-match` operator + `$matches`** for regex capture (PowerShell native, no `[regex]::Match` needed).
- **`& gopass show -o ...`** — the `-o` (output-only) flag is required because `gopass show` without flags prints metadata in addition to the password. Linux `pass` does not have this distinction.
- **`& gopass otp ...`** — gopass has TOTP support built in; no extension package needed (vs. `pass-otp` on Linux).
- **`$LASTEXITCODE`** captures gopass's exit code; mirrors bash's `|| rc=$?` pattern.
- **`[Console]::Error.WriteLine()`** for stderr (visible in `ssh -v`); mirrors `echo ... >&2`.
- **`[Console]::Out.Write($out + "`n")`** for stdout. Critical: `Write-Output` adds `\r\n` on Windows, and sshd rejects passwords containing `\r`. Direct .NET `TextWriter` writes precise bytes; combined with `00-encoding.ps1`'s `$OutputEncoding = UTF8 (no BOM)` this produces clean ASCII bytes terminated with a single LF.
- **No `try`/`catch` for `gopass` calls**. Native command failures don't throw in PowerShell; `$LASTEXITCODE` plus stdout-empty check catches all failure modes.

### `corp-ssh-askpass.cmd` (shim)

```cmd
@echo off
where /q pwsh
if %ERRORLEVEL% EQU 0 (
    pwsh       -NoProfile -ExecutionPolicy Bypass -File "%~dp0corp-ssh-askpass.ps1" %*
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0corp-ssh-askpass.ps1" %*
)
```

- `where /q pwsh` is silent; just sets `%ERRORLEVEL%`.
- `pwsh.exe` cold start ≈ 80ms; `powershell.exe` ≈ 200ms. The fallback exists so users without PS7 still work.
- `-NoProfile` skips loading the user's PS profile (faster + avoids any side effects).
- `-ExecutionPolicy Bypass` is per-invocation; does not change machine policy.
- `"%~dp0corp-ssh-askpass.ps1"` resolves the .ps1 relative to the .cmd's location — they live side by side in `~/.local/bin/`.
- `%*` forwards the prompt text. `ssh.exe` quotes the prompt argument; `cmd.exe`'s arg-passing preserves quotes for shells. SSH prompts contain no shell metacharacters (`(user@host) Password:` form), so no escaping risk.

### `30-ssh-askpass.ps1` (profile fragment)

```powershell
# 30-ssh-askpass.ps1 — Wire ssh.exe to corp-ssh-askpass helper for password+OTP hosts.
$askpassCmd = Join-Path $env:USERPROFILE '.local\bin\corp-ssh-askpass.cmd'
if (Test-Path -LiteralPath $askpassCmd) {
    $env:SSH_ASKPASS = $askpassCmd
    $env:SSH_ASKPASS_REQUIRE = 'force'
}
```

Naming: prefix `30-` places it after `00-encoding`, `10-aliases`, `20-functions` and before `90-prompt`, `95-dotfiles-update`. The shared loader at `Documents/PowerShell/Microsoft.PowerShell_profile.ps1` reads `Documents/_shared-profile.d/*.ps1` sorted by name, so prefix ordering is deterministic.

**Per-shell, not system-wide**, by design. Mirrors Linux `.bashrc` scoping. Trade-off (documented): IDE-spawned `ssh.exe` (e.g., VS Code's git integration) does not inherit these env vars unless the IDE's terminal is PowerShell that loaded this profile. The `[Environment]::SetEnvironmentVariable(..., 'User')` alternative would persist to user-registry and reach all processes, but `SSH_ASKPASS_REQUIRE=force` is too invasive globally — it would change `ssh.exe` behaviour for tools that explicitly want TTY prompts.

### `.chezmoiignore.tmpl` modifications

Replace the existing single-line block:

```gotemplate
# ── corp-ssh-askpass（只部署到 Linux/WSL，Windows/macOS 排除）─────────
{{- if ne .chezmoi.os "linux" }}
.local/bin/corp-ssh-askpass
{{- end }}
```

with a per-platform matrix:

```gotemplate
# ── corp-ssh-askpass: bash helper deploys on Linux/WSL only ─────────
{{- if ne .chezmoi.os "linux" }}
.local/bin/corp-ssh-askpass
{{- end }}

# ── corp-ssh-askpass: PowerShell helper + .cmd shim deploy on Windows only ──
{{- if ne .chezmoi.os "windows" }}
.local/bin/corp-ssh-askpass.ps1
.local/bin/corp-ssh-askpass.cmd
{{- end }}

# ── PowerShell profile fragment: Windows only ───────────────────────
{{- if ne .chezmoi.os "windows" }}
Documents/_shared-profile.d/30-ssh-askpass.ps1
{{- end }}
```

The `Documents/` ignore for non-Windows already exists at the top of the file; the explicit per-fragment ignore is defense-in-depth in case the broader rule is restructured.

### `run_once_install-cli-tools.ps1.tmpl` additions

Append to the existing Scoop install block:

```powershell
# ── GPG + password store for corp-ssh-askpass ────────────────────────────
Install-ScoopPackage "gpg"
Install-ScoopPackage "gopass"
```

`Install-ScoopPackage` is the existing helper; checks `Get-Command` first, skips if installed. `gpg` is the minimal GnuPG package (includes `pinentry-basic.exe`); no Kleopatra GUI.

## Cross-Platform Vault Sharing

**One-time GPG key import**:

```powershell
gpg --import <path-to-corp-ssh-key.asc>
gpg --list-secret-keys                          # verify FPR matches Phase 1
gpg --edit-key 24FC3F9C15EE7FB843F0DBBD405E281250CD6367
  > trust
  > 5                                            # ultimate trust (this is my key)
  > save
```

**`gpg-agent.conf`** (manual, not chezmoi-managed):

```powershell
$gnupgHome = Join-Path $env:APPDATA 'gnupg'
New-Item -ItemType Directory -Path $gnupgHome -Force | Out-Null
@'
default-cache-ttl 28800
max-cache-ttl 28800
'@ | Set-Content -Path (Join-Path $gnupgHome 'gpg-agent.conf') -Encoding ascii
gpg-connect-agent reloadagent /bye
```

**Vault copy** (one-time, manual):

```powershell
$src = '\\wsl$\Ubuntu\home\<wsl-user>\.password-store'
$dst = Join-Path $env:USERPROFILE '.password-store'
Copy-Item -Path $src -Destination $dst -Recurse -Force
gopass list                                      # verify entries decrypt
```

The vault contents are GPG-encrypted `.gpg` files; bytes are platform-independent, so direct copy through the `\\wsl$\` UNC path is safe. No CRLF translation is involved (binary read).

**`hosts.yaml` copy** (one-time):

```powershell
$src = '\\wsl$\Ubuntu\home\<wsl-user>\.corp-ssh\hosts.yaml'
$dst = Join-Path $env:USERPROFILE '.corp-ssh\hosts.yaml'
New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null
Copy-Item -Path $src -Destination $dst -Force
```

**Rotation** (manual dual-write):

```bash
# WSL
pass insert -f corp/password
```

```powershell
# Windows
gopass insert -f corp/password
```

WSL and Windows `gpg-agent` instances are independent daemons — caches do not share. First call after switching platforms always re-prompts for passphrase. Accepted trade-off.

## Setup Guide Outline (`docs/corp-ssh-setup-windows.md`)

| § | Section | Content |
|---|---|---|
| 1 | What this does | Mirrors Linux opener; adds "shared vault with WSL" line. |
| 2 | Prerequisites | Table: OpenSSH ≥ 9.0 (verify `ssh -V`), Scoop, `scoop install gpg gopass`. |
| 3.A | Setup (existing WSL) | Steps A.1–A.10 covering scoop install, GPG key import + trust, gpg-agent.conf, vault copy, hosts.yaml copy, `chezmoi apply`, profile reload, cache warm, ssh config edit, smoke test. |
| 3.B | Setup (fresh Windows, no WSL) | Alternative: `gpg --quick-generate-key`, `gopass init <FPR>`, `gopass insert corp/password`, `gopass otp insert corp/totp`. **Out of scope for this implementation's testing** — §3.A (existing-WSL path) is the deployment path; §3.B is documented for future colleagues or future Windows-only setup but not exercised end-to-end now. |
| 4 | How it works | Layer 1 + Layer 2 with Windows-specific notes (named pipe, pinentry-basic, profile fragment). |
| 5 | Troubleshooting | Table including: profile not loaded, `'powershell' not recognized`, GPG decryption failures, GUI dialog hidden behind windows, IDE git not inheriting env, ControlMaster failure (graceful degradation). |
| 6 | Known limitations | macOS deferred (Phase 3+); ControlMaster best-effort; vault sync manual. |
| 7 | Cross-references | Linux guide; Phase 1 design spec; this design spec. |

## Considered Alternatives

### Helper invocation: PowerShell rewrite vs. Git Bash + `.cmd` wrapper

PowerShell rewrite chosen. Trade-offs:

|  | PowerShell rewrite (chosen) | Git Bash + `.cmd` |
|---|---|---|
| Cold start | `pwsh` ~80ms / `powershell` ~200ms | `bash.exe` ~200-400ms on Windows (fork/exec is heavy) |
| Dependencies | Built-in (PS5.1) or Scoop `pwsh` | Requires Git for Windows installed |
| Source duplication | Two helpers (bash + ps1) to maintain | One source-of-truth bash helper |
| Encoding pitfalls | Need to use `[Console]::Out.Write` for clean stdout | Bash `printf` is naturally LF-only; but `bash.exe` stdin/stdout pipe encoding is its own minefield (CRLF, UTF-8 BOM, locale issues) |

The duplication cost is small (~50 LOC, 1:1 logical correspondence). PowerShell wins on cold start (matters since askpass is invoked 1-2 times per ssh first-auth) and removes the implicit Git-for-Windows dependency.

### Password store: `gopass` vs. `pass` via MSYS2 vs. cloud

`gopass` chosen. `pass` via MSYS2 was rejected because it requires installing the entire MSYS2 runtime and battles with Git Bash for PATH. Cloud (Bitwarden / Vaultwarden) was rejected for the same reasons as Phase 1: single-user single-credential use case does not justify SaaS or always-on container.

### GPG: Gpg4win (Scoop `gpg`) vs. Git for Windows bundled `gpg` vs. WSL cross-call

Scoop `gpg` chosen — minimal binary, includes `pinentry-basic.exe`, no GUI suite. Git for Windows ships an older `gpg` (typically 2.2.x) with limited pinentry support and conflicts on PATH if both are installed. WSL cross-call (`wsl gpg ...`) was rejected for ~500ms cold-start penalty per invocation and inability to share gpg-agent cache across the WSL boundary.

### `pinentry`: GUI dialog (`pinentry-basic.exe`) vs. CLI

GUI accepted. CLI alternatives all impose unreasonable cost: `pinentry-curses` requires MSYS2 (~400MB) plus complex TTY forwarding from a non-TTY askpass invocation; `gpg-preset-passphrase` defeats the agent threat model. `pinentry-basic.exe` is a small Win32-API dialog bundled with Scoop's `gpg` package — zero extra deps, fires once per 8h cache TTL.

### Env var setting: per-shell PowerShell profile vs. user-wide registry

Per-shell chosen. `[Environment]::SetEnvironmentVariable(..., 'User')` would set `SSH_ASKPASS_REQUIRE=force` for every process the user starts, including IDE-spawned `ssh.exe` for git operations. Helper declines unknown prompts so it would not leak credentials, but globally forcing `SSH_ASKPASS_REQUIRE=force` changes `ssh.exe` behaviour in ways that could break tools expecting TTY prompts.

### `gpg-agent.conf`: chezmoi-managed vs. manual

Manual chosen. The file is small (2 lines) and users frequently customize it (e.g., `pinentry-program` selection). chezmoi management would either fight user changes or require complex modify-script logic. Phase 1's `docs/corp-ssh-setup.md` follows the same pattern.

## Deployment Plan

| Phase | Action | Verification |
|---|---|---|
| **W0** | Confirm Win32-OpenSSH is in PATH and version ≥ 9.0 | `ssh -V` shows `OpenSSH_for_Windows_9.x` |
| **W1** | Author `dot_local/bin/corp-ssh-askpass.ps1` in chezmoi source | `Test-Path` passes; PSScriptAnalyzer (if available) clean |
| **W2** | Author `dot_local/bin/corp-ssh-askpass.cmd` shim | File created, content matches design |
| **W3** | Author `Documents/exact__shared-profile.d/30-ssh-askpass.ps1` | File created, content matches design |
| **W4** | Update `.chezmoiignore.tmpl` per-platform matrix | `chezmoi verify` passes on Windows |
| **W5** | Update `run_once_install-cli-tools.ps1.tmpl` to install `gpg` + `gopass` | Diff review |
| **W6** | Author `docs/corp-ssh-setup-windows.md` (sanitized, placeholders) | `grep` for sensitive tokens returns no hits |
| **W7** | Cross-reference edits to existing docs | Links resolve |
| **W8** | Commit P1-P7 changes (single commit, as `feat(corp-ssh): Windows phase 2`) | `git status` clean |
| **W9** | User: `chezmoi apply` on Windows; `scoop install gpg gopass` if needed | Helper + shim + profile fragment present |
| **W10** | User: GPG key import + trust, `gpg-agent.conf`, vault copy, `hosts.yaml` copy | `gopass list` succeeds; `gopass show -o corp/password` succeeds |
| **W11** | User: `~/.ssh/config` ControlMaster block (best-effort) | `ssh -G <corp-host>` shows `controlmaster auto` |
| **W12** | Smoke test (Testing Plan below) | All cases pass |

W1–W8 are repo changes. W9–W12 are local Windows state changes.

## Testing Plan

### Happy path

1. **Cache warm, fresh ssh.** `gopass show -o corp/password >$null` (enter passphrase if first time). Then `ssh <corp-host> hostname`. Expected: returns hostname, no manual input.
2. **ControlMaster reuse (if Layer 1 works).** Run (1) again immediately. Expected: <500ms, no auth activity in `ssh -v`.
3. **ControlMaster degradation (if Layer 1 fails on 9.5p2).** If named-pipe master is non-functional, verify Layer 2 still carries each ssh: every connection re-runs askpass but still requires zero manual input as long as gpg-agent cache is warm.
4. **PowerShell session restart, cache still warm.** Close PowerShell, reopen, ssh again immediately. Expected: cache holds (gpg-agent is per-session daemon — persists until logout); no prompt.
5. **From IDE terminal (PowerShell).** Open VS Code integrated terminal (PowerShell), run `ssh <corp-host>`. Expected: zero input. Confirms profile fragment loaded in IDE terminal.

### Edge cases

1. **Cold cache.** `gpg-connect-agent reloadagent /bye`, then `ssh <corp-host>`. Expected: `pinentry-basic.exe` dialog appears for passphrase; after entry, ssh proceeds.
2. **Unknown host.** `ssh some-non-corp-host`. Expected: helper exits 1, ssh aborts current auth method without leaking corp credentials. With `SSH_ASKPASS_REQUIRE=force`, no TTY fallback — user gets `Permission denied`. Recovery: per-session `$env:SSH_ASKPASS_REQUIRE='never'; ssh some-non-corp-host`.
3. **From `cmd.exe` (out of scope).** Run `ssh.exe <corp-host>` directly from `cmd.exe`. Expected: env vars not set, ssh prompts on TTY. Document as "PowerShell only"; not a bug.
4. **From IDE git integration (e.g., VS Code git pull).** If IDE uses `ssh.exe` from a shell that didn't load the PowerShell profile, askpass won't be invoked. Document in troubleshooting.
5. **Passphrase-protected SSH key.** `SSH_ASKPASS_REQUIRE=force` intercepts the passphrase prompt. Helper exits 1 (prompt format mismatch). Documented constraint: keys used in this environment must be unencrypted, or user runs `$env:SSH_ASKPASS_REQUIRE='never'` per-session.
6. **`gopass.exe` not in PATH.** Helper invocation fails with `LASTEXITCODE` non-zero. Recovery: `scoop install gopass` then new PowerShell session.
7. **GUI dialog hidden behind other windows.** `pinentry-basic.exe` always opens centered on primary monitor; if hidden, Alt+Tab to surface. Documented in troubleshooting.

## Future Work

- **macOS port** (Phase 3). Same architecture; `gopass` from Homebrew, `pinentry-mac` for native dialog.
- **`gopass git init` for vault sync**. If dual-write rotation becomes painful, init the vault as a git repo with a private GitLab/GitHub remote; pull/push between platforms.
- **ControlMaster runtime verification on `OpenSSH_for_Windows_9.5p2`**. Empirically test whether the named-pipe implementation actually works for sustained sessions. If reliable, document as "verified on this version"; if not, contribute to upstream.
- **Pre-warm cache on profile load**. Optional fragment that runs `gopass show -o corp/password >$null` non-blockingly at PowerShell startup, consolidating the GUI dialog appearance to "once per terminal session".
- **Branch A (Kerberos) reactivation**. Same trigger as Phase 1: if IT enables IPA-native OTP preauth or provisions user certificates.

## Cross-references

- Phase 1 design: [`2026-04-24-corp-ssh-redesign.md`](2026-04-24-corp-ssh-redesign.md)
- Phase 1 setup guide: [`../corp-ssh-setup.md`](../../corp-ssh-setup.md)
- Phase 2 setup guide (to be written): `../corp-ssh-setup-windows.md`
