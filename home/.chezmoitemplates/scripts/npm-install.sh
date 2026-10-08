# Idempotent npm global-install guard.
# Requires scripts/log.sh to be loaded first (uses log_step / log_skip).
# Usage: {{ "{{" }} template "scripts/npm-install.sh" {{ "}}" }}
#        npm_install claude @anthropic-ai/claude-code

# Look in the active npm's global node_modules, NOT command -v: a stale copy
# under an old Node install (or the Windows-side npm prefix under WSL) on PATH
# satisfies command -v, so the active Node never gets the package.
npm_has_global() {
    [ -f "$(npm root -g)/$1/package.json" ]
}

npm_install() {
    local cmd="$1"
    local pkg="$2"
    if npm_has_global "$pkg"; then
        log_skip "[$cmd] already installed"
    else
        log_step "[$cmd] installing $pkg"
        npm install -g "$pkg"
    fi
}
