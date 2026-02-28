#!/bin/bash
# run-in-workspace.sh — Resolve workspace dir and run a command there
# Installed to ~/run-in-workspace.sh by setup.sh
# Usage: ~/run-in-workspace.sh <command> [args...]

if [ -f "$HOME/.sandbox-workdir" ]; then
    WORKDIR="$(cat "$HOME/.sandbox-workdir")"
else
    WORKDIR="$(find /workspaces -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -1)"
fi

if [ -z "$WORKDIR" ] || [ ! -d "$WORKDIR" ]; then
    echo "❌ Could not find workspace directory." >&2
    exit 1
fi

cd "$WORKDIR" || exit 1
exec "$@"
