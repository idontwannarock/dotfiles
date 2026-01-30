# Uncomment to detect which step throws error
#$ErrorActionPreference = 'Stop'

# Load all profile fragments
$profileDir = Join-Path $PSScriptRoot "profile.d"

if (Test-Path $profileDir) {
    Get-ChildItem $profileDir -Filter *.ps1 |
        Sort-Object Name |
        ForEach-Object {
            . $_.FullName
        }
}
