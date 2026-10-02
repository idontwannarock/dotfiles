# corp-ssh-askpass.Tests.ps1 — Pester 5 tests for home/dot_local/bin/corp-ssh-askpass.ps1
#
# Black-box: invokes the helper as a child process with controlled $env:USERPROFILE,
# a mock bw serve (HttpListener on a free port, reached via CORP_SSH_BW_API), and
# various prompt strings. Asserts exit code, stdout, and stderr.

BeforeAll {
    $script:RepoRoot   = Split-Path -Parent $PSScriptRoot
    $script:HelperPath = Join-Path $RepoRoot 'home\dot_local\bin\corp-ssh-askpass.ps1'

    # Mock bw serve. Each test sets $Mock.Mode ('ok' | 'locked') and $Mock.Items.
    # The listener runs in its own runspace so the helper, a child process, can
    # call it while the test thread waits.
    $script:Mock = [hashtable]::Synchronized(@{ Mode = 'ok'; Items = @() })
    $tcp = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $tcp.Start(); $port = $tcp.LocalEndpoint.Port; $tcp.Stop()
    $script:MockUrl  = "http://localhost:$port"
    $script:Listener = [System.Net.HttpListener]::new()
    $Listener.Prefixes.Add("$MockUrl/")
    $Listener.Start()
    $script:Server = [powershell]::Create().AddScript({
        param($l, $m)
        while ($l.IsListening) {
            try { $ctx = $l.GetContext() } catch { break }
            $path = $ctx.Request.Url.AbsolutePath
            $body = if ($path -eq '/sync') { @{ success = $true } }
                elseif ($m.Mode -eq 'locked') { @{ success = $false; message = 'Vault is locked.' } }
                elseif ($path -eq '/list/object/items') { @{ success = $true; data = @{ object = 'list'; data = @($m.Items) } } }
                elseif ($path -like '/object/totp/*') {
                    $id = $path.Substring('/object/totp/'.Length)
                    $it = @($m.Items) | Where-Object { $_.id -eq $id } | Select-Object -First 1
                    if ($it) { @{ success = $true; data = @{ object = 'string'; data = $it.code } } } else { @{ success = $false } }
                } else { @{ success = $false } }
            $bytes = [System.Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Depth 6))
            $ctx.Response.ContentType = 'application/json'
            $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            $ctx.Response.Close()
        }
    }).AddArgument($Listener).AddArgument($Mock)
    $null = $Server.BeginInvoke()

    function New-Item-Fixture([string]$Id, [string]$Name, [string]$Password, [string]$Code) {
        @{ id = $Id; name = $Name; code = $Code; login = @{ password = $Password; totp = $(if ($Code) { 'otpauth://x' }) } }
    }

    function Invoke-Helper {
        param([string]$Prompt)
        # Run helper in a child PowerShell so $env:USERPROFILE/PATH overrides take effect.
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName               = (Get-Process -Id $PID).Path
        $psi.Arguments              = "-NoProfile -ExecutionPolicy Bypass -File `"$HelperPath`" `"$Prompt`""
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        # stdin MUST be redirected. Invoke-AskHuman treats a non-redirected stdin
        # as "a human is watching" and blocks on $Host.UI.ReadLine(); inheriting
        # the console would hang the suite instead of failing it.
        $psi.RedirectStandardInput   = $true
        $psi.UseShellExecute        = $false
        $psi.EnvironmentVariables['USERPROFILE']          = $env:USERPROFILE
        $psi.EnvironmentVariables['PATH']                 = $env:PATH
        $psi.EnvironmentVariables['CORP_SSH_BW_API']      = $env:CORP_SSH_BW_API
        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.StandardInput.Close()
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

AfterAll {
    $Listener.Stop()
    $Server.Dispose()
}

Describe 'corp-ssh-askpass.ps1' {

    BeforeEach {
        # Per-test sandbox under TEMP. Acts as $HOME for the helper.
        $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("corp-ssh-test-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $Sandbox -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $Sandbox '.corp-ssh') -Force | Out-Null

        $Mock.Mode  = 'ok'
        $Mock.Items = @(New-Item-Fixture 'id-corp' 'corp' 'secret-password' '123456')

        # Save and override env.
        $script:OrigUserprofile = $env:USERPROFILE
        $env:USERPROFILE        = $Sandbox
        $env:CORP_SSH_BW_API    = $MockUrl
    }

    AfterEach {
        $env:USERPROFILE     = $OrigUserprofile
        $env:CORP_SSH_BW_API = $null
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
            $r = Invoke-Helper -Prompt '(user@corp-host.example.com) Password:'
            $r.ExitCode | Should -Be 0
            $r.Stdout.TrimEnd("`r","`n") | Should -Be 'secret-password'
        }

        It 'returns OTP for known host with One-time Password prompt (substring trap)' {
            # Critical regression test: bash version's case-statement was wrong-order
            # in the original 2026-04-24 draft. "Password:" matches "One-time Password:"
            # as a substring; OTP branch must come first.
            $r = Invoke-Helper -Prompt '(user@corp-host.example.com) One-time Password:'
            $r.ExitCode | Should -Be 0
            $r.Stdout.TrimEnd("`r","`n") | Should -Be '123456'
        }

        It 'matches short-form hostname against FQDN-prefix allowlist entry' {
            $r = Invoke-Helper -Prompt '(user@other-short-host) Password:'
            $r.ExitCode | Should -Be 0
        }

        It 'parses double-@ prompt (user principal contains @)' {
            $r = Invoke-Helper -Prompt '(ad-user@realm@corp-host.example.com) Password:'
            $r.ExitCode | Should -Be 0
            $r.Stdout.TrimEnd("`r","`n") | Should -Be 'secret-password'
        }

        It 'parses builtin password-auth prompt shape (no parentheses, lowercase p)' {
            # Hosts answering with the `password` method rather than
            # keyboard-interactive produce a client-side prompt of the form
            # "user@host's password: ". The original regex required parens.
            $r = Invoke-Helper -Prompt "root@corp-host.example.com's password: "
            $r.ExitCode | Should -Be 0
            $r.Stdout.TrimEnd("`r","`n") | Should -Be 'secret-password'
        }

        It 'declines unknown host (exit 1, no stdout)' {
            $Mock.Items = @(New-Item-Fixture 'id-corp' 'corp' 'should-not-leak' '123456')
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

    Context 'host-key confirmation (Invoke-AskHuman)' {
        # SSH_ASKPASS_REQUIRE=force sends host-key confirmations here too. The
        # helper must not answer them itself: exit 1 reads as "no" and breaks
        # `ssh <any-new-host>` with "Host key verification failed."
        #
        # Only the no-human branch is automatable. The console branch needs a
        # real console and a keystroke; verify it by hand with
        #   ssh <some-new-host>
        # in a PowerShell window -- the yes/no prompt must appear.
        BeforeEach {
            Set-Content -Path (Join-Path $Sandbox '.corp-ssh\hosts.yaml') -Value @"
pass_path: corp

password_otp_hosts:
  - corp-host.example.com
"@ -Encoding ascii
        }

        It 'declines a host-key prompt when stdin is redirected (nobody to ask)' {
            $Mock.Items = @(New-Item-Fixture 'id-corp' 'corp' 'should-not-leak' '123456')
            $r = Invoke-Helper -Prompt "The authenticity of host 'new.example.com (1.2.3.4)' can't be established.`nAre you sure you want to continue connecting (yes/no/[fingerprint])? "
            $r.ExitCode | Should -Be 1
            $r.Stdout | Should -BeNullOrEmpty
        }

        It 'declines the truncated host-key prompt Windows actually receives' {
            # corp-ssh-askpass.cmd passes %* and cmd.exe cuts the argument at its
            # first newline, so this single line is all the helper ever sees.
            $Mock.Items = @(New-Item-Fixture 'id-corp' 'corp' 'should-not-leak' '123456')
            $r = Invoke-Helper -Prompt "The authenticity of host 'new.example.com (1.2.3.4)' can't be established."
            $r.ExitCode | Should -Be 1
            $r.Stdout | Should -BeNullOrEmpty
        }

        It 'never sends a corp credential to a host-key prompt' {
            # Guards the ordering: the prompt parses as neither shape, so it must
            # reach Invoke-AskHuman before any bw serve call.
            $Mock.Items = @(New-Item-Fixture 'id-corp' 'corp' 'should-not-leak' '123456')
            $r = Invoke-Helper -Prompt 'Are you sure you want to continue connecting (yes/no/[fingerprint])? '
            $r.Stdout | Should -Not -Match 'should-not-leak'
        }
    }

    Context 'password entry selection' {
        BeforeEach {
            Set-Content -Path (Join-Path $Sandbox '.corp-ssh\hosts.yaml') -Value @"
pass_path: corp

password_otp_hosts:
  - corp-host.example.com
  - db-host.example.com
  - dup-host.example.com
  - 10.0.0.5
  - 10.0.0.6
"@ -Encoding ascii
            $Mock.Items = @(
                (New-Item-Fixture 'id-corp' 'corp'                          'ad-secret'  '123456'),
                (New-Item-Fixture 'id-db'   'ssh-local/via-jump1/db-host'   'db-secret'  ''),
                (New-Item-Fixture 'id-db2'  'ssh-local/via-jump1/db-host-2' 'wrong'      ''),
                (New-Item-Fixture 'id-old'  'corp/hosts/corp-host'          'old-scheme' ''),
                (New-Item-Fixture 'id-dup1' 'ssh-local/via-jump1/dup-host'  'dup-1'      ''),
                (New-Item-Fixture 'id-dup2' 'ssh-local/via-jump2/dup-host'  'dup-2'      ''),
                (New-Item-Fixture 'id-ip'   'ssh-local/direct/10.0.0.5'     'ip-secret'  '')
            )
        }

        It 'uses the per-host item when the vault has one' {
            $r = Invoke-Helper -Prompt "root@db-host.example.com's password: "
            $r.ExitCode | Should -Be 0
            $r.Stdout.TrimEnd("`r","`n") | Should -Be 'db-secret'
        }

        It 'falls back to the shared item when no per-host item exists' {
            # Also proves the old "corp/hosts/<host>" name is no longer read.
            $r = Invoke-Helper -Prompt '(user@corp-host.example.com) Password:'
            $r.ExitCode | Should -Be 0
            $r.Stdout.TrimEnd("`r","`n") | Should -Be 'ad-secret'
        }

        It 'fails closed when two per-host items end in the same host' {
            $r = Invoke-Helper -Prompt "root@dup-host.example.com's password: "
            $r.ExitCode | Should -Be 1
            $r.Stdout | Should -BeNullOrEmpty
            $r.Stderr | Should -Match 'more than one item ends in /dup-host'
        }

        It 'keys an IP host on the whole address' {
            $r = Invoke-Helper -Prompt "root@10.0.0.5's password: "
            $r.ExitCode | Should -Be 0
            $r.Stdout.TrimEnd("`r","`n") | Should -Be 'ip-secret'
        }

        It 'does not give one IP host the per-host item of another' {
            # The first label of both addresses is "10".
            $r = Invoke-Helper -Prompt "root@10.0.0.6's password: "
            $r.ExitCode | Should -Be 0
            $r.Stdout.TrimEnd("`r","`n") | Should -Be 'ad-secret'
        }

        It 'fails closed when the vault is locked' {
            # Must NOT fall back to the shared item: that would send the AD
            # password to a host that has its own local account.
            $Mock.Mode = 'locked'
            $r = Invoke-Helper -Prompt "root@db-host.example.com's password: "
            $r.ExitCode | Should -Be 1
            $r.Stdout | Should -BeNullOrEmpty
            $r.Stderr | Should -Match 'bw serve not reachable or locked'
        }
    }

    Context 'bw serve failure' {
        BeforeEach {
            Set-Content -Path (Join-Path $Sandbox '.corp-ssh\hosts.yaml') -Value @"
pass_path: corp

password_otp_hosts:
  - corp-host.example.com
"@ -Encoding ascii
        }

        It 'emits diagnostic to stderr when bw serve is not running' {
            # Port 1 has no listener, so the request is refused.
            $env:CORP_SSH_BW_API = 'http://localhost:1'
            $r = Invoke-Helper -Prompt '(user@corp-host.example.com) Password:'
            $r.ExitCode | Should -Be 1
            $r.Stdout | Should -BeNullOrEmpty
            $r.Stderr | Should -Match 'bw serve not reachable or locked'
            $r.Stderr | Should -Match 'Start-ScheduledTask -TaskName bw-serve-unlock'
        }

        It 'emits diagnostic to stderr when the shared item is missing' {
            $Mock.Items = @()
            $r = Invoke-Helper -Prompt '(user@corp-host.example.com) One-time Password:'
            $r.ExitCode | Should -Be 1
            $r.Stderr | Should -Match 'no Bitwarden item named corp'
        }
    }
}
