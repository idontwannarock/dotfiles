# Claude Code Plugin 安裝腳本 (Windows)
# 安裝 marketplace、plugin 及全域指令

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir = Split-Path -Parent $scriptDir
$totalSteps = 9

Write-Host "=== Claude Code Plugin Setup ===" -ForegroundColor Cyan

# 檢查 claude 指令是否可用
if (-not (Get-Command "claude" -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: claude command not found. Please install Claude Code first." -ForegroundColor Red
    exit 1
}

# 1. 新增 superpowers marketplace
Write-Host "`n[1/$totalSteps] Adding superpowers marketplace..." -ForegroundColor Yellow
try {
    $ErrorActionPreference = "Continue"
    $output = claude plugin marketplace add obra/superpowers-marketplace 2>&1 | Out-String
    $ErrorActionPreference = "Stop"
    if ($LASTEXITCODE -ne 0 -and $output -match 'already installed') {
        Write-Host "  Already installed, skipping." -ForegroundColor Gray
    } elseif ($LASTEXITCODE -ne 0) {
        throw $output
    }
} catch {
    if ("$_" -match 'already installed') {
        Write-Host "  Already installed, skipping." -ForegroundColor Gray
    } else {
        Write-Host "  ERROR: $_" -ForegroundColor Red
        exit 1
    }
}
Write-Host "  Done." -ForegroundColor Green

# 2. 安裝 superpowers plugin (from official marketplace)
Write-Host "`n[2/$totalSteps] Installing superpowers plugin..." -ForegroundColor Yellow
claude plugin install superpowers
Write-Host "  Done." -ForegroundColor Green

# 3. 複製全域 CLAUDE.md
Write-Host "`n[3/$totalSteps] Installing global CLAUDE.md..." -ForegroundColor Yellow
$claudeMd = Join-Path $scriptDir "CLAUDE.md"
$targetDir = Join-Path $env:USERPROFILE ".claude"
$targetFile = Join-Path $targetDir "CLAUDE.md"
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}
if (Test-Path $targetFile) {
    Write-Host "  ~/.claude/CLAUDE.md already exists, backing up..." -ForegroundColor Gray
    Copy-Item $targetFile "$targetFile.bak" -Force
}
Copy-Item $claudeMd $targetFile -Force
Write-Host "  Done." -ForegroundColor Green

# 4. 複製 ensure-openspec.sh 到 ~/.local/bin/ (WSL 環境用)
Write-Host "`n[4/$totalSteps] Installing ensure-openspec.sh to ~/.local/bin/ (for WSL)..." -ForegroundColor Yellow
$localBin = Join-Path $env:USERPROFILE ".local\bin"
if (-not (Test-Path $localBin)) {
    New-Item -ItemType Directory -Path $localBin -Force | Out-Null
}
$srcScript = Join-Path $scriptDir "ensure-openspec.sh"
Copy-Item $srcScript (Join-Path $localBin "ensure-openspec.sh") -Force
Write-Host "  Done." -ForegroundColor Green

# 5. 複製 ensure-openspec.md 到 ~/.claude/commands/
Write-Host "`n[5/$totalSteps] Installing /ensure-openspec skill..." -ForegroundColor Yellow
$commandsDir = Join-Path $env:USERPROFILE ".claude\commands"
if (-not (Test-Path $commandsDir)) {
    New-Item -ItemType Directory -Path $commandsDir -Force | Out-Null
}
$srcSkill = Join-Path $scriptDir "commands\ensure-openspec.md"
Copy-Item $srcSkill (Join-Path $commandsDir "ensure-openspec.md") -Force
Write-Host "  Done." -ForegroundColor Green

# 6. 複製 opsx commands 到 ~/.claude/commands/opsx/
Write-Host "`n[6/$totalSteps] Installing /opsx commands..." -ForegroundColor Yellow
$opsxSrc = Join-Path $repoDir ".claude\commands\opsx"
$opsxDest = Join-Path $env:USERPROFILE ".claude\commands\opsx"
if (-not (Test-Path $opsxDest)) {
    New-Item -ItemType Directory -Path $opsxDest -Force | Out-Null
}
$copied = Get-ChildItem "$opsxSrc\*.md" | ForEach-Object {
    Copy-Item $_.FullName $opsxDest -Force
    $_
}
Write-Host "  Installed $($copied.Count) commands." -ForegroundColor Gray
Write-Host "  Done." -ForegroundColor Green

# 7. 清除舊版 openspec-* skills
Write-Host "`n[7/$totalSteps] Cleaning up legacy openspec-* skills..." -ForegroundColor Yellow
$skillsDir = Join-Path $env:USERPROFILE ".claude\skills"
$legacyDirs = @()
if (Test-Path $skillsDir) {
    $legacyDirs = @(Get-ChildItem -Path $skillsDir -Directory -Filter "openspec-*" -ErrorAction SilentlyContinue)
}
if ($legacyDirs.Count -gt 0) {
    $legacyDirs | ForEach-Object { Remove-Item $_.FullName -Recurse -Force }
    Write-Host "  Removed $($legacyDirs.Count) legacy skill(s)." -ForegroundColor Gray
} else {
    Write-Host "  No legacy skills found." -ForegroundColor Gray
}
Write-Host "  Done." -ForegroundColor Green

# 8. 修復 plugin hook 路徑問題 (Windows: backslash → cygpath workaround)
Write-Host "`n[8/$totalSteps] Fixing plugin hook paths for Windows..." -ForegroundColor Yellow
$pluginCache = Join-Path $env:USERPROFILE ".claude\plugins\cache"
if (Test-Path $pluginCache) {
    $hooksFiles = Get-ChildItem -Path $pluginCache -Recurse -Filter "hooks.json" | Where-Object {
        $_.FullName -match "\\hooks\\hooks\.json$"
    }
    foreach ($file in $hooksFiles) {
        $content = Get-Content $file.FullName -Raw
        # Replace ${CLAUDE_PLUGIN_ROOT}/path/to/script.sh with cygpath wrapper
        # Match commands that directly reference CLAUDE_PLUGIN_ROOT without already being wrapped
        if ($content -match '\$\{CLAUDE_PLUGIN_ROOT\}/' -and $content -notmatch 'cygpath') {
            $lines = $content -split "`n"
            $result = @()
            foreach ($line in $lines) {
                if ($line -match '"command"\s*:\s*"\$\{CLAUDE_PLUGIN_ROOT\}/(.+)"' -and $line -notmatch 'cygpath') {
                    $scriptPath = $Matches[1]
                    $hasComma = $line.TrimEnd().EndsWith(',')
                    $indent = $line -replace '^(\s*).*', '$1'
                    $newCmd = "bash -c 'FIXED_ROOT=`$(cygpath -u \`"`${CLAUDE_PLUGIN_ROOT}\`" 2>/dev/null || echo \`"`${CLAUDE_PLUGIN_ROOT}\`"); \`"`$FIXED_ROOT/$scriptPath\`"'"
                    $comma = if ($hasComma) { ',' } else { '' }
                    $result += "${indent}`"command`": `"$newCmd`"$comma"
                } else {
                    $result += $line
                }
            }
            $result -join "`n" | Set-Content $file.FullName -NoNewline -Encoding UTF8
            Write-Host "  Patched: $($file.FullName)" -ForegroundColor Gray
        } else {
            Write-Host "  Already patched or no fix needed: $($file.FullName)" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "  Plugin cache not found, skipping." -ForegroundColor Gray
}
Write-Host "  Done." -ForegroundColor Green

# 9. 修復 plugin hook 腳本 CRLF 問題 (Windows: CRLF → LF)
Write-Host "`n[9/$totalSteps] Fixing plugin hook script line endings..." -ForegroundColor Yellow
if (Get-Command "dos2unix" -ErrorAction SilentlyContinue) {
    $shFiles = @(Get-ChildItem -Path $pluginCache -Recurse -Filter "*.sh" -ErrorAction SilentlyContinue)
    $ErrorActionPreference = "Continue"
    foreach ($file in $shFiles) {
        dos2unix $file.FullName 2>$null
    }
    $ErrorActionPreference = "Stop"
    Write-Host "  Converted $($shFiles.Count) .sh files to LF." -ForegroundColor Gray
} else {
    Write-Host "  dos2unix not found, skipping. Install with: scoop install dos2unix" -ForegroundColor Yellow
}
Write-Host "  Done." -ForegroundColor Green

Write-Host "`n=== Setup complete ===" -ForegroundColor Cyan
Write-Host "Restart Claude Code to activate plugins."
Write-Host ""
Write-Host "OpenSpec is now available on-demand via /ensure-openspec skill."
Write-Host "OPSX commands (/opsx:*) are installed globally."
