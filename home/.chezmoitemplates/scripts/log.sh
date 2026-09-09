# Structured logging for chezmoi run_* scripts (bash).
# Usage: {{ "{{" }} template "scripts/log.sh" {{ "}}" }}
#
#   log_begin "npm global tools"        === BEGIN npm global tools ===
#   log_section "install Claude Code"   --- install Claude Code
#   log_step "installing foo@1.2.3"         installing foo@1.2.3
#   log_skip "[foo] already installed"       [foo] already installed (skipped)
#   log_warn "upstream returned 500"         !! upstream returned 500
#                                           (took 1.2s)
#                                       === END npm global tools (ok, 3.4s) ===
#
# Each log_section closes the previous section with its elapsed time; log_end
# closes the last one and adds the whole-script total to the closing banner.
#
# log_end takes NO argument — the title comes from the variable log_begin set,
# so the closing banner can never drift from the opening one. log_begin installs
# an EXIT trap, so every exit path (normal end, early `exit 0`, `set -e` abort,
# uncaught error) still prints the closing banner with the real exit code.
# Callers must not install their own EXIT trap.

# Everything these functions print is ASCII, deliberately. The PowerShell mirror
# has to be -- chezmoi captures a run_ script through a pipe and the child pwsh
# encodes it with the console code page, which turned every em dash into "?" once
# the profile stopped running chcp for it (see scripts/log.ps1). Bash has no such
# problem, but the two sides are kept identical on purpose, so the rule is the
# same on both: use "--", never an em dash, in any string these functions print.

_LOG_TITLE=""
_LOG_T0=""
_LOG_SECTION_T0=""

# Verbosity comes from chezmoi's own -v. chezmoi exports no verbosity variable,
# but it does export the whole command line as CHEZMOI_ARGS, so read that rather
# than invent a second switch nobody would remember. Matched token by token: a
# substring test would fire on any path that happens to contain "-v".
_LOG_VERBOSE=""
for _log_arg in ${CHEZMOI_ARGS:-}; do
    case "$_log_arg" in
        -v|--verbose) _LOG_VERBOSE=1 ;;
    esac
done
unset _log_arg

# For call sites that have their own noise to gate, notably a command whose
# output is only worth reading when it failed.
log_is_verbose() { [ -n "$_LOG_VERBOSE" ]; }

# Clock for the elapsed-time suffixes. EPOCHREALTIME (bash 5) gives milliseconds;
# macOS system bash is 3.2 and lacks it, so fall back to SECONDS (whole seconds).
# Both readings in a pair always come from the same source, so the difference is
# valid either way. EPOCHREALTIME honours LC_NUMERIC, hence the comma swap.
_log_now() {
    if [ -n "${EPOCHREALTIME:-}" ]; then
        printf '%s' "${EPOCHREALTIME/,/.}"
    else
        printf '%s' "$SECONDS"
    fi
}

_log_elapsed() {
    LC_ALL=C awk -v t0="$1" -v t1="$(_log_now)" 'BEGIN { printf "%.1fs", t1 - t0 }'
}

# Sections have no explicit close, so each one is closed by whatever comes next:
# the following log_section, or log_end.
_log_close_section() {
    [ -n "$_LOG_SECTION_T0" ] || return 0
    if [ -n "$_LOG_VERBOSE" ]; then
        printf '    (took %s)\n' "$(_log_elapsed "$_LOG_SECTION_T0")"
    fi
    _LOG_SECTION_T0=""
}

log_end() {
    # Must be first: capture the status that triggered the trap.
    local rc=$?
    trap - EXIT
    _log_close_section
    local total
    total="$(_log_elapsed "$_LOG_T0")"
    if [ "$rc" -eq 0 ]; then
        printf '=== END %s (ok, %s) ===\n' "${_LOG_TITLE:-}" "$total"
    else
        printf '=== END %s (FAILED rc=%d, %s) ===\n' "${_LOG_TITLE:-}" "$rc" "$total"
    fi
}

log_begin() {
    _LOG_TITLE="$1"
    _LOG_T0="$(_log_now)"
    printf '=== BEGIN %s ===\n' "$_LOG_TITLE"
    trap log_end EXIT
}

# What each line is for, and why only some survive a quiet run:
#
#   log_begin/log_end   the block and its total. Always: this is the answer to
#                       "what ran and how long did it take".
#   log_warn            always. A warning nobody sees is not a warning.
#   log_step            something changed. Always, because a quiet run that
#                       silently changed the machine is the thing to avoid.
#   log_section         narration of intent. Verbose only.
#   log_skip            nothing happened. Verbose only -- these are the bulk of
#                       the output and they all say the same thing.
#   (took ...)          per-section timing. Verbose only; the total on the END
#                       banner is what a normal run needs.
#
# `--` guards the leading dash in the format string.
log_section() {
    _log_close_section
    if [ -n "$_LOG_VERBOSE" ]; then
        printf -- '--- %s\n' "$1"
    fi
    _LOG_SECTION_T0="$(_log_now)"
}
log_step() { printf '    %s\n' "$1"; }
log_warn() { printf '    !! %s\n' "$1"; }
log_skip() {
    if [ -n "$_LOG_VERBOSE" ]; then
        printf '    %s (skipped)\n' "$1"
    fi
    return 0
}
