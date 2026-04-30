# Corp SSH Setup: Password+OTP Automation

A native-OpenSSH approach to handling corporate SSH targets that require
interactive password + TOTP one-time-password authentication. Designed for
WSL/Ubuntu; Windows and macOS support is future work.

Design rationale and considered alternatives: see
[`docs/superpowers/specs/2026-04-24-corp-ssh-redesign.md`](superpowers/specs/2026-04-24-corp-ssh-redesign.md).

## What this does

After setup:

- First ssh to a corp host per working session requires **zero manual input**
  (credentials supplied automatically from Bitwarden).
- Subsequent ssh/scp/rsync/git-ssh calls to the same host within 8 hours use a
  cached multiplex socket — zero authentication at all.
- Non-interactive callers (cron, `claude -p`, harness scripts) work
  transparently as long as the Bitwarden session at `~/.bw-session` is valid.

## Prerequisites

| Dependency | Used for | Install |
|---|---|---|
| OpenSSH client | Everything | Pre-installed on Ubuntu |
| Bitwarden CLI (`bw`) | Storing password + TOTP, issuing current OTPs | `npm install -g @bitwarden/cli` (or snap / official) |
| Bitwarden account | Vault backing store | GUI signup |

## One-time setup

### 1. Deploy the helper via chezmoi

```bash
chezmoi apply
# Creates ~/.local/bin/corp-ssh-askpass and wires up the shell env.
# Verify:
type corp-ssh-askpass
echo "$SSH_ASKPASS"          # should be .../corp-ssh-askpass
echo "$SSH_ASKPASS_REQUIRE"  # should be "force"
```

If `$SSH_ASKPASS` is empty, source your shell rc (`source ~/.bashrc`) or
start a new shell session.

### 2. Set up Bitwarden

Create the single item that backs all corp SSH auth:

```bash
bw login        # interactive: email + master password + 2FA if enabled
```

Then in the Bitwarden GUI (or CLI), create an item:

- **Name**: your choice, e.g. `<corp-ssh-credential>` — this becomes `bw_item`
  below
- **Username**: your AD principal, e.g. `<ad-user>@<corp-domain>`
- **Password**: current AD password
- **TOTP**: paste the full `otpauth://totp/...` URI, or the base32 secret
  alone; Bitwarden will generate 30-second codes automatically

Verify:

```bash
bw sync
bw get password <corp-ssh-credential>   # should print the password
bw get totp <corp-ssh-credential>       # should print a 6-digit code
```

### 3. Persist the Bitwarden session

The helper reads `~/.bw-session` as a fallback when `BW_SESSION` is not in the
environment (e.g., for cron or harness callers). Populate it once:

```bash
bw unlock --raw > ~/.bw-session
chmod 600 ~/.bw-session
```

This session stays valid until you run `bw lock` manually or change your
Bitwarden master password. The file is loaded automatically by
`~/.bashrc` / `~/.zshrc` on each new shell.

### 4. Create `~/.corp-ssh/hosts.yaml` (local only, never committed)

This file is the allowlist of corp targets that the askpass helper will
answer for, plus the Bitwarden item name.

```bash
mkdir -p ~/.corp-ssh
chmod 700 ~/.corp-ssh
```

```bash
cat > ~/.corp-ssh/hosts.yaml <<EOF
bw_item: <corp-ssh-credential>

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

### 5. Add ControlMaster to `~/.ssh/config`

`~/.ssh/config` is intentionally **not** managed by chezmoi — it is considered
environment-specific. Append the block below to your existing config:

```
# ──── Corp hosts with password+OTP — enable connection multiplexing ─────────
Host <corp-host-pattern-1> <corp-host-pattern-2> ...
  ControlMaster auto
  ControlPath ~/.ssh/cm/%r@%h:%p
  ControlPersist 8h
```

Scope `Host` to the specific corp host aliases (e.g., `Host corpprefix* other-host`).
Avoid `Host *` — it enables multiplexing for every connection, which may not
be desired for short-lived connections like git-over-ssh.

Create the socket directory:

```bash
mkdir -p ~/.ssh/cm
chmod 755 ~/.ssh/cm
```

## How it works

Two layers, both native to OpenSSH, composed:

**Layer 1 — connection reuse (`ControlMaster`)**. On the first ssh to a host,
OpenSSH opens a master connection and keeps the socket at `~/.ssh/cm/` alive
for `ControlPersist` seconds after the last child connection closes. Any
subsequent ssh/scp/rsync/git-ssh to that host during the persist window reuses
the socket — zero auth, sub-100ms connect time.

**Layer 2 — non-interactive credential entry (`SSH_ASKPASS` +
`SSH_ASKPASS_REQUIRE=force`)**. When OpenSSH actually needs to prompt (first
auth to a host, master expired, etc.), instead of reading from the terminal
it invokes the helper `corp-ssh-askpass` with the prompt text as `argv[1]`.
The helper parses the hostname out of the prompt, looks it up in
`~/.corp-ssh/hosts.yaml`, and — if the host is on the allowlist — retrieves
password or TOTP from Bitwarden CLI and writes it to stdout. OpenSSH reads
stdout as the credential.

The helper declines (`exit 1`) for any prompt it doesn't recognize. For
hosts not listed in `hosts.yaml`, the helper declines and the current auth
method fails. No corp credentials are leaked to unrelated servers.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `ssh <corp-host>` still prompts interactively for password | Shell env not updated after chezmoi apply | `source ~/.bashrc`, or start a fresh shell; verify `echo "$SSH_ASKPASS_REQUIRE"` is `force` |
| `ssh <corp-host>` hangs silently | `~/.bw-session` exists but the session is locked | `bw unlock --raw > ~/.bw-session` again; check `bw status` shows `"unlocked"` |
| `Permission denied` even after supplying creds | Bitwarden item name in `hosts.yaml` doesn't match vault | `bw list items --search <substring>` to find the actual name; update `bw_item` in `hosts.yaml` |
| Helper not invoked; ssh still asks on TTY | `SSH_ASKPASS_REQUIRE` not `force`, or helper not executable | `ls -l ~/.local/bin/corp-ssh-askpass` (should have x bit); `echo $SSH_ASKPASS_REQUIRE` |
| Helper invoked but `bw get` fails | BW_SESSION stale or Bitwarden CLI not synced | `bw sync`; re-run `bw unlock --raw > ~/.bw-session` |
| Auth succeeds manually but harness still fails | Harness env doesn't inherit `BW_SESSION` | Helper has a file fallback — verify `~/.bw-session` is readable by the user running the harness |
| Host is listed in `hosts.yaml` but helper declines | `hosts.yaml` entry is ssh alias, not HostName | Regenerate entries using the `ssh -G` recipe in step 4 |
| Passphrase-protected SSH key no longer works | `SSH_ASKPASS_REQUIRE=force` intercepts passphrase prompt too | Use unencrypted keys, OR `SSH_ASKPASS_REQUIRE=never ssh host` per session |

### When the password is rotated

When the corp AD password expires:

1. Complete the password-change flow manually (bypass this automation — call
   `/usr/bin/ssh <corp-host>` directly and follow server prompts, or use a
   web SSO portal if available).
2. Update the Bitwarden item with the new password.
3. `bw sync` to push the change to the CLI cache.
4. If sessions were issued before the rotation, you may need to re-unlock:
   `bw unlock --raw > ~/.bw-session`.

## Known limitations and future work

- **WSL/Ubuntu only for now.** Windows and macOS support deferred until
  OpenSSH port behaviors are verified with `SSH_ASKPASS_REQUIRE=force`.
- **No Bitwarden session auto-renewal.** If the session is invalidated
  (lock, master password change, cloud-side forced logout), the user must
  manually re-unlock. Trade-off: keeping the master password out of any
  file on disk.
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
