# Windows Terminal OSC 9;9 - 報告當前工作目錄，讓 duplicate pane 繼承目錄
# 必須在 Starship 初始化之前定義
function Invoke-Starship-PreCommand {
    $loc = $executionContext.SessionState.Path.CurrentLocation
    $esc = [char]27
    $bel = [char]7
    $dq = [char]34
    $host.ui.Write($esc + ']9;12' + $bel)
    if ($loc.Provider.Name -eq 'FileSystem') {
        $host.ui.Write($esc + ']9;9;' + $dq + $loc.ProviderPath + $dq + $bel)
    }
}

# Bypass scoop shim — shim's CreateProcess fails under SSH ConPTY handle inheritance.
# Fallback to versioned dir because scoop's 'current' junction does not resolve under
# the SSH session token (Win32-OpenSSH reparse-point traversal quirk).
$starshipExe = "$env:USERPROFILE\scoop\apps\starship\current\starship.exe"
if (-not (Test-Path $starshipExe)) {
    $starshipExe = Get-ChildItem "$env:USERPROFILE\scoop\apps\starship" -Directory -Force -ErrorAction SilentlyContinue |
                   Where-Object Name -match '^\d+\.\d+' |
                   Sort-Object Name -Descending |
                   Select-Object -First 1 |
                   ForEach-Object { Join-Path $_.FullName 'starship.exe' }
}
if ($starshipExe -and (Test-Path $starshipExe)) {
    # starship's init output hardcodes the scoop shim path (current_exe() resolves to
    # the shim, not the real binary). Skip the bootstrap stage and call --print-full-init
    # directly, then rewrite any embedded shim references to the resolved exe so prompt
    # invocations also bypass the broken shim.
    $shimPath = "$env:USERPROFILE\scoop\shims\starship.exe"
    $initCode = (& $starshipExe init powershell --print-full-init | Out-String).Replace($shimPath, $starshipExe)
    Invoke-Expression $initCode
}
