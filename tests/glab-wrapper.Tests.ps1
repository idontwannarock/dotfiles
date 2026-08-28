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
# The mock gopass returns $env:MOCK_GOPASS_TOKEN when set and fails otherwise, so
# the real vault (and its pinentry prompt) never enters the test. Giving the vault
# and the environment different token values is what makes the snapshot/restore
# assertion meaningful.

BeforeAll {
    $script:RepoRoot     = Split-Path -Parent $PSScriptRoot
    $script:FragmentPath = Join-Path $RepoRoot 'home\Documents\exact__shared-profile.d\26-glab.ps1'

    $script:MockDir = Join-Path ([IO.Path]::GetTempPath()) ("glab-wrapper-" + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $MockDir -Force | Out-Null

    # Config-store fixtures for the token-in-config guard. `token:` with no value is
    # what glab leaves behind for a host it has never authenticated, and the comment
    # lines are verbatim from glab's own generated config -- both must pass.
    $script:EmptyConfigDir = Join-Path $MockDir 'cfg-empty-dir'
    New-Item -ItemType Directory -Path $EmptyConfigDir -Force | Out-Null

    $script:TokenConfigDir = Join-Path $MockDir 'cfg-token'
    New-Item -ItemType Directory -Path $TokenConfigDir -Force | Out-Null
    "hosts:`n    gitlab.example.com:`n        token: glpat-PLAINTEXT`n" |
        Set-Content -Path (Join-Path $TokenConfigDir 'config.yml') -Encoding utf8

    $script:BlankConfigDir = Join-Path $MockDir 'cfg-blank'
    New-Item -ItemType Directory -Path $BlankConfigDir -Force | Out-Null
    "hosts:`n    gitlab.example.com:`n        token:`n        job_token:`n" |
        Set-Content -Path (Join-Path $BlankConfigDir 'config.yml') -Encoding utf8

    $script:CommentConfigDir = Join-Path $MockDir 'cfg-comment'
    New-Item -ItemType Directory -Path $CommentConfigDir -Force | Out-Null
    "        # Your GitLab access token. To get one, read https://example`n        #   value: Bearer token123`n        token:`n" |
        Set-Content -Path (Join-Path $CommentConfigDir 'config.yml') -Encoding utf8

    $script:JobTokenConfigDir = Join-Path $MockDir 'cfg-jobtoken'
    New-Item -ItemType Directory -Path $JobTokenConfigDir -Force | Out-Null
    "hosts:`n    gitlab.example.com:`n        job_token:  ci-job-token`n" |
        Set-Content -Path (Join-Path $JobTokenConfigDir 'config.yml') -Encoding utf8

    # Echoes one line per argument so the test can assert on argv boundaries and
    # order, which `echo %*` would flatten away.
    @'
@echo off
echo TOKEN:%GITLAB_TOKEN%
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
if not "%MOCK_GOPASS_TOKEN%"=="" (
  echo %MOCK_GOPASS_TOKEN%
  exit /b 0
)
exit /b 1
'@ | Set-Content -Path (Join-Path $MockDir 'gopass.cmd') -Encoding ascii

    function Invoke-Glab {
        param(
            [string]$Arguments,
            [string]$GitlabHost = 'gitlab.example.com',
            [string]$Token = 'faketoken',
            [string]$VaultToken = '',
            [string]$Path = '',
            [string]$Trailer = '',
            [string]$ConfigDir = ''
        )
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName               = (Get-Process -Id $PID).Path
        # Single quotes only inside this string: it becomes a Windows command line,
        # whose parser strips double quotes before PowerShell ever sees them.
        $psi.Arguments              = "-NoProfile -ExecutionPolicy Bypass -Command `". '$FragmentPath'; glab $Arguments; $Trailer exit `$LASTEXITCODE`""
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.UseShellExecute        = $false
        $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
        $psi.StandardErrorEncoding  = [Text.Encoding]::UTF8
        # cmd.exe refuses a UNC working directory, which would break the mocks when
        # the suite is launched from \\wsl.localhost\...
        $psi.WorkingDirectory       = $MockDir
        $psi.EnvironmentVariables['PATH'] = if ($Path) { $Path } else { "$MockDir;$env:PATH" }
        if ($VaultToken) { $psi.EnvironmentVariables['MOCK_GOPASS_TOKEN'] = $VaultToken }
        else { $psi.EnvironmentVariables.Remove('MOCK_GOPASS_TOKEN') | Out-Null }
        if ($GitlabHost) { $psi.EnvironmentVariables['GITLAB_HOST'] = $GitlabHost }
        else { $psi.EnvironmentVariables.Remove('GITLAB_HOST') | Out-Null }
        if ($Token) { $psi.EnvironmentVariables['GITLAB_TOKEN'] = $Token }
        else { $psi.EnvironmentVariables.Remove('GITLAB_TOKEN') | Out-Null }
        # Pinned on every call, never inherited: the config-store guard reads this
        # path, and an unpinned run would consult the developer's real glab config
        # and fail (or pass) for reasons that have nothing to do with the test.
        $psi.EnvironmentVariables['GLAB_CONFIG_DIR'] = if ($ConfigDir) { $ConfigDir } else { $EmptyConfigDir }
        $proc   = [System.Diagnostics.Process]::Start($psi)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
        return [pscustomobject]@{
            ExitCode = $proc.ExitCode
            Stdout   = $stdout
            Stderr   = $stderr
            Argv     = @($stdout -split "`r?`n" | Where-Object { $_ -like 'ARG:*' } | ForEach-Object { $_.Substring(4) })
            SeenToken = @($stdout -split "`r?`n" | Where-Object { $_ -like 'TOKEN:*' } | ForEach-Object { $_.Substring(6) }) | Select-Object -First 1
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

        # The spec scenario is `glab mr create -d "描述"`. The CJK half is not
        # observable through cmd.exe, but the quoted-value-with-spaces half is,
        # and that is the part a splatting bug would break.
        It 'keeps a quoted value containing spaces as one argument' {
            $r = Invoke-Glab -Arguments "mr create -d 'two words'"
            $r.Argv | Should -Be @('mr', 'create', '-d', 'two words')
        }
    }

    Context 'token resolution and restoration' {
        It 'prefers the vault over GITLAB_TOKEN' {
            $r = Invoke-Glab -Arguments 'api version' -VaultToken 'vault-token' -Token 'env-token'
            $r.SeenToken | Should -Be 'vault-token'
        }

        It 'falls back to GITLAB_TOKEN when the vault fails' {
            $r = Invoke-Glab -Arguments 'api version' -Token 'env-token'
            $r.SeenToken | Should -Be 'env-token'
        }

        # The try/finally exists solely for this: PowerShell $env: assignments leak
        # to process scope, so a vault token must not outlive the call.
        It 'restores the caller GITLAB_TOKEN after the call' {
            $r = Invoke-Glab -Arguments 'api version' -VaultToken 'vault-token' -Token 'env-token' `
                             -Trailer "Write-Output ('AFTER:' + `$env:GITLAB_TOKEN);"
            $r.SeenToken | Should -Be 'vault-token'
            $r.Stdout | Should -Match 'AFTER:env-token'
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

        # 127 is the command-not-found convention, matching 96-chezmoi-guard.ps1.
        It 'reports 127 when no glab binary is on PATH' {
            $r = Invoke-Glab -Arguments 'api version' -Path 'C:\Windows\System32'
            $r.Stderr | Should -Match '^glab: binary not on PATH'
            $r.ExitCode | Should -Be 127
        }

        # The leak this guard exists for: `glab auth login` bypasses the wrapper and
        # writes the token as plaintext YAML that survives forever. Found by hand on
        # 2026-08-28, which is exactly the discovery path this replaces.
        It 'refuses when the config store holds a plaintext token' {
            $r = Invoke-Glab -Arguments 'api version' -ConfigDir $TokenConfigDir
            $r.Stderr | Should -Match '^glab: config store'
            $r.Stderr | Should -Not -Match 'glab: glab:'
            $r.ExitCode | Should -Be 1
            $r.Argv.Count | Should -Be 0
        }

        # ASCII-only assertions on purpose. The child runs with -NoProfile, so
        # 00-encoding.ps1 never sets the console to UTF-8 and the CJK half of the
        # message arrives mojibake -- which the file header already states is out of
        # the mirror guarantee. Asserting on it would test the console, not the guard.
        It 'names the offending file and the clearing command in the message' {
            $r = Invoke-Glab -Arguments 'api version' -ConfigDir $TokenConfigDir
            $r.Stderr | Should -Match ([regex]::Escape((Join-Path $TokenConfigDir 'config.yml')))
            $r.Stderr | Should -Match 'glab config set token "" --host'
            $r.Stderr | Should -Match 'docs/gitlab-corp-access.md'
        }

        # job_token is a credential too, and `^token:` does not match it.
        It 'refuses on a plaintext job_token as well' {
            $r = Invoke-Glab -Arguments 'api version' -ConfigDir $JobTokenConfigDir
            $r.ExitCode | Should -Be 1
            $r.Argv.Count | Should -Be 0
        }

        # A guard that fires on the empty key glab leaves for unauthenticated hosts
        # would block every call, so this is the case that decides whether it ships.
        It 'allows a config store whose token key has no value' {
            $r = Invoke-Glab -Arguments 'api version' -ConfigDir $BlankConfigDir
            $r.Argv | Should -Be @('api', 'version')
            $r.ExitCode | Should -Be 0
        }

        It 'does not mistake glab own comment lines for a token' {
            $r = Invoke-Glab -Arguments 'api version' -ConfigDir $CommentConfigDir
            $r.Argv | Should -Be @('api', 'version')
            $r.ExitCode | Should -Be 0
        }

        It 'allows a config store that does not exist' {
            $r = Invoke-Glab -Arguments 'api version' -ConfigDir $EmptyConfigDir
            $r.Argv | Should -Be @('api', 'version')
            $r.ExitCode | Should -Be 0
        }

        It 'writes guard messages to stderr and not to stdout' {
            $r = Invoke-Glab -Arguments 'api version' -GitlabHost ''
            $r.Stderr.Trim() | Should -Not -BeNullOrEmpty
            $r.Stdout | Should -Not -Match 'GITLAB_HOST'
        }
    }
}
