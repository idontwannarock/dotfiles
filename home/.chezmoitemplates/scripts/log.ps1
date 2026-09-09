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

# Everything this file prints is ASCII, deliberately. chezmoi captures a run_
# script's output through a pipe, and the child pwsh encodes that with the
# console code page, which is Big5 on this machine -- an em dash came out as "?"
# in all 13 places one apply printed one. The profile used to hide that by
# running chcp 65001 before anything else, and -NoProfile stopped it
# (see [interpreters.ps1] in .chezmoi.toml.tmpl).
#
# Setting [Console]::OutputEncoding here does not fix it, and neither does
# calling chcp here; both were tried and measured. Adding a UTF-8 BOM does not
# either -- pwsh reads a BOM-less UTF-8 script correctly, so the script side was
# never the broken half. Keeping the output ASCII removes the dependency instead
# of working around it, so keep it that way: use "--", never an em dash, in any
# string these functions print.

$script:LogTitle = ""
$script:LogEnded = $false
$script:LogStart = $null
$script:LogSectionStart = $null
$script:LogChanged = $false

# Verbosity is a variable of this repo's own, not a chezmoi flag.
#
# Reading chezmoi's -v out of CHEZMOI_ARGS was tried first and abandoned: chezmoi
# -v already means something, and that something is loud. It prints a full diff
# of every script it is about to run, hundreds of lines of the script's own
# source, which is the opposite of what someone asking for detail wants.
# --debug is worse: it logs every syscall.
#
#     $env:DOTFILES_LOG_VERBOSE = 1; chezmoi apply
$script:LogVerbose = ($env:DOTFILES_LOG_VERBOSE -eq '1')

# For call sites that have their own noise to gate, notably a command whose
# output is only worth reading when it failed.
function Test-LogVerbose { return $script:LogVerbose }

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
    if ($script:LogVerbose) {
        Write-Host "    (took $(Format-LogElapsed $script:LogSectionStart))" -ForegroundColor DarkGray
    }
    $script:LogSectionStart = $null
}

function Log-Begin {
    param([Parameter(Mandatory = $true)][string]$Title)
    $script:LogTitle = $Title
    $script:LogEnded = $false
    $script:LogStart = Get-Date
    $script:LogSectionStart = $null
    $script:LogChanged = $false
    Write-Host "=== BEGIN $Title ===" -ForegroundColor Cyan
}

# What each line is for, and why only some survive a quiet run:
#
#   Log-Begin/Log-End   the block and its total. Always: this is the answer to
#                       "what ran and how long did it take".
#   Log-Warn            always. A warning nobody sees is not a warning.
#   Log-Step            something changed. Always, because a quiet run that
#                       silently changed the machine is the thing to avoid.
#   Log-Section         narration of intent. Verbose only.
#   Log-Skip            nothing happened. Verbose only -- these are the bulk of
#                       the output and they all say the same thing.
#   (took ...)          per-section timing. Verbose only; the total on the END
#                       banner is what a normal run needs.
function Log-Section {
    param([Parameter(Mandatory = $true)][string]$Purpose)
    Close-LogSection
    if ($script:LogVerbose) { Write-Host "--- $Purpose" -ForegroundColor Cyan }
    $script:LogSectionStart = Get-Date
}

function Log-Step {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:LogChanged = $true
    Write-Host "    $Message" -ForegroundColor Yellow
}

# True once any Log-Step has fired. For a closing line that should only appear
# when something actually changed -- "restart X to activate the changes above"
# printed under an empty block is a false signal, and the quiet run made it
# obvious. Log-Step is already the single place that means "work happened", so
# this reads that rather than asking every call site to set a flag.
function Test-LogChanged { return $script:LogChanged }

function Log-Skip {
    param([Parameter(Mandatory = $true)][string]$Message)
    if ($script:LogVerbose) { Write-Host "    $Message (skipped)" -ForegroundColor Gray }
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
