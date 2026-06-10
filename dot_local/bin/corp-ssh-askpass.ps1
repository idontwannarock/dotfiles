# corp-ssh-askpass.ps1 — SSH_ASKPASS helper for password+OTP hosts (Windows port).
#
# Invoked indirectly by ssh.exe via corp-ssh-askpass.cmd shim, when
# SSH_ASKPASS_REQUIRE=force is set and ssh.exe would otherwise prompt via TTY.
# Reads ~/.corp-ssh/hosts.yaml (local-only, not in the dotfiles repo) to decide
# which hosts to answer for; credentials come from gopass, decrypted via the
# user's gpg-agent cache.
#
# Mirrors dot_local/bin/executable_corp-ssh-askpass (Linux/WSL bash version).
# Tests: tests/corp-ssh-askpass.Tests.ps1.

$ErrorActionPreference = 'Stop'

# Self-contained: ssh.exe hands this helper a minimal environment (no profile,
# possibly no PATH). gopass locates gpg via PATH, so ensure the self-managed
# GnuPG (run_onchange_install-gnupg.ps1.tmpl) is discoverable and points at the
# user keyring. Without this, corp-ssh breaks once the scoop gpg shim (which used
# to be on PATH everywhere) is gone.
$gpgBin = Join-Path $env:USERPROFILE '.local\opt\gnupg\bin'
if (Test-Path -LiteralPath $gpgBin) { $env:Path = "$gpgBin;$env:Path" }
if (-not $env:GNUPGHOME) { $env:GNUPGHOME = Join-Path $env:USERPROFILE '.gnupg' }

$prompt    = if ($args.Count -ge 1) { $args[0] } else { '' }
$hostsFile = Join-Path $env:USERPROFILE '.corp-ssh\hosts.yaml'

# 1. Parse hostname: "(user@host.fqdn) Password:" -> host.fqdn.
#    Greedy "(.+@)?" handles "(ad-user@realm@host.fqdn) Password:" form.
if ($prompt -notmatch '\((.+@)?([^)]+)\) ') { exit 1 }
$targetHost = $matches[2]
$shortHost  = $targetHost.Split('.')[0]

# 2. Allowlist check.
if (-not (Test-Path -LiteralPath $hostsFile)) { exit 1 }
$lines   = Get-Content -LiteralPath $hostsFile
$shortRe = [regex]::Escape($shortHost)
$fqdnRe  = [regex]::Escape($targetHost)
if (-not ($lines -match "^\s*-\s*($shortRe|$fqdnRe)\s*$")) { exit 1 }

# 3. Resolve pass_path from yaml.
$passPath = $null
foreach ($line in $lines) {
    if ($line -match '^\s*pass_path:\s*(\S+)') {
        $passPath = $matches[1]
        break
    }
}
if ([string]::IsNullOrEmpty($passPath)) { exit 1 }

# 4. Dispatch. OTP branch FIRST — "Password:" is a substring of "One-time Password:".
$out = $null
$rc  = 0
if ($prompt -like '*One-time Password:*') {
    $out = & gopass otp     "$passPath/totp"     2>$null
    $rc  = $LASTEXITCODE
} elseif ($prompt -like '*Password:*') {
    $out = & gopass show -o "$passPath/password" 2>$null
    $rc  = $LASTEXITCODE
} else {
    exit 1
}

if ($rc -ne 0 -or [string]::IsNullOrEmpty($out)) {
    [Console]::Error.WriteLine("corp-ssh-askpass: gopass failed (rc=$rc) -- gpg-agent cache cold or store missing.")
    [Console]::Error.WriteLine("corp-ssh-askpass: Warm cache: gopass show -o $passPath/password >`$null")
    exit 1
}

# Bare LF, no BOM. Avoid Write-Output (adds CRLF on Windows; sshd rejects \r in password).
[Console]::Out.Write(($out -replace "[`r`n]+$", '') + "`n")
