#!/bin/sh
# Black-box tests for the rendered Codex plugin installer.

set -u

self_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_root=$(dirname "$self_dir")
bash_template="$repo_root/home/run_install-04-codex-plugins.sh.tmpl"
ps_template="$repo_root/home/run_install-04-codex-plugins.ps1.tmpl"
log_fragment="$repo_root/home/.chezmoitemplates/scripts/log.sh"
nvm_fragment="$repo_root/home/.chezmoitemplates/scripts/load-nvm"
plugin='slack@openai-curated-remote'

for tool in bash jq; do
    command -v "$tool" >/dev/null 2>&1 || {
        printf 'FATAL: %s is required\n' "$tool" >&2
        exit 1
    }
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM
rendered="$tmp/run_install-04-codex-plugins.sh"

[ -f "$bash_template" ] || { printf 'FAIL: missing %s\n' "$bash_template" >&2; exit 1; }
[ -f "$ps_template" ] || { printf 'FAIL: missing %s\n' "$ps_template" >&2; exit 1; }
[ -f "$log_fragment" ] || { printf 'FAIL: missing %s\n' "$log_fragment" >&2; exit 1; }
[ -f "$nvm_fragment" ] || { printf 'FAIL: missing %s\n' "$nvm_fragment" >&2; exit 1; }

# Expand the two fixed shared fragments without requiring chezmoi. The separate
# Render templates workflow exercises the real engine on Linux, macOS, and
# Windows; this suite only needs an executable subject for the stubbed CLI seam.
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
        '{{- if ne .chezmoi.os "windows" -}}'|'{{ end -}}') ;;
        '{{ template "scripts/log.sh" }}') cat "$log_fragment" ;;
        '{{ template "scripts/load-nvm" }}') cat "$nvm_fragment" ;;
        *) printf '%s\n' "$line" ;;
    esac
done <"$bash_template" >"$rendered"
bash -n "$rendered"

failures=0
fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

make_stub() {
    case_dir=$1
    mkdir -p "$case_dir/bin"
    cat >"$case_dir/bin/codex" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >>"$CODEX_STUB_LOG"
case "$1 $2" in
    'plugin list')
        case "$CODEX_STUB_SCENARIO" in
            missing|failed-add) printf '{"installed":[]}\n' ;;
            enabled) printf '{"installed":[{"pluginId":"slack@openai-curated-remote","installed":true,"enabled":true}]}\n' ;;
            disabled) printf '{"installed":[{"pluginId":"slack@openai-curated-remote","installed":true,"enabled":false}]}\n' ;;
            malformed) printf 'not-json\n' ;;
        esac
        ;;
    'plugin add')
        [ "$CODEX_STUB_SCENARIO" != failed-add ] || exit 23
        printf '{"pluginId":"slack@openai-curated-remote"}\n'
        ;;
    *) exit 64 ;;
esac
STUB
    chmod +x "$case_dir/bin/codex"
}

run_case() {
    scenario=$1
    case_dir="$tmp/$scenario"
    mkdir -p "$case_dir/home"
    : >"$case_dir/calls"
    make_stub "$case_dir"
    HOME="$case_dir/home" NVM_DIR="$case_dir/no-nvm" \
        DOTFILES_LOG_VERBOSE=1 \
        CODEX_STUB_SCENARIO=$scenario CODEX_STUB_LOG="$case_dir/calls" \
        PATH="$case_dir/bin:/usr/bin:/bin" bash "$rendered" >"$case_dir/output" 2>&1
    RC=$?
    OUTPUT=$(cat "$case_dir/output")
    CALLS=$(cat "$case_dir/calls")
}

run_case missing
[ "$RC" -eq 0 ] || fail "missing plugin returned $RC"
[ "$(printf '%s\n' "$CALLS" | grep -c '^plugin list --json$')" -eq 1 ] || fail 'missing case did not list once'
[ "$(printf '%s\n' "$CALLS" | grep -c '^plugin add slack@openai-curated-remote --json$')" -eq 1 ] || fail 'missing case did not add the required plugin once'
printf '%s\n' "$OUTPUT" | grep -Fq '=== END Codex plugins (ok,' || fail 'missing case has no successful closing banner'

run_case enabled
[ "$RC" -eq 0 ] || fail "enabled plugin returned $RC"
printf '%s\n' "$CALLS" | grep -q '^plugin add ' && fail 'enabled plugin was reinstalled'
printf '%s\n' "$OUTPUT" | grep -Fq '(skipped)' || fail 'enabled plugin did not log a skip'

run_case disabled
[ "$RC" -eq 0 ] || fail "disabled plugin returned $RC"
[ "$(printf '%s\n' "$CALLS" | grep -c '^plugin add slack@openai-curated-remote --json$')" -eq 1 ] || fail 'disabled plugin was not repaired'

missing_cli_dir="$tmp/unavailable-cli"
mkdir -p "$missing_cli_dir/home" "$missing_cli_dir/bin"
ln -s "$(command -v awk)" "$missing_cli_dir/bin/awk"
HOME="$missing_cli_dir/home" NVM_DIR="$missing_cli_dir/no-nvm" \
    PATH="$missing_cli_dir/bin" /bin/bash "$rendered" >"$missing_cli_dir/output" 2>&1
RC=$?
[ "$RC" -eq 0 ] || fail "missing Codex CLI returned $RC"
grep -Fq 'codex not found' "$missing_cli_dir/output" || fail 'missing Codex CLI did not log a warning'
grep -Fq '=== END Codex plugins (ok,' "$missing_cli_dir/output" || fail 'missing Codex CLI has no successful closing banner'

run_case malformed
[ "$RC" -ne 0 ] || fail 'malformed plugin list returned success'
printf '%s\n' "$OUTPUT" | grep -Fq '=== END Codex plugins (FAILED rc=' || fail 'malformed list has no failed closing banner'

run_case failed-add
[ "$RC" -eq 23 ] || fail "failed add returned $RC instead of 23"
printf '%s\n' "$OUTPUT" | grep -Fq '=== END Codex plugins (FAILED rc=23,' || fail 'failed add has no failed closing banner'

for source in "$bash_template" "$ps_template"; do
    grep -Fq "$plugin" "$source" || fail "plugin identifier missing from $source"
done
grep -Fq '{{- if ne .chezmoi.os "windows" -}}' "$bash_template" || fail 'bash platform guard is missing'
grep -Fq '{{- if eq .chezmoi.os "windows" -}}' "$ps_template" || fail 'PowerShell platform guard is missing'
grep -Fq 'try {' "$ps_template" || fail 'PowerShell logging try block is missing'
grep -Fq '} catch {' "$ps_template" || fail 'PowerShell logging catch block is missing'
grep -Fq '} finally {' "$ps_template" || fail 'PowerShell logging finally block is missing'
grep -Fq -- '-join "`n"' "$ps_template" || fail 'PowerShell does not join multiline native JSON before parsing'
grep -Eq '^[[:space:]]*exit([[:space:]]|$)' "$ps_template" && fail 'PowerShell installer uses exit instead of return'
[ -s "$rendered" ] || fail 'bash template rendered empty on Linux'

if [ "$failures" -ne 0 ]; then
    printf '%s failure(s)\n' "$failures" >&2
    exit 1
fi

printf 'ok: Codex plugin installer reconciles %s\n' "$plugin"
