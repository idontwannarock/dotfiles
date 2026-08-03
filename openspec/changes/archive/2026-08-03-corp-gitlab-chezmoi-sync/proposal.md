## Why

Corp GitLab (`glab` against an internal GitLab EE instance) works on exactly one machine, and only by accident. The binary was hand-dropped into `~/.local/bin` in 2026-06 and is unmanaged; `GITLAB_HOST` is not set anywhere, so a bare `glab api version` targets gitlab.com and returns 401; and the token reaches WSL through `WSLENV` propagation — a shape this repo already retired for `claude-zai` in favour of a local vault. Nothing about corp GitLab access reproduces on a new machine.

A second, older thread closes here too: the plan to adopt GitLab's native MCP endpoint after the instance upgrade. The upgrade happened (the instance now reports `19.2.0-ee`, past the planned 19.0.2), but `/api/v4/mcp` still answers 404 to both GET and POST, as do `/api/v4/mcp/`, `/api/v4/mcp/sse`, and `/api/v4/ai/mcp`. `/api/v4/features` returns 403 for a non-admin token, so whether the `mcp_server` feature flag is merely off cannot be determined from the client side — but the client-visible answer is the same. Native MCP is **not** adopted by this change.

## What Changes

- **`glab` becomes a chezmoi-external.** One cross-platform entry covering Linux, macOS, and Windows, version-pinned and annotated for Renovate. Replaces the unmanaged hand-dropped binary.
- **The token moves from `WSLENV` propagation to the local vault.** A `glab` shell wrapper reads it lazily at call time — `pass` on Unix, `gopass` on Windows — mirroring the `claude-zai` wrapper's shape, and falls back to `$GITLAB_TOKEN` when the vault is unreachable. The `GITLAB_TOKEN` entry is dropped from `WSLENV`.
- **The corp FQDN stays machine-local.** `GITLAB_HOST` is provisioned per machine (Windows registry `HKCU\Environment` + a `WSLENV` entry that propagates it into WSL). No corp FQDN enters this repo — the existing convention, stated in `private_corp-multiplex` ("FQDN/IP host blocks stay machine-local") and in `context/principles.md`'s list of deliberately un-reproduced machine state. Documentation uses a placeholder.
- **New doc** `docs/gitlab-corp-access.md` carrying the per-machine setup steps and the two known traps (`glab auth status` lies; `WSLENV` edits need `wsl --shutdown`).
- **Not** adopting GitLab native MCP; the probe result is recorded so the next person does not re-run it blind.

## Capabilities

### New Capabilities

- `corp-gitlab-access`: how `glab` resolves its credential and its host across platforms — vault-first with an env fallback, host supplied by machine-local state, and the invariant that no corp FQDN appears in this repository.

### Modified Capabilities

- `tool-dependencies`: adds `glab` to the externals-installed set, and makes it the first external whose single entry serves all three OSes rather than being Windows-only.
- `shell-config`: `shell_common` gains a `glab` wrapper function alongside `claude-zai`; the PowerShell profile gains its counterpart.

## Impact

- `home/.chezmoiexternal.toml` — new `glab` entry + Renovate annotation (first `gitlab-releases` datasource in the file).
- `home/.chezmoitemplates/shell-common/base` — `glab` wrapper function.
- `home/Documents/exact__shared-profile.d/` — new PowerShell fragment for the Windows counterpart.
- `docs/gitlab-corp-access.md` — new.
- `docs/renovate.md` — record the new datasource.
- Machines already carrying the hand-installed `glab 1.105.0` have it replaced by the pinned version on next `chezmoi apply`.
- Non-interactive callers (scripts, harnesses, any future MCP server) do not see a shell function; they continue to rely on `$GITLAB_TOKEN` being exported. This is a deliberate limit of the wrapper approach, addressed in design.
- The token currently in use appeared in a session transcript on 2026-06-24. Rotating it while moving it into the vault is the cheap moment; the mechanism does not depend on the rotation happening.
