#!/usr/bin/env bash
# ensure-openspec.sh — 檢查/安裝 OpenSpec CLI 並初始化當前專案
# Exit code: 0 = 成功, 非 0 = 有錯誤需要人工處理

set -euo pipefail

# 載入 nvm（如有）
if ! command -v npm &>/dev/null; then
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
fi

# --- Step 1: 確認 OpenSpec CLI 已安裝 ---
if command -v openspec &>/dev/null; then
    echo "[openspec] CLI already installed: $(openspec --version 2>/dev/null || echo 'unknown version')"
else
    echo "[openspec] CLI not found, installing..."
    if ! command -v npm &>/dev/null; then
        echo "ERROR: npm not found. Please install Node.js first." >&2
        exit 1
    fi
    npm install -g @fission-ai/openspec
    echo "[openspec] CLI installed: $(openspec --version 2>/dev/null || echo 'unknown version')"
fi

# --- Step 2: 確認當前專案已初始化 ---
if [ -d ".openspec" ]; then
    echo "[openspec] Project already initialized, running update..."
    openspec update
    echo "[openspec] Update complete."
else
    echo "[openspec] Project not initialized, running init..."
    openspec init --tools claude
    echo "[openspec] Init complete."
fi

echo ""
echo "[openspec] Done. OpenSpec is ready in this project."
