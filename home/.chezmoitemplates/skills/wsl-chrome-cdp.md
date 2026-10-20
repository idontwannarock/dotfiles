# Use an authenticated Windows Chrome from WSL

Separate **connection setup** from **browser control**. Reuse an independent,
authenticated Windows Chrome when possible. Prefer authorized native browser MCP
tools; use `~/.local/bin/cdp.py` only when MCP is unavailable or unsuitable and the
task permits that fallback. Neither driver requires launching a new empty profile.

This skill does not authorize extra websites, API calls, playlist changes, or
permission changes. Preserve the task's confirmation gates. The user handles login,
OTP, project trust, and UAC prompts; credentials must not pass through the agent.

## 1. Check the session and the execution boundary

Before launching anything, check for an existing endpoint and who is using it.
Record the task's endpoint, profile path, selected tab, and any resources created
by this task. Do not restart a browser or replace forwarding used by another session.

If native browser tools are already loaded and authorized, first list pages and
identify the intended tab's ID. Select that ID with `select_page` before reading
its snapshot, or pass the ID directly only if the loaded snapshot schema supports
it. If these checks succeed, reuse that connection and skip browser/network setup.
Do not inspect unrelated tabs or browser storage.

When a connection fails, distinguish these layers:

| Layer | Check | What failure establishes |
|---|---|---|
| Windows browser | Process, actual listening address/port, local `/json/version` | Whether the intended Chrome endpoint exists |
| Ordinary WSL terminal | Route and endpoint reachability | Whether WSL can reach Windows |
| Agent shell | The same minimal checks within its allowed permissions | Whether this execution environment can perform the checks |
| Native MCP | `list_pages`, confirm/select target ID, then its snapshot | Whether the authorized browser driver works |

Minimal shell checks, only when needed:

```bash
command -v powershell.exe
powershell.exe -NoProfile -NonInteractive -Command 'Write-Output "PS_OK"'
ip route show default
```

`Operation not permitted`, `UtilBindVsockAnyPort: socket failed`, or inaccessible
route data do not prove that the user's WSL or Chrome is broken. If the agent shell
is denied, stop that route. Ask for a minimal comparison from the user's ordinary
WSL terminal when needed. An already-authorized native MCP can be tested independently;
do not introduce a bridge or change permissions to evade the denial. Do not reset
Chrome, firewall rules, or login based only on a shell permission error.

## 2. Launch an independent Chrome only if needed

Use a separate profile, not the user's main browser profile. Check whether the
example profile below is already in use before launching it. Run this from WSL
only when Windows process execution is allowed; otherwise label it clearly for
the user to run in WSL, or translate it explicitly for Windows PowerShell.

```bash
powershell.exe -NoProfile -Command '$dir = Join-Path $env:TEMP "chrome-cdp"; New-Item -ItemType Directory -Force -Path $dir | Out-Null; Start-Process "C:\Program Files\Google\Chrome\Application\chrome.exe" -ArgumentList @("--remote-debugging-port=9222", "--user-data-dir=$dir", "--no-first-run", "--no-default-browser-check", "about:blank")'
```

Use `Start-Process`; a shell launch returning successfully is not proof that Chrome
started. Verify the process and listener. Substitute the chosen port if not 9222:

```bash
powershell.exe -NoProfile -Command "(Get-CimInstance Win32_Process -Filter \"Name='chrome.exe'\" | Where-Object { \$_.CommandLine -like '*chrome-cdp*' }).Count"
powershell.exe -NoProfile -Command 'Get-NetTCPConnection -LocalPort 9222 -State Listen | Select-Object LocalAddress,LocalPort,OwningProcess'
```

**Shell quoting:** bash single quotes preserve PowerShell `$` variables; use double
quotes inside PowerShell. If the PowerShell expression needs literal single quotes,
use bash double quotes and escape its `$` and `"`. Do not paste bare PowerShell into
a bash prompt. Do not assume every client's `!` shortcut uses the same shell.

## 3. Verify networking before adding forwarding

Inspect the actual Chrome listener and existing portproxy/firewall rules. WSL can
use NAT or mirrored networking; IPv4/IPv6 listeners also differ. Do not assume
that every machine needs `v4tov6` or that Chrome always binds only `::1`.

For NAT, `ip route show default` normally identifies the Windows host address.
Verify the address for the current session; it can change after a WSL restart.
When shell networking is allowed, query `/json/version` on the confirmed host and
port with a short timeout. A native MCP connection is also valid verification when
the shell route is restricted. Do not hardcode an old host address into this skill.

If forwarding is necessary:

1. Inspect existing rules and reuse a working rule. Do not create duplicates.
2. Choose the forwarding family from the observed listener: for example, an IPv4
   WSL-facing listener to Windows `::1` requires `v4tov6`.
3. Bind the forward to the required Windows WSL-facing address. Restrict the
   firewall rule's local address, port, remote WSL address/range, and applicable
   profile/interface. Do not default to `0.0.0.0` plus unrestricted remote sources
   and `Profile Any`. Do not widen access just to make a test pass.
4. Show the exact proposed rule and its exposure to the user. Ask them to complete
   the elevated operation. Record the rule identity and whether it was newly created.
5. Verify the resulting endpoint. A closed UAC window or no output is not success.

Existing broad rules deserve a warning and a planned review, not an unannounced
mid-task change that interrupts another session. See [WSL networking](https://learn.microsoft.com/en-us/windows/wsl/networking)
and [TCP listener inspection](https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-nettcpconnection).

## 4. Select and verify the browser driver

### Preferred: native Chrome DevTools MCP

Connect to the existing independent Chrome with `--browser-url=<confirmed-endpoint>`.
Do not launch an unrelated headless profile just because the agent has no `DISPLAY`.
Inspect the installed executable's version and help before constructing arguments.
Prefer the already provisioned executable. Do not install or upgrade a global
package as a side effect of evaluating a task-local connection.

For a new evaluation:

- **Codex:** put the server in the task project's `.codex/config.toml`, not the
  user-level `~/.codex/config.toml`. Start the client in that project and let the
  user handle trust. A home-directory session is not the task project's scope.
- **Other clients:** use their project-scoped MCP configuration and approval flow.
  Do not translate a client-specific command or configuration format blindly.
- Record the exact settings added. Keep unrelated settings unchanged. Do not copy
  machine-specific host addresses, package-cache paths, or versions into shared docs.
- Disable usage statistics and CrUX integration. Inspect the installed version's
  supported update-check opt-out; its environment-variable name can vary by version.
- Start with `list_pages`, `select_page`, `take_snapshot`, and, if needed,
  `take_screenshot` only.
  Do not initially expose click, typing, arbitrary JavaScript, or network tools.
- Confirm the client actually loaded the native tools. Reload if required after a
  configuration change. A valid TOML file or MCP handshake alone proves no browser access.
- Confirm the target ID from `list_pages`. Inspect the loaded tool schemas:
  `take_snapshot` does not always accept `pageId`. Use `select_page` first when
  direct routing is unavailable; do not set `bringToFront` unless needed.
- Require a successful page listing and a fresh snapshot of the intended tab.
  Only then report read-only readiness. Add the minimum write tools only when the
  user authorizes the task actions; this does not remove task-specific confirmation gates.
- If unsuitable or abandoned, remove only this evaluation's added settings. Delete
  the project config file/directory only if otherwise empty. Preserve shared caches.

Native MCP and the shell have separate execution boundaries. Success through one
does not imply success through the other. Read the current [MCP connection guide](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/advanced-usage.md#connecting-to-a-running-chrome-instance)
and [Codex project configuration](https://learn.chatgpt.com/docs/config-file/config-basic)
when setting up a new connection.

### Fallback: `cdp.py`

Use only when permitted by the task and the shell's execution policy. Read the
installed helper before relying on its endpoint or target-selection behavior.
It currently connects only to port **9222**; `CDP_HOST` changes the host, not the
port. Before running any helper command, confirm that this endpoint is the
intended session. If the intended endpoint uses another port, keep an authorized
MCP connection or report the helper as unsuitable. Do not probe an unrelated 9222
endpoint or invent a `CDP_PORT` option.

The helper currently uses the first page target. Do not act until that target is
confirmed as the intended page. Avoid concurrent drivers that can change selection
or navigation.

```text
cdp.py tabs              list page targets
cdp.py nav <url>         navigate, print final URL and title
cdp.py get <url>         navigate and read rendered text
cdp.py eval '<js>'       evaluate JavaScript in the selected page
cdp.py fetch <url>       fetch inside the page with its cookies
```

The helper discovers the Windows host from the default route and rewrites loopback
WebSocket addresses. `CDP_HOST` can supply a confirmed host when discovery is
inapplicable; it is not a way around denied network access. It requires Python's
`websockets` package. `eval` and `fetch` are not substitutes for UI-only work: use
only task-authorized endpoints and methods, and never extract cookies or credentials.

## 5. Login and operate

If the intended site is not logged in, ask the user to log in in this independent
Chrome and wait for confirmation. Verify the intended page after login; do not
request passwords or OTP. Reuse a valid login instead of requesting it again.

Use one controller at a time for page mutations. Inspect fresh page state after an
action, verify its result, and respect the task's pacing and confirmation gates.
Stop on a captcha, site error, uncertain mutation result, or a permission denial.
Do not repeat a mutation merely because its response is delayed.

## 6. Teardown according to ownership and task intent

Treat these as separate operations, not one unconditional cleanup command:

- **Browser:** close only the task's independent instance when no other task uses
  it. Honor an explicit leave-open request. Never kill all Chrome processes or a
  different session's instance based only on a broad profile-name substring.
- **Forwarding/firewall:** when no longer needed, remove only task-created rules
  by their recorded identity. Removal may need UAC. Do not remove pre-existing or
  shared rules without agreement. Verify removal instead of assuming elevation worked.
- **Profile:** do not delete it as routine shutdown. Delete only with user approval,
  after the browser stops and no other session uses it. Login may persist while the
  profile remains; deleting it or Windows temporary-file cleanup can remove that login.
- **MCP:** remove temporary evaluation settings when rejected or abandoned. Otherwise
  retain only the agreed project-scoped configuration. Do not delete shared packages.

Report what remains open and who must finish cleanup. A debug endpoint gives its
clients browser control: warn about remaining exposure if teardown is deferred.

## Dated observations, not platform restrictions

- 2026-09-29: one Windows Chrome 154 setup listened on `::1`; IPv4-to-IPv6
  forwarding worked. Inspect the listener again on other versions or machines.
- An earlier local WSLg session had an unresponsive X server. WSL supports GUI
  applications; missing `DISPLAY` in an agent shell does not establish a Windows
  Chrome limitation. Do not recommend `wsl --shutdown` casually: it stops WSL sessions.
- 2026-10-20: ordinary WSL could reach an authenticated Windows Chrome while the
  agent shell was denied socket/route operations. Native Chrome DevTools MCP later
  listed the intended tab, read snapshots, and performed authorized UI actions.
  This verifies that attach mode does not require a fresh headless login.

## Verified endpoints

| Site | Endpoints |
|---|---|
| Glowroot | `/backend/top-level-agent-rollups?from=&to=`, `/backend/transaction/average?agent-rollup-id=&transaction-type=Web\|Background&from=&to=`, `/backend/transaction/queries`, `/backend/transaction/points` (hyphenated params, e.g. `duration-millis-low`), `/backend/trace/header?agent-id=&trace-id=`, `/backend/transaction/full-query-text?full-text-sha1=` |
| Grafana | `/api/datasources` (Prometheus id=1), `/api/datasources/proxy/1/api/v1/query_range` |
| PMM | `/graph/api/datasources/proxy/1/api/v1/query_range` (`/prometheus/` directly returns Access denied); QAN is **POST** `/v1/qan/metrics:getReport` |
