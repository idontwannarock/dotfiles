#!/bin/bash
#
# Search for worklogs repo and set WORKLOGS_PATH environment variable.
#
# This script searches for a git repository named "worklogs" and adds
# WORKLOGS_PATH to ~/.bashrc for the current user.
#
# Search order:
#   1. $HOME (depth 4)
#   2. /home (depth 5)
#   3. User-accessible paths: /opt, /usr/local, /var (depth 4)
#   4. / (depth 6, excluding system directories)
#
# Usage:
#   ./set-worklogs-path.sh

# Already set and valid?
if [ -n "$WORKLOGS_PATH" ] && [ -d "$WORKLOGS_PATH/.git" ]; then
    echo -e "\033[32mWORKLOGS_PATH already set: $WORKLOGS_PATH\033[0m"
    exit 0
fi

find_worklogs_in() {
    local search_path="$1"
    local max_depth="$2"
    local excludes="${3:-}"

    [ ! -d "$search_path" ] && return 1

    local find_cmd="find \"$search_path\" -maxdepth $max_depth -type d -name \"worklogs\" 2>/dev/null"

    if [ -n "$excludes" ]; then
        find_cmd="find \"$search_path\" -maxdepth $max_depth -type d \\( $excludes \\) -prune -o -type d -name \"worklogs\" -print 2>/dev/null"
    fi

    eval "$find_cmd" | while read -r dir; do
        if [ -d "$dir/.git" ]; then
            echo "$dir"
            return 0
        fi
    done
}

find_worklogs() {
    local found=""

    # 1. Search in $HOME first
    echo -e "\033[36mSearching in $HOME...\033[0m" >&2
    found=$(find_worklogs_in "$HOME" 4)
    if [ -n "$found" ]; then
        echo "$found"
        return 0
    fi

    # 2. Search in /home (for other user directories)
    echo -e "\033[36mSearching in /home...\033[0m" >&2
    found=$(find_worklogs_in "/home" 5)
    if [ -n "$found" ]; then
        echo "$found"
        return 0
    fi

    # 3. Search in user-accessible paths
    local user_paths="/opt /usr/local /var"
    for path in $user_paths; do
        echo -e "\033[36mSearching in $path...\033[0m" >&2
        found=$(find_worklogs_in "$path" 4)
        if [ -n "$found" ]; then
            echo "$found"
            return 0
        fi
    done

    # 4. Search from root, excluding system directories
    echo -e "\033[36mSearching from / (this may take a moment)...\033[0m" >&2
    local sys_excludes="-name proc -o -name sys -o -name dev -o -name run -o -name snap -o -name boot -o -name lib -o -name lib64 -o -name bin -o -name sbin -o -name usr -o -name etc -o -name var -o -name tmp -o -name lost+found -o -name mnt -o -name media -o -name home -o -name opt"
    found=$(find_worklogs_in "/" 6 "$sys_excludes")
    if [ -n "$found" ]; then
        echo "$found"
        return 0
    fi

    return 1
}

repo_path=$(find_worklogs)

if [ -n "$repo_path" ]; then
    # Add to ~/.bashrc if not already present
    if ! grep -q "^export WORKLOGS_PATH=" ~/.bashrc 2>/dev/null; then
        echo "" >> ~/.bashrc
        echo "# Worklogs path" >> ~/.bashrc
        echo "export WORKLOGS_PATH=\"$repo_path\"" >> ~/.bashrc
    else
        # Update existing entry
        sed -i "s|^export WORKLOGS_PATH=.*|export WORKLOGS_PATH=\"$repo_path\"|" ~/.bashrc
    fi

    export WORKLOGS_PATH="$repo_path"

    echo ""
    echo -e "\033[32mFound and configured: $repo_path\033[0m"
    echo -e "\033[33mRestart your shell or run: source ~/.bashrc\033[0m"
else
    echo ""
    echo -e "\033[31mworklogs repo not found.\033[0m"
    echo -e "\033[33mYou can set it manually by adding to ~/.bashrc:\033[0m"
    echo -e "\033[90m  export WORKLOGS_PATH=\"/path/to/worklogs\"\033[0m"
    exit 1
fi
