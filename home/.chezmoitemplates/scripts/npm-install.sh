# Idempotent npm global-install guard.
# Requires scripts/log.sh to be loaded first (uses log_step / log_skip).
# Usage: {{ "{{" }} template "scripts/npm-install.sh" {{ "}}" }}
#        npm_install claude @anthropic-ai/claude-code
npm_install() {
    local cmd="$1"
    local pkg="$2"
    if command -v "$cmd" &>/dev/null; then
        log_skip "[$cmd] already installed"
    else
        log_step "[$cmd] installing $pkg"
        npm install -g "$pkg"
    fi
}
