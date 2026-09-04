---
name: efk-query
description: >
  Use when querying an EFK / OpenSearch / Elasticsearch log cluster from the command line —
  exploring what indices and fields exist, sampling raw documents to learn a log's shape,
  pulling every log line in a time window, or reconstructing one request by traceId.
  Triggers include "查 EFK", "查一下 prod log", "這個 index 有哪些欄位", "撈一筆看看格式",
  "把這個 traceId 的所有 log 撈出來", "search the logs for ...", or any log investigation that
  needs the raw cluster rather than a dashboard. Transport and discovery only — application
  log semantics belong in a project-level skill that calls these scripts.
---

# EFK / OpenSearch query

## Overview

Two scripts, no application knowledge:

| Tool | Purpose |
|---|---|
| `scripts/efk-client.sh` | Raw transport: `search` (POST `_search`) and `get` (arbitrary GET). Prints the cluster's JSON verbatim. |
| `scripts/efk.py` | The parts every hunt re-implements: retries, `search_after` pagination, trace assembly, index/field discovery. |

Project-specific matching, verdicts, and report shapes do **not** go here. Write those in a
repo-level skill and shell out to `efk.py`.

## Credentials

Resolution order (first hit wins):

1. `$EFK_ENV_FILE` — explicit path.
2. `./.env.local`, then `./.env.<env>` in the current directory — per-project override.
3. `~/.agent/local/efk/.env.<env>` — the machine-level store. **The normal case.**

The store lives outside every repository on purpose: it is site-specific and secret, so it is
neither committed nor chezmoi-managed. Each file defines:

```
EFK_USER=...
EFK_PASS=...
EFK_BASE_URL=https://<cluster-host>
EFK_API_MODE=direct          # or: dashboards-proxy
EFK_INDEX=<default pattern>  # optional
```

`direct` talks to the OpenSearch REST API with HTTP basic auth. `dashboards-proxy` tunnels
through a Dashboards console proxy (`/api/console/proxy`) — slower and prone to 502s.

Cluster hostnames, index patterns and which mode a site requires are **not** recorded here.
See `~/.agent/local/efk.md` on this machine.

## Usage

```bash
S=~/.claude/skills/efk-query/scripts

# What does a document actually look like? START HERE on an unfamiliar index.
python3 $S/efk.py sample --env prod --index '<pattern>' -n 2

# Which fields are populated? (falls back to sampled docs when _mapping is denied)
python3 $S/efk.py fields --env prod --index '<pattern>'

# Every hit in a window, one JSON object per line — pipe into jq or your own filter.
echo '{"query":{...},"_source":["@timestamp","message"]}' \
  | python3 $S/efk.py search --env prod --index '<pattern>' --limit 5000

# One request, end to end.
python3 $S/efk.py trace --env prod --index '<pattern>' --id <hex> \
        --from 2026-09-04T01:55:00Z --to 2026-09-04T02:05:00Z

# Anything else the cluster exposes.
python3 $S/efk-client.sh get --env prod --path '_cluster/health'
```

`trace` reads `traceId` / `trace_id` as structured fields and also matches the id inside the log
text, so it spans a layout change. Override the text field with `--text-field log` when the line
is not in `message`.

## Rules that keep queries working

- **Sample before you filter.** A query returning 0 hits usually means a stale field name, not
  "nothing happened". Log shapes move — a switch from `PatternLayout` to structured JSON renames
  the line field and promotes the trace marker to a real field. Pull one unfiltered document and
  read its `_source` before concluding anything.
- **Read-only roles are denied the admin APIs.** `_cat/indices` and `_mapping` commonly return
  `security_exception`. That is a permission wall, not a broken cluster — `efk.py fields` already
  falls back to deriving the field tree from real documents, and `efk.py` never retries a denial.
- **Keep pages small and paginate.** `--page-size` defaults to 250. Wide pages and terms
  aggregations over long windows time out the proxy (502 "Client request timeout").
- **Don't pre-filter on tokens you have not verified.** The standard analyzer keeps a dotted
  token (a hostname, a version string) as ONE token, so matching a fragment of it returns 0.
  When in doubt, pull the window and filter client-side.
- **Re-run a suspiciously thin result.** Proxied clusters return intermittent partial pages. The
  retry loop catches hard errors, not short pages; `trace` warns when a trace looks too short.
- **`@timestamp` is UTC.** Convert before you report a local time, and pass `--from`/`--to` in UTC.
