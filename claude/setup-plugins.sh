#!/usr/bin/env bash
# Claude Code Plugin 安裝腳本 (Linux/macOS)
# 安裝 marketplace、plugin 及全域指令

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_dir="$(cd "$script_dir/.." && pwd)"
total_steps=8

echo "=== Claude Code Plugin Setup ==="

# 檢查 claude 指令是否可用
if ! command -v claude &>/dev/null; then
    echo "ERROR: claude command not found. Please install Claude Code first." >&2
    exit 1
fi

# 1. 新增 superpowers marketplace
echo ""
echo "[1/$total_steps] Adding superpowers marketplace..."
if claude plugin marketplace add obra/superpowers-marketplace 2>&1; then
    echo "  Done."
else
    echo "  Already installed, skipping."
fi

# 2. 安裝 superpowers plugin (from official marketplace)
echo ""
echo "[2/$total_steps] Installing superpowers plugin..."
if claude plugin install superpowers 2>&1; then
    echo "  Done."
else
    echo "  Already installed, skipping."
fi

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

# 7. 複製 opsx commands 到 ~/.claude/commands/opsx/
echo ""
echo "[7/$total_steps] Installing /opsx commands..."
opsx_src="$repo_dir/.claude/commands/opsx"
opsx_dest="$HOME/.claude/commands/opsx"
mkdir -p "$opsx_dest"
cp "$opsx_src"/*.md "$opsx_dest/"
echo "  Installed $(ls "$opsx_dest"/*.md 2>/dev/null | wc -l) commands."
echo "  Done."

# 8. 清除舊版 openspec-* skills
echo ""
echo "[8/$total_steps] Cleaning up legacy openspec-* skills..."
legacy_count=0
for dir in "$HOME/.claude/skills"/openspec-*; do
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        legacy_count=$((legacy_count + 1))
    fi
done
if [ "$legacy_count" -gt 0 ]; then
    echo "  Removed $legacy_count legacy skill(s)."
else
    echo "  No legacy skills found."
fi
echo "  Done."

echo ""
echo "=== Setup complete ==="
echo "Restart Claude Code to activate plugins."
echo ""
echo "OpenSpec is now available on-demand via /ensure-openspec skill."
echo "OPSX commands (/opsx:*) are installed globally."
