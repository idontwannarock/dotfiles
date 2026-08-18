# Corp SSH Setup: Password+OTP Automation

A native-OpenSSH approach to handling corporate SSH targets that require
interactive password + TOTP one-time-password authentication. Designed for
WSL/Ubuntu; Windows and macOS support is future work.

Design rationale and considered alternatives: see
[`openspec/changes/archive/2026-04-24-corp-ssh-redesign/design.md`](../openspec/changes/archive/2026-04-24-corp-ssh-redesign/design.md).

## What this does

After setup:

- First ssh to a corp host per working session requires **zero manual input**
  (credentials supplied automatically from `pass`, decrypted via gpg-agent).
- Subsequent ssh/scp/rsync/git-ssh calls to the same host within 8 hours use a
  cached multiplex socket — zero authentication at all.
- Non-interactive callers (cron, `claude -p`, harness scripts) work
  transparently as long as the gpg-agent passphrase cache is warm.

## Prerequisites

| Dependency | Used for | Install |
|---|---|---|
| OpenSSH client | Everything | Pre-installed on Ubuntu |
| `gnupg` (≥ 2.2) | Encrypts the credential store | Pre-installed on Ubuntu |
| `pinentry-curses` | Passphrase prompt in TTY | Pre-installed on Ubuntu |
| `pass` | Password store CLI | `sudo apt install pass` |
| `pass-extension-otp` | TOTP code generation from `pass` entries | `sudo apt install pass-extension-otp` |
| `oathtool` | Pulled in as dep; useful for ad-hoc TOTP debugging | `sudo apt install oathtool` |

No cloud account required. The credential store is local-only, encrypted with
your GPG key, decrypted on demand via gpg-agent (8-hour passphrase cache).

## One-time setup

### 1. Deploy the helper via chezmoi

```bash
chezmoi apply
# Creates ~/.local/bin/corp-ssh-askpass and wires up the shell env.
# Verify:
ls -l ~/.local/bin/corp-ssh-askpass    # should be executable
echo "$SSH_ASKPASS"                     # should be .../corp-ssh-askpass
echo "$SSH_ASKPASS_REQUIRE"             # should be "force"
echo "$GPG_TTY"                         # should be your tty (e.g. /dev/pts/N)
```

If any of these are empty, source your shell rc (`source ~/.bashrc`) or
start a new shell session.

### 2. Generate a GPG key for the credential store

If you already have a usable GPG key (with an `[E]` encryption capability),
skip to step 3 with that key's fingerprint. Otherwise:

```bash
export GPG_TTY=$(tty)
gpg --quick-generate-key 'corp-ssh local <your.email@example.com>' future-default default 0
```

You'll be prompted twice for a passphrase — this becomes the master secret
that unlocks the credential store. Choose something memorable and strong
(diceware-style 4–6 random words is a good baseline). `future-default` produces
an `ed25519` (sign+cert) primary key with a `cv25519` (encrypt) subkey;
`pass` requires the encryption subkey.

Note the fingerprint from the output (40-char hex on the second line). You
can also retrieve it later with `gpg --list-secret-keys`.

**Tune gpg-agent cache TTL** (so a single passphrase entry lasts a working
session, aligned with ssh `ControlPersist 8h`):

```bash
mkdir -p ~/.gnupg && chmod 700 ~/.gnupg
cat > ~/.gnupg/gpg-agent.conf <<'EOF'
default-cache-ttl 28800
max-cache-ttl 28800
EOF
chmod 600 ~/.gnupg/gpg-agent.conf
gpg-connect-agent reloadagent /bye
```

**Back up the GPG private key.** If you lose it, every secret in `pass` is
unrecoverable. Recommended:

```bash
gpg --export-secret-keys --armor <FPR> > corp-ssh-key.asc   # then store offline
```

### 3. Initialize `pass` and store credentials

```bash
pass init <FPR>                # FPR = the GPG fingerprint from step 2
pass insert corp/password      # interactive: type AD password twice (hidden)
pass otp insert corp/totp      # interactive: paste full otpauth://totp/... URI
```

If you only have the base32 TOTP secret (no full URI), use:

```bash
pass otp insert -s corp/totp   # interactive: paste base32 secret only
```

Defaults to TOTP / SHA1 / 30s / 6 digits per RFC 6238.

Verify:

```bash
pass show corp/password >/dev/null && echo "password OK"
pass otp corp/totp     # should print a 6-digit code matching your authenticator app
```

**Hosts with their own local account.** `corp/password` is the shared AD
password. A host that authenticates against a *local* account instead (a DB box
with its own `root` password, say) keeps its own entry under `corp/hosts/`,
named by the **first segment of its HostName**:

```bash
pass insert corp/hosts/mms-product-grouping-api-db-dev
```

The helper prefers `corp/hosts/<short-host>` when that entry exists and falls
back to `corp/password` otherwise — no configuration needed beyond creating the
entry. Such hosts still need their FQDN on the `hosts.yaml` allowlist below.

The first `pass show` will trigger pinentry to ask for the GPG passphrase.
Subsequent calls within `default-cache-ttl` (8h) skip the prompt.

### 4. Create `~/.corp-ssh/hosts.yaml` (local only, never committed)

This file is the allowlist of corp targets that the askpass helper will
answer for, plus the `pass` path prefix.

```bash
mkdir -p ~/.corp-ssh
chmod 700 ~/.corp-ssh
```

```bash
cat > ~/.corp-ssh/hosts.yaml <<'EOF'
pass_path: corp     # matches `pass insert corp/password` and `pass otp insert corp/totp`

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
Host devkws* dev-livekit devdb-*
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
`~/.corp-ssh/hosts.yaml`, and — if the host is on the allowlist — calls
`pass show` (for password prompts) or `pass otp` (for OTP prompts) and
writes the result to stdout. OpenSSH reads stdout as the credential.

The prompt arrives in one of two shapes, depending on which auth method the
server offers, and the helper recognizes both:

| Auth method | Prompt text | Who composes it |
|---|---|---|
| `keyboard-interactive` (PAM) | `(user@host.fqdn) Password:` | server, wrapped in context by openssh |
| `password` (openssh builtin) | `user@host.fqdn's password: ` | openssh client |

For password prompts the helper picks the entry by checking whether
`~/.password-store/<pass_path>/hosts/<short-host>.gpg` exists, preferring it
over the shared `<pass_path>/password`. It tests the **file**, not `pass show`:
probing by decryption would make a cold gpg-agent cache indistinguishable from
"no per-host entry", and the helper would then send the shared AD password to a
host that never wanted it.

`pass` decrypts via gpg-agent. As long as the agent has the passphrase cached
(8h TTL), no pinentry prompt fires and the helper completes silently. Once
the cache expires, `pass` fails (no TTY available under sshd), the helper
exits 1, and ssh aborts with an error visible in `ssh -v` output.

The helper declines (`exit 1`) for any prompt it doesn't recognize. For
hosts not listed in `hosts.yaml`, the helper declines and the current auth
method fails. No corp credentials are leaked to unrelated servers.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `ssh <corp-host>` still prompts interactively for password | Shell env not updated after chezmoi apply | `source ~/.bashrc`, or start a fresh shell; verify `echo "$SSH_ASKPASS_REQUIRE"` is `force` and `$GPG_TTY` is set |
| `ssh <corp-host>` fails with "permission denied", helper logs "gpg-agent cache cold" | First call of the session and gpg-agent has no cached passphrase | Run `pass show corp/password >/dev/null` interactively to warm the cache, then retry |
| `ControlPath too long` error before any auth | Using `%r@%h:%p` in ControlPath; corp FQDN + user principal exceeds 108 bytes | Switch to `ControlPath ~/.ssh/cm/%C` |
| `Permission denied` even after creds supplied | `pass_path` in `hosts.yaml` mismatch, or wrong host on allowlist | `pass ls` to confirm entries; check `hosts.yaml` entry uses HostName not alias |
| Helper not invoked; ssh still asks on TTY | `SSH_ASKPASS_REQUIRE` not `force`, or helper not executable | `ls -l ~/.local/bin/corp-ssh-askpass` (should have x bit); `echo $SSH_ASKPASS_REQUIRE` |
| Helper invoked but `pass` fails | gpg-agent down, or store missing | `gpg-connect-agent /bye` to restart agent; check `~/.password-store/` exists |
| Auth succeeds manually but cron/harness still fails | Harness env doesn't share gpg-agent | gpg-agent runs as a per-user daemon; any process as same uid can talk to it via `~/.gnupg/S.gpg-agent`. Make sure cron isn't using a different uid or chrooted env |
| Host listed in `hosts.yaml` but helper declines | Entry is ssh alias, not HostName | Regenerate using the `ssh -G` recipe in step 4 |
| Passphrase-protected SSH key no longer works | `SSH_ASKPASS_REQUIRE=force` intercepts passphrase prompt too | Use unencrypted keys, OR `SSH_ASKPASS_REQUIRE=never ssh host` per session |
| `Host key verification failed.` on first connect to a new host, **no** yes/no prompt shown | `SSH_ASKPASS_REQUIRE=force` intercepts the host-key confirmation too, and the helper declines it | Verify the fingerprint out of band — run `ssh-keyscan -t ed25519 <target>` on the jump host and compare with the key `ssh -v` reports — then `ssh -o StrictHostKeyChecking=accept-new <host>` once |
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
Host devkws* dev-livekit devdb-*
  PubkeyAuthentication no          # password(+OTP) only — don't offer agent keys
  ControlMaster auto
  ControlPath ~/.ssh/cm/%C
  ControlPersist 8h
```

Verify: `ssh -G <host> | grep pubkeyauthentication` must print `false`.

**Cause B — a wrong credential is retried every round.** If pubkey is already
off but the error persists, `ssh -v` shows repeated
`read_passphrase: requested to askpass` followed by
`Authentications that can continue`, with **no** `corp-ssh-askpass: pass failed`
line. That means the helper *did* return a credential and the server *rejected*
it every keyboard-interactive round — again burning the attempt budget. The
usual cause is an **expired AD password** (see next section); the tell is that
`~/.password-store/corp/password.gpg` is ~90 days old. Rule out a wrong OTP
first by confirming the clock: `date -u` vs any network time source — TOTP
breaks past ~30s skew; a 0s drift points squarely at the password.

### When the password is rotated

An expired AD password usually surfaces as `Too many authentication failures`
(Cause B above), not a clean "password expired" message, because the rejected
credential is retried until `MaxAuthTries` is hit. When it happens:

1. Complete the password-change flow manually (bypass this automation — call
   `/usr/bin/ssh <corp-host>` directly and follow server prompts, or use a
   web SSO portal if available).
2. Update the entry: `pass insert -f corp/password` (`-f` overwrites without prompting).
3. No sync step needed — `pass` reads from local files on every call.

### When the GPG passphrase needs re-entry

The 8-hour `default-cache-ttl` covers a typical working session. If you want
to force a re-prompt (e.g., before stepping away from the machine):

```bash
gpg-connect-agent reloadagent /bye   # clears all cached passphrases
```

Next `pass show` / `pass otp` (or first corp ssh) will prompt again.

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

- **WSL/Ubuntu and Windows supported; macOS deferred.** Phase 2 (Windows
  native) shipped 2026-04-30 — see [`corp-ssh-setup-windows.md`](corp-ssh-setup-windows.md)
  for the Windows setup guide. macOS port is Phase 3+ (same architecture
  expected to apply: `gopass` from Homebrew, `pinentry-mac` for the dialog).
- **No automated GPG passphrase entry.** If you want to drive the helper
  from a fully unattended context (e.g., a daemon started before any
  interactive login), you'd need to either pre-warm gpg-agent at boot via
  `gpg-preset-passphrase` (requires storing passphrase somewhere) or accept
  that the first call after boot fails.
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
