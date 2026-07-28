# Idempotent system-package install guard (apt on Linux/WSL, brew on macOS).
# Requires scripts/log.sh to be loaded first (uses log_step / log_skip).
#
# The apt/brew split happens at RENDER time, so the deployed script contains
# only the branch this machine will actually run. That means this fragment
# needs the template context passed through — note the trailing dot:
#
#   {{ "{{" }} template "scripts/pkg-install.sh" . {{ "}}" }}
#   pkg_install 7z p7zip-full     # command name, then package name
#   pkg_install curl              # package name defaults to the command name
pkg_install() {
    local cmd="$1"
    local pkg="${2:-$1}"
    if command -v "$cmd" &>/dev/null; then
        log_skip "[$cmd] already installed"
        return
    fi
{{- if eq .chezmoi.os "darwin" }}
    log_step "[$pkg] installing via brew"
    brew install "$pkg"
{{- else }}
    log_step "[$pkg] installing via apt"
    sudo apt-get install -y "$pkg"
{{- end }}
}
