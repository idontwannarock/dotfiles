# WSL agent, Windows Chrome

Chrome runs on Windows and opens CDP on the Windows loopback address. WSL in NAT
mode cannot reach that address. Do not forward the port into WSL. Run the
**Windows** `playwright-cli` from WSL instead: WSL can start Windows programs, and
that `playwright-cli` reaches Chrome on Windows `localhost`. No forward, no firewall
rule, and no UAC prompt are needed.

## Define `pw`

The agent shell does not keep functions between calls. Put these lines at the top
of every Bash call that uses `pw`:

```bash
{ read -r WNODE; read -r WCLI; read -r WTMP; } < <(powershell.exe -NoProfile -Command '(Get-Command node).Source; Join-Path (npm root -g) "@playwright\cli\playwright-cli.js"; $env:TEMP' | tr -d '\r')
WNODE=$(wslpath "$WNODE")
pw() { "$WNODE" "$WCLI" -s=cdp "$@"; }
cd "$(wslpath "$WTMP")"
```

- `pw` calls Windows `node.exe` with the CLI script directly. WSL passes each
  argument to `node.exe` unchanged; JavaScript with `'`, `"`, `&`, `<`, `>`, and `|`
  arrives intact. Do not route `pw` through `cmd.exe` or `powershell.exe`: both
  parse the arguments again.
- The working directory must be a Windows path. `node.exe` started from a WSL path
  gets a `\\wsl.localhost\...` directory. Snapshots and screenshots go to
  `.playwright-cli\` under the Windows `%TEMP%`, and file arguments (`upload`,
  `screenshot --filename`) are Windows paths.
- If the CLI script does not exist, the Windows-side chezmoi apply has not run.
  Tell the user to run it, or to run `npm install -g @playwright/cli` on Windows.
- If the agent shell is denied a Windows program, stop. See step 1 of the skill.

## Launch Chrome and record its PID

```bash
powershell.exe -NoProfile -Command '$dir = Join-Path $env:TEMP "chrome-cdp"; New-Item -ItemType Directory -Force -Path $dir | Out-Null; Start-Process "C:\Program Files\Google\Chrome\Application\chrome.exe" -ArgumentList @("--remote-debugging-port=9222", "--user-data-dir=$dir", "--no-first-run", "--no-default-browser-check", "--disable-backgrounding-occluded-windows", "--disable-renderer-backgrounding", "--disable-background-timer-throttling", "about:blank")'
powershell.exe -NoProfile -Command 'Get-NetTCPConnection -LocalPort 9222 -State Listen | Select-Object LocalAddress,OwningProcess'
```

The listener must be a loopback address (`127.0.0.1` or `::1`). Record
`OwningProcess` as the Chrome PID. A `0.0.0.0` listener on 9222 is a leftover
forward; see the end of this file.

**Shell quoting for `powershell.exe`:** bash single quotes preserve PowerShell `$`
variables; use double quotes inside PowerShell. If the PowerShell expression needs
literal single quotes, use bash double quotes and escape its `$` and `"`.

## Stop Chrome

```bash
powershell.exe -NoProfile -Command 'Stop-Process -Id <PID>; Start-Sleep -Seconds 1; (Get-NetTCPConnection -LocalPort 9222 -State Listen -ErrorAction SilentlyContinue | Measure-Object).Count'
```

The last line prints `0` when the listener is gone. Delete the profile only with
user approval; it removes the saved logins:

```bash
powershell.exe -NoProfile -Command 'Remove-Item -Recurse -Force (Join-Path $env:TEMP "chrome-cdp")'
```

## Remove leftovers from the old forwarding setup

Before 2026-10-27, this skill forwarded port 9222 into WSL with `netsh interface
portproxy` and a `WSL-CDP-9222` firewall rule. Some machines still have them, and
early versions opened them to the whole network (`0.0.0.0`, any remote address).

Inspect; this needs no UAC:

```bash
powershell.exe -NoProfile -Command 'netsh interface portproxy show all; Get-NetFirewallRule -DisplayName "WSL-CDP*" -ErrorAction SilentlyContinue | Select-Object Name,DisplayName,Profile'
```

If anything shows up, tell the user each entry and ask whether another session still
uses it. Continue only after the user confirms that nothing does. Then remove every
port 9222 forward and every `WSL-CDP-*` rule (needs UAC). The script reads the
forwards from the registry, because `netsh` output changes with the Windows display
language. `-EncodedCommand` avoids nested quoting, and `-Wait` holds the shell until
the elevated window closes:

```bash
cat > /tmp/wsl-cdp-reset.ps1 <<'PS1'
foreach ($kind in 'v4tov4', 'v4tov6') {
    $key = "HKLM:\SYSTEM\CurrentControlSet\Services\PortProxy\$kind\tcp"
    (Get-Item $key -ErrorAction SilentlyContinue).Property | Where-Object { $_ -like '*/9222' } | ForEach-Object {
        netsh interface portproxy delete $kind listenport=9222 listenaddress=$($_.Split('/')[0])
    }
}
Get-NetFirewallRule -DisplayName 'WSL-CDP-*' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
PS1
ENC=$(iconv -t UTF-16LE /tmp/wsl-cdp-reset.ps1 | base64 -w0)
powershell.exe -NoProfile -Command "Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-EncodedCommand','$ENC'"
```

To preview without changes and without UAC, add `-WhatIf` to `Remove-NetFirewallRule`,
replace `netsh` with `Write-Output netsh`, and run
`powershell.exe -NoProfile -EncodedCommand "$ENC"`.

Run the inspect command again. It must show no 9222 forward and no `WSL-CDP-*` rule.

## Observations

- 2026-10-27: Windows `playwright-cli` 0.1.22, started from WSL through `node.exe`,
  attached to Chrome 155 on `localhost:9222` with no forward. `goto`, `tab-list`,
  `--raw snapshot`, `click`, and `--raw eval` with a same-origin `fetch` worked.
  The full reset removed 1 forward on `0.0.0.0` and 3 duplicate `WSL-CDP-9222` rules.
