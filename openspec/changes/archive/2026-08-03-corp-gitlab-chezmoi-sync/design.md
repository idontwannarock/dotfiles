## Context

`glab` talks to a corporate GitLab EE instance. Three pieces of state make that work, and today all three live outside chezmoi:

| Piece | Today | Problem |
|---|---|---|
| The binary | hand-dropped `~/.local/bin/glab` 1.105.0 (2026-06-24) | unmanaged, unversioned, absent on a new machine |
| The token | Windows registry → `WSLENV=…GITLAB_TOKEN/u` → WSL env | a propagation shape already retired for `claude-zai` |
| The host | nothing sets `GITLAB_HOST` | bare `glab api version` hits gitlab.com and 401s |

Two constraints shape everything below.

**The repository is public and contains zero corp FQDNs.** A full-text search for the corp domain over `home/`, `docs/`, and `context/` returns nothing. This is deliberate, not accidental: `private_corp-multiplex` states "FQDN/IP host blocks stay machine-local in `~/.ssh/config`; only this generic multiplex + no-pubkey policy is reproduced", and `context/principles.md` lists the WSLENV GitLab token among machine state that is *intentionally* not in the repo. Whatever this change ships must preserve that.

**`claude-zai` already solved the same problem.** It fetches its token from `pass` (Unix) / `gopass` (Windows) at call time, falls back to an env var, and sets the environment for exactly one invocation. Copying that shape costs nothing and keeps one credential idiom in the repo instead of two.

<!-- evergreen-candidate -->
Secrets and corp-identifying values are two different problems with two different answers: secrets go in the vault, corp identifiers stay in machine-local OS state. Neither goes in the repo, but conflating them leads to putting an FQDN in `pass`, where it is neither discoverable nor useful.

## Goals / Non-Goals

**Goals:**

- A new machine gets a working `glab` from `chezmoi apply` plus one documented per-machine step (set `GITLAB_HOST`).
- The token is read from the vault at call time; nothing exports it at shell startup.
- The repository still contains no corp FQDN after this change.
- The version pin is tracked by Renovate like every other external.

**Non-Goals:**

- GitLab native MCP. Probed at `19.2.0-ee`: `/api/v4/mcp` 404 on GET and POST. Recorded, not adopted.
- Making non-interactive callers (cron, harness scripts, a future MCP server) credential-aware. They keep using `$GITLAB_TOKEN` if it is exported.
- Rotating the token. Recommended alongside this change, but the mechanism does not depend on it.
- Managing `GITLAB_HOST` or the `WSLENV` entry from chezmoi. Both carry the corp FQDN.

## Decisions

### D1: One cross-platform external entry, not per-OS entries

`glab`'s release assets are named `glab_<version>_<os>_<arch>.<ext>` with `<os>`/`<arch>` matching chezmoi's `.chezmoi.os` / `.chezmoi.arch` verbatim (`linux_amd64`, `darwin_amd64`, `windows_amd64`). Only the archive extension and the inner path vary (`bin/glab` vs `bin/glab.exe`, `.tar.gz` vs `.zip`). So a single `[".local/bin/glab{{ $ext }}"]` block covers all three OSes, using the `$ext` variable the file already defines.

*Alternative rejected:* a Windows-only external plus apt/brew on Unix, matching how most tools in this repo are split. Rejected because `glab` is not in Ubuntu's archive, and the tarball is the upstream-recommended install everywhere — the split would create work without creating uniformity.

*Consequence:* this is the first entry in `.chezmoiexternal.toml` whose non-`.exe` form is downloaded on Linux and macOS, so the `{{ if eq .chezmoi.os "windows" }}` guards that wrap most of the file must **not** wrap this one.

### D2: Renovate tracks it via the `gitlab-releases` datasource

The custom regex manager in `renovate.json` is datasource-agnostic — it matches `# renovate: datasource=… depName=…` followed by a Go template assignment — so no manager change is needed. The annotation is `datasource=gitlab-releases depName=gitlab-org/cli extractVersion=^v(?<version>.+)$`, because upstream tags carry a `v` prefix the asset filenames do not. This is the file's first non-GitHub datasource; `docs/renovate.md` records it.

### D3: The wrapper shadows `glab` rather than taking a new name

`claude-zai` uses a distinct name because `claude` must stay callable unwrapped. `glab` has no such need — every corp invocation wants the token. Shadowing means existing muscle memory and existing scripts that source `shell_common` keep working with no edit.

Recursion is avoided with `command glab` (bash) and `Get-Command -CommandType Application` (PowerShell). Both are the same mechanism `claude-zai`'s neighbours already use.

*Alternative rejected:* exporting `GITLAB_TOKEN` at shell startup from the vault. Rejected because it fires a gpg pinentry prompt on every new shell — including non-interactive ones, where it hangs. Lazy is the only workable timing.

### D4: The wrapper fails loudly on a missing host

If `GITLAB_HOST` is unset, `glab` silently targets gitlab.com and returns `401 Unauthorized` — an error that points at the token when the actual fault is the host. The wrapper checks first and says so. This is the single highest-value line in the change: it converts the exact misdiagnosis that made the original setup look broken into a one-line answer.

### D5: `GITLAB_HOST` provisioned by hand, documented with a placeholder

Windows registry `HKCU\Environment` + a `WSLENV=GITLAB_HOST/u` entry, both set once per machine. `docs/gitlab-corp-access.md` gives the PowerShell snippet with `gitlab.example.com` as the value, and says plainly that the real FQDN is deliberately absent.

*Alternative rejected:* `promptStringOnce` in `.chezmoi.toml.tmpl`, storing the FQDN in the machine-local chezmoi config. It works and would automate the shell-side export — but it splits corp state across two machine-local stores (registry for the token's fallback, chezmoi config for the host) and adds an init prompt on every machine including the ones that never touch corp GitLab. Keeping host and token in the same place is worth more than the automation.

## Risks / Trade-offs

- **Shell functions do not reach non-interactive callers.** A script run as `bash script.sh` sees no `glab` function. → The fallback path is unchanged: if `$GITLAB_TOKEN` is exported, plain `glab` still works. Documented as a known limit rather than papered over. If a future MCP server or harness needs it, that is the moment to revisit — not now, speculatively.
- **Replacing the running binary.** The external overwrites the hand-installed 1.105.0 with the pin. → `glab` is a single static binary with no state outside `~/.config/glab-cli`; the upgrade is a file swap. Config is untouched.
- **`gopass` on Windows has a known open bug** (noted in `docs/claude-zai-wrapper.md`, which is why the registry env var is still kept as a fallback there). → The same fallback ordering applies here: vault first, `$GITLAB_TOKEN` second. Windows is no worse off than it is for `claude-zai`.
- **`WSLENV` edits need a full restart** (`wsl --shutdown` + Windows Terminal restart), which makes "I set it and it did not work" the default first experience. → Called out in the doc next to the snippet, not buried in prose.
- **Dropping `GITLAB_TOKEN` from `WSLENV` before the vault entry exists** leaves no credential at all. → Migration order below puts the vault write first.

## Migration Plan

1. Store the token in the vault: `pass insert -m gitlab/corp-token` (WSL) and `gopass` (Windows). Encryption needs only the public key, so this does not prompt for a passphrase. Rotate the token first if the 2026-06-24 transcript exposure is judged material — storing the new value directly saves a second write.
2. `chezmoi apply` — lands the external and the wrapper.
3. Verify: `glab api version` returns the instance version, with no `GITLAB_TOKEN` in the environment.
4. Only then remove `GITLAB_TOKEN` from `WSLENV`; keep the registry variable itself as the fallback.

Rollback is `git revert` plus re-exporting `GITLAB_TOKEN`; nothing is destroyed that the vault does not now hold.

## Open Questions

None blocking. One deferred: whether `mcp_server` is merely disabled by feature flag on the corp instance is unanswerable without admin access, and the answer would not change this design — only whether a follow-up change becomes possible.
