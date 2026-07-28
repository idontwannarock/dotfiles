# Structured logging for chezmoi run_* scripts (PowerShell 5.1+).
# Usage: {{ "{{" }} template "scripts/log.ps1" {{ "}}" }}
#
# Output format is byte-for-byte identical to scripts/log.sh:
#
#   Log-Begin "npm global tools"        === BEGIN npm global tools ===
#   Log-Section "install Claude Code"   --- install Claude Code
#   Log-Step "installing foo@1.2.3"         installing foo@1.2.3
#   Log-Skip "[foo] already installed"       [foo] already installed (skipped)
#   Log-Warn "upstream returned 500"         !! upstream returned 500
#                                       === END npm global tools (ok) ===
#
# Log-End takes no title — it reads the one Log-Begin stored, so the closing
# banner can never drift from the opening one.
#
# bash gets its closing banner from an EXIT trap; PowerShell has no equivalent,
# so wrap the script body like this and exit early with `return`, never `exit`
# (`exit` bypasses finally):
#
#   Log-Begin "wave 1 migration"
#   try {
#       ...body...
#   } catch {
#       Log-End -ErrorRecord $_
#       throw
#   } finally {
#       Log-End
#   }
#
# catch runs before finally, and Log-End is idempotent, so a failure reports
# FAILED and the finally call is a no-op.

$script:LogTitle = ""
$script:LogEnded = $false

function Log-Begin {
    param([Parameter(Mandatory = $true)][string]$Title)
    $script:LogTitle = $Title
    $script:LogEnded = $false
    Write-Host "=== BEGIN $Title ===" -ForegroundColor Cyan
}

function Log-Section {
    param([Parameter(Mandatory = $true)][string]$Purpose)
    Write-Host "--- $Purpose" -ForegroundColor Cyan
}

function Log-Step {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "    $Message" -ForegroundColor Yellow
}

function Log-Skip {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "    $Message (skipped)" -ForegroundColor Gray
}

function Log-Warn {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "    !! $Message" -ForegroundColor Red
}

function Log-End {
    param($ErrorRecord = $null)
    if ($script:LogEnded) { return }
    $script:LogEnded = $true
    if ($null -ne $ErrorRecord) {
        Write-Host "=== END $script:LogTitle (FAILED rc=1) ===" -ForegroundColor Cyan
        Write-Host "    !! $($ErrorRecord.Exception.Message)" -ForegroundColor Red
    } else {
        Write-Host "=== END $script:LogTitle (ok) ===" -ForegroundColor Cyan
    }
}
