# Use an authenticated Chrome through playwright-cli

Control an independent, logged-in Chrome with `playwright-cli` attached over CDP.
`playwright-cli` is a shell command. It adds no tool schema to the agent context,
and scripts can call it the same way the agent does.

This skill does not authorize extra websites, API calls, playlist changes, or
permission changes. Preserve the task's confirmation gates. The user handles login,
OTP, project trust, and UAC prompts; credentials must not pass through the agent.

**The CDP port is a remote control with no password.** Any program that reaches
it can use every login in that Chrome. Keep the port on the loopback address of
the machine that runs Chrome, and run `playwright-cli` on that same machine. Do
not forward the port, open a firewall rule for it, or bind it to `0.0.0.0`.

## 0. Read the environment reference

Commands that depend on the OS or environment are in a reference file. Read the
one that matches before you run anything:

| Agent runs in | Chrome runs in | Read |
|---|---|---|
| WSL | Windows | `references/wsl.md` |

No other combination is verified. For any other one, stop and tell the user.

The reference defines `pw`: the `playwright-cli` command for that environment,
with the session `-s=cdp`. The steps below use `pw`. The reference also gives the
commands to launch Chrome, find its PID, stop it, and remove leftovers.

## 1. Check for an existing session and the execution boundary

Before launching anything, check for an existing endpoint and who is using it.
Record the task's endpoint, profile path, Chrome PID, selected tab, and any
resources created by this task. Do not restart a browser used by another session.

If `pw tab-list` already works, reuse that session and skip step 2. Do not inspect
unrelated tabs or browser storage.

A permission error in the agent shell (`Operation not permitted`, a denied socket,
a denied interop call) does not prove that Chrome or the machine is broken. Stop
that route and report it. Do not introduce a bridge or change permissions to evade
the denial. Do not reset Chrome or the login based only on a shell permission error.

If the user wants to continue in a client whose shell is denied, a project-scoped
Chrome DevTools MCP with `--browser-url=<confirmed-endpoint>` runs outside the
shell; the setup is in `docs/claude-code.md`. Add it only with the user's agreement
and remove it after.

## 2. Launch an independent Chrome only if needed

Use a separate profile, never the user's main browser profile. Check whether that
profile is already in use before launching. Launch Chrome with these flags:

| Flag | Why |
|---|---|
| `--remote-debugging-port=9222` | Opens CDP on loopback only |
| `--user-data-dir=<separate profile>` | Keeps the user's main profile out of reach |
| `--no-first-run`, `--no-default-browser-check` | Skips the first-run dialogs |
| `--disable-backgrounding-occluded-windows`, `--disable-renderer-backgrounding`, `--disable-background-timer-throttling` | A covered or background window stops painting; without these, `click` waits for the element to become "stable" and times out |

A launch command that returns is not proof that Chrome started. Verify the listener
and record its PID with the reference's commands. Then attach:

```bash
pw attach --cdp=http://localhost:9222
pw tab-list
pw tab-select <index>
```

Select the intended tab with `tab-select` and confirm it before you read or act.

## 3. Operate

Read the installed `playwright-cli --help` before you use a command that is not below.

| Task | Command |
|---|---|
| Open a page | `pw goto <url>` |
| Read the page | `pw --raw snapshot`, or `pw find <text>` for one part |
| Click or fill | `pw click <ref>`, `pw fill <ref> <text>`; refs such as `e13` come from the snapshot |
| Call an API with the login cookies | `pw --raw eval "async () => { const r = await fetch('<url>', {credentials: 'include'}); return {status: r.status, body: await r.json()}; }"` |
| Many API calls | One `eval` with `Promise.all` inside the page, not one `eval` per URL |
| Screenshot | `pw screenshot` |
| Stop controlling | `pw detach` |

`--raw` prints only the result. An `eval` that returns an object prints JSON, so
`jq` can read it. A returned string prints as a quoted JSON string.

`fetch` runs inside the page, so it obeys the page's origin. Open a page on the
API's site first; a `fetch` from `about:blank` to another site fails with
`Failed to fetch`.

Use `fetch` only for task-authorized endpoints and methods. Never read or export
cookies, storage, or credentials: no `cookie-*`, `localstorage-*`, `sessionstorage-*`,
or `state-save` on this browser.

Write a script only for a fixed flow with several steps, for example fetch, then
click, then fetch again. The script calls the same `playwright-cli` commands.
Until a flow is that fixed, the table above and the endpoints at the end of this
skill are the reference.

## 4. Login

If the intended site is not logged in, ask the user to log in in this independent
Chrome and wait for confirmation. Verify the intended page after login; do not
request passwords or OTP. Reuse a valid login instead of requesting it again.

Use one controller at a time for page mutations. Inspect fresh page state after an
action, verify its result, and respect the task's pacing and confirmation gates.
Stop on a captcha, site error, uncertain mutation result, or a permission denial.
Do not repeat a mutation merely because its response is delayed.

## 5. Teardown according to ownership and task intent

Treat these as separate operations:

- **Driver:** run `pw detach`. It stops control and leaves Chrome running. Do not
  run `close`, `close-all`, `kill-all`, or `delete-data` on an attached session:
  the browser and its login belong to the user.
- **Browser:** stop only the task's Chrome, by its recorded PID, when no other task
  uses it. Honor an explicit leave-open request. Never kill all Chrome processes or
  match by a profile-name substring.
- **Profile:** do not delete it as routine shutdown. It keeps the login. Delete it
  only with user approval, after the browser stops and no other session uses it.
- **MCP:** if a fallback MCP was added, remove its settings. Do not delete shared packages.

Report what remains open. While Chrome runs with CDP, any local program can control
it: warn the user if the browser stays open.

## Dated observations, not platform restrictions

- An earlier local WSLg session had an unresponsive X server. WSL supports GUI
  applications; missing `DISPLAY` in an agent shell does not establish a Windows
  Chrome limitation. Do not recommend `wsl --shutdown` casually: it stops WSL sessions.
- 2026-09-29: Chrome 154 listened on `::1`. 2026-10-27: Chrome 155 with a fresh
  profile listened on `127.0.0.1`. Check the listener; do not assume the address.
- 2026-10-27: `playwright-cli` 0.1.22 attached to an authenticated Chrome 155. An
  in-page `fetch` returned Grafana `/api/datasources` and a Prometheus query
  through `/api/datasources/proxy/1/`.
- 2026-10-27: a `click` on a background Chrome window timed out while waiting for
  the element to be stable. The same click worked after a relaunch with the three
  `--disable-*` flags in step 2.

## Verified endpoints

| Site | Endpoints |
|---|---|
| Glowroot | `/backend/top-level-agent-rollups?from=&to=`, `/backend/transaction/average?agent-rollup-id=&transaction-type=Web\|Background&from=&to=`, `/backend/transaction/queries`, `/backend/transaction/points` (hyphenated params, e.g. `duration-millis-low`), `/backend/trace/header?agent-id=&trace-id=`, `/backend/transaction/full-query-text?full-text-sha1=` |
| Grafana | `/api/datasources` (Prometheus id=1), `/api/datasources/proxy/1/api/v1/query_range` |
| PMM | `/graph/api/datasources/proxy/1/api/v1/query_range` (`/prometheus/` directly returns Access denied); QAN is **POST** `/v1/qan/metrics:getReport` |
