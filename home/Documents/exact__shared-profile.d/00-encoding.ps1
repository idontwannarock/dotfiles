try {
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    # No chcp call needed: the two [Console] setters above already switch the console
    # code page (verified: chcp reports 65001 after them, on PS5.1 and PS7).
} catch {}

# Only clear screen in interactive terminal sessions (skip during chezmoi runs, scripts, etc.)
if ([Environment]::UserInteractive -and $Host.Name -eq 'ConsoleHost' -and -not $env:CHEZMOI) {
    Clear-Host
}
