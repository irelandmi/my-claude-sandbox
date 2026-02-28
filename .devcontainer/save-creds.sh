#!/bin/bash
# save-creds.sh — Backs up OAuth credentials to persistent volume
PERSIST_DIR="$HOME/.claude-persist"
CLAUDE_DIR="$HOME/.claude"
mkdir -p "$PERSIST_DIR"

if [ -f "$CLAUDE_DIR/.credentials.json" ]; then
    cp "$CLAUDE_DIR/.credentials.json" "$PERSIST_DIR/.credentials.json" 2>/dev/null
    echo "🔑 OAuth credentials backed up to persistent volume"
fi

if [ -f "$HOME/.config/claude-code/auth.json" ]; then
    cp "$HOME/.config/claude-code/auth.json" "$PERSIST_DIR/auth.json" 2>/dev/null
fi
