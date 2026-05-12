# 30-ssh-askpass.ps1 — Wire ssh.exe to corp-ssh-askpass helper for password+OTP hosts.
#
# When the helper exists, point SSH_ASKPASS at the .cmd shim and set
# SSH_ASKPASS_REQUIRE=force so ssh.exe uses the helper instead of TTY-prompting.
# Helper declines (exit 1) for unknown prompts, so non-corp ssh is unaffected.
#
# Mirror of .chezmoitemplates/shell-common/linux's SSH_ASKPASS block.
# Note: no GPG_TTY equivalent — Windows pinentry is GUI-based (pinentry-basic.exe
# from Scoop's gpg package).
#
# Constraint (same as Linux): SSH keys with passphrases must be unencrypted,
# or override per-session: $env:SSH_ASKPASS_REQUIRE='never'.

$askpassCmd = Join-Path $env:USERPROFILE '.local\bin\corp-ssh-askpass.cmd'
if (Test-Path -LiteralPath $askpassCmd) {
    $env:SSH_ASKPASS = $askpassCmd
    $env:SSH_ASKPASS_REQUIRE = 'force'
}
