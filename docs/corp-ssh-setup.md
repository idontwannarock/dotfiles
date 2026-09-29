# Corp SSH Setup: Password+OTP Automation

A native-OpenSSH approach to handling corporate SSH targets that require
interactive password + TOTP one-time-password authentication. Designed for
WSL/Ubuntu on a Windows host. Credentials come from a Bitwarden vault through
`bw serve`, which runs on Windows. The Windows setup guide is
[`corp-ssh-setup-windows.md`](corp-ssh-setup-windows.md). Native Linux is
untested. macOS support is future work.

Design rationale and considered alternatives: see
[`openspec/changes/archive/2026-04-24-corp-ssh-redesign/design.md`](../openspec/changes/archive/2026-04-24-corp-ssh-redesign/design.md).
That design predates the move from `pass` to Bitwarden; the two-layer
architecture is unchanged.

## What this does

After setup:

- First ssh to a corp host per working session requires **zero manual input**.
  The helper reads the credentials from `bw serve` on Windows.
- Subsequent ssh/scp/rsync/git-ssh calls to the same host within 8 hours use a
  cached multiplex socket — zero authentication at all.
- Non-interactive callers (cron, `claude -p`, harness scripts) work
  transparently as long as `bw serve` is unlocked. The Windows logon unlocks
  it with no prompt.
- To rotate the AD password, update the `corp` item in Bitwarden. Nothing
  else changes.

## Prerequisites

| Dependency | Used for | Install |
|---|---|---|
| OpenSSH client | Everything | Pre-installed on Ubuntu |
| `jq` | Parses the JSON that `bw serve` returns | `sudo apt install jq` |
| `curl.exe` (Windows) | Reaches `bw serve` on Windows localhost from WSL | Ships with Windows 10 and later; WSL interop puts it on `PATH` |
| Bitwarden account + `bw serve` on Windows | The vault that holds the corp credentials | See [`corp-ssh-setup-windows.md`](corp-ssh-setup-windows.md) |
| `curl` + Bitwarden CLI (native Linux only) | A local `bw serve` when there is no `curl.exe` | Untested — see [Known limitations](#known-limitations-and-future-work) |

The WSL side has no local credential store. It holds no secret on disk.

## One-time setup

### 1. Deploy the helper via chezmoi

```bash
chezmoi apply
# Creates ~/.local/bin/corp-ssh-askpass and wires up the shell env.
# Verify:
ls -l ~/.local/bin/corp-ssh-askpass    # should be executable
echo "$SSH_ASKPASS"                     # should be .../corp-ssh-askpass
echo "$SSH_ASKPASS_REQUIRE"             # should be "force"
command -v curl.exe jq                  # both should resolve
```

If any of these are empty, source your shell rc (`source ~/.bashrc`) or
start a new shell session.

### 2. Set up the Bitwarden account and items

**Account.** Use a Bitwarden account that holds **only** corp items. Keep
private passwords in a different vault. `bw serve` exposes the whole vault to
local processes while it is unlocked (see [How it works](#how-it-works)), so
the vault must not hold anything else.

- Register the account with a personal email address, not the company email.
  The company can disable the company mailbox, and a new-device login can
  send a verification code by email.
- TOTP storage requires Bitwarden Premium.
- Turn on two-step login for the Bitwarden account. Do not store the TOTP
  seed of the Bitwarden account itself in Bitwarden.

**Items.** Create these items in any Bitwarden client (web vault, desktop
app, browser extension, or `bw`). Names must match exactly, including case.

| Item name | Field | Value |
|---|---|---|
| `corp` | `login.password` | The AD password |
| `corp` | `login.totp` | The full `otpauth://totp/...` URI, or the base32 secret only |
| `corp/hosts/<short-host>` | `login.password` | The local-account password of one host (optional) |

`corp` is the value of `pass_path` in `hosts.yaml` (step 4). The key keeps the
name `pass_path` for compatibility, but it now names a Bitwarden item prefix.

**Hosts with their own local account.** The `corp` item holds the shared AD
password. A host that authenticates against a *local* account instead (a DB
box with its own `root` password, say) needs its own item. Name the item
`corp/hosts/<short-host>`, where `<short-host>` is the **first DNS label of
its HostName**:

```
corp/hosts/mms-product-grouping-api-db-dev
```

The helper prefers `corp/hosts/<short-host>` when that item exists and falls
back to `corp` otherwise — no configuration needed beyond creating the item.
Such hosts still need their FQDN on the `hosts.yaml` allowlist below.

### 3. Start and unlock `bw serve` on Windows

One `bw serve` on Windows serves both Windows and WSL. Install it, log in,
and register the logon unlock as described in
[`corp-ssh-setup-windows.md`](corp-ssh-setup-windows.md). Then verify from WSL:

```bash
curl.exe -s http://localhost:8087/status
```

The JSON must contain `"status":"unlocked"`. `"locked"` means `bw serve` runs
but is not unlocked. No output means `bw serve` is not running.

### 4. Create `~/.corp-ssh/hosts.yaml` (local only, never committed)

This file is the allowlist of corp targets that the askpass helper will
answer for, plus the Bitwarden item prefix.

```bash
mkdir -p ~/.corp-ssh
chmod 700 ~/.corp-ssh
```

```bash
cat > ~/.corp-ssh/hosts.yaml <<'EOF'
pass_path: corp     # Bitwarden item name: "corp", plus "corp/hosts/<short-host>"

password_otp_hosts:
  # Entries must match the hostname openssh actually connects to
  # (HostName from ssh config), NOT the ssh config alias.
  # Either the full FQDN or its first-segment short form is accepted.
  - <actual-host-1>.<corp-domain>
  - <actual-host-2>
EOF

chmod 600 ~/.corp-ssh/hosts.yaml
```

**To regenerate entries from your existing `~/.ssh/config`**:

```bash
for alias in <alias1> <alias2> ...; do
  ssh -G "$alias" | awk '/^hostname / { print "  - " $2 }'
done
```

Paste the output into the `password_otp_hosts:` section.

### 5. ControlMaster drop-in (chezmoi-managed) + Include

`~/.ssh/config` itself stays **machine-local** — it holds corp FQDNs/IPs that must
not enter the repo. The generic multiplex + no-pubkey policy, which carries no
secrets, *is* reproduced: chezmoi deploys it as a drop-in at
`~/.ssh/config.d/corp-multiplex` (source `home/private_dot_ssh/private_config.d/private_corp-multiplex`,
WSL/Linux/macOS only — Win32-OpenSSH has no ControlMaster):

```
# ──── Corp hosts authenticating by password — enable connection multiplexing ────
Host devkws* dev-livekit devdb-* stgdb-*
  PubkeyAuthentication no          # password(+OTP) only — don't offer agent keys (avoids MaxAuthTries)
  ControlMaster auto
  ControlPath ~/.ssh/cm/%C
  ControlPersist 8h
```

For the drop-in to take effect, the machine-local `~/.ssh/config` needs **one line**
(the only manual step per machine — add it near the top):

```
Include ~/.ssh/config.d/*
```

Adjust the `Host` patterns in the drop-in to your corp aliases if they differ.
Avoid `Host *` — it enables multiplexing for every connection, which may not
be desired for short-lived connections like git-over-ssh.

The `%C` token hashes `%l%h%p%r` (local-user / host / port / remote-user) into
a fixed 40-char hex string. **Do not use `%r@%h:%p`** — corporate FQDNs plus
full user principals routinely push the resulting socket path past the Linux
108-byte `UNIX_PATH_MAX` limit, producing `ControlPath too long` errors.

Create the socket directory:

```bash
mkdir -p ~/.ssh/cm
chmod 755 ~/.ssh/cm
```

### Migrating from `pass` (one time)

Earlier versions of this setup kept the credentials in `pass` (WSL) and
`gopass` (Windows). To move them, create the Bitwarden items from these
`pass` entries:

| `pass` entry | Bitwarden item and field |
|---|---|
| `corp/password` | `corp` → `login.password` |
| The `otpauth://` line of `corp/totp` | `corp` → `login.totp` |
| Each `corp/hosts/<short-host>` | `corp/hosts/<short-host>` → `login.password` |

The simplest way is the Bitwarden desktop app or web vault: copy each value
and paste it into the item.

To script it, run the script below in your own WSL terminal. It was used for
the real migration on 2026-09-29. It asks for the Bitwarden master password,
and `pass` may ask for the gpg passphrase. Secrets travel through environment
variables and stdin, never through a command line. An item that already
exists is skipped, so a second run is safe. Set `BW` to your `bw.exe` path
first (see the Windows guide).

```bash
#!/usr/bin/env bash
# One-time migration: copy corp credentials from pass into Bitwarden.
#   pass corp/password + corp/totp  -> Bitwarden item "corp" (password + totp)
#   pass corp/hosts/<h>             -> Bitwarden item "corp/hosts/<h>" (password)
# Skips an item that already exists by exact name, so a rerun is safe.
set -euo pipefail

BW=/mnt/c/Users/user/AppData/Local/Microsoft/WinGet/Packages/Bitwarden.CLI_Microsoft.Winget.Source_8wekyb3d8bbwe/bw.exe
STORE="${PASSWORD_STORE_DIR:-$HOME/.password-store}"
cd /mnt/c   # bw.exe warns when started from a WSL UNC path

echo "Bitwarden master password:"
S=$("$BW" unlock --raw)
[ -n "$S" ] || { echo "unlock failed" >&2; exit 1; }

"$BW" sync --session "$S" >/dev/null

exists() {
  "$BW" list items --search "$1" --session "$S" \
    | jq -e --arg n "$1" 'any(.[]; .name == $n)' >/dev/null
}

# Secrets travel in env vars and stdin, never in argv.
create() {  # $1 = name; PW and TOTP env vars hold the secrets
  if exists "$1"; then echo "skip   $1 (already exists)"; return; fi
  NAME="$1" jq -n '{
      type: 1, name: $ENV.NAME, notes: null, favorite: false, fields: [],
      organizationId: null, folderId: null, collectionIds: null, reprompt: 0,
      login: { uris: [], username: null, password: $ENV.PW,
               totp: (if $ENV.TOTP == "" then null else $ENV.TOTP end) } }' \
    | base64 -w0 | "$BW" create item --session "$S" >/dev/null
  echo "create $1"
}

# Plain assignments, so set -e stops the script when pass or grep fails,
# instead of creating an item with an empty secret.
PW=$(pass show corp/password | head -1)
TOTP=$(pass show corp/totp | grep -m1 '^otpauth://')
[ -n "$PW" ] && [ -n "$TOTP" ] || { echo "empty corp secret" >&2; exit 1; }
PW="$PW" TOTP="$TOTP" create corp

for f in "$STORE"/corp/hosts/*.gpg; do
  h=$(basename "$f" .gpg)
  PW=$(pass show "corp/hosts/$h" | head -1)
  [ -n "$PW" ] || { echo "empty secret: corp/hosts/$h" >&2; exit 1; }
  PW="$PW" TOTP="" create "corp/hosts/$h"
done

"$BW" lock >/dev/null
echo "done"
```

Nothing deletes the old `pass`/`gopass` store. You can keep it as a fallback
or remove it by hand. The helpers no longer read it.

## How it works

Two layers, both native to OpenSSH, composed:

**Layer 1 — connection reuse (`ControlMaster`)**. On the first ssh to a host,
OpenSSH opens a master connection and keeps the socket at `~/.ssh/cm/` alive
for `ControlPersist` seconds after the last child connection closes. Any
subsequent ssh/scp/rsync/git-ssh to that host during the persist window reuses
the socket — zero auth, sub-200ms connect time.

**Layer 2 — non-interactive credential entry (`SSH_ASKPASS` +
`SSH_ASKPASS_REQUIRE=force`)**. When OpenSSH actually needs to prompt (first
auth to a host, master expired, etc.), instead of reading from the terminal
it invokes the helper `corp-ssh-askpass` with the prompt text as `argv[1]`.
The helper parses the hostname out of the prompt, looks it up in
`~/.corp-ssh/hosts.yaml`, and — if the host is on the allowlist — asks
`bw serve` for the item and writes the password or the current TOTP code to
stdout. OpenSSH reads stdout as the credential.

The prompt arrives in one of two shapes, depending on which auth method the
server offers, and the helper recognizes both:

| Auth method | Prompt text | Who composes it |
|---|---|---|
| `keyboard-interactive` (PAM) | `(user@host.fqdn) Password:` | server, wrapped in context by openssh |
| `password` (openssh builtin) | `user@host.fqdn's password: ` | openssh client |

**Where `bw serve` runs.** `bw serve` runs on Windows and listens on
`localhost:8087` (it binds `::1`). WSL uses the default NAT networking, where
WSL `localhost` is not Windows `localhost`. So the helper calls `curl.exe`, the
Windows curl. `curl.exe` runs on the Windows side and sees Windows `localhost`.
Do not expose `bw serve` on another interface to reach it from WSL: that puts
an unauthenticated vault API on the network. When `curl.exe` is not on `PATH`
(native Linux), the helper uses `curl` against a local `bw serve`.

**Requests per prompt.** For a Password prompt the helper first sends
`POST /sync`, so a password rotated in the vault reaches ssh at once. An
offline sync is not fatal: the cached vault still answers. The sync costs
about 0.5 s per real login; `ControlPersist 8h` makes real logins rare. The
OTP prompt skips the sync. Then one `GET /list/object/items?search=<pass_path>`
returns both the `corp` item and any `corp/hosts/<short-host>` item. The
helper matches the item names exactly. For the OTP prompt it calls
`GET /object/totp/<id>` on the `corp` item.

**Per-host selection.** For a Password prompt the helper uses
`corp/hosts/<short-host>` when that item exists, and the `corp` item
otherwise. Both come from the same list response, so a per-host lookup
cannot fail on its own.

**Fail closed.** When `bw serve` is stopped or locked, the list request fails.
The helper then exits 1 with `corp-ssh-askpass: bw serve not reachable or
locked.` on stderr. It never falls back to the shared password. ssh aborts,
and the message is visible in `ssh -v` output.

**ProxyJump and stdin.** Under `ProxyJump` the jump ssh runs with `-W`, so its
stdin is the tunnel, and the helper inherits it. WSL interop forwards stdin
to `curl.exe`, which then ate tunnel bytes. The inner connection broke with
`Bad packet length 1231976033` (`Inva` in ASCII) or
`message authentication code incorrect`. The helper runs `exec </dev/null`
before it calls curl. `tests/corp-ssh-askpass.test.sh` guards this. Keep that
line when you edit the helper.

The helper never sends a credential for a prompt it doesn't recognize, and
never for a host missing from `hosts.yaml`. No corp credentials are leaked to
unrelated servers.

It does not answer those prompts with `exit 1` either. `SSH_ASKPASS_REQUIRE=force`
routes *every* openssh question through the helper, host-key confirmations
included, and `exit 1` there reads as "no" — plain `ssh <any-new-host>` would die
with `Host key verification failed.` and never show the yes/no prompt. So the
helper's `ask_human()` re-asks on `/dev/tty`: host-key answers echo, passwords
don't. With no controlling terminal (cron, CI, agents) there is nobody to ask,
and it declines with `exit 1` as before.

## Troubleshooting

These checks are safe to run at any time. They print no secret.

- `curl.exe -s http://localhost:8087/status` — shows whether `bw serve` is
  running, and `locked` or `unlocked`.
- `powershell.exe -NoProfile -Command "Get-ScheduledTaskInfo -TaskName bw-serve-unlock"`
  — shows when the logon unlock task last ran and its result.
- `ssh -v <corp-host>` — the helper's own messages start with
  `corp-ssh-askpass:`.

| Symptom | Likely cause | Fix |
|---|---|---|
| `ssh <corp-host>` still prompts interactively for password | Shell env not updated after chezmoi apply | `source ~/.bashrc`, or start a fresh shell; verify `echo "$SSH_ASKPASS_REQUIRE"` is `force` |
| `ssh -v` shows `corp-ssh-askpass: bw serve not reachable or locked.` | `bw serve` on Windows is stopped or locked | Run `Start-ScheduledTask -TaskName bw-serve-unlock` on Windows, then retry. Check with `curl.exe -s http://localhost:8087/status` |
| `ssh -v` shows `corp-ssh-askpass: no Bitwarden item named corp.` | The item name does not match `pass_path` exactly | Rename the item in Bitwarden, or fix `pass_path` in `hosts.yaml`. Names are case-sensitive |
| `ssh -v` shows `corp-ssh-askpass: empty answer from bw serve for <host>.` | The item has no password, or no TOTP for the OTP prompt | Fill in `login.password` or `login.totp` on the item |
| `command -v curl.exe` prints nothing on WSL | WSL interop or the Windows `PATH` is off in this distro | Check `/etc/wsl.conf` for `[interop] enabled=false` or `appendWindowsPath=false` |
| `ControlPath too long` error before any auth | Using `%r@%h:%p` in ControlPath; corp FQDN + user principal exceeds 108 bytes | Switch to `ControlPath ~/.ssh/cm/%C` |
| `Permission denied` even after creds supplied | Wrong value in the item, wrong host on allowlist, or a per-host item missing | Check the item in Bitwarden; check `hosts.yaml` entry uses HostName not alias |
| Helper not invoked; ssh still asks on TTY | `SSH_ASKPASS_REQUIRE` not `force`, or helper not executable | `ls -l ~/.local/bin/corp-ssh-askpass` (should have x bit); `echo $SSH_ASKPASS_REQUIRE` |
| `Bad packet length ...` or `message authentication code incorrect` through a `ProxyJump` host | The helper's `exec </dev/null` line is missing, so `curl.exe` read the tunnel's stdin | Re-apply the helper (`chezmoi apply ~/.local/bin/corp-ssh-askpass`); see [How it works](#how-it-works) |
| Host listed in `hosts.yaml` but helper declines | Entry is ssh alias, not HostName | Regenerate using the `ssh -G` recipe in step 4 |
| Passphrase-protected SSH key no longer works | `SSH_ASKPASS_REQUIRE=force` intercepts passphrase prompt too | Use unencrypted keys, OR `SSH_ASKPASS_REQUIRE=never ssh host` per session |
| `Host key verification failed.` on first connect to a new host, **no** yes/no prompt shown | Helper predates `ask_human()`, or the shell has no controlling terminal | Update `~/.local/bin/corp-ssh-askpass` (`chezmoi apply ~/.local/bin/corp-ssh-askpass`). In a real terminal the yes/no prompt should appear. From a script or agent, verify the fingerprint out of band with `ssh-keyscan -t ed25519 <target>` and then `ssh -o StrictHostKeyChecking=accept-new <host>` once |
| `Permission denied, please try again.` repeated, **never** prompted for a password | Host missing from `hosts.yaml`, or its prompt shape is unrecognized — the helper declines and ssh submits an empty password | `ssh -v` shows `read_passphrase: requested to askpass`; add the HostName to `hosts.yaml`. To see the real prompt text, point `SSH_ASKPASS` at a wrapper that logs `$1` |
| `Too many authentication failures` (disconnect before any credential is accepted) | (a) ssh offers agent/default pubkeys to a password+OTP host and exhausts server `MaxAuthTries`, or (b) a wrong/stale credential — usually an expired AD password — is retried every round | See ["Too many authentication failures"](#too-many-authentication-failures) below |

### "Too many authentication failures"

This one message has two unrelated causes. `ssh -v <host>` tells them apart —
and the fix is completely different for each.

**Cause A — ssh offers public keys the host never wanted.** Corp hosts use
password+OTP (`keyboard-interactive`), but if the ssh config host block lacks
`PubkeyAuthentication no`, ssh first offers every identity it has — ssh-agent
keys, gpg-agent SSH keys, *and* the default `~/.ssh/id_*` files. Each offer
counts against the server's `MaxAuthTries` (default 6), so once enough keys are
loaded (e.g. after unlocking gpg-agent) the budget is spent **before** the
password prompt is ever reached. In `ssh -v` you'll see multiple
`Offering public key:` lines.

Fix — the corp host block must disable pubkey auth. It lives in the
chezmoi-managed drop-in `~/.ssh/config.d/corp-multiplex` (see
[section 5](#5-controlmaster-drop-in-chezmoi-managed--include)), so `chezmoi apply`
plus the one-line `Include ~/.ssh/config.d/*` in the machine-local `~/.ssh/config`
reproduces it on every machine:

```
Host devkws* dev-livekit devdb-* stgdb-*
  PubkeyAuthentication no          # password(+OTP) only — don't offer agent keys
  ControlMaster auto
  ControlPath ~/.ssh/cm/%C
  ControlPersist 8h
```

Verify: `ssh -G <host> | grep pubkeyauthentication` must print `false`.

**Cause B — a wrong credential is retried every round.** If pubkey is already
off but the error persists, `ssh -v` shows repeated
`read_passphrase: requested to askpass` followed by
`Authentications that can continue`, with **no** `corp-ssh-askpass:` error
line. That means the helper *did* return a credential and the server *rejected*
it every keyboard-interactive round — again burning the attempt budget. The
usual cause is an **expired AD password** (see next section); the tell is that
the password in the `corp` item is ~90 days old. Rule out a wrong OTP
first by confirming the clock: `date -u` vs any network time source — TOTP
breaks past ~30s skew; a 0s drift points squarely at the password.

### When the password is rotated

An expired AD password usually surfaces as `Too many authentication failures`
(Cause B above), not a clean "password expired" message, because the rejected
credential is retried until `MaxAuthTries` is hit. When it happens:

1. Complete the password-change flow manually (bypass this automation — call
   `/usr/bin/ssh <corp-host>` directly and follow server prompts, or use a
   web SSO portal if available).
2. Update `login.password` of the `corp` item in any Bitwarden client.
3. Nothing else. The helper syncs `bw serve` before every Password prompt, so
   the next login uses the new password.

### Locking the vault

`bw serve` has no idle timeout. One unlock lasts until `bw serve` stops
(Windows logoff or reboot) or until something calls `/lock`. To lock it by
hand (e.g. before stepping away from the machine):

```bash
curl.exe -s -X POST http://localhost:8087/lock
```

To unlock it again, run `Start-ScheduledTask -TaskName bw-serve-unlock` on
Windows. See [`corp-ssh-setup-windows.md`](corp-ssh-setup-windows.md) for the
unlock details.

### When remote group membership changes

Linux reads supplementary groups at login and freezes them for the
session's lifetime. ControlMaster keeps that authenticated session alive
for `ControlPersist 8h`, so after a remote admin runs
`usermod -aG <group> <you>`, ssh calls that reuse the master still see
the *old* group list — even from a freshly-spawned terminal.

Force the next ssh to re-authenticate by tearing down the master:

```bash
ssh -O check <corp-host>     # confirm a master is running (optional)
ssh -O exit  <corp-host>     # close it; multiplexed sessions also die
ssh <corp-host> 'id -Gn'     # verify the new group is present
```

- `-O exit` vs `-O stop`: `exit` tears the master down immediately;
  `stop` only refuses *new* multiplexed clients while existing ones keep
  running. Use `exit` to actually re-login.
- Closing every terminal is not sufficient — `ControlPersist 8h` keeps
  the master process alive in the background until the timer expires.
- Remote `newgrp <group>` does not help. It forks a new shell with the
  added GID but does not touch the sshd process serving your master;
  only a brand-new ssh connection re-runs PAM and reloads groups.

The same procedure applies any time you need a remote login to pick up
state set at login (PAM-injected env vars, shell rc changes that depend
on group membership, etc.).

## Known limitations and future work

- **WSL/Ubuntu and Windows supported; macOS deferred.** See
  [`corp-ssh-setup-windows.md`](corp-ssh-setup-windows.md) for the Windows
  setup guide. The macOS port is Phase 3+.
- **Native Linux is untested.** Without `curl.exe` the helper uses `curl`
  against a `bw serve` on the same machine. Nothing in this repo starts or
  unlocks that `bw serve`.
- **`bw serve` is an unauthenticated localhost API.** While it is unlocked,
  any local process on Windows can call `localhost:8087` and read the vault.
  The default origin protection of `bw serve` blocks browsers. That is why
  the account holds only corp items.
- **WSL depends on Windows.** When `bw serve` on Windows is stopped or locked,
  corp ssh from WSL fails closed.
- **Password rotation is manual.** The design detects expired passwords via
  auth failures, not via proactive notification.

## Why not Kerberos / GSSAPI?

The corp sshd advertises `gssapi-with-mic` in its supported authentication
methods. A working Kerberos setup (one `kinit` per day) would eliminate
password+OTP entry entirely. During this project's probing in 2026-04-24,
the Kerberos path was validated up to the OTP preauth stage but failed at
KDC-side OTP validation. The most likely cause (uncorroborated without IT
admin access) is that the corp IPA realm proxies OTP to an external
RADIUS-backed MFA provider, and `kinit` consults only IPA-native OTP tokens.

Full investigation record — including krb5.conf setup, anonymous PKINIT for
FAST armor, and KDC trace output — is preserved in the design spec under
"Considered Alternatives → Branch A". If IT later enables IPA-native OTP
preauth or provisions user certificates, reactivating the Kerberos path is
straightforward; the filesystem state left by the probing (krb5.conf,
ipa-ca-bundle.pem, krb5-pkinit package) is already in place.
