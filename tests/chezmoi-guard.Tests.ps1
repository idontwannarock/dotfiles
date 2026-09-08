# chezmoi-guard.Tests.ps1 — Pester 5 tests for
# home/Documents/exact__shared-profile.d/96-chezmoi-guard.ps1
#
# Black-box: dot-sources the profile fragment in a child PowerShell whose PATH is
# headed by a mock chezmoi.cmd, then asserts on stderr and exit code. A child
# process is required because the fragment defines a function named `chezmoi`,
# which would otherwise shadow the real binary for the rest of the test session.

BeforeAll {
    $script:RepoRoot     = Split-Path -Parent $PSScriptRoot
    $script:FragmentPath = Join-Path $RepoRoot 'home\Documents\exact__shared-profile.d\96-chezmoi-guard.ps1'

    # Mock chezmoi: exits with %MOCK_CHEZMOI_RC% for every subcommand except
    # `status`, which prints a fixed 3-line listing so the pending count in the
    # warning is deterministic. %MOCK_STATUS_RC% makes `status` itself fail --
    # the case the guard used to report as "0 pending", and the reason the two
    # codes are separate knobs rather than one.
    $script:MockDir = Join-Path ([IO.Path]::GetTempPath()) ("chezmoi-guard-" + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $MockDir -Force | Out-Null
    @'
@echo off
rem Flat, deliberately: `exit /b N` nested inside a parenthesised if-block
rem returns 0, not N. Measured -- the same logic written with the block yields
rem 0 for every code, which read here as "status succeeded with no output" and
rem made the new failed-status case assert against the wrong branch.
rem Argument echo for the --init injection tests. Two flat lines for the same
rem reason the rest of this file is flat: `exit /b N` inside a parenthesised
rem if-block returns 0.
if "%MOCK_ECHO_ARGS%"=="1" echo ARGS:%*
if "%MOCK_ECHO_ARGS%"=="1" exit /b 0
if not "%1"=="status" exit /b %MOCK_CHEZMOI_RC%
if not "%MOCK_STATUS_RC%"=="0" exit /b %MOCK_STATUS_RC%
if "%MOCK_STATUS_EMPTY%"=="1" exit /b 0
echo  M .one
echo  M .two
echo  M .three
exit /b 0
'@ | Set-Content -Path (Join-Path $MockDir 'chezmoi.cmd') -Encoding ascii

    function Invoke-Guard {
        param([string]$Arguments, [int]$Rc, [string]$Path = '', [int]$StatusRc = 0, [int]$StatusEmpty = 0, [int]$EchoArgs = 0)
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName               = (Get-Process -Id $PID).Path
        $psi.Arguments              = "-NoProfile -ExecutionPolicy Bypass -Command `". '$FragmentPath'; chezmoi $Arguments; exit `$LASTEXITCODE`""
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.UseShellExecute        = $false
        $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
        $psi.StandardErrorEncoding  = [Text.Encoding]::UTF8
        # Load-bearing: cmd.exe refuses a UNC working directory, so the mock
        # chezmoi.cmd misbehaves if the tests are launched from \\wsl.localhost\...
        $psi.WorkingDirectory       = $MockDir
        $psi.EnvironmentVariables['PATH']             = if ($Path) { $Path } else { "$MockDir;$env:PATH" }
        $psi.EnvironmentVariables['MOCK_CHEZMOI_RC']  = "$Rc"
        $psi.EnvironmentVariables['MOCK_STATUS_RC']   = "$StatusRc"
        $psi.EnvironmentVariables['MOCK_STATUS_EMPTY'] = "$StatusEmpty"
        $psi.EnvironmentVariables['MOCK_ECHO_ARGS']   = "$EchoArgs"
        $proc   = [System.Diagnostics.Process]::Start($psi)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
        return [pscustomobject]@{ ExitCode = $proc.ExitCode; Stdout = $stdout; Stderr = $stderr }
    }
}

AfterAll {
    if ($script:MockDir -and (Test-Path $script:MockDir)) {
        Remove-Item $script:MockDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe '96-chezmoi-guard.ps1' {

    Context 'apply / update failure' {
        It 'warns that later targets were not deployed' {
            $r = Invoke-Guard -Arguments 'apply' -Rc 1
            $r.Stderr | Should -Match 'apply .* \(exit 1\)'
            $r.Stderr | Should -Match 'target'
        }

        It 'reports the pending item count from chezmoi status' {
            $r = Invoke-Guard -Arguments 'apply' -Rc 1
            $r.Stderr | Should -Match '3'
        }

        # Regression: whatever aborts the apply usually aborts `status` too, and
        # an empty result was counted as zero -- so the guard announced
        # "0 pending" at the one moment it exists to raise an alarm. Assert the
        # message, not merely that something was printed: a count and a
        # can't-tell read identically to a test that only checks for output.
        It 'says the count is unknown when status fails too' {
            $r = Invoke-Guard -Arguments 'apply' -Rc 1 -StatusRc 4
            $r.Stderr | Should -Match 'exit 4'
            $r.Stderr | Should -Not -Match '0 筆待處理'
        }

        It 'still reports a genuine zero as zero' {
            $r = Invoke-Guard -Arguments 'apply' -Rc 1 -StatusEmpty 1
            $r.Stderr | Should -Match '0 筆待處理'
        }

        It 'covers update as well as apply' {
            $r = Invoke-Guard -Arguments 'update' -Rc 2
            $r.Stderr | Should -Match 'update .* \(exit 2\)'
        }

        It 'preserves the exit code' {
            (Invoke-Guard -Arguments 'apply' -Rc 3).ExitCode | Should -Be 3
        }

        It 'still fires when the subcommand follows a long global flag' {
            $r = Invoke-Guard -Arguments '--verbose apply' -Rc 1
            $r.Stderr | Should -Match 'apply .* \(exit 1\)'
        }

        # Regression: [CmdletBinding()] would bind -v to -Verbose and swallow it,
        # so the subcommand never reached the wrapper (and never reached chezmoi).
        It 'passes chezmoi short flags through untouched' {
            $r = Invoke-Guard -Arguments '-v apply' -Rc 1
            $r.Stderr | Should -Match 'apply .* \(exit 1\)'
        }

        It 'writes the warning to stderr, not stdout' {
            $r = Invoke-Guard -Arguments 'apply' -Rc 1
            $r.Stdout | Should -Not -Match '中止'
        }
    }

    Context 'paths that must stay silent' {
        It 'prints nothing extra when apply succeeds' {
            $r = Invoke-Guard -Arguments 'apply' -Rc 0
            $r.Stderr | Should -Not -Match 'exit'
            $r.ExitCode | Should -Be 0
        }

        # 127 is the command-not-found convention, matching 26-glab.ps1.
        It 'reports 127 when no chezmoi binary is on PATH' {
            $r = Invoke-Guard -Arguments 'apply' -Rc 1 -Path 'C:\Windows\System32'
            $r.Stderr | Should -Match 'chezmoi: binary not on PATH'
            $r.ExitCode | Should -Be 127
        }

        It 'ignores failures from other subcommands' {
            $r = Invoke-Guard -Arguments 'cat' -Rc 1
            $r.Stderr | Should -Not -Match 'exit 1'
            $r.ExitCode | Should -Be 1
        }
    }

    # chezmoi reads no `init` key in the [update] config section, so without this
    # injection the generated config goes stale whenever .chezmoi.toml.tmpl gains
    # a key and chezmoi only warns. Mirrors the bash half in
    # .chezmoitemplates/shell-common/base.
    Context '--init injection for update' {
        It 'adds --init to a bare update' {
            $r = Invoke-Guard -Arguments 'update' -Rc 0 -EchoArgs 1
            $r.Stdout | Should -Match 'ARGS:update --init'
        }

        It 'keeps the caller flags and still adds --init' {
            $r = Invoke-Guard -Arguments 'update --dry-run' -Rc 0 -EchoArgs 1
            $r.Stdout | Should -Match 'ARGS:update --dry-run --init'
        }

        It 'does not double --init when the caller already passed it' {
            $r = Invoke-Guard -Arguments 'update --init' -Rc 0 -EchoArgs 1
            $r.Stdout | Should -Match 'ARGS:update --init'
            $r.Stdout | Should -Not -Match '--init --init'
        }

        It 'leaves apply alone' {
            $r = Invoke-Guard -Arguments 'apply' -Rc 0 -EchoArgs 1
            $r.Stdout | Should -Match 'ARGS:apply'
            $r.Stdout | Should -Not -Match '--init'
        }

        # Only $1 is inspected. The failure warning above scans every argument
        # for the word "update", which would hand this command a flag it rejects.
        It 'leaves a target that happens to be named update alone' {
            $r = Invoke-Guard -Arguments 'add update' -Rc 0 -EchoArgs 1
            $r.Stdout | Should -Match 'ARGS:add update'
            $r.Stdout | Should -Not -Match '--init'
        }
    }
}
