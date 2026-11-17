#Requires -Version 5.1
# switch-pwsh-to-msi.ps1 -- replace the Microsoft Store (MSIX) PowerShell 7 with the
# official MSI build in C:\Program Files\PowerShell\7. Run ELEVATED.
#
# Why this exists: winget's Microsoft.PowerShell ships an MSIX bundle -- it never
# lands in Program Files and its install fails 0x80070005 under elevation, so winget
# can't give you the MSI. The real MSI is only on GitHub releases, and only up to the
# 7.6 LTS line: 7.7.0 and later ship no MSI. The helper installs the newest stable
# release that has one.
#
# Why it is NOT part of `chezmoi apply`: MSI install needs admin (interactive UAC),
# the swap is destructive, and pwsh is chezmoi's .ps1 interpreter (chicken-and-egg).
# So this is a deliberate manual, one-shot helper. Keep a Windows PowerShell 5.1
# window open as a fallback while this runs.
#
# Order matters: download + verify + install the MSI BEFORE removing the MSIX, so a
# network/signature/install failure never leaves the machine with no pwsh at all.

$ErrorActionPreference = 'Stop'

# Pick the release to install from a list of GitHub release objects.
function Select-MsiRelease($Releases) {
    $Releases |
        Where-Object { -not $_.prerelease -and -not $_.draft } |
        Where-Object { $_.assets.name -match 'win-x64\.msi$' } |
        Sort-Object { [version]($_.tag_name -replace '^v') } -Descending |
        Select-Object -First 1
}

# 1. Require elevation (do not self-relaunch: keep all output in this terminal).
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script must run elevated (Administrator)." -ForegroundColor Red
    Write-Host "Open an elevated PowerShell / Windows Terminal and run it again:" -ForegroundColor Yellow
    Write-Host "    switch-pwsh-to-msi.ps1" -ForegroundColor Yellow
    exit 1
}

# 2. Resolve + download the newest STABLE release that ships an MSI. PowerShell 7.7.0 and
#    later ship no MSI (MSIX only), so releases/latest can point at a release with none.
Write-Host "[1/5] Resolving newest stable PowerShell release with an MSI from GitHub..." -ForegroundColor Cyan
$releases = Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases?per_page=100' -Headers @{ 'User-Agent' = 'dotfiles-switch-pwsh' }
$rel = Select-MsiRelease $releases
if (-not $rel) { throw "No stable PowerShell release with a win-x64 MSI found. Nothing was changed." }
$asset = $rel.assets | Where-Object { $_.name -match 'win-x64\.msi$' } | Select-Object -First 1
$newest = $releases | Where-Object { -not $_.prerelease -and -not $_.draft } |
    Sort-Object { [version]($_.tag_name -replace '^v') } -Descending | Select-Object -First 1
if ($newest.tag_name -ne $rel.tag_name) {
    Write-Host "      Newest stable release $($newest.tag_name) has no MSI. Installing $($rel.tag_name) instead." -ForegroundColor Yellow
}
$msi = Join-Path $env:TEMP $asset.name
Write-Host "      $($rel.tag_name) -> $($asset.name)" -ForegroundColor Gray
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $msi -UseBasicParsing

# 3. Verify Authenticode (Valid + signed by Microsoft) BEFORE running the installer.
Write-Host "[2/5] Verifying Authenticode signature..." -ForegroundColor Cyan
$sig = Get-AuthenticodeSignature -FilePath $msi
if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'Microsoft Corporation') {
    throw "MSI signature check failed (Status=$($sig.Status); Signer=$($sig.SignerCertificate.Subject)). Not installing."
}
Write-Host "      OK: $($sig.SignerCertificate.Subject)" -ForegroundColor Gray

# 4. Install silently. 3010 = success-but-reboot-required, treat as success.
Write-Host "[3/5] Installing MSI (msiexec /qn)..." -ForegroundColor Cyan
$p = Start-Process msiexec.exe -ArgumentList @('/i', $msi, '/qn', '/norestart') -Wait -PassThru
if ($p.ExitCode -notin @(0, 3010)) { throw "msiexec exited $($p.ExitCode)." }
if ($p.ExitCode -eq 3010) { Write-Host "      (a reboot is pending to finish, but install succeeded)" -ForegroundColor Yellow }
try { Remove-Item -LiteralPath $msi -Force -ErrorAction SilentlyContinue } catch {}

# 5. Now that the MSI is in place, remove the Store/MSIX build (per-user + provisioned).
Write-Host "[4/5] Removing Store/MSIX PowerShell (per-user + provisioned)..." -ForegroundColor Cyan
Get-AppxPackage Microsoft.PowerShell -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match 'Microsoft.PowerShell' } |
    ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null }

# 6. Verify the MSI build is in place.
Write-Host "[5/5] Verifying..." -ForegroundColor Cyan
$pf7 = 'C:\Program Files\PowerShell\7\pwsh.exe'
if (-not (Test-Path -LiteralPath $pf7)) { throw "Expected $pf7 after install but it is missing." }
$ver = & $pf7 -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
Write-Host "Done. MSI pwsh $ver at $pf7" -ForegroundColor Green
Write-Host "Open a NEW console so 'pwsh' resolves to the MSI build." -ForegroundColor Yellow
