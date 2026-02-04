<#
.SYNOPSIS
    Search for worklogs repo and set WORKLOGS_PATH environment variable.

.DESCRIPTION
    This script searches for a git repository named "worklogs" and sets the
    WORKLOGS_PATH environment variable permanently for the current user.

    Search methods (in order of priority):
    1. Everything CLI (es.exe) - extremely fast if available
    2. Recursive filesystem search from drive roots

.EXAMPLE
    .\Set-WorklogsPath.ps1
#>

[CmdletBinding()]
param()

# Already set and valid?
if ($env:WORKLOGS_PATH -and (Test-Path "$env:WORKLOGS_PATH\.git")) {
    Write-Host "WORKLOGS_PATH already set: $env:WORKLOGS_PATH" -ForegroundColor Green
    return
}

function Find-WithEverything {
    if (-not (Get-Command es -ErrorAction SilentlyContinue)) {
        return $null
    }

    if (-not (Get-Process Everything -ErrorAction SilentlyContinue)) {
        Write-Host "Everything is not running, skipping..." -ForegroundColor Gray
        return $null
    }

    Write-Host "Searching with Everything..." -ForegroundColor Cyan
    $results = es -r "^worklogs$" -ad 2>$null | Where-Object { Test-Path "$_\.git" }
    return $results | Select-Object -First 1
}

function Find-WithFilesystem {
    Write-Host "Searching filesystem (this may take a moment)..." -ForegroundColor Cyan

    # Get all fixed drives
    $drives = Get-PSDrive -PSProvider FileSystem |
        Where-Object { $_.Free -ne $null } |
        Select-Object -ExpandProperty Root

    # Directories to skip
    $excludes = @(
        'Windows', 'Program Files', 'Program Files (x86)',
        'ProgramData', '$Recycle.Bin', 'Recovery', 'PerfLogs'
    )

    foreach ($drive in $drives) {
        Write-Host "  Scanning $drive ..." -ForegroundColor Gray

        $found = Get-ChildItem $drive -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin $excludes } |
            ForEach-Object {
                Get-ChildItem $_.FullName -Directory -Recurse -Depth 3 -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -eq "worklogs" -and (Test-Path "$($_.FullName)\.git") }
            } |
            Select-Object -First 1

        if ($found) { return $found.FullName }
    }

    return $null
}

# Try Everything first, then filesystem
$repoPath = Find-WithEverything
if (-not $repoPath) {
    $repoPath = Find-WithFilesystem
}

if ($repoPath) {
    [Environment]::SetEnvironmentVariable("WORKLOGS_PATH", $repoPath, "User")
    $env:WORKLOGS_PATH = $repoPath

    # 設定別名讓當前 session 也能使用
    Set-Alias -Name createnewlog -Value "$repoPath\create-new-log.ps1" -Scope Global
    Set-Alias -Name gitpushlog -Value "$repoPath\git-push.ps1" -Scope Global

    Write-Host ""
    Write-Host "Found and configured: $repoPath" -ForegroundColor Green
    Write-Host "Aliases 'createnewlog' and 'gitpushlog' are now available." -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "worklogs repo not found." -ForegroundColor Red
    Write-Host "You can set it manually:" -ForegroundColor Yellow
    Write-Host '  [Environment]::SetEnvironmentVariable("WORKLOGS_PATH", "C:\path\to\worklogs", "User")' -ForegroundColor Gray
}
