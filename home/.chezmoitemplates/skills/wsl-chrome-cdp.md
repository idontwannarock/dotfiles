# Use an authenticated Windows Chrome from WSL

Separate **connection setup** from **browser control**. Reuse an independent,
authenticated Windows Chrome when possible. Control it with `playwright-cli`
attached over CDP. It does not need a new empty profile.

This skill does not authorize extra websites, API calls, playlist changes, or
permission changes. Preserve the task's confirmation gates. The user handles login,
OTP, project trust, and UAC prompts; credentials must not pass through the agent.

## 1. Check the session and the execution boundary

Before launching anything, check for an existing endpoint and who is using it.
Record the task's endpoint, profile path, selected tab, and any resources created
by this task. Do not restart a browser or replace forwarding used by another session.

If `playwright-cli -s=cdp tab-list` already works, reuse that session and skip
browser and network setup. Do not inspect unrelated tabs or browser storage.

When a connection fails, distinguish these layers:

| Layer | Check | What failure establishes |
|---|---|---|
| Windows browser | Process, actual listening address/port, local `/json/version` | Whether the intended Chrome endpoint exists |
| Ordinary WSL terminal | Route and endpoint reachability | Whether WSL can reach Windows |
| Agent shell | The same minimal checks within its allowed permissions | Whether this execution environment can perform the checks |
| `playwright-cli` | `attach`, `tab-list`, `tab-select`, then `snapshot` | Whether the browser driver works |

Minimal shell checks, only when needed:

```bash
command -v powershell.exe
powershell.exe -NoProfile -NonInteractive -Command 'Write-Output "PS_OK"'
ip route show default
```

`Operation not permitted`, `UtilBindVsockAnyPort: socket failed`, or inaccessible
route data do not prove that the user's WSL or Chrome is broken. If the agent shell
is denied, stop that route. Ask for a minimal comparison from the user's ordinary
WSL terminal when needed. Do not introduce a bridge or change permissions to evade
the denial. Do not reset
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

Commands for the NAT case with Chrome on `::1`. Inspect first; this needs no UAC:

```bash
powershell.exe -NoProfile -Command 'netsh interface portproxy show all; Get-NetFirewallRule -DisplayName "WSL-CDP*" -ErrorAction SilentlyContinue | Select-Object Name,DisplayName,Profile'
```

The add command binds the forward to the Windows WSL-facing address only. The firewall
rule admits only this WSL address. `-Name` is the rule identity: a second add with the
same name fails instead of creating a duplicate. Show it to the user; it needs UAC:

```bash
WINHOST=$(ip route show default | awk '{print $3}')
WSLIP=$(ip -4 -o addr show eth0 | awk '{split($4,a,"/"); print a[1]}')
powershell.exe -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-Command','netsh interface portproxy add v4tov6 listenport=9222 listenaddress=$WINHOST connectport=9222 connectaddress=::1; New-NetFirewallRule -Name WSL-CDP-9222 -DisplayName WSL-CDP-9222 -Direction Inbound -Protocol TCP -LocalPort 9222 -LocalAddress $WINHOST -RemoteAddress $WSLIP -Action Allow'"
curl -s -m 5 "http://$WINHOST:9222/json/version"
```

`$WSLIP` changes after a WSL restart. The rule then no longer admits WSL: remove it
and add it again.

Existing broad rules deserve a warning and a planned review, not an unannounced
mid-task change that interrupts another session. See [WSL networking](https://learn.microsoft.com/en-us/windows/wsl/networking)
and [TCP listener inspection](https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-nettcpconnection).

## 4. Select and verify the browser driver

### Default: `playwright-cli`

`playwright-cli` is a shell command. It adds no tool schema to the agent context,
and scripts can call it the same way the agent does. Attach it to the confirmed
endpoint; it does not start a new browser or a new profile:

```bash
WINHOST=$(ip route show default | awk '{print $3}')
cd "$(mktemp -d)"    # snapshots go to ./.playwright-cli/; keep them out of repos
playwright-cli -s=cdp attach --cdp="http://$WINHOST:9222"
playwright-cli -s=cdp tab-list
playwright-cli -s=cdp tab-select <index>
```

Use `-s=cdp` (or `PLAYWRIGHT_CLI_SESSION=cdp`) on every command. Select the intended
tab with `tab-select` and confirm it before you read or act. Read the installed
`playwright-cli --help` before you use a command that is not below.

| Task | Command |
|---|---|
| Open a page | `playwright-cli -s=cdp goto <url>` |
| Read the page | `playwright-cli -s=cdp --raw snapshot`, or `find <text>` for one part |
| Click or fill | `click <ref>`, `fill <ref> <text>`; refs such as `e13` come from the snapshot |
| Call an API with the login cookies | `playwright-cli -s=cdp --raw eval "async () => { const r = await fetch('<url>', {credentials: 'include'}); return {status: r.status, body: await r.json()}; }"` |
| Many API calls | One `eval` with `Promise.all` inside the page, not one `eval` per URL |
| Screenshot | `playwright-cli -s=cdp screenshot` |
| Stop controlling | `playwright-cli -s=cdp detach` |

`--raw` prints only the result. An `eval` that returns an object prints JSON, so
`jq` can read it. A returned string prints as a quoted JSON string.

Use `fetch` only for task-authorized endpoints and methods. Never read or export
cookies, storage, or credentials: no `cookie-*`, `localstorage-*`, `sessionstorage-*`,
or `state-save` on this browser.

End with `detach`. It leaves Chrome running. Do not run `close`, `close-all`,
`kill-all`, or `delete-data` on an attached session: the browser and its login
belong to the user.

Write a script only for a fixed flow with several steps, for example fetch, then
click, then fetch again. The script calls the same `playwright-cli` commands.
Until a flow is that fixed, the table above and the endpoints at the end of this
skill are the reference.

### When the agent shell cannot reach Chrome

`playwright-cli` runs in the agent shell. When the shell is denied network access
(see step 1), `playwright-cli` cannot work either. Do not bypass the denial. Report
it. If the user wants to continue in that client, a project-scoped Chrome DevTools
MCP with `--browser-url=<confirmed-endpoint>` runs outside the shell; the setup is
in `docs/claude-code.md`. Add it only with the user's agreement and remove it after.

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

- **Driver:** run `playwright-cli -s=cdp detach`. It stops control and leaves
  Chrome running.
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

Commands. `<PID>` is the `OwningProcess` recorded from the listener check in step 2.
Stop the browser (no UAC), then confirm that the listener is gone:

```bash
powershell.exe -NoProfile -Command 'Stop-Process -Id <PID>; Start-Sleep -Seconds 1; (Get-NetTCPConnection -LocalPort 9222 -State Listen -ErrorAction SilentlyContinue | Measure-Object).Count'
```

Remove the task-created forward and rule (needs UAC), then run the inspect command
from step 3 to confirm removal:

```bash
WINHOST=$(ip route show default | awk '{print $3}')
powershell.exe -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-Command','netsh interface portproxy delete v4tov6 listenport=9222 listenaddress=$WINHOST; Remove-NetFirewallRule -Name WSL-CDP-9222'"
```

Report what remains open and who must finish cleanup. A debug endpoint gives its
clients browser control: warn about remaining exposure if teardown is deferred.

### Full reset: leftovers from earlier sessions

Earlier sessions can leave duplicate `WSL-CDP-9222` rules, a forward on `0.0.0.0`,
or a CDP Chrome that nobody closed. The task-scoped teardown above does not touch
them. Do a full reset when the user asks to restore the machine, or when the step 3
inspect command shows entries that this task did not create.

1. Run the step 3 inspect command and the step 2 listener check. Tell the user each
   entry you found: forwards on port 9222, `WSL-CDP-*` rules, and the listener PID.
2. Ask whether another session still uses that Chrome or forward. Continue only
   after the user confirms that nothing uses them.
3. Stop the browser with the stop command above, using the listener PID.
4. Remove every port 9222 forward and every `WSL-CDP-*` rule (needs UAC). The script
   reads the forwards from the registry, because `netsh` output changes with the
   Windows display language. `-EncodedCommand` avoids nested quoting:

   ```bash
   cat > /tmp/wsl-cdp-reset.ps1 <<'PS1'
   foreach ($kind in 'v4tov4', 'v4tov6') {
       $key = "HKLM:\SYSTEM\CurrentControlSet\Services\PortProxy\$kind\tcp"
       (Get-Item $key -ErrorAction SilentlyContinue).Property | Where-Object { $_ -like '*/9222' } | ForEach-Object {
           netsh interface portproxy delete $kind listenport=9222 listenaddress=$($_.Split('/')[0])
       }
   }
   Get-NetFirewallRule -DisplayName 'WSL-CDP-*' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
   PS1
   ENC=$(iconv -t UTF-16LE /tmp/wsl-cdp-reset.ps1 | base64 -w0)
   powershell.exe -NoProfile -Command "Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-EncodedCommand','$ENC'"
   ```

   To preview without changes and without UAC, add `-WhatIf` to `Remove-NetFirewallRule`,
   replace `netsh` with `Write-Output netsh`, and run
   `powershell.exe -NoProfile -EncodedCommand "$ENC"`.
   `-Wait` holds the shell until the elevated window closes, so step 5 checks the result
   and not the state before the reset.
5. Verify: the inspect command shows no 9222 forward and no `WSL-CDP-*` rule, and
   `curl -s -m 5 "http://$WINHOST:9222/json/version"` returns nothing.
6. Ask before you delete the profile. Deleting it removes the saved logins:

   ```bash
   powershell.exe -NoProfile -Command 'Remove-Item -Recurse -Force (Join-Path $env:TEMP "chrome-cdp")'
   ```

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
- 2026-10-21: `playwright-cli` 0.1.22 attached over CDP to a local headless Chromium.
  `goto`, `tab-list`, `--raw snapshot`, `click` by locator, and `--raw eval` with an
  in-page `fetch` all worked. `detach` left the browser running.
- 2026-10-27: `playwright-cli` attached through the Windows portproxy (`v4tov6` to
  `::1`) to an authenticated Chrome 155. An in-page `fetch` returned Grafana
  `/api/datasources` and a Prometheus query through `/api/datasources/proxy/1/`.

## Verified endpoints

| Site | Endpoints |
|---|---|
| Glowroot | `/backend/top-level-agent-rollups?from=&to=`, `/backend/transaction/average?agent-rollup-id=&transaction-type=Web\|Background&from=&to=`, `/backend/transaction/queries`, `/backend/transaction/points` (hyphenated params, e.g. `duration-millis-low`), `/backend/trace/header?agent-id=&trace-id=`, `/backend/transaction/full-query-text?full-text-sha1=` |
| Grafana | `/api/datasources` (Prometheus id=1), `/api/datasources/proxy/1/api/v1/query_range` |
| PMM | `/graph/api/datasources/proxy/1/api/v1/query_range` (`/prometheus/` directly returns Access denied); QAN is **POST** `/v1/qan/metrics:getReport` |
