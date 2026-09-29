# corp-ssh-askpass.ps1 — SSH_ASKPASS helper for password+OTP hosts (Windows port).
#
# Invoked indirectly by ssh.exe via corp-ssh-askpass.cmd shim, when
# SSH_ASKPASS_REQUIRE=force is set and ssh.exe would otherwise prompt via TTY.
# Reads ~/.corp-ssh/hosts.yaml (local-only, not in the dotfiles repo) to decide
# which hosts to answer for; credentials come from a running, unlocked
# `bw serve` (Bitwarden CLI) on localhost:8087 -- see bw-serve-unlock.ps1.
#
# Mirrors dot_local/bin/executable_corp-ssh-askpass (Linux/WSL bash version),
# including its Invoke-AskHuman / ask_human fallback.
# Tests: tests/corp-ssh-askpass.Tests.ps1.

$ErrorActionPreference = 'Stop'

# CORP_SSH_BW_API exists for the tests, which serve a fixture on another port.
$api = if ($env:CORP_SSH_BW_API) { $env:CORP_SSH_BW_API } else { 'http://localhost:8087' }

$prompt    = if ($args.Count -ge 1) { $args[0] } else { '' }
$hostsFile = Join-Path $env:USERPROFILE '.corp-ssh\hosts.yaml'

# 0. Fallback for prompts this helper does not own. SSH_ASKPASS_REQUIRE=force
#    routes EVERY openssh question here, including host-key confirmations
#    ("Are you sure you want to continue connecting (yes/no/...)?") and password
#    prompts for hosts outside hosts.yaml. Exiting 1 answers those with "no":
#    connecting to any new host then fails with "Host key verification failed."
#    So hand the question back to the human instead.
#
#    ssh.exe reads this helper's stdout as the answer, so the question itself
#    must go to the console device (CONOUT$), never to stdout. Redirected stdin
#    means nobody is there to answer -- Pester, CI, scheduled tasks -- and
#    declining stays correct; this is the Windows counterpart of the bash
#    version's /dev/tty check.
function Invoke-AskHuman {
    if ([Console]::IsInputRedirected) { exit 1 }
    try { $conOut = [System.IO.StreamWriter]::new('CONOUT$') } catch { exit 1 }
    # Host-key confirmations arrive truncated. openssh passes the whole
    # multi-line question as one argument, but corp-ssh-askpass.cmd hands it to
    # the script with %*, and cmd.exe cuts an argument at its first newline --
    # measured, not assumed. Only "The authenticity of host '<h>' can't be
    # established." survives, so match on that as well as on the yes/no line the
    # bash version does see, and re-compose the question ourselves.
    $isHostKey = ($prompt -like '*(yes/no*') -or ($prompt -like '*authenticity of host*')
    try {
        $conOut.Write($prompt)
        $conOut.Flush()
        if ($isHostKey) {
            if ($prompt -notlike '*(yes/no*') {
                $conOut.Write("`n[corp-ssh-askpass] The key fingerprint line was lost in the shim and cannot be shown here. Verify it out of band before answering.`nAre you sure you want to continue connecting (yes/no/[fingerprint])? ")
                $conOut.Flush()
            }
            $reply = $Host.UI.ReadLine()                 # host-key answer, echo it back
        } else {
            $sec   = $Host.UI.ReadLineAsSecureString()   # password, keep it off the screen
            $reply = [System.Net.NetworkCredential]::new('', $sec).Password
            $conOut.Write("`n")
            $conOut.Flush()
        }
    } catch { exit 1 }
    # Bare LF, no BOM -- same reason as the success path below.
    [Console]::Out.Write($reply + "`n")
    exit 0
}

# 1. Parse hostname. Two shapes exist, one per auth method:
#      keyboard-interactive (PAM) -> "(user@host.fqdn) Password:"
#      password (openssh builtin) -> "user@host.fqdn's password: "
#    Greedy "(.+@)?" in both handles "(ad-user@realm@host.fqdn) Password:" form.
if ($prompt -match '\((.+@)?([^)]+)\) ') {
    $targetHost = $matches[2]
} elseif ($prompt -match "^(.+@)?(.+)'s password: ?$") {
    $targetHost = $matches[2]
} else {
    Invoke-AskHuman   # prompt format unrecognized -> not ours, ask the human
}
$shortHost = $targetHost.Split('.')[0]

# 2. Allowlist check.
if (-not (Test-Path -LiteralPath $hostsFile)) { Invoke-AskHuman }
$lines   = Get-Content -LiteralPath $hostsFile
$shortRe = [regex]::Escape($shortHost)
$fqdnRe  = [regex]::Escape($targetHost)
if (-not ($lines -match "^\s*-\s*($shortRe|$fqdnRe)\s*$")) { Invoke-AskHuman }   # not a corp host -> ask the human, as plain ssh would

# 3. Resolve the Bitwarden item prefix from yaml. The shared AD credential is
#    the item named "$passPath" (password + TOTP seed).
$passPath = $null
foreach ($line in $lines) {
    if ($line -match '^\s*pass_path:\s*(\S+)') {
        $passPath = $matches[1]
        break
    }
}
if ([string]::IsNullOrEmpty($passPath)) { Invoke-AskHuman }

function Stop-WithHint([string]$msg) {
    [Console]::Error.WriteLine("corp-ssh-askpass: $msg")
    [Console]::Error.WriteLine('corp-ssh-askpass: Start and unlock bw serve: Start-ScheduledTask -TaskName bw-serve-unlock')
    exit 1
}

# 3b. Hosts with their own local account (not the shared AD principal) keep
#     their password in the item "$passPath/hosts/<shortHost>". One list
#     request answers both lookups. A locked or stopped bw serve fails the
#     request, and the helper fails closed -- it never falls back to the shared
#     password because a per-host lookup failed.
$isOtp = $prompt -like '*One-time Password:*'
if (-not $isOtp) {
    # Sync first, so a password rotated in the vault reaches ssh at once.
    # An offline sync is not fatal: the cached vault still answers.
    try { $null = Invoke-RestMethod -Method Post -Uri "$api/sync" -TimeoutSec 10 } catch { }
}
try { $list = Invoke-RestMethod -Uri "$api/list/object/items?search=$passPath" -TimeoutSec 10 } catch { $list = $null }
if (-not $list -or -not $list.success) { Stop-WithHint 'bw serve not reachable or locked.' }
$items   = @($list.data.data)
$shared  = $items | Where-Object { $_.name -ceq $passPath } | Select-Object -First 1
$perHost = $items | Where-Object { $_.name -ceq "$passPath/hosts/$shortHost" } | Select-Object -First 1

# 4. Dispatch. OTP branch FIRST -- "Password:" is a substring of "One-time Password:".
$out = $null
if ($isOtp) {
    if (-not $shared) { Stop-WithHint "no Bitwarden item named $passPath." }
    try { $out = (Invoke-RestMethod -Uri "$api/object/totp/$($shared.id)" -TimeoutSec 10).data.data } catch { }
} elseif (($prompt -like '*Password:*') -or ($prompt -like "*'s password:*")) {
    $out = if ($perHost) { $perHost.login.password } elseif ($shared) { $shared.login.password }
} else {
    Invoke-AskHuman
}

if ([string]::IsNullOrEmpty($out)) { Stop-WithHint "empty answer from bw serve for $targetHost." }

# Bare LF, no BOM. Avoid Write-Output (adds CRLF on Windows; sshd rejects \r in password).
[Console]::Out.Write(($out -replace "[`r`n]+$", '') + "`n")
