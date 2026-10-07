# Corp SSH Setup: Password+OTP Automation (Windows)

A Windows-native port of the WSL/Linux corp-ssh automation. Same
architecture (Layer 1 ControlMaster + Layer 2 SSH_ASKPASS), Windows
mechanisms (PowerShell helper, Bitwarden CLI `bw serve`, a logon scheduled
task that unlocks it).

Design rationale and Phase 1/2 deltas:
[`openspec/changes/archive/2026-04-30-corp-ssh-windows-phase2/design.md`](../openspec/changes/archive/2026-04-30-corp-ssh-windows-phase2/design.md).
That design predates the move from `gopass` to Bitwarden; the two-layer
architecture is unchanged.

For the WSL/Linux side, see [`corp-ssh-setup.md`](corp-ssh-setup.md).

## What this does

After setup:

- First ssh to a corp host per session requires zero manual input.
  The helper reads the credentials from `bw serve` on `localhost:8087`.
- ControlMaster (best-effort on `OpenSSH_for_Windows_9.5p2`) reuses the
  authenticated socket for 8 hours — subsequent ssh/scp/rsync to the same
  host avoid re-auth entirely.
- The Windows logon unlocks `bw serve` with no prompt. One unlock lasts until
  logoff or reboot.
- One vault serves Windows and WSL. The WSL helper calls the same `bw serve`
  on Windows. To rotate the AD password, update the `corp` item once.

## Prerequisites

| Dependency | Used for | Install |
|---|---|---|
| Win32-OpenSSH ≥ 9.0 | ssh.exe with SSH_ASKPASS support | Bundled with Windows 11 (Optional Feature) — verify `ssh -V` |
| Git for Windows | Provides bash (chezmoi `sh`) | Scoop or https://gitforwindows.org |
| Bitwarden CLI (`bw`) | Runs `bw serve`, the local vault API | `winget install Bitwarden.CLI` |
| Bitwarden account | The vault that holds the corp items; TOTP storage requires Premium | See [the account and items section](corp-ssh-setup.md#2-set-up-the-bitwarden-account-and-items) |
| PowerShell 7 (optional) | Faster cold-start for askpass helper (`pwsh.exe` ~80ms vs `powershell.exe` ~200ms) | `winget install Microsoft.PowerShell` |

chezmoi may still install GnuPG and `gopass` for other tools. corp-ssh does
not use them.

**`bw` may not be on `PATH`.** On the tested machine, winget did not create
the `bw` shim in `%LOCALAPPDATA%\Microsoft\WinGet\Links`. The full path is:

```
%LOCALAPPDATA%\Microsoft\WinGet\Packages\Bitwarden.CLI_Microsoft.Winget.Source_8wekyb3d8bbwe\bw.exe
```

`bw-serve-unlock.ps1` looks for `bw.exe` on `PATH` first, then falls back to
`%LOCALAPPDATA%\Microsoft\WinGet\Packages\Bitwarden.CLI_*\bw.exe`. For manual
commands, call it by full path when `bw` is not found:

```powershell
$bw = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Bitwarden.CLI_*\bw.exe" | Select-Object -First 1 -ExpandProperty FullName
& $bw --version
```

## Setup, Path A: Existing WSL deployment

This is the path if you already completed the WSL/Ubuntu setup and have
`~/.corp-ssh/hosts.yaml` there. The WSL side needs no local credential setup:
its helper uses the `bw serve` on Windows that this path sets up.

### A.1 Install the Bitwarden CLI and log in

```powershell
winget install Bitwarden.CLI
```

Open a new PowerShell window. For an account in the EU region, point `bw` at
the EU server first:

```powershell
bw config server https://vault.bitwarden.eu
```

Log in once:

```powershell
bw login
```

`bw login` asks for the email, the master password, and the two-step login
code. It prints a session key and suggests setting `BW_SESSION`. You do not
need it: `bw-serve-unlock.ps1` unlocks `bw serve` on its own.

If `bw` is not found, use the full path from [Prerequisites](#prerequisites).

### A.2 Create the items

Create the `corp` item and any `ssh-local/<label>/<host-key>` items as described in
[`corp-ssh-setup.md` § Set up the Bitwarden account and items](corp-ssh-setup.md#2-set-up-the-bitwarden-account-and-items).
If the credentials are still in `pass`, follow
[`corp-ssh-setup.md` § Migrating from `pass`](corp-ssh-setup.md#migrating-from-pass-one-time).

### A.3 Copy hosts.yaml from WSL

Do this **before** `chezmoi apply`. The logon task is registered only on a
machine that has `~/.corp-ssh/hosts.yaml` at apply time.

If a private workspace deploys `hosts.yaml` (see
[private-workspaces.md](private-workspaces.md)), skip the copy. Run
`chezmoi update` twice instead: the workspace writes the file after the public
scripts run, so the second run registers the logon task.

```powershell
$src = '\\wsl$\Ubuntu\home\<wsl-user>\.corp-ssh\hosts.yaml'
$dst = Join-Path $env:USERPROFILE '.corp-ssh\hosts.yaml'
New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null
Copy-Item -Path $src -Destination $dst -Force
```

Replace `<wsl-user>` with your WSL username. If your WSL distro is named
something other than `Ubuntu`, adjust the UNC path accordingly
(`\\wsl$\<distro>\...`).

Verify:
```powershell
Get-Content ~\.corp-ssh\hosts.yaml
```
Should show `pass_path:` and `password_otp_hosts:` entries.

### A.4 Run chezmoi apply (deploys helper + shim + unlock script + logon task + profile fragment)

```powershell
chezmoi apply
```

After apply, verify:
```powershell
Test-Path ~\.local\bin\corp-ssh-askpass.ps1
Test-Path ~\.local\bin\corp-ssh-askpass.cmd
Test-Path ~\.local\bin\bw-serve-unlock.ps1
Test-Path ~\Documents\_shared-profile.d\30-ssh-askpass.ps1
Get-ScheduledTask -TaskName bw-serve-unlock
```
The four `Test-Path` lines should return `True`, and the task should exist.

If the task is missing, `hosts.yaml` did not exist when `chezmoi apply` ran.
Create it (A.3) and run `chezmoi apply` again. The script that registers the
task (`run_onchange_register-bw-serve-unlock.ps1.tmpl`) renders only when
`hosts.yaml` exists, so creating the file makes the next apply run it.

### A.5 First unlock

The task runs at each logon. To run it now:

```powershell
Start-ScheduledTask -TaskName bw-serve-unlock
```

A console window opens. It starts `bw serve` hidden if it is not running,
then asks once for the Bitwarden master password:

```
Bitwarden master password (unlocks bw serve for corp-ssh):
```

After a successful unlock, the script stores the master password
DPAPI-encrypted at `%LOCALAPPDATA%\bw-serve-unlock\master.dpapi`, prints
`bw serve is unlocked.`, and the window closes by itself. Later logons use
the stored password and show no prompt.

Verify:
```powershell
curl.exe -s http://localhost:8087/status
```
The JSON must contain `"status":"unlocked"`.

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

### A.7 Add ControlMaster to ~/.ssh/config (best-effort)

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

### A.8 Smoke test

```powershell
ssh <corp-host> hostname
```
Expected: returns the host's hostname with no manual input. Repeat — should
be near-instant if ControlMaster is working.

Run the same command from WSL. It uses the same `bw serve` through
`curl.exe`.

If you see `Permission denied`, run with `-v` and check stderr for lines that
start with `corp-ssh-askpass:`. `bw serve not reachable or locked.` means
`bw serve` is stopped or locked; run A.5 again.

## Setup, Path B: Fresh Windows (no WSL)

(Out of scope for this implementation's testing. Documented for future
colleagues or Windows-only setups.)

Same as Path A, with two changes:

- A.2: create the items from scratch (there is no `pass` store to migrate).
- A.3: create `hosts.yaml` instead of copying it:

```powershell
New-Item -ItemType Directory -Path ~\.corp-ssh -Force | Out-Null
@'
pass_path: corp

password_otp_hosts:
  - <actual-host-1>.<corp-domain>
  - <actual-host-2>
'@ | Set-Content -Path ~\.corp-ssh\hosts.yaml -Encoding ascii
```

Then continue with A.4–A.8.

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
looks it up in `~/.corp-ssh/hosts.yaml`, asks `bw serve` for the item, and
writes the password or the current TOTP code to stdout. ssh.exe reads stdout
as the response.

**Requests per prompt.** For a Password prompt the helper first sends
`POST /sync`, so a password rotated in the vault reaches ssh at once. An
offline sync is not fatal: the cached vault still answers. The sync costs
about 0.5 s per real login. The OTP prompt skips the sync. One
`GET /list/object/items` returns the `corp` item and any
`ssh-local/<label>/<host-key>` item; the helper matches names exactly and
case-sensitively. The OTP answer comes from `GET /object/totp/<id>`.

**Fail closed.** When `bw serve` is stopped or locked, the helper exits 1
and writes `corp-ssh-askpass: bw serve not reachable or locked.` to stderr.
It never falls back to the shared password. When `bw serve` is not running
at all, the failure takes about 9 s, because Windows retries the refused
connection.

**The logon unlock.** `chezmoi apply` registers the scheduled task
`bw-serve-unlock`: trigger at logon, Interactive logon type,
`ExecutionTimeLimit` 0 so `bw serve` outlives the task. The task runs
`~/.local/bin/bw-serve-unlock.ps1`, which:

1. Starts `bw serve` hidden if `localhost:8087/status` does not answer.
2. Unlocks it with the master password from
   `%LOCALAPPDATA%\bw-serve-unlock\master.dpapi`. DPAPI lets only this Windows
   user, logged on, decrypt that file. So the Windows logon is what unlocks
   the vault.
3. Asks for the master password in its console window when the file is
   missing or the stored password fails (first run, or after a master
   password change), and stores the new one after it unlocks.
4. Syncs the vault and exits. The window closes by itself.

`bw serve` has no idle timeout. One unlock lasts until the `bw serve` process
stops (logoff or reboot) or until something calls `/lock`.

**Security.** `bw serve` has no authentication of its own. While it is
unlocked, any local process on Windows can call `localhost:8087` and read the
vault. The default origin protection of `bw serve` blocks browsers. That is
why the Bitwarden account holds only corp items. Do not expose `bw serve` on
any interface other than localhost.

`SSH_ASKPASS_REQUIRE=force` routes *every* ssh.exe question through the helper,
host-key confirmations included. The helper must not answer those with `exit 1`
-- that reads as "no", and `ssh <any-new-host>` then dies with
`Host key verification failed.` with no prompt shown. `Invoke-AskHuman` re-asks
the human instead: ssh.exe reads the helper's stdout as the answer, so the
question goes to the console device `CONOUT$`, and the reply comes from
`$Host.UI.ReadLine()` (host keys, echoed) or `ReadLineAsSecureString()`
(passwords, hidden). A redirected stdin means nobody is there to answer, and it
declines as before.

**The fingerprint line does not survive to the helper.** ssh.exe passes the
whole multi-line question as one argument, but `corp-ssh-askpass.cmd` forwards
it with `%*` and cmd.exe cuts an argument at its first newline. The helper
receives only `The authenticity of host '<host>' can't be established.`, so it
matches on that line and re-composes the yes/no question itself. Verify the
fingerprint out of band before answering:
`ssh-keyscan -t ed25519 <host> | ssh-keygen -lf -` from a host you trust.

## Troubleshooting

These checks are safe to run at any time. They print no secret.

- `curl.exe -s http://localhost:8087/status` — shows whether `bw serve` is
  running, and `locked` or `unlocked`.
- `Get-ScheduledTaskInfo -TaskName bw-serve-unlock` — shows when the logon
  unlock task last ran and its result.
- `ssh -v <corp-host>` — the helper's own messages start with
  `corp-ssh-askpass:`.

The unlock window closes as soon as the script ends, also after an error. To
read an error message, run the script in an open PowerShell window:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ~\.local\bin\bw-serve-unlock.ps1
```

| Symptom | Likely cause | Fix |
|---|---|---|
| `ssh <corp-host>` still prompts on TTY | PowerShell profile not loaded | Close + reopen PowerShell, or `. $PROFILE`. Verify `$env:SSH_ASKPASS_REQUIRE` is `force`. |
| `Host key verification failed.` on first connect to a new host, **no** yes/no prompt shown | Helper predates `Invoke-AskHuman`, or the session has no console (scheduled task, redirected stdin) | Re-apply `~/.local/bin/corp-ssh-askpass.ps1`. From a real PowerShell window the yes/no prompt must appear; from a script, verify out of band and use `ssh -o StrictHostKeyChecking=accept-new <host>` once. |
| `'powershell' is not recognized` from `.cmd` | Running ssh.exe directly from cmd.exe with no PATH | This setup is PowerShell-only by design. Run from a PowerShell session. |
| `Permission denied`, `ssh -v` shows `corp-ssh-askpass: bw serve not reachable or locked.` | `bw serve` is stopped (logoff, reboot, crash) or locked | `Start-ScheduledTask -TaskName bw-serve-unlock`, then retry. |
| Each corp ssh takes about 9 s and then fails | `bw serve` is not running; Windows retries the refused connection | `Start-ScheduledTask -TaskName bw-serve-unlock`. |
| `ssh -v` shows `corp-ssh-askpass: no Bitwarden item named corp.` | The item name does not match `pass_path` exactly | Rename the item in Bitwarden, or fix `pass_path` in `hosts.yaml`. Names are case-sensitive. |
| `ssh -v` shows `corp-ssh-askpass: empty answer from bw serve for <host>.` | The item has no password, or no TOTP for the OTP prompt | Fill in `login.password` or `login.totp` on the item. |
| Unlock script: `bw.exe not found. Install it: winget install Bitwarden.CLI` | `bw` is not installed, or not on `PATH` and not in the winget package directory | `winget install Bitwarden.CLI`. |
| Unlock script: `bw is not logged in. Run: bw login` | No `bw login` on this Windows user | Run `bw login` once (A.1), then `Start-ScheduledTask -TaskName bw-serve-unlock`. |
| Unlock script: `bw serve did not start within 30 seconds.` | `bw serve` failed to start, or port 8087 is in use | Run `bw serve` in a PowerShell window and read its output. |
| The unlock window asks for the master password at every logon | The stored password no longer unlocks (master password changed), or `master.dpapi` cannot be written | Enter the current master password once; the script stores it. Check that `%LOCALAPPDATA%\bw-serve-unlock\` is writable. |
| `Get-ScheduledTask -TaskName bw-serve-unlock` finds nothing | `hosts.yaml` did not exist when `chezmoi apply` ran | Create `~\.corp-ssh\hosts.yaml`, then run `chezmoi apply` again. |
| `ssh -G <corp-host>` shows `controlmaster false` despite config | Block in `~/.ssh/config` not matching `<corp-host>` pattern | Verify `Host` line scope; `ssh -F /dev/null -G <corp-host>` to bypass config and confirm baseline. |
| ssh from VS Code git integration fails | IDE-spawned ssh.exe didn't inherit profile env vars | Configure IDE to use PowerShell as default shell; or set env vars in IDE settings. |
| `controlpath too long` error | Using `%r@%h:%p` instead of `%C` | Use `%C` (40-char hash). Spec § Components for rationale. |
| `where /q pwsh` reports false but `pwsh` works in shell | PATH not refreshed since install | Open new PowerShell session. |

### When the password rotates

Update `login.password` of the `corp` item in any Bitwarden client. Nothing
else. Both the Windows helper and the WSL helper sync `bw serve` before every
Password prompt, so the next login on either side uses the new password.

To complete the password-change flow itself, see
[`corp-ssh-setup.md` § When the password is rotated](corp-ssh-setup.md#when-the-password-is-rotated).

### Locking the vault

```powershell
Invoke-RestMethod -Method Post -Uri http://localhost:8087/lock
```

Next corp ssh fails closed until `bw serve` is unlocked again. To unlock it,
run `Start-ScheduledTask -TaskName bw-serve-unlock`. The task uses the stored
password and shows no prompt. To require the master password again, delete
`%LOCALAPPDATA%\bw-serve-unlock\master.dpapi` first.

### When remote group membership changes

Same situation as on WSL — sshd loads supplementary groups at login and
freezes them for the session. ControlMaster (when working on
Win32-OpenSSH) reuses that authenticated session for `ControlPersist 8h`,
so a remote `usermod -aG` is invisible until the master is torn down.

```powershell
ssh -O check <corp-host>     # confirm a master is running (optional)
ssh -O exit  <corp-host>     # close it; multiplexed sessions also die
ssh <corp-host> 'id -Gn'     # verify the new group is present
```

The `-O exit` vs `-O stop` distinction and the "closing PowerShell isn't
enough" caveat apply the same as on WSL — see
[`corp-ssh-setup.md` § When remote group membership changes](corp-ssh-setup.md#when-remote-group-membership-changes)
for the full explanation.

## Known limitations and future work

- **macOS deferred** (Phase 3+).
- **ControlMaster best-effort** on `OpenSSH_for_Windows_9.5p2`. Layer 2
  (askpass) carries everything if Layer 1 misbehaves.
- **`bw serve` is an unauthenticated localhost API.** While it is unlocked,
  any local process on Windows can read the vault. The account holds only
  corp items for that reason.
- **The logon unlock needs an interactive logon.** The task uses the
  Interactive logon type, and DPAPI needs the user logged on. Nothing unlocks
  `bw serve` before the first logon after a reboot.
- **PowerShell-only.** ssh.exe from cmd.exe or environment without
  profile-loaded shell does not benefit from this automation.

## Why not Kerberos / GSSAPI?

Same answer as Phase 1 — see
[`corp-ssh-setup.md` § Why not Kerberos](corp-ssh-setup.md#why-not-kerberos--gssapi)
for the full investigation. If IT later enables IPA-native OTP preauth or
provisions user certificates, the Kerberos path becomes viable on both
WSL and Windows without code changes here.
