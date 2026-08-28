# 26-glab.ps1 — corp GitLab CLI wrapper.
#
# Token source: this machine's own gopass store, entry gitlab/corp-token. It is
# NOT shared with WSL's `pass` — they are two separate stores
# (C:\Users\<user>\.password-store here, ~/.password-store in WSL), each filled by
# its own one-time insert; see docs/gitlab-corp-access.md. Skipping the Windows
# insert because the WSL one is already done yields a 401, an error that points at
# the token when the fault is that this store has no entry.
# Falls back to $env:GITLAB_TOKEN if gopass unavailable or entry missing.
#
# The host comes from machine-local state (HKCU\Environment), deliberately not
# from this repo — see docs/gitlab-corp-access.md. Without it glab targets
# gitlab.com and a corp token yields 401, an error that points at the token when
# the fault is the host; this wrapper stops that before any request goes out.
#
# PowerShell $env:* assignments leak to process scope (unlike bash's inline
# VAR=val), so GITLAB_TOKEN is snapshotted + restored via try/finally to keep
# glab invocations outside this wrapper unaffected.
#
# Mirror of .chezmoitemplates/shell-common/base's glab(). What is guaranteed to
# match: the message text (byte-for-byte), the fact that it lands on the process's
# stderr handle, and the non-zero exit code. What is NOT: the line terminator
# (CRLF here, LF there) and the rendering of non-ASCII, which relies on
# 00-encoding.ps1 having set the console to UTF-8 first.
#
# [Console]::Error.WriteLine rather than Write-Error, deliberately, with a known
# cost. Write-Error prefixes the function name a second time (`glab: glab: ...`)
# and both PS 5.1 and PS 7 render an ErrorRecord as a multi-line block quoting the
# calling source line -- nothing like bash's one line. The price of the clean line
# is that PowerShell's `2>` redirects only its own error stream, so it does not
# intercept this; OS-level redirection of the whole process still does. Do not
# "fix" this back to Write-Error without re-reading that trade-off.
#
# Deliberately NOT [CmdletBinding()] + ValueFromRemainingArguments: named binding
# runs before remaining-argument collection, and common parameters are prefix-
# matched, so glab's own short flags get eaten — `-d` (--description) binds to
# -Debug and vanishes, `-R` (--repo) fails to bind at all. A bare function's
# $args is the only PowerShell shape equivalent to bash's "$@".

function glab {
    if (-not $env:GITLAB_HOST) {
        $global:LASTEXITCODE = 1
        [Console]::Error.WriteLine('glab: GITLAB_HOST 未設定；不設會連向 gitlab.com 並回 401。見 docs/gitlab-corp-access.md')
        return
    }

    # config store 是 glab 的第二條憑證來源，明文 YAML 且永久落地。`glab auth login`
    # 與不帶 --global 的 `glab config set token …` 都繞過這個 wrapper 直接寫它，所以
    # 「刻意不使用 config store」這條約定被破壞時，沒有任何東西會發出聲音 —— 2026-08-28
    # 就是靠人工翻檔才發現一顆躺了不知多久的明文權杖。
    #
    # 只擋不改：自動清掉會讓「權杖曾經落地、必須輪替」這個唯一重要的後果無聲消失。
    # 位置在 vault 讀取之前，讓一個注定被拒絕的呼叫不觸發 gopass 的密碼提示。
    $configDir = if ($env:GLAB_CONFIG_DIR) { $env:GLAB_CONFIG_DIR }
                 else { Join-Path (Join-Path $HOME '.config') 'glab-cli' }
    $stores = @(Join-Path $configDir 'config.yml')
    # --absolute-git-dir 而非 --git-dir：後者回相對路徑，訊息裡的檔案位置會隨當下的
    # cwd 而變，貼給別人時失去意義。git 不在 PATH 上時只查 global store —— repo-local
    # store 位於 .git 之下，沒有 git 也就沒有那個目錄。
    $gitDir = if (Get-Command git -CommandType Application -ErrorAction SilentlyContinue) {
        & git rev-parse --absolute-git-dir 2>$null
    }
    if ($gitDir) { $stores += (Join-Path (Join-Path $gitDir 'glab-cli') 'config.yml') }
    foreach ($store in $stores) {
        if (-not (Test-Path -LiteralPath $store -PathType Leaf)) { continue }
        # 冒號後必須有非空白字元：glab 對未設定的 host 會留下空的 `token:`，而它自帶的
        # 說明註解（`# Your GitLab access token…`）去除前導空白後以 # 開頭，兩者都不命中。
        # job_token 要單獨列出 —— `^token:` 匹配不到它，而 CI job token 一樣是憑證。
        # -CaseSensitive 不可省：Select-String 預設不分大小寫，而 bash 版的 grep -E 分，
        # 少了它兩邊對 `Token:` 給出相反的答案，而沒有任何測試釘得住這個差異。
        if (-not (Select-String -LiteralPath $store -Pattern '^\s*(token|job_token):\s*\S' -CaseSensitive -Quiet)) { continue }
        $global:LASTEXITCODE = 1
        [Console]::Error.WriteLine(('glab: config store 內有明文 token（{0}）。wrapper 於呼叫當下自 vault 取，config store 不該存 —— 這顆是 glab auth login 或 glab config set 寫的。該 token 已明文落地，請輪替；清除指令要繞過本 wrapper（否則被這道守衛自己擋下），見 docs/gitlab-corp-access.md' -f $store))
        return
    }

    $token = $null
    if (Get-Command gopass -CommandType Application -ErrorAction SilentlyContinue) {
        $token = & gopass show -o gitlab/corp-token 2>$null
        if ($LASTEXITCODE -ne 0) { $token = $null }
    }
    if (-not $token) { $token = $env:GITLAB_TOKEN }
    if (-not $token) {
        $global:LASTEXITCODE = 1
        [Console]::Error.WriteLine('glab: no token (vault entry gitlab/corp-token unreadable and GITLAB_TOKEN unset)')
        return
    }

    # -CommandType Application skips this function, so no recursion. Select-Object
    # is load-bearing: Get-Command returns EVERY glab on PATH, and `.Source` on a
    # multi-element result yields the paths joined into one unrunnable string.
    $exe = Get-Command glab -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $exe) {
        # 127, not 1: this is the "command not found" condition, which is what bash
        # would report here (it has no such guard -- `command glab` surfaces 127
        # itself) and what 96-chezmoi-guard.ps1 uses for the same case. The other
        # two guards mirror an explicit `return 1` in the bash version.
        $global:LASTEXITCODE = 127
        [Console]::Error.WriteLine('glab: binary not on PATH (expected ~/.local/bin/glab.exe from the chezmoi external)')
        return
    }

    $snapshot = [Environment]::GetEnvironmentVariable('GITLAB_TOKEN', 'Process')
    try {
        $env:GITLAB_TOKEN = $token
        & $exe.Source @args
    }
    finally {
        if ($null -eq $snapshot) {
            Remove-Item 'Env:\GITLAB_TOKEN' -ErrorAction SilentlyContinue
        } else {
            [Environment]::SetEnvironmentVariable('GITLAB_TOKEN', $snapshot, 'Process')
        }
    }
}
