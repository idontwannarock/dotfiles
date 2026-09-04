#!/usr/bin/env python3
"""
Generic EFK/OpenSearch query helper — transport-level only, no project logic.

Wraps efk-client.sh with the things every log hunt re-implements: retries,
search_after pagination, whole-trace fetch, and index/field discovery.

Subcommands:
  indices  --env prod [--filter foo]              list indices (name, docs, size)
  fields   --env prod --index '<pat>'             field names from the mapping
  sample   --env prod --index '<pat>' [-n 1]      dump raw _source docs (learn the shape)
  search   --env prod --index '<pat>' --body -    paginate every hit, print JSON lines
  trace    --env prod --index '<pat>' --id <hex>  every line of one trace, time-ordered

Times: --from/--to are passed through verbatim; @timestamp is normally UTC.
"""
import argparse, json, os, subprocess, sys, urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
CLIENT = os.environ.get("EFK_CLIENT", os.path.join(HERE, "efk-client.sh"))
RETRIES = 6
# Retrying a permission/auth denial never helps — fail fast and say so.
FATAL = ("security_exception", "authentication_exception", "Unauthorized")


def _run(args, stdin=None):
    return subprocess.run(["bash", CLIENT] + args, input=stdin,
                          capture_output=True, text=True, encoding="utf-8")


def get(env, path, soft=False):
    """Raw GET with retries. Returns parsed JSON, the raw text if not JSON, or
    None when soft=True and the call keeps failing (e.g. a readonly role that is
    denied the _mapping / _cat admin APIs)."""
    for _ in range(RETRIES):
        r = _run(["get", "--env", env, "--path", path])
        if not r.stdout:
            continue
        try:
            d = json.loads(r.stdout)
        except Exception:
            return r.stdout
        if isinstance(d, dict) and ("error" in d or "statusCode" in d):
            if any(f in r.stdout for f in FATAL):
                break
            continue
        return d
    msg = f"GET {path} failed after {RETRIES} tries: {(r.stdout or r.stderr)[:300]}"
    if soft:
        print("[warn] " + msg, file=sys.stderr)
        return None
    sys.exit(msg)


def search(env, index, body):
    """One _search call, with retries on hard errors (proxy 502s are common)."""
    for _ in range(RETRIES):
        r = _run(["search", "--env", env, "--index", index, "--body", "-"], stdin=json.dumps(body))
        try:
            d = json.loads(r.stdout)
        except Exception:
            continue
        if "error" in d or "statusCode" in d:
            if any(f in r.stdout for f in FATAL):
                break
            continue
        return d
    sys.exit(f"search failed after {RETRIES} tries: {(r.stdout or r.stderr)[:300]}")


def paginate(env, index, body, page_size=250, limit=None):
    """Yield every hit via search_after. Keep page_size small; wide pages time out."""
    body = dict(body)
    body["size"] = page_size
    body["sort"] = body.get("sort") or [{"@timestamp": "asc"}, {"_id": "asc"}]
    after, seen = None, 0
    while True:
        page = dict(body)
        if after:
            page["search_after"] = after
        hits = search(env, index, page).get("hits", {}).get("hits", [])
        if not hits:
            return
        for h in hits:
            yield h
            seen += 1
            if limit and seen >= limit:
                return
        if len(hits) < page_size:
            return
        after = hits[-1].get("sort")
        if not after:
            return


def _range(frm, to):
    r = {}
    if frm: r["gte"] = frm
    if to:  r["lte"] = to
    return [{"range": {"@timestamp": r}}] if r else []


def cmd_indices(a):
    out = get(a.env, "_cat/indices?v&h=index,docs.count,store.size&s=index", soft=True)
    if out is None:
        sys.exit("Cannot list indices — a read-only log role is usually denied the _cat admin API.\n"
                 "Ask a human for the index pattern, then use `sample` to learn its shape.")
    for line in (out if isinstance(out, str) else json.dumps(out)).splitlines():
        if not a.filter or a.filter.lower() in line.lower():
            print(line)


def _fields_from_docs(a, n=25):
    """Derive the field tree from real documents. The fallback that always works:
    reading docs needs no admin privilege, and it reports what is actually populated."""
    body = {"size": n, "sort": [{"@timestamp": "desc"}],
            "query": {"bool": {"filter": _range(a.frm, a.to) or [{"match_all": {}}]}}}
    names = {}
    def walk(o, prefix=""):
        for k, v in (o or {}).items():
            name = f"{prefix}{k}"
            if isinstance(v, dict):
                walk(v, name + ".")
            else:
                names.setdefault(name, type(v).__name__)
    for h in search(a.env, a.index, body).get("hits", {}).get("hits", []):
        walk(h.get("_source", {}))
    for k in sorted(names):
        print(f"{k}  ({names[k]})")
    print(f"\n{len(names)} field(s) seen in {n} sampled doc(s) — populated fields only, "
          f"not the full mapping.", file=sys.stderr)


def cmd_fields(a):
    m = get(a.env, urllib.parse.quote(a.index, safe="*") + "/_mapping", soft=True)
    if not isinstance(m, dict) or not m:
        print("[info] _mapping unavailable; deriving fields from sampled documents instead.",
              file=sys.stderr)
        return _fields_from_docs(a)
    names = set()
    def walk(props, prefix=""):
        for k, v in (props or {}).items():
            name = f"{prefix}{k}"
            if isinstance(v, dict) and "properties" in v:
                walk(v["properties"], name + ".")
            else:
                names.add(f"{name}  ({v.get('type', '?')})" if isinstance(v, dict) else name)
    for idx in (m.values() if isinstance(m, dict) else []):
        walk(((idx or {}).get("mappings") or {}).get("properties"))
    for n in sorted(names):
        print(n)
    print(f"\n{len(names)} field(s) across {len(m) if isinstance(m, dict) else 0} index/indices", file=sys.stderr)


def cmd_sample(a):
    body = {"size": a.n, "sort": [{"@timestamp": "desc"}],
            "query": {"bool": {"filter": _range(a.frm, a.to) or [{"match_all": {}}]}}}
    if a.q:
        body["query"]["bool"]["must"] = [{"query_string": {"query": a.q}}]
    for h in search(a.env, a.index, body).get("hits", {}).get("hits", []):
        print(json.dumps(h.get("_source", {}), ensure_ascii=False, indent=2))
        print("-" * 70)


def cmd_search(a):
    body = json.load(sys.stdin) if a.body == "-" else json.loads(a.body)
    for h in paginate(a.env, a.index, body, a.page_size, a.limit):
        print(json.dumps(h.get("_source", h), ensure_ascii=False))


def cmd_trace(a):
    """Trace id may be a structured field or only embedded in the log text."""
    body = {"sort": [{"@timestamp": "asc"}, {"_id": "asc"}],
            "query": {"bool": {"filter": _range(a.frm, a.to),
                               "should": [{"match_phrase": {f: a.id}} for f in a.trace_fields.split(",")]
                                         + [{"match": {a.text_field: a.id}}],
                               "minimum_should_match": 1}}}
    n = 0
    for h in paginate(a.env, a.index, body, a.page_size):
        src = h.get("_source", {})
        line = src.get(a.text_field) or json.dumps(src, ensure_ascii=False)
        print(f"{src.get('@timestamp', '')}  {str(line).strip()[:a.width]}")
        n += 1
    print(f"\n{n} line(s) in trace {a.id}", file=sys.stderr)
    if n and n < 4:
        print("WARNING: suspiciously few lines — proxies return partial pages; re-run before "
              "concluding anything.", file=sys.stderr)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--env", default="prod")
    sub = ap.add_subparsers(dest="cmd", required=True)

    def common(p, index=True):
        p.add_argument("--env", default="prod")
        if index: p.add_argument("--index", required=True)
        p.add_argument("--from", dest="frm", default=None, help="UTC ISO, e.g. 2026-09-01T00:00:00Z")
        p.add_argument("--to", default=None)
        p.add_argument("--page-size", type=int, default=250)

    p = sub.add_parser("indices"); p.add_argument("--env", default="prod")
    p.add_argument("--filter", default=""); p.set_defaults(fn=cmd_indices)
    p = sub.add_parser("fields");  common(p); p.set_defaults(fn=cmd_fields)
    p = sub.add_parser("sample");  common(p); p.add_argument("-n", type=int, default=1)
    p.add_argument("--q", default="", help="optional query_string filter"); p.set_defaults(fn=cmd_sample)
    p = sub.add_parser("search");  common(p); p.add_argument("--body", default="-")
    p.add_argument("--limit", type=int, default=None); p.set_defaults(fn=cmd_search)
    p = sub.add_parser("trace");   common(p); p.add_argument("--id", required=True)
    p.add_argument("--trace-fields", default="traceId,trace_id")
    p.add_argument("--text-field", default="message")
    p.add_argument("--width", type=int, default=300); p.set_defaults(fn=cmd_trace)

    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
