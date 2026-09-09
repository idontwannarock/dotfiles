#!/bin/sh
# Regression tests for Codex config generation and per-machine plugin state.

set -u

self_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_root=$(dirname "$self_dir")
unix_generator="$repo_root/home/dot_codex/modify_config.toml"
windows_generator="$repo_root/home/run_after_modify-codex-config.ps1.tmpl"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

failures=0
fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

cat >"$tmp/input.toml" <<'EOF'
model = "local-old-value"

[projects."/work/one"]
trust_level = "trusted"

[plugins."slack@openai-curated"]
enabled = true

[projects."/work/two"]
trust_level = "untrusted"

[plugins."example@personal"]
enabled = false

[mcp_servers.slack]
url = "https://mcp.slack.com/mcp"
EOF

bash "$unix_generator" <"$tmp/input.toml" >"$tmp/once.toml"
bash "$unix_generator" <"$tmp/once.toml" >"$tmp/twice.toml"

for expected in \
    '[projects."/work/one"]' \
    '[projects."/work/two"]' \
    '[plugins."slack@openai-curated"]' \
    '[plugins."example@personal"]'; do
    grep -Fqx "$expected" "$tmp/once.toml" || fail "Unix generator did not preserve $expected"
done

cmp -s "$tmp/once.toml" "$tmp/twice.toml" || fail 'Unix generator output is not a fixed point'

grep -Fq '/^\[(projects|plugins)\./' "$unix_generator" || \
    fail 'Unix keep filter does not include both project and plugin tables'
grep -Fq "'^\[(projects|plugins)\." "$windows_generator" || \
    fail 'Windows keep filter does not include both project and plugin tables'

for source in "$unix_generator" "$windows_generator"; do
    grep -Fq '[mcp_servers.slack]' "$source" && fail "direct Slack MCP table remains in $source"
    grep -Fq 'https://mcp.slack.com/mcp' "$source" && fail "direct Slack MCP URL remains in $source"
done

if [ "$failures" -ne 0 ]; then
    printf '%s failure(s)\n' "$failures" >&2
    exit 1
fi

printf 'ok: Codex config preserves project and plugin state without direct Slack MCP\n'
