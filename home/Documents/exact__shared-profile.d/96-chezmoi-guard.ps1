# 96-chezmoi-guard.ps1 — 讓 chezmoi apply 的中止不再無聲。
#
# chezmoi 依 target path 字典序處理且沒有 skip-on-error：任何一項失敗，字典序排在它
# 之後的 target 全部靜默落空，而 chezmoi 的輸出只有那一行錯誤。曾因此讓
# Documents/_shared-profile.d/26-glab.ps1 長期沒部署到 Windows，靠跨機比對才發現。
#
# 待處理筆數只在失敗路徑上算 —— `chezmoi status` 要掃 external 底下數千個檔案，
# 該機實測 31 秒，不能放進 shell 啟動路徑。
#
# Mirror of .chezmoitemplates/shell-common/base's chezmoi() function; the two
# warning strings are kept byte-identical on purpose.

function chezmoi {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

    # -CommandType Application skips this function, so no recursion. Select-Object
    # is load-bearing: Get-Command returns EVERY chezmoi on PATH, and `.Source` on a
    # multi-element result yields the paths joined into one unrunnable string.
    $exe = Get-Command chezmoi -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $exe) {
        Write-Error 'chezmoi: binary not on PATH'
        return
    }

    & $exe.Source @Remaining
    $rc = $LASTEXITCODE
    if ($rc -eq 0) { return }

    $sub = @($Remaining | Where-Object { $_ -in @('apply', 'update') }) | Select-Object -First 1
    if (-not $sub) {
        $global:LASTEXITCODE = $rc
        return
    }

    Write-Host ''
    Write-Host "chezmoi: $sub 中止 (exit $rc)。chezmoi 依字典序處理 target 且不跳過失敗項 —— 排在它之後的 target 全部未部署。" -ForegroundColor Yellow
    $pending = @(& $exe.Source status 2>$null).Count
    Write-Host "chezmoi: 目前 $pending 筆待處理（chezmoi status）。" -ForegroundColor Yellow
    Write-Host ''

    $global:LASTEXITCODE = $rc
}
