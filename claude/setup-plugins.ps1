# Claude Code Plugin 安裝腳本 (Windows)
# 安裝 marketplace、plugin、OpenSpec CLI 及全域指令

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$totalSteps = 5

Write-Host "=== Claude Code Plugin Setup ===" -ForegroundColor Cyan

# 檢查 claude 指令是否可用
if (-not (Get-Command "claude" -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: claude command not found. Please install Claude Code first." -ForegroundColor Red
    exit 1
}

# 檢查 npm 指令是否可用
if (-not (Get-Command "npm" -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: npm command not found. Please install Node.js first." -ForegroundColor Red
    exit 1
}

# 1. 新增 superpowers marketplace
Write-Host "`n[1/$totalSteps] Adding superpowers marketplace..." -ForegroundColor Yellow
claude plugin marketplace add obra/superpowers-marketplace
Write-Host "  Done." -ForegroundColor Green

# 2. 安裝 superpowers plugin (from official marketplace)
Write-Host "`n[2/$totalSteps] Installing superpowers plugin..." -ForegroundColor Yellow
claude plugin install superpowers
Write-Host "  Done." -ForegroundColor Green

# 3. Clone subtask plugin
Write-Host "`n[3/$totalSteps] Installing subtask plugin..." -ForegroundColor Yellow
$subtaskDir = Join-Path $env:USERPROFILE ".claude\plugins\subtask"
if (Test-Path $subtaskDir) {
    Write-Host "  subtask already exists, pulling latest..." -ForegroundColor Gray
    git -C $subtaskDir pull
} else {
    git clone https://github.com/zippoxer/subtask.git $subtaskDir
}
Write-Host "  Done." -ForegroundColor Green

# 4. 安裝 OpenSpec CLI
Write-Host "`n[4/$totalSteps] Installing OpenSpec CLI..." -ForegroundColor Yellow
npm install -g @fission-ai/openspec
Write-Host "  Done." -ForegroundColor Green

# 5. 複製全域 CLAUDE.md
Write-Host "`n[5/$totalSteps] Installing global CLAUDE.md..." -ForegroundColor Yellow
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

Write-Host "`n=== Setup complete ===" -ForegroundColor Cyan
Write-Host "Restart Claude Code to activate plugins."
Write-Host ""
Write-Host "To enable OpenSpec in a project, run:"
Write-Host "  cd <project-dir>; openspec init --tools claude"
