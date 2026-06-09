# 25-claude-zai.ps1 — Route Claude Code to z.ai's Anthropic-compatible endpoint.
#
# Token source: gopass z.ai/claude-code-token (shared vault with WSL `pass`).
# Falls back to $env:ZAI_API_KEY if gopass unavailable or entry missing.
#
# PowerShell $env:* assignments leak to process scope (unlike bash's inline
# VAR=val), so the 6 ANTHROPIC_* env vars are snapshotted + restored via
# try/finally to keep `claude` invocations outside this wrapper unaffected.
#
# Mirror of .chezmoitemplates/shell-common/base's claude-zai() function.

function claude-zai {
    [CmdletBinding()]
    param(
        [string] $OpusModel = 'GLM-5.1',
        [string] $SonnetModel = 'GLM-5',
        [string] $HaikuModel = 'GLM-5-Turbo',
        [string] $TimeoutMs = '3000000',
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

    $token = $null
    if (Get-Command gopass -ErrorAction SilentlyContinue) {
        $token = & gopass show -o z.ai/claude-code-token 2>$null
        if ($LASTEXITCODE -ne 0) { $token = $null }
    }
    if (-not $token) { $token = $env:ZAI_API_KEY }
    if (-not $token) {
        Write-Error "claude-zai: no token (gopass z.ai/claude-code-token unreadable and `$env:ZAI_API_KEY unset)"
        return
    }

    $names = @(
        'ANTHROPIC_BASE_URL'
        'ANTHROPIC_AUTH_TOKEN'
        'ANTHROPIC_DEFAULT_OPUS_MODEL'
        'ANTHROPIC_DEFAULT_SONNET_MODEL'
        'ANTHROPIC_DEFAULT_HAIKU_MODEL'
        'API_TIMEOUT_MS'
    )
    $snapshot = @{}
    foreach ($n in $names) {
        $snapshot[$n] = [Environment]::GetEnvironmentVariable($n, 'Process')
    }

    try {
        $env:ANTHROPIC_BASE_URL             = 'https://api.z.ai/api/anthropic'
        $env:ANTHROPIC_AUTH_TOKEN           = $token
        $env:ANTHROPIC_DEFAULT_OPUS_MODEL   = $OpusModel
        $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $SonnetModel
        $env:ANTHROPIC_DEFAULT_HAIKU_MODEL  = $HaikuModel
        $env:API_TIMEOUT_MS                 = $TimeoutMs
        & claude @Remaining
    }
    finally {
        foreach ($n in $names) {
            $prev = $snapshot[$n]
            if ($null -eq $prev) {
                Remove-Item "Env:\$n" -ErrorAction SilentlyContinue
            } else {
                [Environment]::SetEnvironmentVariable($n, $prev, 'Process')
            }
        }
    }
}
