---
name: wsl-chrome-cdp
description: "Use when working from WSL and you need a browser session that is already logged in — internal sites behind IPA/SSO/OTP (Glowroot, Grafana, PMM, corp dashboards) whose data has no API token available. Triggers include 「幫我查 Glowroot/Grafana/PMM」、「要登入才看得到的內部站台」、「用瀏覽器抓這個內部頁面」, or any request to read a page the agent cannot reach with plain curl because it needs the user's authenticated session. Drives the user's Windows-side Chrome over CDP through a netsh portproxy. Skip for public URLs (use WebFetch), for headless scraping that needs no login, and on non-WSL machines."
---

# Drive Windows Chrome from WSL (CDP)

WSL cannot render a headful browser (WSLg's X server is present but not serving), and
`chrome-devtools-mcp` runs headless with an empty profile — so neither can reach a site
that requires the user's interactive login. The working path is: launch a **separate**
Chrome on the Windows side with a debug port, forward that port into WSL, let the **user**
log in, then drive it with `~/.local/bin/cdp.py`.

Only steps 2 and 5b need the user: they raise a UAC prompt, and step 3 is the login itself.
The non-elevated commands the agent can run itself through the Bash tool — `powershell.exe`
is on `PATH` from WSL. No credentials pass through the agent either way.

**`!` in the prompt runs bash, not PowerShell.** Pasting the blocks below verbatim gets
`New-Item: command not found`. Every command has to go through `powershell.exe -NoProfile
-Command <one string>`, and the quoting has exactly two shapes — get them wrong and the
failure is silent, not loud:

- **Contains `$`** (`$dir`, `$env:TEMP`, `$_`) → wrap in **bash single quotes** so bash
  leaves them alone, and use double quotes inside PowerShell.
- **Contains a literal single quote** (WQL `-Filter "Name='chrome.exe'"`, `-ArgumentList
  'a','b'`) → wrap in **bash double quotes** with `\"` for the inner double quotes, and
  escape any `$` as `\$`. Bash single quotes cannot contain a single quote at all.

Avoid needing both at once: drop quotes where PowerShell doesn't require them
(`-DisplayName WSL-CDP-9222` has no space, so it needs none).

## 1. Launch the CDP Chrome

```
powershell.exe -NoProfile -Command '$dir = Join-Path $env:TEMP "chrome-cdp"; New-Item -ItemType Directory -Force -Path $dir | Out-Null; Start-Process "C:\Program Files\Google\Chrome\Application\chrome.exe" -ArgumentList @("--remote-debugging-port=9222", "--user-data-dir=$dir", "--no-first-run", "--no-default-browser-check", "about:blank")'
```

`--user-data-dir` is what keeps this off the user's main browser. Use `Start-Process`;
`cmd.exe /c start` swallows the arguments and Chrome dies silently. Confirm it actually
came up before moving on — a silent death here looks identical to a port problem later:

```
powershell.exe -NoProfile -Command "(Get-CimInstance Win32_Process -Filter \"Name='chrome.exe'\" | Where-Object { \$_.CommandLine -like '*chrome-cdp*' }).Count"
```

## 2. Forward the port into WSL (needs UAC)

Chrome binds 127.0.0.1 only — current versions ignore `--remote-debugging-address=0.0.0.0`.
WSL2 is NAT'd, so the Windows side must forward:

Both commands need elevation, so they run in a second shell raised with `-Verb RunAs`:

```
powershell.exe -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-Command','netsh interface portproxy add v4tov4 listenport=9222 listenaddress=0.0.0.0 connectport=9222 connectaddress=127.0.0.1; New-NetFirewallRule -DisplayName WSL-CDP-9222 -Direction Inbound -LocalPort 9222 -Protocol TCP -Action Allow -Profile Any'"
```

The elevated window closes instantly and its output never comes back — no news is good news.
Verify from the WSL side instead:

```
curl -s -m 5 http://$(ip route show default | awk '{print $3}'):9222/json/version
```

## 3. Have the user log in

Tell the user which sites to log into in that Chrome window. Wait for confirmation.
Passwords and OTP never reach the agent.

## 4. Drive it from WSL

```
cdp.py tabs              list page targets
cdp.py nav <url>         navigate, print final url + title
cdp.py get <url>         navigate + print document.body.innerText  (best for JSON APIs)
cdp.py eval '<js>'       evaluate JS in the page (awaitPromise, returnByValue)
cdp.py fetch <url>       fetch from inside the page with cookies, print status + body
```

`cdp.py` detects the Windows host from `ip route show default` and rewrites the
`webSocketDebuggerUrl` (which always claims 127.0.0.1) to that address. Override with
`CDP_HOST=<ip>` if detection is wrong. It needs the `websockets` package
(`pip install --user websockets`, or apt `python3-websockets`).

**Bulk reads: use `eval`, not a loop of `get`.** Do the `fetch` fan-out inside the page
and aggregate before returning — one round trip instead of N:

```
cdp.py eval '(async()=>{const u=[...]; const r=await Promise.all(u.map(x=>fetch(x,{credentials:"include"}).then(r=>r.json()))); return JSON.stringify(r);})()'
```

## 5. Clean up — always

While the port is open, anything on the LAN can drive that Chrome. Close it as soon as
the query is done.

**5a — no UAC, so run it yourself.** The filter kills only the CDP Chrome, never the user's
main browser; the trailing count should print `0`:

```
powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='chrome.exe'\" | Where-Object { \$_.CommandLine -like '*chrome-cdp*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }; Start-Sleep -Seconds 1; Remove-Item -Recurse -Force (Join-Path \$env:TEMP 'chrome-cdp') -ErrorAction SilentlyContinue; (Get-CimInstance Win32_Process -Filter \"Name='chrome.exe'\" | Where-Object { \$_.CommandLine -like '*chrome-cdp*' }).Count"
```

**5b — needs UAC, so hand it to the user.**

```
powershell.exe -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-Command','netsh interface portproxy delete v4tov4 listenport=9222 listenaddress=0.0.0.0; Remove-NetFirewallRule -DisplayName WSL-CDP-9222'"
```

## Limitations (state these to the user, don't paper over them)

- **One UAC prompt per use**, twice per cycle (setup + teardown). No unprivileged
  alternative has been explored.
- **The login does not persist.** The profile lives in `%TEMP%\chrome-cdp` and step 5
  deletes it; Windows disk cleanup would too. Every cycle needs a fresh login. If this
  becomes routine, move `--user-data-dir` to a stable path and drop the `Remove-Item`.

## Dead ends — do not retry

- **WSLg / headful Chrome inside WSL.** `/mnt/wslg`, `DISPLAY=:0` and `/tmp/.X11-unix/X0`
  all exist, but no X server is actually serving (`xdpyinfo` hangs). Headful Chrome stalls
  at startup and the debug port never opens; the same command headless is up in 4 seconds —
  that contrast is the fastest way to tell "GUI hung" from "port problem". Only fix is
  `wsl --shutdown` from Windows, which kills the current session.
- **`chrome-devtools-mcp`.** No `DISPLAY`, so headless only, and its profile has no login.
  Failed attempts leave ~8 MB in `~/.cache/chrome-devtools-mcp/chrome-profile/` plus a stale
  `SingletonLock` that breaks the *next* launch — delete the directory if you tried it.
- **API tokens / service accounts.** Grafana 9.0.4 (LDAP→IPA), PMM (Grafana 11.6.4) and
  Glowroot 0.13.6 all support them, but the user's account lacks the permission to create one.

## Verified endpoints

| Site | Endpoints |
|---|---|
| Glowroot | `/backend/top-level-agent-rollups?from=&to=`, `/backend/transaction/average?agent-rollup-id=&transaction-type=Web\|Background&from=&to=`, `/backend/transaction/queries`, `/backend/transaction/points` (hyphenated params, e.g. `duration-millis-low`), `/backend/trace/header?agent-id=&trace-id=`, `/backend/transaction/full-query-text?full-text-sha1=` |
| Grafana | `/api/datasources` (Prometheus id=1), `/api/datasources/proxy/1/api/v1/query_range` |
| PMM | `/graph/api/datasources/proxy/1/api/v1/query_range` (`/prometheus/` directly returns Access denied); QAN is **POST** `/v1/qan/metrics:getReport` |
