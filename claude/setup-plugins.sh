#!/usr/bin/env bash
# Claude Code Plugin 安裝腳本 (Linux/macOS)
# 安裝 marketplace、plugin 及全域指令

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
total_steps=6

echo "=== Claude Code Plugin Setup ==="

# 檢查 claude 指令是否可用
if ! command -v claude &>/dev/null; then
    echo "ERROR: claude command not found. Please install Claude Code first." >&2
    exit 1
fi

# 1. 新增 superpowers marketplace
echo ""
echo "[1/$total_steps] Adding superpowers marketplace..."
claude plugin marketplace add obra/superpowers-marketplace
echo "  Done."

# 2. 安裝 superpowers plugin (from official marketplace)
echo ""
echo "[2/$total_steps] Installing superpowers plugin..."
claude plugin install superpowers
echo "  Done."

# 3. Clone subtask plugin
echo ""
echo "[3/$total_steps] Installing subtask plugin..."
subtask_dir="$HOME/.claude/plugins/subtask"
if [ -d "$subtask_dir" ]; then
    echo "  subtask already exists, pulling latest..."
    git -C "$subtask_dir" pull
else
    git clone https://github.com/zippoxer/subtask.git "$subtask_dir"
fi
echo "  Done."

# 4. 複製全域 CLAUDE.md
echo ""
echo "[4/$total_steps] Installing global CLAUDE.md..."
claude_md="$script_dir/CLAUDE.md"
target_dir="$HOME/.claude"
target_file="$target_dir/CLAUDE.md"
mkdir -p "$target_dir"
if [ -f "$target_file" ]; then
    echo "  ~/.claude/CLAUDE.md already exists, backing up..."
    cp "$target_file" "$target_file.bak"
fi
cp "$claude_md" "$target_file"
echo "  Done."

# 5. 複製 ensure-openspec.sh 到 ~/.local/bin/
echo ""
echo "[5/$total_steps] Installing ensure-openspec.sh to ~/.local/bin/..."
mkdir -p "$HOME/.local/bin"
cp "$script_dir/ensure-openspec.sh" "$HOME/.local/bin/ensure-openspec.sh"
chmod +x "$HOME/.local/bin/ensure-openspec.sh"
echo "  Done."

# 6. 複製 ensure-openspec.md 到 ~/.claude/commands/
echo ""
echo "[6/$total_steps] Installing /ensure-openspec skill..."
mkdir -p "$HOME/.claude/commands"
cp "$script_dir/commands/ensure-openspec.md" "$HOME/.claude/commands/ensure-openspec.md"
echo "  Done."

echo ""
echo "=== Setup complete ==="
echo "Restart Claude Code to activate plugins."
echo ""
echo "OpenSpec is now available on-demand via /ensure-openspec skill."
