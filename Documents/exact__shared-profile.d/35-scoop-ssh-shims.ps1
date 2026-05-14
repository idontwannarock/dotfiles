# 35-scoop-ssh-shims.ps1 -- Bypass scoop shims that fail under Win32-OpenSSH.
#
# Win32-OpenSSH SSH sessions cannot reliably launch scoop-installed binaries
# via the shim:
#   1. The 'current' junction does not resolve under the SSH session token
#      (Win32-OpenSSH reparse-point traversal quirk).
#   2. The shim's CreateProcess() fails under SSH ConPTY handle inheritance.
#
# Workaround: resolve the real exe inside the latest versioned dir and define
# a global function that forwards args. Only activate under SSH so local
# sessions keep using the shim untouched.
#
# Starship has its own bypass in 90-prompt.ps1 because its init output embeds
# the shim path and needs string rewriting; this file handles plain TUI tools
# whose only problem is the shim itself.

if (-not ($env:SSH_CONNECTION -or $env:SSH_CLIENT)) { return }

# zellij: terminal multiplexer used over SSH from mobile.
$zellijDir = Join-Path $env:USERPROFILE 'scoop\apps\zellij'
if (Test-Path -LiteralPath $zellijDir) {
    $zellijExe = Get-ChildItem $zellijDir -Directory -Force -ErrorAction SilentlyContinue |
                 Where-Object Name -match '^\d+\.\d+' |
                 Sort-Object Name -Descending |
                 Select-Object -First 1 |
                 ForEach-Object { Join-Path $_.FullName 'zellij.exe' }
    if ($zellijExe -and (Test-Path -LiteralPath $zellijExe)) {
        # Bake the resolved path into the ScriptBlock so the function survives
        # $zellijExe leaving script scope after this file finishes dot-sourcing.
        $body = [ScriptBlock]::Create("& `"$zellijExe`" @args")
        Set-Item -Path 'function:global:zellij' -Value $body
    }
}
