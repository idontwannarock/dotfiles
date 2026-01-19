# 更新 scoop 自身
scoop update

# 取得 scoop status 的結果（已是 ScoopStatus 物件陣列）
$statusOutput = scoop status

# 過濾出需要更新的套件
$updates = $statusOutput | Where-Object {
    $_.'Installed Version' -and $_.'Latest Version' -and $_.'Installed Version' -ne $_.'Latest Version'
}

if (-not $updates -or $updates.Count -eq 0) {
    Write-Host "`n✅ 所有套件都是最新的。"
    exit 0
}

Write-Host "`n🔍 偵測到以下可更新的套件："
foreach ($item in $updates) {
    $app = $item.Name
    $installed = $item.'Installed Version'
    $latest = $item.'Latest Version'
    Write-Host "- $app：$installed → $latest"
}

foreach ($item in $updates) {
    $app = $item.Name
    $installed = $item.'Installed Version'
    $latest = $item.'Latest Version'

    Write-Host "`n$app ($installed → $latest)"
    $response = Read-Host "是否要更新 [$app]? (y/N)"

    if ($response -match '^(y|Y)$') {
        Write-Host "→ 開始更新 $app..."
        scoop update $app
    } else {
        Write-Host "→ 略過 $app"
    }
}

Write-Host "`n🎉 所有選定的套件已處理完畢。"
