# 24-bw-get.ps1 -- Get-BwSecret: read one field of a Bitwarden item from a
# running, unlocked `bw serve` on localhost:8087.
#
# Used by 25-claude-zai.ps1 and 26-glab.ps1. bw serve is started and unlocked
# at logon by the bw-serve-unlock scheduled task; see docs/corp-ssh-setup-windows.md.
# Returns $null when bw serve is not reachable or locked, the item does not
# exist, or the field is empty. Callers fall back to an env var.
#
# Mirror of ~/.local/bin/bw-get (Linux/WSL).

function Get-BwSecret {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [ValidateSet('password', 'totp')] [string] $Field = 'password'
    )
    $api = 'http://localhost:8087'
    try {
        $status = (Invoke-RestMethod -Uri "$api/status" -TimeoutSec 5).data.template
        if ($status.status -ne 'unlocked') { return $null }
        # Sync when the local copy is over 10 minutes old, so a secret rotated in
        # the vault arrives soon without paying for a sync on every call.
        if (-not $status.lastSync -or ((Get-Date) - [datetime]$status.lastSync).TotalMinutes -gt 10) {
            try { $null = Invoke-RestMethod -Method Post -Uri "$api/sync" -TimeoutSec 10 } catch { }
        }
        $item = @((Invoke-RestMethod -Uri "$api/list/object/items?search=$Name" -TimeoutSec 5).data.data) |
            Where-Object { $_.name -ceq $Name } | Select-Object -First 1
        if (-not $item) { return $null }
        $out = if ($Field -eq 'totp') {
            (Invoke-RestMethod -Uri "$api/object/totp/$($item.id)" -TimeoutSec 5).data.data
        } else {
            $item.login.password
        }
        if ([string]::IsNullOrEmpty($out)) { return $null }
        return $out
    } catch {
        return $null
    }
}
