# gpg-agent cache for headless `pass` callers

`pass` decrypts with gpg, and gpg asks gpg-agent for the passphrase. This page
covers the gpg-agent settings and helpers that keep a headless `pass` call from
opening pinentry on the wrong terminal.

No caller in this repo reads `pass` any more. corp-ssh and the `glab` wrapper
read Bitwarden through `bw serve` (see
[corp-ssh-setup.md](corp-ssh-setup.md) and
[gitlab-corp-access.md](gitlab-corp-access.md)). The machine-local
`dex-auto-login` also moved to `bw-get`. The helpers below (`gpg-cache-warm`,
`gpg-cache-keepalive` and its timer, `pinentry-timeout`) stay installed until a
later retirement. This page documents them as they are.

**Tune gpg-agent cache TTL.** These are two timers with different meanings, and
giving them the same value silently disables the first one:

- `default-cache-ttl` is an **idle** timer. Per `man gpg-agent`: *"Each time a
  cache entry is accessed, the entry's timer is reset."* Continuous work
  extends it indefinitely.
- `max-cache-ttl` is an **absolute** ceiling measured from the moment the
  passphrase was entered: *"expired even if it has been accessed recently."*

Set to the same value, the ceiling always wins — the idle timer can never fire,
because any day you are still working is a day you kept resetting it. The
symptom is a prompt that interrupts you at the same elapsed mark regardless of
what you are doing. Give the ceiling plenty of room and let the idle timer
decide:

```bash
mkdir -p ~/.gnupg && chmod 700 ~/.gnupg
cat > ~/.gnupg/gpg-agent.conf <<'EOF'
default-cache-ttl 86400     # idle: a full day untouched forces a re-entry
max-cache-ttl 2592000       # ceiling: 30 days, a backstop rather than a limit
pinentry-program /home/YOU/.local/bin/pinentry-timeout   # absolute path; ~ is not expanded
EOF
chmod 600 ~/.gnupg/gpg-agent.conf
gpg-connect-agent reloadagent /bye
```

`reloadagent` clears every cached passphrase, so run it when you do not mind
re-entering.

**Cap abandoned prompts — but not with `pinentry-timeout`.** gpg-agent keeps
exactly **one** pinentry child, so a prompt nobody answers blocks every later
passphrase request until it is killed by hand. Worse, it has already painted
over whatever terminal gpg-agent was told to use, which may be another session.

The obvious knob does not work. gpg-agent does send the Assuan `SETTIMEOUT`
command and pinentry-curses 1.1.1 answers `OK` — then ignores it. Measured
2026-09-04: under `SETTIMEOUT 5` a prompt was still waiting at 57 seconds. The
same binary's command-line `--timeout` flag expired at exactly 5 seconds and
returned `ERR 83886142 Timeout <Pinentry>`. So `pinentry-timeout` in this file
is not a loose setting; it is no setting at all, and leaving it in only makes
you believe you are protected.

`~/.local/bin/pinentry-timeout` (chezmoi-managed, Linux only) injects the flag
that does work:

```bash
exec /usr/bin/pinentry-curses --timeout "${PINENTRY_TIMEOUT:-120}" "$@"
```

Verifying it takes three checks, and the first two alone are a false green:

1. gpg-agent really calls the wrapper — trigger a prompt, then read
   `/proc/$(pgrep pinentry)/cmdline` and confirm `--timeout 120` is there.
   Reading `gpg-agent.conf` proves only that you edited a file.
2. The normal path still works — enter the passphrase, confirm `pass show`
   succeeds and column 7 of `gpg-connect-agent 'keyinfo --list' /bye` turns `1`.
3. The timeout path completes — the wrapper is re-read on every exec, so
   `sed` its default down to 15 seconds *without* reloading the agent (and
   therefore without clearing the cache), force a prompt with
   `gpg-connect-agent "GET_PASSPHRASE throwaway-id X Prompt Desc" /bye`, and
   leave it alone. The prompt must vanish on schedule and a later `pass show`
   must still succeed, proving the agent's single pinentry slot was released.
   Restore the default afterwards.

`GET_PASSPHRASE` with a throwaway cache-id is the trick that makes step 3 cheap:
it touches no keygrip, so a warm key cache survives the test.

**Keep the cache warm, and refuse to run when it is not.** The timeout above
caps a single prompt. It does not help against the shape that actually hurts: a
background poll loop. On 2026-09-09 a `kubectl` loop retried every three
seconds with a cold cache, so killing one pinentry only made room for the next,
and the terminal it painted over belonged to a different session. Two pieces
address that, and neither replaces the other.

`~/.local/bin/gpg-cache-warm` (chezmoi-managed, Linux only) exits 0 when the
password store's decryption key is cached and 1 when it is not. It derives the
keygrip from `.gpg-id` rather than hardcoding it, and it reads **only the
encryption subkey**: `pass` decrypts and never signs, so a warm signing key says
nothing about whether a prompt will appear. Every headless caller of `pass`
should guard on it and fail with a message instead of summoning pinentry.

No caller in this repo uses the guard any more (see the top of this page). A
future caller should skip the guard only when its controlling terminal is
`GPG_TTY`: a human in their own shell, where a prompt is wanted. Do not use
`[ -t 0 ]` for this test. An agent that runs in a PTY passes it, while its
`GPG_TTY` still names another terminal.

`~/.local/bin/gpg-cache-keepalive`, run every six hours by
`gpg-cache-keepalive.timer`, does one cache-hit decrypt. Because
`default-cache-ttl` is an idle timer, that single access pushes the 24-hour
window forward, so the cache survives a working week and expires only at the
30-day ceiling. It calls the guard first and exits quietly when the cache is
cold: warming needs a passphrase, a passphrase needs pinentry, and pinentry from
a timer draws on whatever terminal it finds.

Two details make the difference between this working and only looking like it:

- **Call the guard by path.** systemd's user PATH does not include
  `~/.local/bin`. A bare `gpg-cache-warm` there resolves to nothing, exits 127,
  and reads as "cold" — a keepalive that silently refreshes nothing forever.
- **Log which branch ran.** Both paths exit 0, because a cold cache is not a
  failure. Without a line in the journal, a keepalive that never warms anything
  is indistinguishable from one that works. Check with
  `journalctl --user -u gpg-cache-keepalive -n 5`; it must say `cache refreshed`.

Neither piece survives a reboot or a gpg-agent restart. Both clear the cache
outright, and only a human can refill it.

**Back up the GPG private key.** If you lose it, every secret in `pass` is
unrecoverable. Recommended:

```bash
gpg --export-secret-keys --armor <FPR> > pass-key.asc   # then store offline
```

