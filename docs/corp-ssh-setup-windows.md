# Corp SSH Setup: Password+OTP Automation (Windows)

A Windows-native port of the WSL/Linux corp-ssh automation. Same
architecture (Layer 1 ControlMaster + Layer 2 SSH_ASKPASS), Windows
mechanisms (PowerShell helper, gopass.exe, Gpg4win).

Design rationale and Phase 1/2 deltas:
[`docs/superpowers/specs/2026-04-30-corp-ssh-windows-phase2-design.md`](superpowers/specs/2026-04-30-corp-ssh-windows-phase2-design.md).

For the WSL/Linux side, see [`corp-ssh-setup.md`](corp-ssh-setup.md).

## What this does

After setup:

- First ssh to a corp host per session requires zero manual input
  (credentials supplied automatically from gopass via gpg-agent cache).
- ControlMaster (best-effort on `OpenSSH_for_Windows_9.5p2`) reuses the
  authenticated socket for 8 hours — subsequent ssh/scp/rsync to the same
  host avoid re-auth entirely.
- Vault is shared with WSL: same GPG key, same `~/.password-store/`.
  Password rotation requires manual dual-write across both platforms.

## Prerequisites

| Dependency | Used for | Install |
|---|---|---|
| Win32-OpenSSH ≥ 9.0 | ssh.exe with SSH_ASKPASS support | Bundled with Windows 11 (Optional Feature) — verify `ssh -V` |
| Scoop | Package management for `gpg`/`gopass` | https://scoop.sh |
| `gpg` (Scoop) | GnuPG 2.x + `gpg-agent.exe` + `pinentry-basic.exe` | `scoop install gpg` |
| `gopass` (Scoop) | `pass`-compatible native binary; built-in TOTP | `scoop install gopass` |
| PowerShell 7 (optional) | Faster cold-start for askpass helper (`pwsh.exe` ~80ms vs `powershell.exe` ~200ms) | `winget install Microsoft.PowerShell` |

The `chezmoi apply` step (below) installs `gpg` + `gopass` automatically via
the existing `run_once_install-cli-tools.ps1.tmpl`.

## Setup, Path A: Existing WSL deployment

This is the path if you already completed Phase 1 setup on WSL/Ubuntu and
just need the same vault accessible from Windows.

### A.1 Run chezmoi apply (deploys helper + shim + profile fragment)

```powershell
chezmoi apply
```

After apply, verify:
```powershell
Test-Path ~\.local\bin\corp-ssh-askpass.ps1
Test-Path ~\.local\bin\corp-ssh-askpass.cmd
Test-Path ~\Documents\_shared-profile.d\30-ssh-askpass.ps1
```
All three should return `True`.

### A.2 Import the GPG private key

Locate your GPG private key backup (`.asc` file produced on WSL via
`gpg --export-secret-keys --armor <FPR> > corp-ssh-key.asc`).

```powershell
gpg --import path\to\corp-ssh-key.asc
gpg --list-secret-keys
```

Verify the fingerprint matches your WSL setup. Then mark the key as
ultimately trusted (it's your own key):

```powershell
gpg --edit-key <FPR>
# At the gpg> prompt:
# trust
# 5
# y
# save
```

### A.3 Configure gpg-agent (8h cache TTL)

```powershell
$gnupgHome = Join-Path $env:APPDATA 'gnupg'
New-Item -ItemType Directory -Path $gnupgHome -Force | Out-Null
@'
default-cache-ttl 28800
max-cache-ttl 28800
'@ | Set-Content -Path (Join-Path $gnupgHome 'gpg-agent.conf') -Encoding ascii
gpg-connect-agent reloadagent /bye
```

### A.4 Copy the vault from WSL

```powershell
$src = '\\wsl$\Ubuntu\home\<wsl-user>\.password-store'
$dst = Join-Path $env:USERPROFILE '.password-store'
Copy-Item -Path $src -Destination $dst -Recurse -Force
```

Replace `<wsl-user>` with your WSL username. If your WSL distro is named
something other than `Ubuntu`, adjust the UNC path accordingly
(`\\wsl$\<distro>\...`).

Verify:
```powershell
gopass list
```
Should list at least `corp/password` and `corp/totp`.

### A.5 Copy hosts.yaml from WSL

```powershell
$src = '\\wsl$\Ubuntu\home\<wsl-user>\.corp-ssh\hosts.yaml'
$dst = Join-Path $env:USERPROFILE '.corp-ssh\hosts.yaml'
New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null
Copy-Item -Path $src -Destination $dst -Force
```

Verify:
```powershell
Get-Content ~\.corp-ssh\hosts.yaml
```
Should show `pass_path:` and `password_otp_hosts:` entries.

### A.6 Reload PowerShell profile

Close all PowerShell windows and open a fresh one (or: `. $PROFILE`). Then:
```powershell
$env:SSH_ASKPASS
$env:SSH_ASKPASS_REQUIRE
```
Both should be set: SSH_ASKPASS to `<userprofile>\.local\bin\corp-ssh-askpass.cmd`,
SSH_ASKPASS_REQUIRE to `force`.

If empty, the profile fragment isn't loading — check
`Test-Path ~\Documents\_shared-profile.d\30-ssh-askpass.ps1`.

### A.7 Warm gpg-agent cache

```powershell
gopass show -o corp/password >$null
```

A `pinentry-basic.exe` dialog appears. Type your GPG passphrase. After
this, the cache stays warm for 8 hours.

### A.8 Add ControlMaster to ~/.ssh/config (best-effort)

Append to `~\.ssh\config`:

```
# ──── Corp hosts with password+OTP — enable connection multiplexing ─────────
Host <corp-host-pattern-1> <corp-host-pattern-2>
  ControlMaster auto
  ControlPath ~/.ssh/cm/%C
  ControlPersist 8h
```

Create the socket directory:
```powershell
New-Item -ItemType Directory -Path ~\.ssh\cm -Force | Out-Null
```

ControlMaster on Win32-OpenSSH 9.5p2 uses named pipes (vs. Unix sockets
on Linux). The option is parser-supported (`ssh -G localhost` shows
`controlmaster false` as default). If runtime named-pipe ControlMaster
misbehaves on your version, simply omit the `Host` block — Layer 2
(askpass) still works standalone, you just re-auth on every ssh.

### A.9 Smoke test

```powershell
ssh <corp-host> hostname
```
Expected: returns the host's hostname with no manual input. Repeat — should
be near-instant if ControlMaster is working.

If you see `Permission denied`, run with `-v` and check stderr for
`corp-ssh-askpass: gopass failed`. That indicates a cold cache; warm it
manually with A.7.

## Setup, Path B: Fresh Windows (no WSL)

(Out of scope for this implementation's testing. Documented for future
colleagues or Windows-only setups.)

Same as Path A but replace A.2–A.5 with:

```powershell
# Generate a new key (interactive — set passphrase)
gpg --quick-generate-key 'corp-ssh local <your-email>' future-default default 0
gpg --list-secret-keys                                # note the FPR

# Initialize the vault and store credentials
gopass init <FPR>
gopass insert corp/password                           # paste password
gopass otp insert corp/totp                           # paste otpauth://totp/... URI
# (or `gopass otp insert -s corp/totp` if you only have the base32 secret)

# Create hosts.yaml
New-Item -ItemType Directory -Path ~\.corp-ssh -Force | Out-Null
@'
pass_path: corp

password_otp_hosts:
  - <actual-host-1>.<corp-domain>
  - <actual-host-2>
'@ | Set-Content -Path ~\.corp-ssh\hosts.yaml -Encoding ascii
```

Then continue with A.6–A.9.

## How it works

Two layers, both leveraging native ssh.exe mechanisms:

**Layer 1 — connection reuse (ControlMaster, best-effort)**. On `OpenSSH_for_Windows_9.x`,
ControlMaster uses named pipes (Windows equivalent of Unix sockets). After
the first authenticated ssh, subsequent calls within `ControlPersist 8h`
reuse the named-pipe connection — no auth, near-instant.

**Layer 2 — non-interactive credential entry (`SSH_ASKPASS` + `SSH_ASKPASS_REQUIRE=force`)**.
When ssh.exe needs to prompt, instead of reading from terminal it invokes
`SSH_ASKPASS` (which points at `corp-ssh-askpass.cmd` → forwards to
`corp-ssh-askpass.ps1`). The helper parses the hostname out of the prompt,
looks it up in `~/.corp-ssh/hosts.yaml`, calls `gopass show -o` (or
`gopass otp`), and writes the credential to stdout. ssh.exe reads stdout
as the response.

`gopass` decrypts via `gpg.exe`, which talks to `gpg-agent.exe` over a
Windows named pipe. As long as gpg-agent has the GPG passphrase cached
(8h TTL), no `pinentry-basic.exe` dialog fires and the helper completes
silently. Cold cache → dialog appears once.

The helper is GUI-free; only the GPG-passphrase entry triggers a dialog,
and only when the cache is cold.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `ssh <corp-host>` still prompts on TTY | PowerShell profile not loaded | Close + reopen PowerShell, or `. $PROFILE`. Verify `$env:SSH_ASKPASS_REQUIRE` is `force`. |
| `'powershell' is not recognized` from `.cmd` | Running ssh.exe directly from cmd.exe with no PATH | This setup is PowerShell-only by design. Run from a PowerShell session. |
| `Permission denied`, `ssh -v` shows `corp-ssh-askpass: gopass failed` | gpg-agent cache cold | `gopass show -o corp/password >$null` to warm cache (dialog appears once). |
| `gopass: decryption failed: No secret key` | GPG key not imported, or trust not set | `gpg --list-secret-keys`; `gpg --edit-key <FPR> trust 5 save`. |
| Pinentry dialog appears but I can't see it | Hidden behind other windows | Alt+Tab through. `gpg-connect-agent reloadagent /bye` to retry if stuck. |
| `ssh -G <corp-host>` shows `controlmaster false` despite config | Block in `~/.ssh/config` not matching `<corp-host>` pattern | Verify `Host` line scope; `ssh -F /dev/null -G <corp-host>` to bypass config and confirm baseline. |
| ssh from VS Code git integration fails | IDE-spawned ssh.exe didn't inherit profile env vars | Configure IDE to use PowerShell as default shell; or set env vars in IDE settings. |
| `controlpath too long` error | Using `%r@%h:%p` instead of `%C` | Use `%C` (40-char hash). Spec § Components for rationale. |
| `where /q pwsh` reports false but `pwsh` works in shell | PATH not refreshed since install | Open new PowerShell session. |

### When the password rotates

Phase 1 (WSL) and Phase 2 (Windows) maintain independent vault copies.
On rotation, dual-write:

```bash
# WSL
pass insert -f corp/password
```

```powershell
# Windows
gopass insert -f corp/password
```

Future work: `gopass git init` + private remote could replace dual-write.
Tracked in spec.

### Forcing a passphrase re-prompt

```powershell
gpg-connect-agent reloadagent /bye
```

Next `gopass show` (or first corp ssh) will prompt again.

## Known limitations and future work

- **macOS deferred** (Phase 3+). Same architecture expected to apply.
- **ControlMaster best-effort** on `OpenSSH_for_Windows_9.5p2`. Layer 2
  (askpass) carries everything if Layer 1 misbehaves.
- **No automated vault sync.** Manual dual-write at rotation. Tracked.
- **PowerShell-only.** ssh.exe from cmd.exe or environment without
  profile-loaded shell does not benefit from this automation.

## Why not Kerberos / GSSAPI?

Same answer as Phase 1 — see
[`corp-ssh-setup.md` § Why not Kerberos](corp-ssh-setup.md#why-not-kerberos--gssapi)
for the full investigation. If IT later enables IPA-native OTP preauth or
provisions user certificates, the Kerberos path becomes viable on both
WSL and Windows without code changes here.
