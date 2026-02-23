# PowerShell 7 profile loader
# Uncomment to detect which step throws error
#$ErrorActionPreference = 'Stop'

# Load shared fragments (compatible with PS5 & PS7)
$sharedDir = Join-Path (Split-Path (Split-Path $PROFILE)) "_shared-profile.d"
if (Test-Path $sharedDir) {
    Get-ChildItem $sharedDir -Filter *.ps1 |
        Sort-Object Name |
        ForEach-Object { . $_.FullName }
}

# Load PS7-specific fragments
$profileDir = Join-Path (Split-Path $PROFILE) "profile.d"
if (Test-Path $profileDir) {
    Get-ChildItem $profileDir -Filter *.ps1 |
        Sort-Object Name |
        ForEach-Object { . $_.FullName }
}
