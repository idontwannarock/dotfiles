Set-Alias scoopupdate "$HOME\.local\bin\scoop-interactive-update.ps1"

# Worklog workflow trigger — 觸發遠端 create-daily.yml GitHub Actions workflow
# 與等待 run 完成。不讀 WORKLOGS_PATH、不依賴 CWD、不做本地 git 操作。
# repo hardcoded: idontwannarock/worklogs（與 CLAUDE.md 的 skills 設定一致）
#
# 錯誤回報走 [Console]::Error.WriteLine + 顯式 $global:LASTEXITCODE，避免
# Write-Error 在 caller 設 $ErrorActionPreference='Stop' 時變成 terminating
# error，與 POSIX 版的 printf >&2 + return 1 行為對齊。
function createnewlog {
    [CmdletBinding()]
    param()

    $repo = 'idontwannarock/worklogs'
    $workflow = 'create-daily.yml'

    # Capture the previously most-recent run ID before triggering, so the
    # poll can distinguish the new run from existing history (race window:
    # gh workflow run returns before GitHub indexes the new run record).
    $prevRunId = gh -R $repo run list --workflow=$workflow --limit=1 --json databaseId --jq '.[0].databaseId'
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("error: 查詢既有 run 列表失敗 (gh run list exit=$LASTEXITCODE)")
        $global:LASTEXITCODE = 1
        return
    }

    Write-Host '==> 觸發 Create Daily Worklog workflow...' -ForegroundColor Cyan
    gh -R $repo workflow run $workflow
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("error: 觸發 workflow 失敗 (gh workflow run exit=$LASTEXITCODE)")
        $global:LASTEXITCODE = 1
        return
    }

    # Poll until a NEW run ID appears（最多 10 秒，每秒一次）。
    # 比較 $candidate -ne $prevRunId 避免撞到舊 run（重要：若只檢查
    # 「非空」，prev_id 存在時第一次 poll 會立刻撈到舊 run，把它的歷史
    # 結果當成新 run 的結果回報，造成假成功/假失敗）。
    $runId = $null
    for ($i = 0; $i -lt 10; $i++) {
        Start-Sleep -Seconds 1
        $candidate = gh -R $repo run list --workflow=$workflow --limit=1 --json databaseId --jq '.[0].databaseId'
        if ($LASTEXITCODE -ne 0) {
            [Console]::Error.WriteLine("error: 查詢 run ID 失敗 (gh run list exit=$LASTEXITCODE)")
            $global:LASTEXITCODE = 1
            return
        }
        if ($candidate -and $candidate -ne $prevRunId) {
            $runId = $candidate
            break
        }
    }

    if (-not $runId) {
        [Console]::Error.WriteLine('error: 找不到 workflow run（輪詢 10 秒仍未出現新 run），請到 GitHub Actions 頁面確認')
        $global:LASTEXITCODE = 1
        return
    }

    Write-Host "==> 等待 workflow run #$runId 完成..." -ForegroundColor Cyan
    gh -R $repo run watch $runId --exit-status
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("error: workflow run #$runId 失敗或被取消 (exit=$LASTEXITCODE)")
        # $LASTEXITCODE 已經是 gh run watch 的退出碼，不需要覆寫
        return
    }

    Write-Host '==> Workflow 完成。' -ForegroundColor Green
}
