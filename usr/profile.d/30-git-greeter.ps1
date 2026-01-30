$global:lastRepository = $null

function Check-DirectoryForNewRepository {
    $currentRepository = git rev-parse --show-toplevel 2>$null
    if ($currentRepository -and ($currentRepository -ne $global:lastRepository)) {
        onefetch | Write-Host
    }
    $global:lastRepository = $currentRepository
}

function Set-Location {
    Microsoft.PowerShell.Management\Set-Location @args
    Check-DirectoryForNewRepository
}

Check-DirectoryForNewRepository
