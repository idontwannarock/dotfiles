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

Invoke-Expression (&starship init powershell)

#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module
if ($PSVersionTable.PSVersion.Major -ge 7) {
    # PowerShell 7+: 使用 PowerToys 模組 (需安裝 PowerToys 並啟用 CommandNotFound)
    Import-Module -Name Microsoft.WinGet.CommandNotFound -ErrorAction SilentlyContinue
} else {
    # Windows PowerShell 5.x: CommandNotFoundAction fallback
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
}
#f45873b3-b655-43a6-b217-97c00aa0db58
