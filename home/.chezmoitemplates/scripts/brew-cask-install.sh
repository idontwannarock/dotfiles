# Idempotent Homebrew cask install guard (macOS only).
# Requires scripts/log.sh to be loaded first (uses log_step / log_skip).
# Usage: {{ "{{" }} template "scripts/brew-cask-install.sh" {{ "}}" }}
#        brew_install_cask docker
#
# Casks are GUI apps, so the presence check goes through `brew list --cask`
# rather than `command -v` — most of them put nothing on PATH.
brew_install_cask() {
    local cask="$1"
    if brew list --cask "$cask" &>/dev/null 2>&1; then
        log_skip "[$cask] already installed"
    else
        log_step "[$cask] installing via brew cask"
        brew install --cask "$cask"
    fi
}
