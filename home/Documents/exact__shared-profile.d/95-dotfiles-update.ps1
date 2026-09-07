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

# ── 每日檢查 chezmoi 自己有沒有新版 ─────────────────────────────────────────
# Mirror of .chezmoitemplates/shell-common/base's _chezmoi_check_version。獨立旗標
# 與函式,不併進上面那支:那支任何一步失敗都直接 return,併進去等於讓 dotfiles fetch
# 失敗時連帶靜音版本檢查,而兩者沒有因果關係。
#
# 建議的指令在這裡與 bash 那側**刻意不同**:Windows 的 chezmoi 由 winget 佈署
# （README「Windows」段),`chezmoi upgrade` 不認得 winget 裝的副本。
function Invoke-ChezmoiVersionCheck {
    $flagDir  = Join-Path $env:USERPROFILE ".local\share"
    $flagFile = Join-Path $flagDir "chezmoi-last-version-check"
    $today    = Get-Date -Format "yyyyMMdd"

    if ((Test-Path $flagFile) -and ((Get-Content $flagFile -ErrorAction SilentlyContinue) -eq $today)) {
        return
    }

    $exe = Get-Command chezmoi -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $exe) { return }

    if (-not (Test-Path $flagDir)) {
        New-Item -ItemType Directory -Path $flagDir -Force | Out-Null
    }
    # 旗標在打網路之前就寫,理由同上面那支。
    $today | Set-Content $flagFile -NoNewline

    $verLine = (& $exe.Source --version 2>$null) | Select-Object -First 1
    if ($verLine -notmatch 'version v([0-9][0-9.]*)') { return }
    $current = $Matches[1]

    # -TimeoutSec 是承重的:這支跑在 profile 載入路徑上。
    try {
        $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/twpayne/chezmoi/releases/latest' `
            -TimeoutSec 3 -ErrorAction Stop
    } catch { return }
    if ($rel.tag_name -notmatch '^v([0-9][0-9.]*)$') { return }
    $latest = $Matches[1]

    if ($current -eq $latest) { return }

    # 只陳述兩個版本,不宣稱哪個較新 —— 同 bash 那側的理由。
    Write-Host "`nchezmoi: $current installed, $latest available. Run 'winget upgrade twpayne.chezmoi'.`n" -ForegroundColor Yellow
}

Invoke-ChezmoiVersionCheck
