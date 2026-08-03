# 26-glab.ps1 — corp GitLab CLI wrapper.
#
# Token source: gopass gitlab/corp-token (shared vault with WSL `pass`).
# Falls back to $env:GITLAB_TOKEN if gopass unavailable or entry missing.
#
# The host comes from machine-local state (HKCU\Environment), deliberately not
# from this repo — see docs/gitlab-corp-access.md. Without it glab targets
# gitlab.com and a corp token yields 401, an error that points at the token when
# the fault is the host; this wrapper stops that before any request goes out.
#
# PowerShell $env:* assignments leak to process scope (unlike bash's inline
# VAR=val), so GITLAB_TOKEN is snapshotted + restored via try/finally to keep
# glab invocations outside this wrapper unaffected.
#
# Mirror of .chezmoitemplates/shell-common/base's glab() function; the two
# error strings are kept byte-identical on purpose.

function glab {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

    if (-not $env:GITLAB_HOST) {
        Write-Error 'glab: GITLAB_HOST 未設定；不設會連向 gitlab.com 並回 401。見 docs/gitlab-corp-access.md'
        return
    }

    $token = $null
    if (Get-Command gopass -ErrorAction SilentlyContinue) {
        $token = & gopass show -o gitlab/corp-token 2>$null
        if ($LASTEXITCODE -ne 0) { $token = $null }
    }
    if (-not $token) { $token = $env:GITLAB_TOKEN }
    if (-not $token) {
        Write-Error 'glab: no token (vault entry gitlab/corp-token unreadable and GITLAB_TOKEN unset)'
        return
    }

    # -CommandType Application skips this function, so no recursion.
    $exe = Get-Command glab -CommandType Application -ErrorAction SilentlyContinue
    if (-not $exe) {
        Write-Error 'glab: binary not on PATH (expected ~/.local/bin/glab.exe from the chezmoi external)'
        return
    }

    $snapshot = [Environment]::GetEnvironmentVariable('GITLAB_TOKEN', 'Process')
    try {
        $env:GITLAB_TOKEN = $token
        & $exe.Source @Remaining
    }
    finally {
        if ($null -eq $snapshot) {
            Remove-Item 'Env:\GITLAB_TOKEN' -ErrorAction SilentlyContinue
        } else {
            [Environment]::SetEnvironmentVariable('GITLAB_TOKEN', $snapshot, 'Process')
        }
    }
}
