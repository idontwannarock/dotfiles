# Corp SSH Setup: Password+OTP Automation

A native-OpenSSH approach to handling corporate SSH targets that require
interactive password + TOTP one-time-password authentication. Designed for
WSL/Ubuntu; Windows and macOS support is future work.

Design rationale and considered alternatives: see
[`docs/superpowers/specs/2026-04-24-corp-ssh-redesign.md`](superpowers/specs/2026-04-24-corp-ssh-redesign.md).

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

### 5. Add ControlMaster to `~/.ssh/config`

`~/.ssh/config` is intentionally **not** managed by chezmoi — it is considered
environment-specific. Append the block below to your existing config:

```
# ──── Corp hosts with password+OTP — enable connection multiplexing ─────────
Host <corp-host-pattern-1> <corp-host-pattern-2> ...
  ControlMaster auto
  ControlPath ~/.ssh/cm/%C
  ControlPersist 8h
```

Scope `Host` to the specific corp host aliases (e.g., `Host corpprefix* other-host`).
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

### When the password is rotated

When the corp AD password expires:

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
