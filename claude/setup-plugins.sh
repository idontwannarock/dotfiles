#!/usr/bin/env bash
# Claude Code Plugin 安裝腳本 (Linux/macOS)
# 安裝 marketplace 與 plugin

set -euo pipefail

echo "=== Claude Code Plugin Setup ==="

# 檢查 claude 指令是否可用
if ! command -v claude &>/dev/null; then
    echo "ERROR: claude command not found. Please install Claude Code first." >&2
    exit 1
fi

# 1. 新增 superpowers marketplace
echo ""
echo "[1/3] Adding superpowers marketplace..."
claude mcp add-marketplace superpowers-marketplace obra/superpowers-marketplace
echo "  Done."

# 2. 安裝 superpowers plugin (from official marketplace)
echo ""
echo "[2/3] Installing superpowers plugin..."
claude plugin install superpowers
echo "  Done."

# 3. Clone subtask plugin
echo ""
echo "[3/3] Installing subtask plugin..."
subtask_dir="$HOME/.claude/plugins/subtask"
if [ -d "$subtask_dir" ]; then
    echo "  subtask already exists, pulling latest..."
    git -C "$subtask_dir" pull
else
    git clone https://github.com/zippoxer/subtask.git "$subtask_dir"
fi
echo "  Done."

echo ""
echo "=== All plugins installed ==="
echo "Restart Claude Code to activate plugins."
