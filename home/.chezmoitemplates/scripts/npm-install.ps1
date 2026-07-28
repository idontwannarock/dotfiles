# Idempotent npm global-install guard (PowerShell).
# Requires scripts/log.ps1 to be loaded first (uses Log-Step / Log-Skip).
# Usage: {{ "{{" }} template "scripts/npm-install.ps1" {{ "}}" }}
#        Install-NpmPackage -Command "claude" -Package "@anthropic-ai/claude-code"
function Install-NpmPackage {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string]$Package
    )
    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        Log-Skip "[$Command] already installed"
    } else {
        Log-Step "[$Command] installing $Package"
        npm install -g $Package
    }
}
