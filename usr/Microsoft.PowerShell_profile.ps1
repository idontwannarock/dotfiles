# fastfetch is used to print system info
try {
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    chcp 65001 > $null
} catch {}

Clear-Host

# Force Fastfetch to use YOUR config every time (bypass path confusion)
if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
    fastfetch -c "C:/Users/HowardWang/.config/fastfetch/config.jsonc"
}

# equivalent to linux which to find location of the command
function which($command_name)
{
    Get-Command $command_name | Select-Object -ExpandProperty Definition
}

# Set alias
Set-Alias scoopupdate "$HOME\.local\bin\scoop-interactive-update.ps1"

#Invoke-Expression (&scoop-search --hook)

# git repository greeter

# Set the console output encoding to UTF-8, so that special characters are displayed correctly when piping to Write-Host
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
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

# Optional: Check the repository also when opening a shell directly in a repository directory
# Uncomment the following line if desired
Check-DirectoryForNewRepository

# MUST placed at the end to init starship
Invoke-Expression (&starship init powershell)
