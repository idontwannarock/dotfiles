# Corp GitLab access (`glab`)

`glab` against a corporate GitLab EE instance. chezmoi provides the binary and a
shell wrapper; two pieces of state stay on the machine and are set once by hand.

## What chezmoi provides

| Piece | Where |
|---|---|
| `glab` binary | `.chezmoiexternal.toml` → `~/.local/bin/glab` (all three OSes, one pinned entry, Renovate-tracked) |
| `glab` wrapper | `.chezmoitemplates/shell-common/base` (bash/zsh) and `Documents/exact__shared-profile.d/26-glab.ps1` (PowerShell) |

The wrapper resolves the token **at call time**. It reads the Bitwarden item
`gitlab/corp-token` first and `GITLAB_TOKEN` second. No shell startup path reads
a secret.

The item comes from `bw serve`, the same one that corp-ssh uses. One `bw serve`
runs on Windows, on `localhost:8087`, and serves both Windows and WSL. The
`bw-serve-unlock` logon task starts and unlocks it. See
[corp-ssh-setup.md](corp-ssh-setup.md) and
[corp-ssh-setup-windows.md](corp-ssh-setup-windows.md) for the `bw serve` setup.

| Platform | Reader | Where |
|---|---|---|
| Linux / WSL (bash/zsh) | `~/.local/bin/bw-get gitlab/corp-token` | `home/dot_local/bin/executable_bw-get` |
| Windows (PowerShell) | `Get-BwSecret -Name gitlab/corp-token` | `Documents/exact__shared-profile.d/24-bw-get.ps1` |
| macOS | none; `GITLAB_TOKEN` only | see [Known limits](#known-limits) |

Both readers return the item's `login.password`. Both sync `bw serve` only when
its vault copy is older than 10 minutes. `bw-get` exits 0 on success, 1 when the
item is missing or the field is empty, and 2 when `bw serve` is not reachable or
is locked. `Get-BwSecret` returns `$null` on any failure. On any failure the
wrapper uses `GITLAB_TOKEN`.

The bash/zsh wrapper calls `bw-get` by path, so `~/.local/bin` need not be on
`PATH`. Under WSL, `bw-get` reaches `bw serve` through `curl.exe`. It never
forwards its stdin to `curl.exe`.

Until 2026-09-29 the token lived in `pass` (Linux/WSL/macOS) and `gopass`
(Windows). The bash/zsh wrapper then had a gpg-cache guard, because a cold
cache could start pinentry on another terminal. Nothing reads `pass` now, so no
pinentry can appear and the guard is gone.

## What stays on the machine

**The token**, in the Bitwarden item `gitlab/corp-token`. Secrets never enter this repo.

**The instance FQDN**, in `HKCU\Environment`. This is deliberate and worth
stating plainly: this repository is public and contains **no** corp hostnames.
The same rule governs `~/.ssh/config` — see the note in
`home/private_dot_ssh/config.d/corp-multiplex` — and `context/principles.md`
lists this state among what is intentionally not reproduced. Every command below
uses `gitlab.example.com` as a stand-in; substitute the real host.

## One-time setup

### 1. Store the token in Bitwarden

Create a personal access token in the GitLab UI (`api` scope). Then create a
Bitwarden item in any Bitwarden client (web vault, desktop app, browser
extension, or `bw`):

| Item name | Field | Value |
|---|---|---|
| `gitlab/corp-token` | `login.password` | The token |

The name must match exactly, including case. Use the same Bitwarden account as
corp-ssh. That account holds only company items. One item serves both Windows
and WSL.

`bw serve` must run and be unlocked. Verify from WSL:

```bash
curl.exe -s http://localhost:8087/status    # must contain "status":"unlocked"
```

The migration from `pass` was done on 2026-09-29. Nothing deletes the old
`pass` entry `gitlab/corp-token`.

### 2. Point `glab` at the instance

```powershell
# Windows, once
[Environment]::SetEnvironmentVariable('GITLAB_HOST', 'gitlab.example.com', 'User')

# propagate it into WSL
$cur = [Environment]::GetEnvironmentVariable('WSLENV', 'User')
$new = if ($cur) { "$cur:GITLAB_HOST/u" } else { 'GITLAB_HOST/u' }
[Environment]::SetEnvironmentVariable('WSLENV', $new, 'User')
```

> **Trap — `WSLENV` changes need a full restart.** Opening a new tab is not
> enough. Run `wsl --shutdown` *and* restart Windows Terminal, or the variable
> will be missing and you will conclude the change did not work.

On a Linux or macOS machine with no Windows side, export `GITLAB_HOST` from a
machine-local file that is not chezmoi-managed.

### 3. Verify

```bash
glab api version    # → {"version":"…-ee",…}
```

> **Trap — `glab auth status` lies.** It reports "not authenticated" because it
> only inspects its own config store, which this setup deliberately does not
> use. REST operations work regardless. Test with `glab api version`, never with
> `auth status`.

## Failure messages

Both wrappers emit the same two strings, on purpose:

| Message | Meaning |
|---|---|
| `GITLAB_HOST 未設定；…` | Step 2 is missing or the shell predates it. Without the guard `glab` would target gitlab.com and return `401`, which reads like a token problem and is not. |
| `no token (Bitwarden item gitlab/corp-token unreadable and GITLAB_TOKEN unset)` | Step 1 is missing, or `bw serve` is not running or is locked, and no fallback is exported. On Linux/WSL, run `~/.local/bin/bw-get gitlab/corp-token >/dev/null; echo $?` to see which: 1 means no item, 2 means `bw serve`. |
| `config store 內有明文 token（…）` | Something wrote a token into `glab`'s own config file. See below. |

To reach gitlab.com deliberately, bypass the wrapper: `command glab …` in bash,
or `& (Get-Command glab -CommandType Application | Select-Object -First 1).Source …` in PowerShell.

## The config store is off-limits, and the wrapper enforces it

`glab` has a second credential source the wrapper does not control: its own
config store, plain-text YAML that lives forever.

| Store | Path | Written by |
|---|---|---|
| global | `${GLAB_CONFIG_DIR:-~/.config/glab-cli}/config.yml` | `glab auth login`, `glab config set … --host …` |
| repo-local | `<git-dir>/glab-cli/config.yml` | `glab config set …` **without** `--global` |

Both commands bypass the wrapper and write the token themselves. On 2026-08-28 a
corp token was found sitting in the global store in plain text, put there by a
`glab auth login` run at an unknown earlier date and discovered only by reading
the file by hand. Note that `XDG_CONFIG_HOME` does **not** move this — only
`GLAB_CONFIG_DIR` does (verified against glab 1.112.0).

The wrapper now scans both stores before every call. A non-empty `token:` or
`job_token:` makes it refuse, name the file, and exit 1 — before it reads the
item, so a refused call never touches `bw serve`. An empty `token:` (what `glab`
leaves for a host it has never authenticated) and `glab`'s own comment lines are
not matched.

**The wrapper does not clean up after you, deliberately.** Silently deleting the
line would erase the only thing that matters: the token was on disk in plain
text and has to be rotated. Do both, in this order:

1. Rotate. Revoke the old token in the GitLab UI and create a new one. Put
   the new token in `login.password` of the item `gitlab/corp-token`, in any
   Bitwarden client. One edit serves both Windows and WSL.
2. Clear the store:

```bash
# `command` is load-bearing -- the guard refuses every call through the
# wrapper, including this one. `--host`, not `-h`; `-h` is help.
command glab config set token "" --host gitlab.example.com
```

```powershell
# Windows: the same bypass
& (Get-Command glab -CommandType Application | Select-Object -First 1).Source config set token "" --host gitlab.example.com
```

`glab` drops the key entirely when the value is empty, so nothing is left behind.
For the repo-local store, delete `<git-dir>/glab-cli/config.yml` — no bypass
needed for that one.

The message the guard prints does **not** carry the command, on purpose: the two
platforms need different bypass syntax, and the two wrappers are required to emit
byte-identical strings. It points here instead.

> **Do not run `glab auth login`.** It is the one command that reintroduces this,
> and it buys nothing here — the wrapper already supplies the token on every
> call. This is also why `glab auth status` reports "not authenticated"; see the
> trap above.

## Known limits

- **Non-interactive callers see no wrapper.** A script run as `bash script.sh`,
  a cron job, or a harness gets the bare binary. They work only if
  `GITLAB_TOKEN` is exported in their environment. This is accepted rather than
  solved — solving it means exporting a decrypted secret into every process,
  which is what the vault move was undoing.
  The config-store guard is skipped for the same reason, so a leaked token can
  still go unnoticed until the next interactive call.
- **A rotated token can take up to 10 minutes to arrive.** The readers sync
  `bw serve` only when its vault copy is older than 10 minutes. A corp ssh
  login syncs at once, so the next `glab` call after it gets the new token.
- **`bw serve` must run and be unlocked.** When it is stopped or locked, the
  wrapper uses `GITLAB_TOKEN`, or fails with the `no token` message.
- **macOS has no Bitwarden reader.** chezmoi deploys `bw-get` on Linux/WSL
  only. On macOS the wrapper uses `GITLAB_TOKEN` only. Before 2026-09-29 macOS
  read `pass`.

## GitLab native MCP — probed, not adopted

Probed 2026-08-03 against the corp instance at `19.2.0-ee`:

| Path | GET | POST (`initialize`) |
|---|---|---|
| `/api/v4/mcp` | 404 | 404 |
| `/api/v4/mcp/`, `/api/v4/mcp/sse`, `/api/v4/ai/mcp` | 404 | — |

`/api/v4/features` returns 403 to a non-admin token, so whether the `mcp_server`
feature flag is merely disabled cannot be determined from the client side. The
client-visible answer is the same either way: there is nothing to connect to.
Re-probe after an instance upgrade, not before.
