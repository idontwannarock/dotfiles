# Claude Code Plugin 安裝腳本 (Windows)
# 安裝 marketplace 與 plugin

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== Claude Code Plugin Setup ===" -ForegroundColor Cyan

# 檢查 claude 指令是否可用
if (-not (Get-Command "claude" -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: claude command not found. Please install Claude Code first." -ForegroundColor Red
    exit 1
}

# 1. 新增 superpowers marketplace
Write-Host "`n[1/3] Adding superpowers marketplace..." -ForegroundColor Yellow
claude mcp add-marketplace superpowers-marketplace obra/superpowers-marketplace
Write-Host "  Done." -ForegroundColor Green

# 2. 安裝 superpowers plugin (from official marketplace)
Write-Host "`n[2/3] Installing superpowers plugin..." -ForegroundColor Yellow
claude plugin install superpowers
Write-Host "  Done." -ForegroundColor Green

# 3. Clone subtask plugin
Write-Host "`n[3/3] Installing subtask plugin..." -ForegroundColor Yellow
$subtaskDir = Join-Path $env:USERPROFILE ".claude\plugins\subtask"
if (Test-Path $subtaskDir) {
    Write-Host "  subtask already exists, pulling latest..." -ForegroundColor Gray
    git -C $subtaskDir pull
} else {
    git clone https://github.com/zippoxer/subtask.git $subtaskDir
}
Write-Host "  Done." -ForegroundColor Green

Write-Host "`n=== All plugins installed ===" -ForegroundColor Cyan
Write-Host "Restart Claude Code to activate plugins."
