# Corp SSH Phase 2 (Windows Native) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the Phase 1 (WSL/Linux) corp-ssh password+OTP automation to Windows native PowerShell + ssh.exe + Gpg4win + gopass, so corp ssh works zero-input from Windows the same way it does from WSL, sharing the same GPG key + `~/.password-store/`.

**Architecture:** Layer 1 ControlMaster (best-effort on Win32-OpenSSH 9.5p2 named pipe) + Layer 2 SSH_ASKPASS via `corp-ssh-askpass.ps1` (PowerShell port of the bash helper) wrapped in a `.cmd` shim so `ssh.exe`'s `CreateProcess(SSH_ASKPASS)` can launch it. PowerShell profile fragment exports `SSH_ASKPASS`/`SSH_ASKPASS_REQUIRE` per-shell. Vault and key are imported once from WSL via `\\wsl$\` UNC path; subsequent rotation is manual dual-write.

**Tech Stack:** PowerShell 5.1 + 7, chezmoi templates, Win32-OpenSSH 9.5p2, Scoop (`gpg`, `gopass`), Pester 5 (test framework), Markdown.

**Spec:** [`../specs/2026-04-30-corp-ssh-windows-phase2-design.md`](../specs/2026-04-30-corp-ssh-windows-phase2-design.md)

**Commit policy:** Per project CLAUDE.md, do NOT auto-commit between tasks. Stage all changes; the final task assembles a single commit only when the user explicitly approves.

---

## File Structure

| Path | Action | Responsibility |
|---|---|---|
| `tests/corp-ssh-askpass.Tests.ps1` | Create | Pester 5 tests for the helper (regex parsing, allowlist, OTP-first ordering, error path) |
| `dot_local/bin/corp-ssh-askpass.ps1` | Create | PowerShell helper invoked indirectly by `ssh.exe` via SSH_ASKPASS |
| `dot_local/bin/corp-ssh-askpass.cmd` | Create | 8-line `.cmd` shim that `SSH_ASKPASS` actually points at |
| `Documents/exact__shared-profile.d/30-ssh-askpass.ps1` | Create | Profile fragment exporting `SSH_ASKPASS`/`SSH_ASKPASS_REQUIRE` |
| `.chezmoiignore.tmpl` | Modify | Per-platform exclusions for the three new files |
| `run_once_install-cli-tools.ps1.tmpl` | Modify | Append Scoop install for `gpg` + `gopass` |
| `docs/corp-ssh-setup.md` | Modify | Cross-reference link to Windows guide; remove "WSL/Ubuntu only" caveat |
| `docs/superpowers/specs/2026-04-24-corp-ssh-redesign.md` | Modify | Future Work bullet links to Phase 2 spec |
| `docs/corp-ssh-setup-windows.md` | Create | Windows setup guide (~250 lines) modelled on Linux version |

---

### Task 1: Pester Test Scaffold

**Files:**
- Create: `tests/corp-ssh-askpass.Tests.ps1`

This task writes the test file FIRST (TDD red phase). Tests will fail because the helper doesn't exist yet. Task 2 implements the helper to make these tests pass.

The tests are black-box: they invoke the `.ps1` as a child process with controlled `$env:USERPROFILE`, a mock `gopass.cmd` on PATH, and various prompt strings. We assert exit code, stdout, and stderr.

- [ ] **Step 1: Verify Pester 5 is available**

Run:
```powershell
Get-Module -ListAvailable Pester | Select-Object Name, Version
```
Expected: at least one entry with Version >= 5.0. PS7 ships Pester 5+ built-in. If absent on PS5.1:
```powershell
Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
```

- [ ] **Step 2: Add `tests` to `.chezmoiignore.tmpl` so the test dir is not deployed**

Open `.chezmoiignore.tmpl`. The top block already lists `claude`, `passgen`, `scoop`, `scripts`, `openspec`, `neovim`, `docs`, `README.md`. Add `tests` to that list (alphabetically reasonable position):

```gotemplate
# ── 專案文件（不部署到任何平台）─────────────────────────────────────────────
README.md
claude
docs
neovim
openspec
passgen
scoop
scripts
tests
```

- [ ] **Step 3: Write the Pester test file**

Create `tests/corp-ssh-askpass.Tests.ps1`:

```powershell
# corp-ssh-askpass.Tests.ps1 — Pester 5 tests for dot_local/bin/corp-ssh-askpass.ps1
#
# Black-box: invokes the helper as a child process with controlled $env:USERPROFILE,
# a mock gopass.cmd on PATH, and various prompt strings. Asserts exit code,
# stdout, and stderr.

BeforeAll {
    $script:RepoRoot   = Split-Path -Parent $PSScriptRoot
    $script:HelperPath = Join-Path $RepoRoot 'dot_local\bin\corp-ssh-askpass.ps1'
}

Describe 'corp-ssh-askpass.ps1' {

    BeforeEach {
        # Per-test sandbox under TEMP. Acts as $HOME for the helper.
        $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("corp-ssh-test-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $Sandbox -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $Sandbox '.corp-ssh') -Force | Out-Null

        # Mock gopass.cmd lives in $Sandbox\bin and prepends to PATH.
        # Behaviour controlled by $env:MOCK_GOPASS_OUTPUT and $env:MOCK_GOPASS_RC.
        $script:MockBin = Join-Path $Sandbox 'bin'
        New-Item -ItemType Directory -Path $MockBin -Force | Out-Null
        $mockGopass = @'
@echo off
if defined MOCK_GOPASS_OUTPUT echo %MOCK_GOPASS_OUTPUT%
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
        $env:MOCK_GOPASS_OUTPUT   = $null
        $env:MOCK_GOPASS_RC       = $null
        Remove-Item -Path $Sandbox -Recurse -Force -ErrorAction SilentlyContinue
    }

    function Invoke-Helper {
        param([string]$Prompt)
        # Run helper in a child PowerShell so $env:USERPROFILE/PATH overrides take effect.
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName               = (Get-Process -Id $PID).Path
        $psi.Arguments              = "-NoProfile -ExecutionPolicy Bypass -File `"$HelperPath`" `"$Prompt`""
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.UseShellExecute        = $false
        $psi.EnvironmentVariables['USERPROFILE']        = $env:USERPROFILE
        $psi.EnvironmentVariables['PATH']               = $env:PATH
        $psi.EnvironmentVariables['MOCK_GOPASS_OUTPUT'] = $env:MOCK_GOPASS_OUTPUT
        $psi.EnvironmentVariables['MOCK_GOPASS_RC']     = $env:MOCK_GOPASS_RC
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
            $env:MOCK_GOPASS_OUTPUT = 'secret-password'
            $r = Invoke-Helper -Prompt '(user@corp-host.example.com) Password:'
            $r.ExitCode | Should -Be 0
            $r.Stdout.TrimEnd("`r","`n") | Should -Be 'secret-password'
        }

        It 'returns OTP for known host with One-time Password prompt (substring trap)' {
            # Critical regression test: bash version's case-statement was wrong-order
            # in the original 2026-04-24 draft. "Password:" matches "One-time Password:"
            # as a substring; OTP branch must come first.
            $env:MOCK_GOPASS_OUTPUT = '123456'
            $r = Invoke-Helper -Prompt '(user@corp-host.example.com) One-time Password:'
            $r.ExitCode | Should -Be 0
            $r.Stdout.TrimEnd("`r","`n") | Should -Be '123456'
        }

        It 'matches short-form hostname against FQDN-prefix allowlist entry' {
            $env:MOCK_GOPASS_OUTPUT = 'secret-password'
            $r = Invoke-Helper -Prompt '(user@other-short-host) Password:'
            $r.ExitCode | Should -Be 0
        }

        It 'parses double-@ prompt (user principal contains @)' {
            $env:MOCK_GOPASS_OUTPUT = 'secret-password'
            $r = Invoke-Helper -Prompt '(ad-user@realm@corp-host.example.com) Password:'
            $r.ExitCode | Should -Be 0
        }

        It 'declines unknown host (exit 1, no stdout)' {
            $env:MOCK_GOPASS_OUTPUT = 'should-not-leak'
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
```

- [ ] **Step 4: Run the tests to confirm they fail (red phase)**

Run:
```powershell
Invoke-Pester -Path tests\corp-ssh-askpass.Tests.ps1 -Output Detailed
```
Expected: all 9 tests fail. Each failure should be either "helper script not found" or similar — not test-framework errors. If you see Pester syntax errors, fix them before moving on.

---

### Task 2: Implement `corp-ssh-askpass.ps1`

**Files:**
- Create: `dot_local/bin/corp-ssh-askpass.ps1`

This task implements the helper to make Task 1's tests pass (TDD green phase).

- [ ] **Step 1: Write the helper**

Create `dot_local/bin/corp-ssh-askpass.ps1`:

```powershell
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

# 4. Dispatch. OTP branch FIRST — "Password:" is substring of "One-time Password:"
#    and PowerShell's -like is also first-match if cascaded.
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
```

- [ ] **Step 2: Run tests to confirm they pass (green phase)**

Run:
```powershell
Invoke-Pester -Path tests\corp-ssh-askpass.Tests.ps1 -Output Detailed
```
Expected: all 9 tests pass.

If any test fails:
- "returns password for known FQDN" failing → check `$args[0]` capture or stdout encoding
- "returns OTP" failing → critical: case-statement order regression. OTP branch MUST come first
- "matches short-form" failing → check `Split('.')[0]` logic
- "double-@ prompt" failing → regex `(.+@)?` greediness — should already be greedy, verify regex
- "declines unknown host" failing — risk: helper might be too permissive; check the `-not ($lines -match ...)` clause
- "declines on malformed prompt" failing — check the early `-notmatch` exit
- "declines when hosts.yaml missing" failing — check `Test-Path` returns false on missing file
- "diagnostic when gopass non-zero" failing — check post-hoc validation block

---

### Task 3: `.cmd` Shim

**Files:**
- Create: `dot_local/bin/corp-ssh-askpass.cmd`

This is what `SSH_ASKPASS` will point at. `ssh.exe`'s `CreateProcess` cannot launch `.ps1` directly; the `.cmd` is a Windows-native bootstrap.

- [ ] **Step 1: Write the shim**

Create `dot_local/bin/corp-ssh-askpass.cmd`:

```cmd
@echo off
where /q pwsh
if %ERRORLEVEL% EQU 0 (
    pwsh       -NoProfile -ExecutionPolicy Bypass -File "%~dp0corp-ssh-askpass.ps1" %*
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0corp-ssh-askpass.ps1" %*
)
```

Notes:
- `where /q pwsh` is silent; only sets `%ERRORLEVEL%`. PS7 cold-start ~80ms vs PS5.1 ~200ms — askpass is invoked 1-2 times per ssh first-auth, so saving 250ms matters perceptibly.
- `%~dp0` = directory of the `.cmd` file with trailing backslash. Resolves the `.ps1` relative to the `.cmd`.
- `%*` forwards all args. SSH prompts contain no shell metacharacters (`(user@host) Password:`), so no escaping risk.
- 8 lines including blank-line separator and the if/else braces — close to the spec's "~3 lines" estimate (the spec collapses `if (...) (...) else (...)` mentally; on disk it's 8).

- [ ] **Step 2: Smoke-check the shim resolves correctly**

Run from the dotfiles repo root:
```powershell
cmd /c "dot_local\bin\corp-ssh-askpass.cmd 'malformed-prompt-for-test'"
echo "exit code: $LASTEXITCODE"
```
Expected: exit code 1 (helper declines because prompt doesn't match regex). No PowerShell error spew.

If you see `'pwsh' is not recognized` or similar, the `where /q pwsh` branch logic is broken — verify with `where /q pwsh; echo %ERRORLEVEL%` standalone.

---

### Task 4: Profile Fragment

**Files:**
- Create: `Documents/exact__shared-profile.d/30-ssh-askpass.ps1`

- [ ] **Step 1: Write the fragment**

Create `Documents/exact__shared-profile.d/30-ssh-askpass.ps1`:

```powershell
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
```

- [ ] **Step 2: Verify fragment loads in a profile-loading PowerShell session**

After Task 9 (`chezmoi apply`), this fragment will deploy to `~/Documents/_shared-profile.d/30-ssh-askpass.ps1`. For now we only verify syntax:

```powershell
Get-Command -Syntax -ErrorAction SilentlyContinue { . Documents\exact__shared-profile.d\30-ssh-askpass.ps1 } 2>&1 | Out-Null
$result = & { try { . Documents\exact__shared-profile.d\30-ssh-askpass.ps1; 'OK' } catch { $_.Exception.Message } }
$result
```
Expected: prints `OK`. Any other output indicates a syntax error.

---

### Task 5: `.chezmoiignore.tmpl` Per-Platform Matrix

**Files:**
- Modify: `.chezmoiignore.tmpl`

Replace the existing single-line corp-ssh-askpass block (which only excludes the bash helper on non-Linux) with a per-platform matrix.

- [ ] **Step 1: Update the file**

Open `.chezmoiignore.tmpl`. Locate the existing block at the bottom of the file:

```gotemplate
# ── corp-ssh-askpass（只部署到 Linux/WSL，Windows/macOS 排除）─────────
{{- if ne .chezmoi.os "linux" }}
.local/bin/corp-ssh-askpass
{{- end }}
```

Replace with:

```gotemplate
# ── corp-ssh-askpass: bash helper deploys on Linux/WSL only ─────────
{{- if ne .chezmoi.os "linux" }}
.local/bin/corp-ssh-askpass
{{- end }}

# ── corp-ssh-askpass: PowerShell helper + .cmd shim deploy on Windows only ──
{{- if ne .chezmoi.os "windows" }}
.local/bin/corp-ssh-askpass.ps1
.local/bin/corp-ssh-askpass.cmd
{{- end }}

# ── PowerShell profile fragment 30-ssh-askpass: Windows only ───────────
{{- if ne .chezmoi.os "windows" }}
Documents/_shared-profile.d/30-ssh-askpass.ps1
{{- end }}
```

Note: target paths in `.chezmoiignore.tmpl` use the deployed names (no `dot_`/`exact_`/`executable_` prefixes), matching the existing convention.

Also confirm Step 2 of Task 1 added `tests` to the project-files block — if not, add it now.

- [ ] **Step 2: Verify chezmoi parses the template without errors**

Run:
```powershell
chezmoi execute-template < .chezmoiignore.tmpl | Out-String
```
Expected: prints the rendered (Windows-platform) ignore list. No template-syntax errors.

- [ ] **Step 3: Verify the helper trio is NOT excluded on Windows**

Run:
```powershell
$rendered = chezmoi execute-template < .chezmoiignore.tmpl
$rendered -split "`n" | Select-String '\.local/bin/corp-ssh-askpass'
```
Expected on Windows host: shows ONLY `.local/bin/corp-ssh-askpass` (the bash one) being excluded; the `.ps1` and `.cmd` lines are NOT in the output (they only appear on non-Windows).

---

### Task 6: Install Script — Add `gpg` + `gopass`

**Files:**
- Modify: `run_once_install-cli-tools.ps1.tmpl`

- [ ] **Step 1: Append the GPG/gopass install block**

Open `run_once_install-cli-tools.ps1.tmpl`. Locate the final `Write-Host "=== CLI tools setup complete. ===" -ForegroundColor Cyan` line. Insert before it:

```powershell
# ── GPG + password store for corp-ssh-askpass (Phase 2) ─────────────────
Install-ScoopPackage "gpg"
Install-ScoopPackage "gopass"
```

The `Install-ScoopPackage` helper is already defined earlier in the file; it checks `Get-Command -ErrorAction SilentlyContinue` and skips if installed.

- [ ] **Step 2: Render the template to verify it parses**

Run:
```powershell
chezmoi execute-template < run_once_install-cli-tools.ps1.tmpl | Select-String 'gopass|gpg'
```
Expected: shows the `Install-ScoopPackage "gpg"` and `Install-ScoopPackage "gopass"` lines on a Windows host.

---

### Task 7: Cross-Reference Edits

**Files:**
- Modify: `docs/corp-ssh-setup.md`
- Modify: `docs/superpowers/specs/2026-04-24-corp-ssh-redesign.md`

- [ ] **Step 1: Update Linux setup guide's "Known limitations and future work" section**

Open `docs/corp-ssh-setup.md`. Locate the section starting with `## Known limitations and future work`. Replace its first bullet:

Find:
```markdown
- **WSL/Ubuntu only for now.** Windows and macOS support deferred. The
  Layer 1+2 architecture is portable: Win32-OpenSSH supports `SSH_ASKPASS`,
  GPG runs via Gpg4win, and `gopass` provides a `pass`-compatible native
  Windows binary. Helper currently is a bash script and would need a
  PowerShell rewrite or Git Bash wrapper for native Windows use.
```

Replace with:
```markdown
- **WSL/Ubuntu and Windows supported; macOS deferred.** Phase 2 (Windows
  native) shipped 2026-04-30 — see [`corp-ssh-setup-windows.md`](corp-ssh-setup-windows.md)
  for the Windows setup guide. macOS port is Phase 3+ (same architecture
  expected to apply: `gopass` from Homebrew, `pinentry-mac` for the dialog).
```

- [ ] **Step 2: Update Phase 1 spec's Future Work section**

Open `docs/superpowers/specs/2026-04-24-corp-ssh-redesign.md`. Locate the Future Work section's Windows bullet:

Find:
```markdown
- **Windows OpenSSH port**. Same `ControlMaster` + askpass mechanism should work on Windows OpenSSH (ssh.exe supports `SSH_ASKPASS`). Git Bash is the likely shell context. Deferred — requires testing.
```

Replace with:
```markdown
- **Windows OpenSSH port**. Implemented Phase 2, 2026-04-30. PowerShell helper, `.cmd` shim for `SSH_ASKPASS`, shared GPG key + `~/.password-store/`. See [`2026-04-30-corp-ssh-windows-phase2-design.md`](2026-04-30-corp-ssh-windows-phase2-design.md).
```

- [ ] **Step 3: Verify the links resolve (relative paths)**

Run:
```powershell
Test-Path docs\corp-ssh-setup-windows.md
```
Expected: `False` for now (we haven't written it yet — it's Task 8). After Task 8 completes, this should return `True`. Don't fix the link; the file will exist by end of plan.

```powershell
Test-Path docs\superpowers\specs\2026-04-30-corp-ssh-windows-phase2-design.md
```
Expected: `True` (already exists from brainstorming).

---

### Task 8: Write `docs/corp-ssh-setup-windows.md`

**Files:**
- Create: `docs/corp-ssh-setup-windows.md`

Mirror `docs/corp-ssh-setup.md` structure with Windows specifics. Targets ~250 lines.

- [ ] **Step 1: Write the file**

Create `docs/corp-ssh-setup-windows.md`:

```markdown
# Corp SSH Setup: Password+OTP Automation (Windows)

A Windows-native port of the WSL/Linux corp-ssh automation. Same
architecture (Layer 1 ControlMaster + Layer 2 SSH_ASKPASS), Windows
mechanisms (PowerShell helper, gopass.exe, Gpg4win).

Design rationale and Phase 1/2 deltas:
[`docs/superpowers/specs/2026-04-30-corp-ssh-windows-phase2-design.md`](superpowers/specs/2026-04-30-corp-ssh-windows-phase2-design.md).

For the WSL/Linux side, see [`corp-ssh-setup.md`](corp-ssh-setup.md).

## What this does

After setup:

- First ssh to a corp host per session requires zero manual input
  (credentials supplied automatically from gopass via gpg-agent cache).
- ControlMaster (best-effort on `OpenSSH_for_Windows_9.5p2`) reuses the
  authenticated socket for 8 hours — subsequent ssh/scp/rsync to the same
  host avoid re-auth entirely.
- Vault is shared with WSL: same GPG key, same `~/.password-store/`.
  Password rotation requires manual dual-write across both platforms.

## Prerequisites

| Dependency | Used for | Install |
|---|---|---|
| Win32-OpenSSH ≥ 9.0 | ssh.exe with SSH_ASKPASS support | Bundled with Windows 11 (Optional Feature) — verify `ssh -V` |
| Scoop | Package management for `gpg`/`gopass` | https://scoop.sh |
| `gpg` (Scoop) | GnuPG 2.x + `gpg-agent.exe` + `pinentry-basic.exe` | `scoop install gpg` |
| `gopass` (Scoop) | `pass`-compatible native binary; built-in TOTP | `scoop install gopass` |
| PowerShell 7 (optional) | Faster cold-start for askpass helper (`pwsh.exe` ~80ms vs `powershell.exe` ~200ms) | `winget install Microsoft.PowerShell` |

The `chezmoi apply` step (below) installs `gpg` + `gopass` automatically via
the existing `run_once_install-cli-tools.ps1.tmpl`.

## Setup, Path A: Existing WSL deployment

This is the path if you already completed Phase 1 setup on WSL/Ubuntu and
just need the same vault accessible from Windows.

### A.1 Run chezmoi apply (deploys helper + shim + profile fragment)

```powershell
chezmoi apply
```

After apply, verify:
```powershell
Test-Path ~\.local\bin\corp-ssh-askpass.ps1
Test-Path ~\.local\bin\corp-ssh-askpass.cmd
Test-Path ~\Documents\_shared-profile.d\30-ssh-askpass.ps1
```
All three should return `True`.

### A.2 Import the GPG private key

Locate your GPG private key backup (`.asc` file produced on WSL via
`gpg --export-secret-keys --armor <FPR> > corp-ssh-key.asc`).

```powershell
gpg --import path\to\corp-ssh-key.asc
gpg --list-secret-keys
```

Verify the fingerprint matches your WSL setup. Then mark the key as
ultimately trusted (it's your own key):

```powershell
gpg --edit-key <FPR>
# At the gpg> prompt:
# trust
# 5
# y
# save
```

### A.3 Configure gpg-agent (8h cache TTL)

```powershell
$gnupgHome = Join-Path $env:APPDATA 'gnupg'
New-Item -ItemType Directory -Path $gnupgHome -Force | Out-Null
@'
default-cache-ttl 28800
max-cache-ttl 28800
'@ | Set-Content -Path (Join-Path $gnupgHome 'gpg-agent.conf') -Encoding ascii
gpg-connect-agent reloadagent /bye
```

### A.4 Copy the vault from WSL

```powershell
$src = '\\wsl$\Ubuntu\home\<wsl-user>\.password-store'
$dst = Join-Path $env:USERPROFILE '.password-store'
Copy-Item -Path $src -Destination $dst -Recurse -Force
```

Replace `<wsl-user>` with your WSL username. If your WSL distro is named
something other than `Ubuntu`, adjust the UNC path accordingly
(`\\wsl$\<distro>\...`).

Verify:
```powershell
gopass list
```
Should list at least `corp/password` and `corp/totp`.

### A.5 Copy hosts.yaml from WSL

```powershell
$src = '\\wsl$\Ubuntu\home\<wsl-user>\.corp-ssh\hosts.yaml'
$dst = Join-Path $env:USERPROFILE '.corp-ssh\hosts.yaml'
New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null
Copy-Item -Path $src -Destination $dst -Force
```

Verify:
```powershell
Get-Content ~\.corp-ssh\hosts.yaml
```
Should show `pass_path:` and `password_otp_hosts:` entries.

### A.6 Reload PowerShell profile

Close all PowerShell windows and open a fresh one (or: `. $PROFILE`). Then:
```powershell
$env:SSH_ASKPASS
$env:SSH_ASKPASS_REQUIRE
```
Both should be set: SSH_ASKPASS to `<userprofile>\.local\bin\corp-ssh-askpass.cmd`,
SSH_ASKPASS_REQUIRE to `force`.

If empty, the profile fragment isn't loading — check
`Test-Path ~\Documents\_shared-profile.d\30-ssh-askpass.ps1`.

### A.7 Warm gpg-agent cache

```powershell
gopass show -o corp/password >$null
```

A `pinentry-basic.exe` dialog appears. Type your GPG passphrase. After
this, the cache stays warm for 8 hours.

### A.8 Add ControlMaster to ~/.ssh/config (best-effort)

Append to `~\.ssh\config`:

```
# ──── Corp hosts with password+OTP — enable connection multiplexing ─────────
Host <corp-host-pattern-1> <corp-host-pattern-2>
  ControlMaster auto
  ControlPath ~/.ssh/cm/%C
  ControlPersist 8h
```

Create the socket directory:
```powershell
New-Item -ItemType Directory -Path ~\.ssh\cm -Force | Out-Null
```

ControlMaster on Win32-OpenSSH 9.5p2 uses named pipes (vs. Unix sockets
on Linux). The option is parser-supported (`ssh -G localhost` shows
`controlmaster false` as default). If runtime named-pipe ControlMaster
misbehaves on your version, simply omit the `Host` block — Layer 2
(askpass) still works standalone, you just re-auth on every ssh.

### A.9 Smoke test

```powershell
ssh <corp-host> hostname
```
Expected: returns the host's hostname with no manual input. Repeat — should
be near-instant if ControlMaster is working.

If you see `Permission denied`, run with `-v` and check stderr for
`corp-ssh-askpass: gopass failed`. That indicates a cold cache; warm it
manually with A.7.

## Setup, Path B: Fresh Windows (no WSL)

(Out of scope for this implementation's testing. Documented for future
colleagues or Windows-only setups.)

Same as Path A but replace A.2–A.5 with:

```powershell
# Generate a new key (interactive — set passphrase)
gpg --quick-generate-key 'corp-ssh local <your-email>' future-default default 0
gpg --list-secret-keys                                # note the FPR

# Initialize the vault and store credentials
gopass init <FPR>
gopass insert corp/password                           # paste password
gopass otp insert corp/totp                           # paste otpauth://totp/... URI
# (or `gopass otp insert -s corp/totp` if you only have the base32 secret)

# Create hosts.yaml
New-Item -ItemType Directory -Path ~\.corp-ssh -Force | Out-Null
@'
pass_path: corp

password_otp_hosts:
  - <actual-host-1>.<corp-domain>
  - <actual-host-2>
'@ | Set-Content -Path ~\.corp-ssh\hosts.yaml -Encoding ascii
```

Then continue with A.6–A.9.

## How it works

Two layers, both leveraging native ssh.exe mechanisms:

**Layer 1 — connection reuse (ControlMaster, best-effort)**. On `OpenSSH_for_Windows_9.x`,
ControlMaster uses named pipes (Windows equivalent of Unix sockets). After
the first authenticated ssh, subsequent calls within `ControlPersist 8h`
reuse the named-pipe connection — no auth, near-instant.

**Layer 2 — non-interactive credential entry (`SSH_ASKPASS` + `SSH_ASKPASS_REQUIRE=force`)**.
When ssh.exe needs to prompt, instead of reading from terminal it invokes
`SSH_ASKPASS` (which points at `corp-ssh-askpass.cmd` → forwards to
`corp-ssh-askpass.ps1`). The helper parses the hostname out of the prompt,
looks it up in `~/.corp-ssh/hosts.yaml`, calls `gopass show -o` (or
`gopass otp`), and writes the credential to stdout. ssh.exe reads stdout
as the response.

`gopass` decrypts via `gpg.exe`, which talks to `gpg-agent.exe` over a
Windows named pipe. As long as gpg-agent has the GPG passphrase cached
(8h TTL), no `pinentry-basic.exe` dialog fires and the helper completes
silently. Cold cache → dialog appears once.

The helper is GUI-free; only the GPG-passphrase entry triggers a dialog,
and only when the cache is cold.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `ssh <corp-host>` still prompts on TTY | PowerShell profile not loaded | Close + reopen PowerShell, or `. $PROFILE`. Verify `$env:SSH_ASKPASS_REQUIRE` is `force`. |
| `'powershell' is not recognized` from `.cmd` | Running ssh.exe directly from cmd.exe with no PATH | This setup is PowerShell-only by design. Run from a PowerShell session. |
| `Permission denied`, `ssh -v` shows `corp-ssh-askpass: gopass failed` | gpg-agent cache cold | `gopass show -o corp/password >$null` to warm cache (dialog appears once). |
| `gopass: decryption failed: No secret key` | GPG key not imported, or trust not set | `gpg --list-secret-keys`; `gpg --edit-key <FPR> trust 5 save`. |
| Pinentry dialog appears but I can't see it | Hidden behind other windows | Alt+Tab through. `gpg-connect-agent reloadagent /bye` to retry if stuck. |
| `ssh -G <corp-host>` shows `controlmaster false` despite config | Block in `~/.ssh/config` not matching `<corp-host>` pattern | Verify `Host` line scope; `ssh -F /dev/null -G <corp-host>` to bypass config and confirm baseline. |
| ssh from VS Code git integration fails | IDE-spawned ssh.exe didn't inherit profile env vars | Configure IDE to use PowerShell as default shell; or set env vars in IDE settings. |
| `controlpath too long` error | Using `%r@%h:%p` instead of `%C` | Use `%C` (40-char hash). Spec § Components for rationale. |
| `where /q pwsh` reports false but `pwsh` works in shell | PATH not refreshed since install | Open new PowerShell session. |

### When the password rotates

Phase 1 (WSL) and Phase 2 (Windows) maintain independent vault copies.
On rotation, dual-write:

```bash
# WSL
pass insert -f corp/password
```

```powershell
# Windows
gopass insert -f corp/password
```

Future work: `gopass git init` + private remote could replace dual-write.
Tracked in spec.

### Forcing a passphrase re-prompt

```powershell
gpg-connect-agent reloadagent /bye
```

Next `gopass show` (or first corp ssh) will prompt again.

## Known limitations and future work

- **macOS deferred** (Phase 3+). Same architecture expected to apply.
- **ControlMaster best-effort** on `OpenSSH_for_Windows_9.5p2`. Layer 2
  (askpass) carries everything if Layer 1 misbehaves.
- **No automated vault sync.** Manual dual-write at rotation. Tracked.
- **PowerShell-only.** ssh.exe from cmd.exe or environment without
  profile-loaded shell does not benefit from this automation.

## Why not Kerberos / GSSAPI?

Same answer as Phase 1 — see
[`corp-ssh-setup.md` § Why not Kerberos](corp-ssh-setup.md#why-not-kerberos--gssapi)
for the full investigation. If IT later enables IPA-native OTP preauth or
provisions user certificates, the Kerberos path becomes viable on both
WSL and Windows without code changes here.
```

- [ ] **Step 2: Verify the file renders cleanly**

Run:
```powershell
$lines = (Get-Content docs\corp-ssh-setup-windows.md).Length
Write-Host "Line count: $lines"
```
Expected: somewhere between 220 and 280 lines (rough sanity check).

```powershell
Select-String -Path docs\corp-ssh-setup-windows.md -Pattern 'TBD|TODO|FIXME|XXX' | ForEach-Object { $_.Line }
```
Expected: no output (no leftover placeholders).

---

### Task 9: Final Verification + Stage Commit

**Files:** none modified — verification + staging only.

- [ ] **Step 1: Run all Pester tests one more time**

Run:
```powershell
Invoke-Pester -Path tests\corp-ssh-askpass.Tests.ps1 -Output Detailed
```
Expected: 9/9 pass.

- [ ] **Step 2: Run `chezmoi diff` to inspect what would deploy**

Run:
```powershell
chezmoi diff
```
Expected on a Windows host: shows additions for
- `~/.local/bin/corp-ssh-askpass.ps1` (new file)
- `~/.local/bin/corp-ssh-askpass.cmd` (new file)
- `~/Documents/_shared-profile.d/30-ssh-askpass.ps1` (new file)
- changes to `~/.local/share/chezmoi/.chezmoiignore` reflecting the per-platform matrix
- changes to the Scoop install runner

Should NOT show `tests/...` entries (excluded via `.chezmoiignore.tmpl`).

- [ ] **Step 3: Run `chezmoi verify`**

Run:
```powershell
chezmoi verify
```
Expected: silent (no errors). If it complains, check that target paths in
`.chezmoiignore.tmpl` use deployed names (no `dot_`/`exact_`/`executable_`
prefixes).

- [ ] **Step 4: Stage all changes**

Run:
```powershell
git add tests/corp-ssh-askpass.Tests.ps1
git add dot_local/bin/corp-ssh-askpass.ps1
git add dot_local/bin/corp-ssh-askpass.cmd
git add Documents/exact__shared-profile.d/30-ssh-askpass.ps1
git add .chezmoiignore.tmpl
git add run_once_install-cli-tools.ps1.tmpl
git add docs/corp-ssh-setup.md
git add docs/superpowers/specs/2026-04-24-corp-ssh-redesign.md
git add docs/corp-ssh-setup-windows.md
git add docs/superpowers/specs/2026-04-30-corp-ssh-windows-phase2-design.md
git add docs/superpowers/plans/2026-04-30-corp-ssh-windows-phase2.md
```

Run `git status` and confirm only these files are staged.

- [ ] **Step 5: Create the commit (USER-TRIGGERED — do not auto-commit)**

**STOP.** Per project CLAUDE.md, do not commit without explicit user approval.

Once user approves:

```powershell
git commit -m "feat(corp-ssh): Windows phase 2 — PowerShell askpass + shared vault"
```

Suggested commit body (paste into editor or `-m` second arg):

```
Phase 2 of corp-ssh password+OTP automation, porting Phase 1 (WSL/Linux,
commit 5a35758) to Windows native.

Changes:
- corp-ssh-askpass.ps1 + .cmd shim — PowerShell port of bash askpass
  helper, invoked via SSH_ASKPASS_REQUIRE=force on Win32-OpenSSH 9.5p2
- 30-ssh-askpass.ps1 profile fragment — exports SSH_ASKPASS env vars
  per-shell (PS5.1 + PS7 via shared-profile.d loader)
- run_once install adds Scoop gpg + gopass packages
- .chezmoiignore.tmpl per-platform matrix: bash on Linux, ps1+cmd on Windows
- Pester tests covering regex parsing, allowlist, OTP-first ordering, error
  path; tests/ excluded from chezmoi deployment
- New docs/corp-ssh-setup-windows.md (Path A: import vault from WSL;
  Path B: fresh Windows from scratch)
- Cross-references to/from Phase 1 spec and Linux setup guide

Architecture: Layer 1 (ControlMaster) is best-effort on Win32-OpenSSH —
named-pipe runtime correctness assumed-pending-test. Layer 2 (askpass)
is required and fully tested. If Layer 1 misbehaves, Layer 2 carries
each ssh first-auth (still zero-input as long as gpg-agent cache is warm).

Vault sharing with WSL: same GPG key (FPR 24FC3F9C...50CD6367) imported
once; same ~/.password-store/ copied via \\wsl$\ UNC. Rotation is manual
dual-write; gopass git init for sync is future work.

Spec: docs/superpowers/specs/2026-04-30-corp-ssh-windows-phase2-design.md
Plan: docs/superpowers/plans/2026-04-30-corp-ssh-windows-phase2.md
```

---

## Deployment Runbook (Post-Merge, User-Side)

After the commit lands, the user runs these on their Windows box to activate Phase 2. These are NOT implementation steps — they are operator actions tracked here so the implementer doesn't forget what's needed for end-to-end verification.

| # | Step | Command / Action |
|---|---|---|
| 1 | `chezmoi update` | `chezmoi update` |
| 2 | Install gpg + gopass | (auto, via `run_once_install-cli-tools.ps1.tmpl`); verify `gpg --version` and `gopass --version` |
| 3 | Import GPG key | Setup guide §A.2 |
| 4 | Configure gpg-agent.conf | Setup guide §A.3 |
| 5 | Copy vault from WSL | Setup guide §A.4 |
| 6 | Copy hosts.yaml | Setup guide §A.5 |
| 7 | Reload PowerShell profile | Setup guide §A.6 |
| 8 | Warm cache | Setup guide §A.7 |
| 9 | Edit `~/.ssh/config` ControlMaster block | Setup guide §A.8 |
| 10 | Smoke test | Setup guide §A.9 — `ssh <corp-host> hostname` |
| 11 | Update memory | Save Phase 2 deployment outcome (worked/issues) so future sessions know status |

If Step 10 succeeds: Phase 2 is live. Update `MEMORY.md` `corp-ssh` entry to mark Windows as supported.

If Step 10 fails: capture `ssh -v` output and the exact failure. Common modes are documented in setup guide § Troubleshooting.
