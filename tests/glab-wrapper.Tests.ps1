# glab-wrapper.Tests.ps1 — Pester 5 tests for
# home/Documents/exact__shared-profile.d/26-glab.ps1
#
# Black-box: dot-sources the profile fragment in a child PowerShell whose PATH is
# headed by a mock glab.cmd (echoes the argv it received) and a mock gopass.cmd,
# then asserts on that argv, on stderr, and on the exit code. A child process is
# required because the fragment defines a function named `glab`, which would
# otherwise shadow the real binary for the rest of the test session — and because
# the guard paths must run with GITLAB_HOST / GITLAB_TOKEN controlled.
#
# The mock gopass always fails, so the token comes from $env:GITLAB_TOKEN. That
# keeps the real vault (and its pinentry prompt) out of the test entirely.

BeforeAll {
    $script:RepoRoot     = Split-Path -Parent $PSScriptRoot
    $script:FragmentPath = Join-Path $RepoRoot 'home\Documents\exact__shared-profile.d\26-glab.ps1'

    $script:MockDir = Join-Path ([IO.Path]::GetTempPath()) ("glab-wrapper-" + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $MockDir -Force | Out-Null

    # Echoes one line per argument so the test can assert on argv boundaries and
    # order, which `echo %*` would flatten away.
    @'
@echo off
:loop
if "%~1"=="" goto end
echo ARG:%~1
shift
goto loop
:end
exit /b 0
'@ | Set-Content -Path (Join-Path $MockDir 'glab.cmd') -Encoding ascii

    @'
@echo off
exit /b 1
'@ | Set-Content -Path (Join-Path $MockDir 'gopass.cmd') -Encoding ascii

    function Invoke-Glab {
        param([string]$Arguments, [string]$GitlabHost = 'gitlab.example.com', [string]$Token = 'faketoken')
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName               = (Get-Process -Id $PID).Path
        $psi.Arguments              = "-NoProfile -ExecutionPolicy Bypass -Command `". '$FragmentPath'; glab $Arguments; exit `$LASTEXITCODE`""
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.UseShellExecute        = $false
        $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
        $psi.StandardErrorEncoding  = [Text.Encoding]::UTF8
        # cmd.exe refuses a UNC working directory, which would break the mocks when
        # the suite is launched from \\wsl.localhost\...
        $psi.WorkingDirectory       = $MockDir
        $psi.EnvironmentVariables['PATH'] = "$MockDir;$env:PATH"
        if ($GitlabHost) { $psi.EnvironmentVariables['GITLAB_HOST'] = $GitlabHost }
        else { $psi.EnvironmentVariables.Remove('GITLAB_HOST') | Out-Null }
        if ($Token) { $psi.EnvironmentVariables['GITLAB_TOKEN'] = $Token }
        else { $psi.EnvironmentVariables.Remove('GITLAB_TOKEN') | Out-Null }
        $proc   = [System.Diagnostics.Process]::Start($psi)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
        return [pscustomobject]@{
            ExitCode = $proc.ExitCode
            Stdout   = $stdout
            Stderr   = $stderr
            Argv     = @($stdout -split "`r?`n" | Where-Object { $_ -like 'ARG:*' } | ForEach-Object { $_.Substring(4) })
        }
    }
}

AfterAll {
    if ($script:MockDir -and (Test-Path $script:MockDir)) {
        Remove-Item $script:MockDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe '26-glab.ps1' {

    Context 'argument pass-through' {
        # Regression: [CmdletBinding()] bound -d to -Debug and dropped it, so glab
        # received `mr create desc` and read the description as a positional arg.
        It 'passes -d through instead of binding it to -Debug' {
            $r = Invoke-Glab -Arguments 'mr create -d desc'
            $r.Argv | Should -Be @('mr', 'create', '-d', 'desc')
        }

        # Regression: -R failed to bind at all, so the command never ran.
        It 'passes -R through without a binding error' {
            $r = Invoke-Glab -Arguments 'mr list -R owner/repo'
            $r.Argv | Should -Be @('mr', 'list', '-R', 'owner/repo')
            $r.ExitCode | Should -Be 0
        }

        # No `=` in the arguments here: cmd.exe treats it as a token separator, so
        # the batch mock reports `key=value` as two arguments no matter who passed
        # it (verified by calling the mock directly). That is the mock's limit, not
        # the wrapper's — keep the assertion on something the mock can observe.
        It 'preserves argument order for flags that never collided' {
            $r = Invoke-Glab -Arguments 'api projects/1 -X GET'
            $r.Argv | Should -Be @('api', 'projects/1', '-X', 'GET')
        }
    }

    Context 'guard paths' {
        It 'refuses without GITLAB_HOST, prefixing the message exactly once' {
            $r = Invoke-Glab -Arguments 'api version' -GitlabHost ''
            $r.Stderr | Should -Match '^glab: GITLAB_HOST'
            $r.Stderr | Should -Not -Match 'glab: glab:'
            $r.ExitCode | Should -Be 1
            $r.Argv.Count | Should -Be 0
        }

        It 'refuses when neither the vault nor GITLAB_TOKEN yields a token' {
            $r = Invoke-Glab -Arguments 'api version' -Token ''
            $r.Stderr | Should -Match '^glab: no token'
            $r.Stderr | Should -Not -Match 'glab: glab:'
            $r.ExitCode | Should -Be 1
            $r.Argv.Count | Should -Be 0
        }

        It 'writes guard messages to stderr, not stdout' {
            $r = Invoke-Glab -Arguments 'api version' -GitlabHost ''
            $r.Stdout | Should -Not -Match 'GITLAB_HOST'
        }
    }
}
