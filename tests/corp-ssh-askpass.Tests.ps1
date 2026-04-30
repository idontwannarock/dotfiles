# corp-ssh-askpass.Tests.ps1 — Pester 5 tests for dot_local/bin/corp-ssh-askpass.ps1
#
# Black-box: invokes the helper as a child process with controlled $env:USERPROFILE,
# a mock gopass.cmd on PATH, and various prompt strings. Asserts exit code,
# stdout, and stderr.

BeforeAll {
    $script:RepoRoot   = Split-Path -Parent $PSScriptRoot
    $script:HelperPath = Join-Path $RepoRoot 'dot_local\bin\corp-ssh-askpass.ps1'

    function Invoke-Helper {
        param([string]$Prompt)
        # Run helper in a child PowerShell so $env:USERPROFILE/PATH overrides take effect.
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName               = (Get-Process -Id $PID).Path
        $psi.Arguments              = "-NoProfile -ExecutionPolicy Bypass -File `"$HelperPath`" `"$Prompt`""
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.UseShellExecute        = $false
        $psi.EnvironmentVariables['USERPROFILE']          = $env:USERPROFILE
        $psi.EnvironmentVariables['PATH']                 = $env:PATH
        if ($env:MOCK_GOPASS_PASSWORD) { $psi.EnvironmentVariables['MOCK_GOPASS_PASSWORD'] = $env:MOCK_GOPASS_PASSWORD }
        if ($env:MOCK_GOPASS_OTP)      { $psi.EnvironmentVariables['MOCK_GOPASS_OTP']      = $env:MOCK_GOPASS_OTP }
        if ($env:MOCK_GOPASS_RC)       { $psi.EnvironmentVariables['MOCK_GOPASS_RC']       = $env:MOCK_GOPASS_RC }
        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
        return [pscustomobject]@{
            ExitCode = $proc.ExitCode
            Stdout   = $stdout
            Stderr   = $stderr
        }
    }
}

Describe 'corp-ssh-askpass.ps1' {

    BeforeEach {
        # Per-test sandbox under TEMP. Acts as $HOME for the helper.
        $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("corp-ssh-test-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $Sandbox -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $Sandbox '.corp-ssh') -Force | Out-Null

        # Mock gopass.cmd lives in $Sandbox\bin and prepends to PATH.
        # Behaviour controlled by $env:MOCK_GOPASS_PASSWORD / MOCK_GOPASS_OTP / MOCK_GOPASS_RC.
        $script:MockBin = Join-Path $Sandbox 'bin'
        New-Item -ItemType Directory -Path $MockBin -Force | Out-Null
        $mockGopass = @'
@echo off
if "%1"=="otp" (
  if defined MOCK_GOPASS_OTP echo %MOCK_GOPASS_OTP%
) else (
  if defined MOCK_GOPASS_PASSWORD echo %MOCK_GOPASS_PASSWORD%
)
if defined MOCK_GOPASS_RC exit /b %MOCK_GOPASS_RC%
exit /b 0
'@
        Set-Content -Path (Join-Path $MockBin 'gopass.cmd') -Value $mockGopass -Encoding ascii

        # Save and override env.
        $script:OrigUserprofile = $env:USERPROFILE
        $script:OrigPath        = $env:PATH
        $env:USERPROFILE        = $Sandbox
        $env:PATH               = "$MockBin;$env:PATH"
    }

    AfterEach {
        $env:USERPROFILE          = $OrigUserprofile
        $env:PATH                 = $OrigPath
        $env:MOCK_GOPASS_PASSWORD = $null
        $env:MOCK_GOPASS_OTP      = $null
        $env:MOCK_GOPASS_RC       = $null
        Remove-Item -Path $Sandbox -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'allowlist + prompt parsing' {
        BeforeEach {
            Set-Content -Path (Join-Path $Sandbox '.corp-ssh\hosts.yaml') -Value @"
pass_path: corp

password_otp_hosts:
  - corp-host.example.com
  - other-short-host
"@ -Encoding ascii
        }

        It 'returns password for known FQDN host with standard prompt' {
            $env:MOCK_GOPASS_PASSWORD = 'secret-password'
            $r = Invoke-Helper -Prompt '(user@corp-host.example.com) Password:'
            $r.ExitCode | Should -Be 0
            $r.Stdout.TrimEnd("`r","`n") | Should -Be 'secret-password'
        }

        It 'returns OTP for known host with One-time Password prompt (substring trap)' {
            # Critical regression test: bash version's case-statement was wrong-order
            # in the original 2026-04-24 draft. "Password:" matches "One-time Password:"
            # as a substring; OTP branch must come first.
            $env:MOCK_GOPASS_OTP = '123456'
            $r = Invoke-Helper -Prompt '(user@corp-host.example.com) One-time Password:'
            $r.ExitCode | Should -Be 0
            $r.Stdout.TrimEnd("`r","`n") | Should -Be '123456'
        }

        It 'matches short-form hostname against FQDN-prefix allowlist entry' {
            $env:MOCK_GOPASS_PASSWORD = 'secret-password'
            $r = Invoke-Helper -Prompt '(user@other-short-host) Password:'
            $r.ExitCode | Should -Be 0
        }

        It 'parses double-@ prompt (user principal contains @)' {
            $env:MOCK_GOPASS_PASSWORD = 'secret-password'
            $r = Invoke-Helper -Prompt '(ad-user@realm@corp-host.example.com) Password:'
            $r.ExitCode | Should -Be 0
            $r.Stdout.TrimEnd("`r","`n") | Should -Be 'secret-password'
        }

        It 'declines unknown host (exit 1, no stdout)' {
            $env:MOCK_GOPASS_PASSWORD = 'should-not-leak'
            $r = Invoke-Helper -Prompt '(user@some-other-host.example.com) Password:'
            $r.ExitCode | Should -Be 1
            $r.Stdout | Should -BeNullOrEmpty
        }

        It 'declines on malformed prompt' {
            $r = Invoke-Helper -Prompt 'not a valid prompt'
            $r.ExitCode | Should -Be 1
        }

        It 'declines when hosts.yaml is missing' {
            Remove-Item -Path (Join-Path $Sandbox '.corp-ssh\hosts.yaml') -Force
            $r = Invoke-Helper -Prompt '(user@corp-host.example.com) Password:'
            $r.ExitCode | Should -Be 1
        }
    }

    Context 'gopass failure' {
        BeforeEach {
            Set-Content -Path (Join-Path $Sandbox '.corp-ssh\hosts.yaml') -Value @"
pass_path: corp

password_otp_hosts:
  - corp-host.example.com
"@ -Encoding ascii
        }

        It 'emits diagnostic to stderr when gopass returns non-zero' {
            $env:MOCK_GOPASS_RC = '2'
            $r = Invoke-Helper -Prompt '(user@corp-host.example.com) Password:'
            $r.ExitCode | Should -Be 1
            $r.Stderr | Should -Match 'corp-ssh-askpass: gopass failed'
            $r.Stderr | Should -Match 'Warm cache'
        }

        It 'emits diagnostic to stderr when gopass returns empty stdout' {
            # MOCK_GOPASS_OUTPUT unset → echo skipped → empty stdout, rc=0
            $env:MOCK_GOPASS_RC = $null
            $r = Invoke-Helper -Prompt '(user@corp-host.example.com) Password:'
            $r.ExitCode | Should -Be 1
            $r.Stderr | Should -Match 'corp-ssh-askpass: gopass failed'
        }
    }
}
