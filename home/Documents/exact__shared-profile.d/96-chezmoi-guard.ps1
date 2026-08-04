# 96-chezmoi-guard.ps1 — 讓 chezmoi apply 的中止不再無聲。
#
# chezmoi 依 target path 字典序處理且沒有 skip-on-error：任何一項失敗，字典序排在它
# 之後的 target 全部靜默落空，而 chezmoi 的輸出只有那一行錯誤。曾因此讓
# Documents/_shared-profile.d/26-glab.ps1 長期沒部署到 Windows，靠跨機比對才發現。
#
# 待處理筆數只在失敗路徑上算 —— `chezmoi status` 要掃 external 底下數千個檔案，
# 該機實測 31 秒，不能放進 shell 啟動路徑。
#
# Mirror of .chezmoitemplates/shell-common/base's chezmoi() function。保證一致的是:
# 警告的文字（逐字）、ANSI 顏色碼、訊息落在 process 的 stderr、以及退出碼（拒絕呼叫
# 沿用 chezmoi 自己的碼，找不到執行檔為 127）。**不**保證的是行尾字元（這裡 CRLF、
# 那裡 LF）與非 ASCII 的呈現 —— 後者仰賴 00-encoding.ps1 先把 console 設成 UTF-8。
#
# [Console]::Error.WriteLine 而非 Write-Error，是刻意的取捨。Write-Error 會再前綴一次
# function 名，且 PS 5.1 與 PS 7 都把 ErrorRecord 渲染成引用呼叫端原始碼行的多行區塊，
# 與 bash 的單行 printf >&2 相去甚遠。換來單行乾淨的代價是:PowerShell 的 `2>` 只重導
# 自己的錯誤串流，攔不到 process stderr（OS 層對整個行程的重導仍然攔得到）。要把它改回
# Write-Error 之前，先重讀這段取捨。
#
# 刻意不用 [CmdletBinding()] + ValueFromRemainingArguments：具名參數繫結先於 remaining
# 收集，且 common parameter 支援前綴比對，於是 chezmoi 的短旗標會被吃掉 —— `-v` 綁到
# -Verbose 後消失，`-D <dir>` 綁到 -Debug 後把 <dir> 留成孤兒位置參數。裸 function 的
# $args 不做任何繫結。26-glab.ps1 曾是那個形狀，代價見該檔檔頭。

function chezmoi {
    # -CommandType Application skips this function, so no recursion. Select-Object
    # is load-bearing: Get-Command returns EVERY chezmoi on PATH, and `.Source` on a
    # multi-element result yields the paths joined into one unrunnable string.
    $exe = Get-Command chezmoi -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $exe) {
        $global:LASTEXITCODE = 127
        [Console]::Error.WriteLine('chezmoi: binary not on PATH')
        return
    }

    & $exe.Source @args
    $rc = $LASTEXITCODE
    if ($rc -eq 0) { return }

    $sub = @($args | Where-Object { $_ -in @('apply', 'update') }) | Select-Object -First 1
    if (-not $sub) {
        $global:LASTEXITCODE = $rc
        return
    }

    $y = [char]27 + '[33m'
    $n = [char]27 + '[0m'
    [Console]::Error.WriteLine("`n$y" + "chezmoi: $sub 中止 (exit $rc)。chezmoi 依字典序處理 target 且不跳過失敗項 —— 排在它之後的 target 全部未部署。$n")
    $pending = @(& $exe.Source status 2>$null).Count
    [Console]::Error.WriteLine("$y" + "chezmoi: 目前 $pending 筆待處理（chezmoi status）。$n`n")

    $global:LASTEXITCODE = $rc
}
