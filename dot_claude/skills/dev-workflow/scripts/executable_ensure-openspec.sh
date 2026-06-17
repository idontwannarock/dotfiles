#!/usr/bin/env bash
# ensure-openspec.sh — 初始化/更新當前專案的 OpenSpec 設定
# 全域安裝由 chezmoi run_install-02-npm-tools 處理
# Exit code: 0 = 成功, 非 0 = 有錯誤需要人工處理

set -euo pipefail

if ! command -v openspec &>/dev/null; then
    echo "ERROR: openspec CLI not found. Run 'chezmoi apply' or 'npm install -g @fission-ai/openspec' first." >&2
    exit 1
fi

# Tools to provision. codex gets skills only (no command concept); claude and
# antigravity also emit a command surface (.claude/commands/opsx, .agent/workflows)
# which we prune below to keep a single skill-only surface across all tools.
TOOLS="claude,codex,antigravity"

if [ -d "openspec" ]; then
    echo "[openspec] Project already initialized, refreshing..."
    openspec update
    # 'openspec update' refreshes existing tools but won't add a newly-requested
    # one — re-run init (additive, leaves openspec/ specs untouched) to ensure
    # every tool in $TOOLS is present.
    openspec init --tools "$TOOLS" --force
    echo "[openspec] Refresh complete."
else
    echo "[openspec] Project not initialized, running init..."
    openspec init --tools "$TOOLS"
    echo "[openspec] Init complete."
fi

# Skill-only surface: drop the slash-command / workflow duplicates. Skills are the
# invocation path (see dev-workflow SKILL.md Step 3) — agent/subagent-invocable and
# portable; the /opsx:* commands are just unused clutter. Prune only the openspec-
# namespaced entries so other tools' commands/workflows are left intact.
rm -rf .claude/commands/opsx
rm -f .agent/workflows/opsx-*.md
rmdir .agent/workflows 2>/dev/null || true

echo "[openspec] Done. OpenSpec is ready in this project (claude + codex + antigravity, skill-only)."
