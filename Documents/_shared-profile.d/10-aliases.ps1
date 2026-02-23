Set-Alias scoopupdate "$HOME\.local\bin\scoop-interactive-update.ps1"

# Worklogs aliases (run Set-WorklogsPath.ps1 to configure)
if ($env:WORKLOGS_PATH -and (Test-Path $env:WORKLOGS_PATH)) {
    Set-Alias createnewlog "$env:WORKLOGS_PATH\create-new-log.ps1"
    Set-Alias gitpushlog "$env:WORKLOGS_PATH\git-push.ps1"
}
