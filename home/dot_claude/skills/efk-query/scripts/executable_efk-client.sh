#!/usr/bin/env bash
# =============================================================================
# Thin EFK/OpenSearch HTTP client — transport only, no domain logic.
# =============================================================================
# Actions:
#   search  --env <env> [--index <pattern>] --body -|<json>|--body-file <path>
#   get     --env <env> --path <path>          # raw GET, e.g. _cat/indices?v
#
# Credentials resolution order for --env <env>:
#   1. $EFK_ENV_FILE                       (explicit override: path to a creds file)
#   2. ./.env.local, ./.env.<env>          (cwd — per-project override)
#   3. ~/.agent/local/efk/.env.<env>       (machine-level private tier; the normal case)
#
# Each creds file must define:
#   EFK_USER, EFK_PASS, EFK_BASE_URL, EFK_API_MODE (direct|dashboards-proxy)
#   EFK_INDEX optional default index pattern.
# =============================================================================
set -euo pipefail

PYTHON="$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)"
HOME_STORE="$HOME/.agent/local/efk"

die() { echo "ERROR: $*" >&2; exit 1; }
[[ -n "$PYTHON" ]] || die "python3/python not found"
command -v curl >/dev/null || die "curl not found"

env_name=""; index_override=""; body=""; body_file=""; action=""; path=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    search|get)  action="$1"; shift ;;
    --env)       env_name="$2"; shift 2 ;;
    --index)     index_override="$2"; shift 2 ;;
    --path)      path="$2"; shift 2 ;;
    --body)      body="$2"; shift 2 ;;
    --body-file) body_file="$2"; shift 2 ;;
    -h|--help)   sed -n '2,22p' "$0" >&2; exit 0 ;;
    *) die "Unknown arg: $1 (run with -h for usage)" ;;
  esac
done

[[ -n "$action" ]]   || die "missing action (search|get)"
[[ -n "$env_name" ]] || die "--env is required (e.g. prod)"

env_file=""
if   [[ -n "${EFK_ENV_FILE:-}" && -f "${EFK_ENV_FILE:-}" ]]; then env_file="$EFK_ENV_FILE"
elif [[ -f "./.env.local" ]];                then env_file="./.env.local"
elif [[ -f "./.env.$env_name" ]];            then env_file="./.env.$env_name"
elif [[ -f "$HOME_STORE/.env.$env_name" ]];  then env_file="$HOME_STORE/.env.$env_name"
fi
[[ -n "$env_file" && -f "$env_file" ]] || die "No credentials file for env '$env_name'. Create $HOME_STORE/.env.$env_name (EFK_USER/EFK_PASS/EFK_BASE_URL/EFK_API_MODE) or set EFK_ENV_FILE."

set -a; source "$env_file"; set +a
: "${EFK_USER:?EFK_USER not set in $env_file}"
: "${EFK_PASS:?EFK_PASS not set in $env_file}"
: "${EFK_BASE_URL:?EFK_BASE_URL not set in $env_file}"
: "${EFK_API_MODE:?EFK_API_MODE not set in $env_file (direct|dashboards-proxy)}"

enc() { "$PYTHON" -c "import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1], safe='*/?&='))" "$1"; }

if [[ "$action" == "get" ]]; then
  [[ -n "$path" ]] || die "--path is required for get (e.g. _cat/indices?v)"
  case "$EFK_API_MODE" in
    direct)
      curl -sS -g -u "$EFK_USER:$EFK_PASS" "$EFK_BASE_URL/${path#/}" -H 'Accept: application/json' ;;
    dashboards-proxy)
      curl -sS -u "$EFK_USER:$EFK_PASS" -X POST \
        "$EFK_BASE_URL/api/console/proxy?path=$(enc "${path#/}")&method=GET" -H 'osd-xsrf: true' ;;
    *) die "Unknown EFK_API_MODE: $EFK_API_MODE (expected: direct|dashboards-proxy)" ;;
  esac
  exit 0
fi

index="${index_override:-${EFK_INDEX:-}}"
[[ -n "$index" ]] || die "--index is required (no EFK_INDEX default in $env_file)"

if [[ -n "$body_file" ]]; then
  [[ -f "$body_file" ]] || die "Body file not found: $body_file"; body="$(cat "$body_file")"
elif [[ "$body" == "-" ]]; then
  body="$(cat)"
fi
[[ -n "$body" ]] || die "Request body required (--body-file, --body <json>, or --body - for stdin)"

index_enc="$(enc "$index")"
case "$EFK_API_MODE" in
  direct)
    curl -sS -u "$EFK_USER:$EFK_PASS" -X POST "$EFK_BASE_URL/$index_enc/_search" \
      -H 'Content-Type: application/json' -H 'Accept: application/json' -d "$body" ;;
  dashboards-proxy)
    curl -sS -u "$EFK_USER:$EFK_PASS" -X POST \
      "$EFK_BASE_URL/api/console/proxy?path=$index_enc/_search&method=POST" \
      -H 'Content-Type: application/json' -H 'osd-xsrf: true' -d "$body" ;;
  *) die "Unknown EFK_API_MODE: $EFK_API_MODE (expected: direct|dashboards-proxy)" ;;
esac
