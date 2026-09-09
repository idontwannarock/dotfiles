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
#                                           (took 1.2s)
#                                       === END npm global tools (ok, 3.4s) ===
#
# Each Log-Section closes the previous section with its elapsed time; Log-End
# closes the last one and adds the whole-script total to the closing banner.
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

# chezmoi runs these scripts with -NoProfile (see [interpreters.ps1] in
# .chezmoi.toml.tmpl), so Documents/_shared-profile.d/00-encoding.ps1 does not
# run and the console is left on the OEM code page. Every banner below carries an
# em dash and most section names carry Chinese, both of which print as "?" there.
# This mirrors that fragment, minus its interactive Clear-Host and minus its chcp
# call -- chcp spawns a process, and the point of -NoProfile is to stop paying
# for work the script does not need.
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
} catch {}

$script:LogTitle = ""
$script:LogEnded = $false
$script:LogStart = $null
$script:LogSectionStart = $null

# Invariant culture so the decimal point never becomes a comma on a localized
# machine — the bash side prints under LC_ALL=C for the same reason.
function Format-LogElapsed {
    param([Parameter(Mandatory = $true)][datetime]$Since)
    ((Get-Date) - $Since).TotalSeconds.ToString('F1', [cultureinfo]::InvariantCulture) + 's'
}

# Sections have no explicit close, so each one is closed by whatever comes next:
# the following Log-Section, or Log-End.
function Close-LogSection {
    if ($null -eq $script:LogSectionStart) { return }
    Write-Host "    (took $(Format-LogElapsed $script:LogSectionStart))" -ForegroundColor DarkGray
    $script:LogSectionStart = $null
}

function Log-Begin {
    param([Parameter(Mandatory = $true)][string]$Title)
    $script:LogTitle = $Title
    $script:LogEnded = $false
    $script:LogStart = Get-Date
    $script:LogSectionStart = $null
    Write-Host "=== BEGIN $Title ===" -ForegroundColor Cyan
}

function Log-Section {
    param([Parameter(Mandatory = $true)][string]$Purpose)
    Close-LogSection
    Write-Host "--- $Purpose" -ForegroundColor Cyan
    $script:LogSectionStart = Get-Date
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
    Close-LogSection
    $total = if ($null -ne $script:LogStart) { Format-LogElapsed $script:LogStart } else { "0.0s" }
    if ($null -ne $ErrorRecord) {
        Write-Host "=== END $script:LogTitle (FAILED rc=1, $total) ===" -ForegroundColor Cyan
        Write-Host "    !! $($ErrorRecord.Exception.Message)" -ForegroundColor Red
    } else {
        Write-Host "=== END $script:LogTitle (ok, $total) ===" -ForegroundColor Cyan
    }
}
