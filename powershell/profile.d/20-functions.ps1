function which ($command_name) {
    $cmd = Get-Command $command_name -ErrorAction SilentlyContinue
    if ($cmd) {
        $cmd | Select-Object -ExpandProperty Definition
    } else {
        Write-Host "$command_name not found" -ForegroundColor Red
    }
}

# Edit Windows Terminal settings.json with vim
function Edit-WTSettings {
    $wt = Get-AppxPackage -Name Microsoft.WindowsTerminal
    if ($wt) {
        $path = "$env:LOCALAPPDATA\Packages\$($wt.PackageFamilyName)\LocalState\settings.json"
        if (Test-Path $path) {
            vim $path
        } else {
            Write-Error "Settings file not found: $path"
        }
    } else {
        Write-Error "Windows Terminal not found"
    }
}

Set-Alias wtsettings Edit-WTSettings
