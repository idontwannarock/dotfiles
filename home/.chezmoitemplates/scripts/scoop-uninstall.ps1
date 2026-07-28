# Idempotent scoop package removal, for the one-shot scoop migration scripts.
# Requires scripts/log.ps1 to be loaded first.
# Usage: {{ "{{" }} template "scripts/scoop-uninstall.ps1" {{ "}}" }}
#        Remove-ScoopPackage -Name "docker" -Reason "CLI now at ~/.local/bin/docker.exe"
#
# -Reason is not decoration: it is printed as the section purpose, so the
# "why is this being removed" that used to sit in a file-header comment shows up
# in the chezmoi apply output.
#
# -PruneShims removes leftover ~/scoop/shims/<name>.* entries. It runs even when
# scoop reports the package as absent, because scoop's own state can be broken
# while the shim survives and shadows the chezmoi-managed binary. Opt in only
# where that behaviour has been specified (currently jdtls). Never touches
# ~/.local/bin.
#
# Callers must check for scoop themselves before the loop — this function
# assumes scoop is on PATH.
function Remove-ScoopPackage {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Reason,
        [switch]$PruneShims
    )

    Log-Section "remove scoop $Name — $Reason"

    $installed = $false
    try {
        $listOutput = scoop list $Name 2>$null | Out-String
        $pattern = "(?im)^\s*$([regex]::Escape($Name))\b"
        if ($listOutput -match $pattern) { $installed = $true }
    } catch {}

    if ($installed) {
        Log-Step "[$Name] uninstalling from scoop"
        scoop uninstall $Name 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Log-Warn "[$Name] scoop uninstall returned non-zero exit; continuing"
        }
    } else {
        Log-Skip "[$Name] not installed via scoop"
    }

    if ($PruneShims) {
        $shimDir = Join-Path $env:USERPROFILE "scoop\shims"
        foreach ($ext in @("", ".exe", ".cmd", ".shim", ".ps1")) {
            $shim = Join-Path $shimDir ($Name + $ext)
            if (Test-Path $shim) {
                Log-Step "[$Name] removing orphan scoop shim: $($Name + $ext)"
                Remove-Item $shim -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
