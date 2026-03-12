<#
.SYNOPSIS
    Generate ~/.claude/worklog-config.md from WORKLOGS_PATH.

.DESCRIPTION
    Reads the WORKLOGS_PATH environment variable and writes a config file
    for the record-worklog Claude skill.

.EXAMPLE
    .\set-worklog-config.ps1
#>

[CmdletBinding()]
param()

$Company = "shoalter"
$ConfigPath = Join-Path $HOME ".claude" "worklog-config.md"

if (-not $env:WORKLOGS_PATH) {
    Write-Host "Error: WORKLOGS_PATH is not set." -ForegroundColor Red
    Write-Host "Run set-worklogs-path.ps1 first." -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path "$env:WORKLOGS_PATH\.git")) {
    Write-Host "Error: WORKLOGS_PATH ($env:WORKLOGS_PATH) is not a git repo." -ForegroundColor Red
    exit 1
}

$configDir = Split-Path -Parent $ConfigPath
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir | Out-Null
}

@"
# Worklog Configuration

- repo: $env:WORKLOGS_PATH
- company: $Company
"@ | Set-Content -Path $ConfigPath -Encoding UTF8 -NoNewline

Write-Host "Created $ConfigPath" -ForegroundColor Green
Write-Host "  repo: $env:WORKLOGS_PATH" -ForegroundColor Gray
Write-Host "  company: $Company" -ForegroundColor Gray
