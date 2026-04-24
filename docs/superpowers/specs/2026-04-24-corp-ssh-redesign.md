# Corp SSH Redesign: Password+OTP Automation for Dev Environment

**Status**: Design — 2026-04-24
**Target platform**: WSL/Ubuntu (Phase 1). Windows and macOS explicit Phase 2+.
**Supersedes**: Prior staged implementation (`dot_local/bin/ssh` dispatcher + `dot_local/bin/corp-ssh` pexpect wrapper, all untracked as of this document).

## Problem

A specific set of corporate SSH targets require interactive password + TOTP one-time-password authentication. SSH public-key authentication is disabled server-side by policy. This imposes two classes of cost:

- **Interactive dev work**. Every new ssh connection requires manual password + OTP entry. Cluster operations across many hosts amplify this cost linearly. A single livekit host requires re-auth for every new ssh call (one per command, if not multiplexed).
- **Non-interactive callers**. Scripts, AI tooling (e.g., `claude -p`), cron jobs, and harness orchestration cannot enter credentials interactively and therefore cannot ssh to these hosts at all without additional machinery.

The previous staged implementation addressed this by intercepting every ssh call (dispatcher at `~/.local/bin/ssh`) and driving openssh's keyboard-interactive auth with credentials pulled from Bitwarden CLI (pexpect wrapper at `~/.local/bin/corp-ssh`). While functional, it:

1. Intercepted every ssh invocation, including for non-corp hosts (passthrough only, but still in the hot path).
2. Managed TTY and signal forwarding manually through pexpect's `child.interact()` — fragile around signals, backgrounding, unusual terminals.
3. Contained corp-specific data (hostnames, user principal, Bitwarden item name) inside the chezmoi source tree at `dot_corp-ssh/hosts.yaml`. The dotfiles repo is public; a single accidental `git add .` would leak that data.
4. Did not benefit from OpenSSH's native `ControlMaster` connection multiplexing, so every ssh call, even repeated calls to the same host, paid the full auth cost.

## Goals

- **R1 (baseline)**. Interactive dev work on affected hosts requires at most one password+OTP entry per host per working session (plus Bitwarden unlock once per session). Subsequent calls within that session are transparent.
- **R3 (resilience)**. Non-interactive callers — cron, harness, `claude -p` cross-session — can ssh to affected hosts without manual intervention, as long as the Bitwarden session stored at `~/.bw-session` is valid.
- **Repository hygiene**. No corp-specific data (hostnames, usernames, realm names, Bitwarden item name) in the public dotfiles repo. All sensitive configuration lives in locally-maintained files under `$HOME` that are never committed.

## Non-Goals

- **Cross-platform support**. Phase 1 targets WSL/Ubuntu only. Windows and macOS are explicit Phase 2+.
- **Server-side changes**. Enabling SSH keys, configuring Kerberos OTP-over-KDC, provisioning user certificates, and similar server or AD/IPA-admin actions are out of scope.
- **Automated password rotation**. When the corp AD password expires, the user rotates it manually and updates the Bitwarden item. The design does not attempt to drive the password-change flow.
- **Automated Bitwarden session refresh**. When `~/.bw-session` expires (which in practice means the user ran `bw lock`, or changed their master password, or received a cloud-side forced logout), the user re-runs `bw unlock --raw > ~/.bw-session`. The design does not store master passwords on disk to automate this.

## Architecture

Two layers, both leveraging native OpenSSH mechanisms. No custom dispatcher, no pexpect.

**Layer 1 — Connection reuse** via `ControlMaster` + `ControlPersist` in `~/.ssh/config`. After the first authenticated ssh to a host, OpenSSH retains a multiplex socket at `~/.ssh/cm/<user>@<host>:<port>` for 8 hours. All subsequent ssh/scp/rsync/git-ssh calls to that host reuse the socket — zero auth prompts, sub-100ms connect time.

**Layer 2 — Non-interactive credential entry** via `SSH_ASKPASS` + `SSH_ASKPASS_REQUIRE=force`. When OpenSSH needs a password or keyboard-interactive prompt (first-time connection, master expired, etc.), instead of reading from the TTY it invokes a user-provided helper (`corp-ssh-askpass`) with the prompt text as argv[1]. The helper parses the hostname out of the prompt, looks it up in `~/.corp-ssh/hosts.yaml`, and — if the host is a known corp target — retrieves password or TOTP from Bitwarden CLI and writes it to stdout. OpenSSH reads the helper's stdout as the credential.

```
caller (shell / claude -p / harness / git / scp)
      │
      ▼
/usr/bin/ssh                   ← native openssh, not intercepted
      │  reads ~/.ssh/config:
      │    Host <corp-host-pattern>
      │      ControlMaster auto
      │      ControlPath ~/.ssh/cm/%r@%h:%p
      │      ControlPersist 8h
      │
      ├─ cached socket live → reuse, 0 prompts, 0 auth
      │
      └─ no socket or expired → need interactive auth
             │
             │  SSH_ASKPASS_REQUIRE=force → no TTY read,
             │  invoke helper with prompt text as $1
             ▼
        ~/.local/bin/corp-ssh-askpass  (~30 lines bash)
             │
             │  1. parse hostname out of prompt
             │  2. look up in ~/.corp-ssh/hosts.yaml
             │  3. if match: bw get password | bw get totp
             │  4. if no match: exit 1 (openssh falls back to
             │                   TTY prompt if available, else fails)
             ▼
        credential on stdout → openssh submits, auth completes
        → master socket created, next call is Layer 1
```

**Key design principles**:

- **No dispatcher wraps `ssh`**. PATH resolves to `/usr/bin/ssh` directly. Non-corp connections are unaffected; the helper is only invoked when OpenSSH genuinely needs a prompt.
- **The askpass helper is generic**. It contains no hostnames, realm names, Bitwarden item names, or other corp identifiers. All corp-specific state lives in `~/.corp-ssh/hosts.yaml` (not in the repo) and the Bitwarden vault.
- **ControlMaster provides the resilience**. The askpass helper is only needed during the first-auth window. After that, Layer 1 carries everything for 8 hours.

## Components

### In the dotfiles repo (chezmoi-managed, public-safe)

| Path | Purpose |
|---|---|
| `dot_local/bin/executable_corp-ssh-askpass` | Generic askpass helper. Bash. No corp identifiers. |
| `.chezmoitemplates/shell-common/linux` (additions) | Shell startup: loads `BW_SESSION` from `~/.bw-session`; exports `SSH_ASKPASS*` if helper is installed. |
| `.chezmoiignore.tmpl` (adjustments) | Excludes `corp-ssh-askpass` on non-Linux targets. Old patterns for removed files are deleted. |
| `docs/corp-ssh-setup.md` | Sanitized user-facing setup guide. Placeholders for all corp-specific values. |
| `docs/superpowers/specs/2026-04-24-corp-ssh-redesign.md` | This document. |

### Local, not in repo, not managed by chezmoi

| Path | Purpose | How it gets there |
|---|---|---|
| `~/.ssh/config` (additions) | `ControlMaster`/`ControlPath`/`ControlPersist` for corp host patterns | Manual edit, ~5 lines |
| `~/.corp-ssh/hosts.yaml` | Corp hostnames + Bitwarden item name | Manual, `chmod 600` |
| `~/.bw-session` | Bitwarden session token for helper use | `bw unlock --raw > ~/.bw-session && chmod 600 ~/.bw-session` |
| `~/.ssh/cm/` | ControlMaster socket directory | Created on demand by OpenSSH |
| Bitwarden item `<configurable-name>` | AD password + TOTP secret | Created once in Bitwarden GUI or CLI |

## Detailed Design

### corp-ssh-askpass helper

Full source (commit as `dot_local/bin/executable_corp-ssh-askpass`):

```bash
#!/usr/bin/env bash
# corp-ssh-askpass — SSH_ASKPASS helper for password+OTP hosts.
#
# Invoked by openssh when SSH_ASKPASS_REQUIRE=force is set and openssh
# would otherwise prompt via the TTY. Reads ~/.corp-ssh/hosts.yaml
# (local-only, not in repo) to decide which hosts to answer for;
# credentials come from Bitwarden CLI via the user's unlocked session.

set -eu

prompt="${1:-}"
hosts_file="$HOME/.corp-ssh/hosts.yaml"

# 1. Parse hostname from prompt: "(user@host.fqdn) Password:" → host.fqdn
#    Uses greedy "(.+@)?" to handle prompts where the user principal itself
#    contains '@', e.g. "(ad-user@corp-domain@actual-host.fqdn) Password:".
if [[ ! "$prompt" =~ \((.+@)?([^)]+)\) ]]; then
  exit 1   # prompt format unrecognized → decline
fi
target_host="${BASH_REMATCH[2]}"
short_host="${target_host%%.*}"

# 2. Only answer for hosts listed in hosts.yaml
[[ -r "$hosts_file" ]] || exit 1
if ! grep -qE "^[[:space:]]*-[[:space:]]*(${short_host}|${target_host})[[:space:]]*\$" "$hosts_file"; then
  exit 1   # not a corp host → decline, openssh may fall back to TTY
fi

# 3. Resolve bw_item from yaml
bw_item=$(awk -F: '/^bw_item:/ { print $2 }' "$hosts_file" | tr -d ' ')
[[ -n "$bw_item" ]] || exit 1

# 4. Ensure BW_SESSION — env first, fallback to ~/.bw-session file
if [[ -z "${BW_SESSION:-}" && -r "$HOME/.bw-session" ]]; then
  export BW_SESSION="$(cat "$HOME/.bw-session")"
fi

# 5. Dispatch by prompt content
case "$prompt" in
  *"Password:"*)          bw get password "$bw_item" 2>/dev/null ;;
  *"One-time Password:"*) bw get totp "$bw_item" 2>/dev/null ;;
  *) exit 1 ;;
esac
```

Notes on design choices:

- `exit 1` on unrecognized prompts. OpenSSH interprets this as the user cancelling the prompt and aborts the auth attempt. The alternative — `echo ""; exit 0` — would submit an empty credential, which typically also fails but might trigger additional rounds. `exit 1` is explicit and avoids ambiguity.
- Regex match on `hosts.yaml` is intentionally simple (no YAML parser). The hosts file is small and controlled.
- `BW_SESSION` fallback from file enables non-shell invocation contexts (cron, systemd timer, `claude -p` spawned from a harness without inheriting shell env).

### Shell init additions

`.chezmoitemplates/shell-common/linux` contains (first block exists from prior staged work; second block is new):

```bash
# ── Bitwarden session (used by corp-ssh-askpass and manual `bw` calls) ─────
# Create once per master-password lifetime:
#   bw unlock --raw > ~/.bw-session && chmod 600 ~/.bw-session
if [ -r "$HOME/.bw-session" ]; then
    export BW_SESSION="$(cat "$HOME/.bw-session")"
fi

# ── SSH askpass for hosts requiring password + OTP ─────────────────────────
# Set SSH_ASKPASS_REQUIRE=force so openssh uses the helper regardless of TTY
# state. Safe globally: helper declines (exit 1) for unknown prompts, so ssh
# to hosts with key auth or other methods is unaffected.
if [ -x "$HOME/.local/bin/corp-ssh-askpass" ]; then
    export SSH_ASKPASS="$HOME/.local/bin/corp-ssh-askpass"
    export SSH_ASKPASS_REQUIRE=force
fi
```

### .chezmoiignore.tmpl adjustments

Remove the old exclusions for files that no longer exist in source:

```
{{- if ne .chezmoi.os "linux" }}
.local/bin/corp-ssh      ← REMOVE
.local/bin/ssh           ← REMOVE
.corp-ssh                ← REMOVE (dir no longer in source)
{{- end }}
```

Add exclusion for the new helper on non-Linux:

```
{{- if ne .chezmoi.os "linux" }}
.local/bin/corp-ssh-askpass
{{- end }}
```

### ~/.ssh/config additions (local, manual)

User appends to their existing `~/.ssh/config`:

```
# ──── Corp hosts with password+OTP auth — enable connection multiplexing ──
Host <corp-host-pattern-1> <corp-host-pattern-2> ...
  ControlMaster auto
  ControlPath ~/.ssh/cm/%r@%h:%p
  ControlPersist 8h
```

Scope the `Host` pattern to the actual corp hosts (glob patterns like `<corp-prefix>*` are fine). Do **not** use `Host *` — that would enable multiplexing for all connections, which may not be desired for short-lived connections like git-over-ssh.

The directory `~/.ssh/cm/` must exist with mode no worse than 755:

```bash
mkdir -p ~/.ssh/cm
chmod 755 ~/.ssh/cm
```

### ~/.corp-ssh/hosts.yaml template (local, manual)

```yaml
# ~/.corp-ssh/hosts.yaml — local-only, never committed.
# chmod 600.

bw_item: <your-bitwarden-item-name>

password_otp_hosts:
  # Entries must match the hostname that sshd emits in its prompt, which is
  # the HostName value from ssh config, NOT the ssh config alias. Either the
  # full FQDN or its first-segment short form is accepted (helper checks both).
  - <actual-host-1>.example.com
  - <actual-host-2>         # short form (first dot-separated segment)
```

**Important caveat**: The ssh config alias (e.g., `Host foo` → `ssh foo`) is only a client-side shortcut. After config resolution, openssh connects to `HostName` and the server's PAM emits that FQDN in the prompt. `hosts.yaml` entries therefore must be the actual hostname, not the alias.

To regenerate `hosts.yaml` entries from an existing `~/.ssh/config`:

```bash
for alias in <alias1> <alias2> ...; do
  ssh -G "$alias" | awk '/^hostname / { print "  - " $2 }'
done
```

This emits YAML-ready lines of the form `  - dev-actual-host.corp-domain`.

### Bitwarden item

One item in the user's Bitwarden vault, with name matching `bw_item` in `hosts.yaml`:

- **Name**: matches `bw_item` in `hosts.yaml`
- **Username**: user's AD principal (e.g., `<user>@<corp-domain>`)
- **Password**: current AD password
- **TOTP**: `otpauth://totp/...` URI or base32 secret

`bw get password <item>` and `bw get totp <item>` must both return non-empty values after initial setup.

## R3 — Resilience Extension

R1 already supports non-interactive callers via the `BW_SESSION` file fallback. The residual risk is that `~/.bw-session` becomes invalid, in which case `bw get` fails, `corp-ssh-askpass` returns exit 1, and the ssh call aborts with a non-obvious failure.

R3 adds (optional, defer until R1 pain is observed):

**R3-a: Session health check + alerting**
- Cron job or systemd timer: every hour, run `BW_SESSION=$(cat ~/.bw-session) bw status`
- If not `unlocked`, write a desktop notification (`notify-send`) so the user can proactively refresh before running a harness task.

**R3-b: Harness-side error surfacing**
- Enhance `corp-ssh-askpass` to also emit a diagnostic line to stderr when `bw get` fails (stderr is forwarded to openssh, and to the harness log). Users debugging a stuck harness will see `corp-ssh-askpass: Bitwarden vault locked` in the journal.

Both are lightweight (~20 lines of additional bash). Implementation deferred until observed need.

## Deployment Plan

| Phase | Action | Verification |
|---|---|---|
| **P0** | `rm ~/.local/bin/ssh ~/.local/bin/corp-ssh` in WSL | `type -a ssh` shows `/usr/bin/ssh` only |
| **P1** | Author `dot_local/bin/executable_corp-ssh-askpass` in chezmoi source | File exists, executable bit, `shellcheck` passes |
| **P2** | Update `.chezmoitemplates/shell-common/linux` with both env export blocks | `chezmoi diff` shows expected additions |
| **P3** | Delete `dot_local/bin/executable_ssh`, `dot_local/bin/executable_corp-ssh`, `dot_corp-ssh/`, old `docs/corp-ssh-setup.md` from chezmoi source | Source tree free of old wrapper artifacts |
| **P4** | Adjust `.chezmoiignore.tmpl` (remove old patterns, add new) | `chezmoi verify` passes |
| **P5** | Rewrite `docs/corp-ssh-setup.md` — sanitized, placeholder-based | Grep for sensitive tokens returns no hits |
| **P6** | `chezmoi apply` | `~/.local/bin/corp-ssh-askpass` present, executable |
| **P7** | User: edit `~/.ssh/config` adding ControlMaster block | `ssh -G <corp-host> \| grep -i control` shows config applied |
| **P8** | User: verify `~/.corp-ssh/hosts.yaml` contains **actual hostnames** (FQDN or short form from `ssh -G <alias> \| awk '/^hostname/'`), not ssh config aliases — regenerate if needed. Verify `~/.bw-session` exists or recreate via `bw unlock --raw > ~/.bw-session && chmod 600 ~/.bw-session`. | Files present with mode 600; entries match HostName values in ssh config |
| **P9** | Smoke test (see Testing Plan below) | All test cases pass |
| **P10** | Commit — staged source changes, new docs, no local-only files | `git status` clean after commit |

P1-P5 are repo changes. P6-P10 are WSL state changes. P0 is pre-work.

## Testing Plan

### Happy path

1. **Fresh first connection**. After `bw unlock --raw > ~/.bw-session`, run `/usr/bin/ssh <livekit-host> hostname`. Expected: no prompts, returns hostname in <5 seconds.
2. **Cached second connection**. Immediately run `/usr/bin/ssh <livekit-host> hostname` again. Expected: <100ms, no auth activity in `ssh -v`.
3. **ProxyJump path**. `/usr/bin/ssh <corp-host-behind-jump> hostname`. Expected: dev jump host authenticates via existing SSH key; destination authenticates via askpass. No user input.
4. **ControlMaster socket visibility**. After (1)-(3), `ls ~/.ssh/cm/` shows one socket per destination host.
5. **Non-interactive caller**. From a subshell with no TTY: `setsid -w /usr/bin/ssh <corp-host> hostname`. Expected: succeeds, returns hostname.

### Edge cases

1. **Master expired**. Wait >8 hours after last connection, or manually kill: `/usr/bin/ssh -O exit <corp-host>`. Next ssh should re-authenticate via askpass (zero prompts if Bitwarden unlocked).
2. **Bitwarden locked**. Run `bw lock`, then `/usr/bin/ssh <corp-host>`. Expected: prompt still fires, but `bw get` fails inside helper, helper returns exit 1, openssh aborts with `Permission denied` or similar. Error visible in `ssh -v` output.
3. **Unknown host**. `/usr/bin/ssh random-host-not-in-hosts-yaml`. Expected: askpass helper returns exit 1. With `SSH_ASKPASS_REQUIRE=force`, openssh treats this as a cancelled prompt and fails the current auth method; it does not fall back to TTY. No corp credentials leaked. If the user legitimately needs to enter a password for a non-corp host, they temporarily unset `SSH_ASKPASS_REQUIRE` for that session.
4. **Passphrase-protected SSH key** (user doesn't currently have, but document). If a user later adds a key with passphrase, openssh will call askpass with a prompt like `Enter passphrase for key '...':`. The helper does not match this pattern and returns exit 1, aborting ssh. **Documented constraint**: SSH keys used with this setup must be unencrypted. If a passphrased key is required, the user must unset `SSH_ASKPASS_REQUIRE` for that session (e.g., `SSH_ASKPASS_REQUIRE=never ssh host`) to let openssh prompt via TTY.
5. **Prompt format changes**. If the corp sshd ever changes its prompt format (e.g., drops the `(user@host)` prefix), the regex in the helper will fail to extract the hostname and return exit 1. Detect by running `ssh -v` and observing the raw prompt.

## Considered Alternatives

### Branch A — Kerberos / GSSAPI (deferred, blocked at OTP preauth)

The corp servers advertise GSSAPI in their sshd `Authentications that can continue` list (`publickey,gssapi-keyex,gssapi-with-mic,password,keyboard-interactive`). If a valid Kerberos TGT were in the user's credential cache, sshd would accept it and auth would complete without any password/OTP interaction. One `kinit` per day (TGT lifetime 24h, observed) would cover all corp ssh for the day, with the bonus of `forwardable=true` enabling passwordless `sudo` on the server via credential delegation.

This is the most native, cleanest, and most scalable approach. It failed validation due to client-side OTP preauth constraints.

**Probing conducted (2026-04-24)**:

1. **Server advertises GSSAPI**: Yes. `/usr/bin/ssh -vv <corp-host>` output confirms `gssapi-with-mic` and `gssapi-keyex` in auth methods.
2. **KDC discovery via DNS SRV**: Success once the correct realm (`<ipa-realm>`, discovered via `/etc/krb5.conf` on an authenticated server) was known. Two IPA replicas are published via `_kerberos._udp.<ipa-domain>` and `_kerberos._tcp.<ipa-domain>` SRV records.
3. **Anonymous PKINIT for FAST armor**: Success, after installing `krb5-pkinit` and copying `kdc-ca-bundle.pem` from the server to `/etc/ipa/` on WSL.
4. **FAST-armored real kinit**: **Failed**. KDC offered `PA-OTP-CHALLENGE (141)` inside the FAST channel, client-side OTP module packed a `PA-OTP-REQUEST (142)`, KDC responded `-1765328360/Preauthentication failed`. Both password+OTP-concatenated and OTP-only input formats were rejected.

**Most likely root causes** (none verifiable without IT admin access):

1. (~60% probability) The corp IPA realm proxies OTP validation to a separate RADIUS-backed MFA provider (`ipauserauthtype = radius`). The TOTP secret that the user has stored (and that works for sshd's PAM-driven keyboard-interactive) lives in that external provider, not in IPA's native OTP token store. The KDC's OTP preauth only consults IPA-native tokens, so the validation necessarily fails.
2. (~25%) The user's IPA account has an OTP token configured but it is not enabled for Kerberos preauth (only for sshd PAM).
3. (~10%) TOTP clock drift (`timedatectl` on WSL shows synchronized, so improbable).
4. (~5%) Other IPA policy constraints.

**Path to reactivate Branch A**:

If IT ever enables IPA-native OTP for Kerberos preauth on this user's account, or provisions a user certificate (X.509) that can be used with PKINIT, Branch A becomes viable. The probing work is reusable:

- `/etc/krb5.conf` with `default_realm = <ipa-realm>`, `dns_lookup_kdc = true`, `pkinit_anchors` pointing at the IPA CA bundle.
- `krb5-pkinit` package installed.
- `/etc/ipa/kdc-ca-bundle.pem` copied from a corp server.
- Anonymous PKINIT for FAST armor works.

The only missing piece is a working preauth mechanism on the user's IPA account. When that arrives, the flow is:

```bash
kinit <user>@<ipa-realm>     # enter password and OTP as prompted
klist                          # verify TGT present
/usr/bin/ssh <corp-host>       # openssh will try gssapi-with-mic first,
                               # succeed silently
```

At that point Branch B (this spec) becomes redundant for Kerberos-capable hosts, though leaving Branch B in place as a fallback for servers that reject GSSAPI is reasonable.

### Old staged implementation — pexpect + Bitwarden + dispatcher (replaced)

The prior staged approach (in `dot_local/bin/executable_ssh` + `dot_local/bin/executable_corp-ssh` + `dot_corp-ssh/hosts.yaml`) wrapped every ssh invocation. Retrospectively:

**What worked**: it functionally handled the password+OTP flow, including from non-interactive contexts.

**Why replaced**:

- All ssh calls passed through the dispatcher (even for non-corp hosts, even for repeat calls after initial auth).
- Managed the full connection lifetime via `pexpect.spawn` + `child.interact()` — fragile around signal forwarding, unusual terminals, and process-group handoff.
- Did not use ControlMaster, so the pexpect+bw auth ran on every ssh.
- Stored corp hostnames and Bitwarden item name inside the chezmoi source tree (`dot_corp-ssh/hosts.yaml`). Staged but never committed, which is fragile — any `git add .` in the repo would have leaked to the public repo.

**Reusable ideas**:

- `hosts.yaml` format (hostname list + bw_item name) is reused; only its location changed from `dot_corp-ssh/hosts.yaml` in the repo to `~/.corp-ssh/hosts.yaml` locally.
- The Bitwarden session persistence pattern (`~/.bw-session` file loaded by shell init) is reused wholesale.
- The password-rotation handling is reused in spirit (manual rotation; helper fails loudly, user updates Bitwarden, `bw sync`, retry).

### Why not sshpass

`sshpass` is designed for single-password auth. It cannot handle the second prompt (`One-time Password:`) without patches or hacks. The askpass mechanism is the native OpenSSH facility for this exact scenario.

### Why not storing credentials in the filesystem

An askpass helper that reads `~/.ssh/corp-password` directly would be simpler. Rejected because:

- A plaintext password on disk is a persistent secret. A locked Bitwarden vault is a less-persistent secret (the unlocked session expires or can be locked on demand).
- Bitwarden TOTP generation is better than storing a TOTP secret in a flat file — the secret stays inside the vault, only 30-second codes escape.
- Password rotation is user-driven via Bitwarden GUI, which is the same workflow the user already uses for other passwords. No new rotation ritual.

## Future Work

- **R3 implementation** if user observes session-lock issues in production harness use.
- **Branch A reactivation** if IT enables IPA-native OTP or provisions user certificates.
- **Windows OpenSSH port**. Same `ControlMaster` + askpass mechanism should work on Windows OpenSSH (ssh.exe supports `SSH_ASKPASS`). Git Bash is the likely shell context. Deferred — requires testing.
- **macOS port**. Same mechanism should work. `SSH_ASKPASS_REQUIRE=force` behavior varies by OpenSSH version. Deferred.
- **Cluster operation ergonomics**. User mentioned wanting to script kws-cluster operations (config edit → restart → verify across all hosts). With R1 in place, this is a straightforward shell loop or ansible playbook; auth is amortized. Not part of this spec but enabled by it.
