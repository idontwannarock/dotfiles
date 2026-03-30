# 自動 fetch dotfiles 並提示更新（每日一次）
function Invoke-DotfilesUpdateCheck {
    $flagDir  = Join-Path $env:USERPROFILE ".local\share"
    $flagFile = Join-Path $flagDir "chezmoi-last-fetch"
    $today    = Get-Date -Format "yyyyMMdd"

    if ((Test-Path $flagFile) -and ((Get-Content $flagFile -ErrorAction SilentlyContinue) -eq $today)) {
        return
    }

    if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) { return }
    if (-not (Get-Command git    -ErrorAction SilentlyContinue)) { return }

    if (-not (Test-Path $flagDir)) {
        New-Item -ItemType Directory -Path $flagDir -Force | Out-Null
    }
    $today | Set-Content $flagFile -NoNewline

    chezmoi git -- fetch -q 2>$null
    if ($LASTEXITCODE -ne 0) { return }

    $behind = chezmoi git -- rev-list HEAD..origin/main --count 2>$null
    if ([int]$behind -gt 0) {
        Write-Host "`ndotfiles: $behind new commit(s). Run 'chezmoi update' to apply.`n" -ForegroundColor Yellow
    }
}

Invoke-DotfilesUpdateCheck
