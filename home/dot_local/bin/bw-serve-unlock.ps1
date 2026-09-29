# bw-serve-unlock.ps1 -- start `bw serve` and unlock it once per logon.
#
# corp-ssh-askpass reads credentials from bw serve on localhost:8087. bw serve
# has no idle timeout, so one unlock lasts until logoff or reboot. A logon
# scheduled task runs this script; it is also safe to run by hand at any time.

$ErrorActionPreference = 'Stop'
$api = 'http://localhost:8087'

function Get-BwStatus {
    try { (Invoke-RestMethod -Uri "$api/status" -TimeoutSec 5).data.template.status }
    catch { $null }
}

$status = Get-BwStatus
if (-not $status) {
    # winget does not always create the bw shim on PATH, so fall back to the
    # package directory.
    $bw = (Get-Command bw.exe -ErrorAction SilentlyContinue).Source
    if (-not $bw) {
        $bw = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Bitwarden.CLI_*\bw.exe" |
            Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $bw) { throw 'bw.exe not found. Install it: winget install Bitwarden.CLI' }
    Start-Process -FilePath $bw -ArgumentList 'serve' -WindowStyle Hidden
    foreach ($i in 1..30) {
        Start-Sleep -Seconds 1
        $status = Get-BwStatus
        if ($status) { break }
    }
    if (-not $status) { throw 'bw serve did not start within 30 seconds.' }
}

if ($status -eq 'unauthenticated') { throw 'bw is not logged in. Run: bw login' }

function Invoke-Unlock([securestring]$secure) {
    $body = @{ password = [System.Net.NetworkCredential]::new('', $secure).Password } | ConvertTo-Json
    # The response carries the session key, so never print it.
    try { $null = Invoke-RestMethod -Method Post -Uri "$api/unlock" -ContentType 'application/json' -Body $body; $true }
    catch { $false }
}

# The master password is stored encrypted with DPAPI, which only this Windows
# user, logged on, can decrypt. So the Windows logon is what unlocks the vault.
$secretFile = "$env:LOCALAPPDATA\bw-serve-unlock\master.dpapi"
if ($status -ne 'unlocked' -and (Test-Path $secretFile)) {
    try {
        if (Invoke-Unlock (Get-Content $secretFile | ConvertTo-SecureString)) { $status = Get-BwStatus }
    } catch { }
}

# No stored password, or it no longer works (for example, after a master
# password change): ask, and store the new one when it unlocks.
while ($status -ne 'unlocked') {
    $s = Read-Host 'Bitwarden master password (unlocks bw serve for corp-ssh)' -AsSecureString
    if (Invoke-Unlock $s) {
        $null = New-Item -ItemType Directory -Force (Split-Path $secretFile)
        $s | ConvertFrom-SecureString | Set-Content $secretFile
    } else {
        Write-Host 'Unlock failed. Try again, or close this window to skip.'
    }
    Remove-Variable s
    $status = Get-BwStatus
}

try { $null = Invoke-RestMethod -Method Post -Uri "$api/sync" } catch { }
Write-Host 'bw serve is unlocked.'
