#!/usr/bin/env bash
# ensure-openspec.sh — 初始化/更新當前專案的 OpenSpec 設定
# 全域安裝由 chezmoi run_once_install-openspec 處理
# Exit code: 0 = 成功, 非 0 = 有錯誤需要人工處理

set -euo pipefail

if ! command -v openspec &>/dev/null; then
    echo "ERROR: openspec CLI not found. Run 'chezmoi apply' or 'npm install -g @fission-ai/openspec' first." >&2
    exit 1
fi

if [ -d ".claude/commands/opsx" ]; then
    echo "[openspec] Project already initialized, running update..."
    openspec update
    echo "[openspec] Update complete."
else
    echo "[openspec] Project not initialized, running init..."
    openspec init --tools claude
    echo "[openspec] Init complete."
fi

echo "[openspec] Done. OpenSpec is ready in this project."
