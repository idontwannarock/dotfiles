# Windows PowerShell 5 profile loader
# Uncomment to detect which step throws error
#$ErrorActionPreference = 'Stop'

# Load shared fragments (compatible with PS5 & PS7)
$sharedDir = Join-Path (Split-Path (Split-Path $PROFILE)) "_shared-profile.d"
$sharedNames = @()
if (Test-Path $sharedDir) {
    $sharedScripts = Get-ChildItem $sharedDir -Filter *.ps1 | Sort-Object Name
    $sharedNames = $sharedScripts | ForEach-Object { $_.Name }
    $sharedScripts | ForEach-Object { . $_.FullName }
}

# Load PS5-specific fragments (skip any already loaded from _shared-profile.d)
$profileDir = Join-Path (Split-Path $PROFILE) "profile.d"
if (Test-Path $profileDir) {
    Get-ChildItem $profileDir -Filter *.ps1 |
        Where-Object { $_.Name -notin $sharedNames } |
        Sort-Object Name |
        ForEach-Object { . $_.FullName }
}
