## 1. Driver change

- [x] 1.1 Install `@playwright/cli` in both npm installers.
- [x] 1.2 Rewrite the driver section of the shared skill body; update both guides.
- [x] 1.3 Remove the `cdp.py` source, its ignore entry, and add its target to `.chezmoiremove`.

## 2. Verification

- [x] 2.1 Local CDP test: `attach`, `goto`, `tab-list`, `--raw snapshot`, `click`, `--raw eval` with `fetch`, `detach`.
- [x] 2.2 Render and validate both wrappers; run the shell test suites; validate this change.
- [x] 2.3 Attach through the Windows portproxy and fetch one Grafana API with the login cookies.

## Verification results

- Local headless Chromium over CDP: every command in the skill table worked; `detach` left the browser running.
- 2026-10-27, through the Windows portproxy: `attach`, `tab-list`, and `--raw eval` with `fetch` returned HTTP 200 from Grafana `/api/datasources` and from a Prometheus query through the datasource proxy. The `--raw` output piped into `jq`.
- Both rendered skills pass validation and are byte-identical. All shell suites pass. Strict OpenSpec validation passes.
