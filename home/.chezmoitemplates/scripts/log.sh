# Structured logging for chezmoi run_* scripts (bash).
# Usage: {{ "{{" }} template "scripts/log.sh" {{ "}}" }}
#
#   log_begin "npm global tools"        === BEGIN npm global tools ===
#   log_section "install Claude Code"   --- install Claude Code
#   log_step "installing foo@1.2.3"         installing foo@1.2.3
#   log_skip "[foo] already installed"       [foo] already installed (skipped)
#   log_warn "upstream returned 500"         !! upstream returned 500
#                                       === END npm global tools (ok) ===
#
# log_end takes NO argument — the title comes from the variable log_begin set,
# so the closing banner can never drift from the opening one. log_begin installs
# an EXIT trap, so every exit path (normal end, early `exit 0`, `set -e` abort,
# uncaught error) still prints the closing banner with the real exit code.
# Callers must not install their own EXIT trap.

_LOG_TITLE=""

log_end() {
    # Must be first: capture the status that triggered the trap.
    local rc=$?
    trap - EXIT
    if [ "$rc" -eq 0 ]; then
        printf '=== END %s (ok) ===\n' "${_LOG_TITLE:-}"
    else
        printf '=== END %s (FAILED rc=%d) ===\n' "${_LOG_TITLE:-}" "$rc"
    fi
}

log_begin() {
    _LOG_TITLE="$1"
    printf '=== BEGIN %s ===\n' "$_LOG_TITLE"
    trap log_end EXIT
}

# `--` guards the leading dash in the format string.
log_section() { printf -- '--- %s\n' "$1"; }
log_step()    { printf '    %s\n' "$1"; }
log_skip()    { printf '    %s (skipped)\n' "$1"; }
log_warn()    { printf '    !! %s\n' "$1"; }
