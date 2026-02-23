# Windows PowerShell 5.x CommandNotFoundAction fallback
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
