# Windows PowerShell 5.x CommandNotFoundAction fallback.
#
# Prerequisite: `winget.exe` reachable on PATH. Win10 1809+ and Win11 ship it
# OS-bundled at %LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe via the
# Microsoft.DesktopAppInstaller Store package. Without winget the `winget
# search` call below silently returns nothing (`2>$null`) and the handler
# emits no suggestions — no error surfaces to the user.
#
# Unlike the PowerShell 7 sibling, this script does NOT depend on PowerToys
# or the `Microsoft.WinGet.CommandNotFound` module (those target PS 7 only).
$ExecutionContext.InvokeCommand.CommandNotFoundAction = {
    param($commandName, $commandLookup, $errorRecord)

    # Skip short commands, PowerShell's auto-prefixed attempts, and relative paths
    if ($commandName.Length -lt 2) { return }
    if ($commandName -like "get-*") { return }
    if ($commandName -like ".\*") { return }

    Write-Host "Command '$commandName' not found. Searching winget..." -ForegroundColor Yellow
    $results = winget search $commandName --source winget 2>$null |
        Where-Object {
            $_ -and
            $_ -notmatch "^[-\s]*$" -and
            $_ -notmatch "^\s*Name\s+" -and
            $_ -notmatch "[█▒]" -and
            $_ -notmatch "\d+(\.\d+)?\s*(KB|MB|GB)" -and
            $_ -notmatch "^\s*[\\/|\-]\s*$"
        } |
        Select-Object -First 5

    if ($results) {
        Write-Host "Available via winget:" -ForegroundColor Cyan
        $results | ForEach-Object { Write-Host "  $_" }
        Write-Host "Run: winget install <package-name>" -ForegroundColor Green
    }
}
