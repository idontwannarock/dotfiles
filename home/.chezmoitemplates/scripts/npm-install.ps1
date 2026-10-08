# Idempotent npm global-install guard (PowerShell).
# Requires scripts/log.ps1 to be loaded first (uses Log-Step / Log-Skip).
# Usage: {{ "{{" }} template "scripts/npm-install.ps1" {{ "}}" }}
#        Install-NpmPackage -Command "claude" -Package "@anthropic-ai/claude-code"

# Look in the active npm's global node_modules, NOT Get-Command: a stale copy
# under an old Node install on PATH once satisfied Get-Command, so the active
# Node never got the package.
function Test-NpmGlobalPackage {
    param([Parameter(Mandatory = $true)][string]$Package)
    Test-Path (Join-Path (npm root -g) "$Package\package.json")
}

function Install-NpmPackage {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string]$Package
    )
    if (Test-NpmGlobalPackage $Package) {
        Log-Skip "[$Command] already installed"
    } else {
        Log-Step "[$Command] installing $Package"
        npm install -g $Package
    }
}
