#!/bin/bash
#
# Generate ~/.claude/worklog-config.md from WORKLOGS_PATH.
#
# Prerequisites:
#   WORKLOGS_PATH must be set (run set-worklogs-path.sh first)
#
# Usage:
#   ./set-worklog-config.sh

COMPANY="shoalter"
CONFIG_PATH="$HOME/.claude/worklog-config.md"

if [ -z "$WORKLOGS_PATH" ]; then
    echo -e "\033[31mError: WORKLOGS_PATH is not set.\033[0m"
    echo -e "\033[33mRun set-worklogs-path.sh first.\033[0m"
    exit 1
fi

if [ ! -d "$WORKLOGS_PATH/.git" ]; then
    echo -e "\033[31mError: WORKLOGS_PATH ($WORKLOGS_PATH) is not a git repo.\033[0m"
    exit 1
fi

mkdir -p "$(dirname "$CONFIG_PATH")"

cat > "$CONFIG_PATH" << EOF
# Worklog Configuration

- repo: $WORKLOGS_PATH
- company: $COMPANY
EOF

echo -e "\033[32mCreated $CONFIG_PATH\033[0m"
echo -e "\033[90m  repo: $WORKLOGS_PATH\033[0m"
echo -e "\033[90m  company: $COMPANY\033[0m"
