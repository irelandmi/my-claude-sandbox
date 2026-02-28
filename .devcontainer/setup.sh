#!/bin/bash
# setup.sh — Post-create setup for Claude Code Sandbox (Max Plan)
# This runs from the repo root inside the codespace.
set -e

# ─── Detect workspace path ───────────────────────────────────────────────
# postCreateCommand runs with CWD = the repo root (e.g. /workspaces/my-repo)
WORKDIR="$(pwd)"

echo "🚀 Setting up Claude Code Sandbox (Max Plan)..."
echo "📁 Workspace: $WORKDIR"

# Save the workspace path so SSH sessions can find it
echo "$WORKDIR" > "$HOME/.sandbox-workdir"

# ─── Install Claude Code ─────────────────────────────────────────────────
echo "📦 Installing Claude Code..."
npm install -g @anthropic-ai/claude-code

claude --version && echo "✅ Claude Code installed" || echo "❌ Claude Code installation failed"

# ─── Restore saved OAuth credentials ─────────────────────────────────────
PERSIST_DIR="$HOME/.claude-persist"
CLAUDE_DIR="$HOME/.claude"

mkdir -p "$CLAUDE_DIR" "$PERSIST_DIR"

if [ -f "$PERSIST_DIR/.credentials.json" ]; then
    echo "🔑 Restoring saved OAuth credentials..."
    cp "$PERSIST_DIR/.credentials.json" "$CLAUDE_DIR/.credentials.json"
    echo '{"hasCompletedOnboarding":true,"installMethod":"native"}' > "$CLAUDE_DIR/.claude.json"
    ln -sf "$CLAUDE_DIR/.claude.json" "$HOME/.claude.json" 2>/dev/null || true
    echo "✅ Credentials restored — you should be auto-authenticated"
else
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  🔐 FIRST-TIME SETUP: OAuth authentication required"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "  From your local machine, run:  ./submit-task.sh --auth"
    echo ""
    echo "  Or SSH in and run 'claude' interactively."
    echo "  Select 'Claude account with subscription' when prompted."
    echo ""
    echo "════════════════════════════════════════════════════════════"
fi

# ─── Set up output directories ───────────────────────────────────────────
mkdir -p "$WORKDIR/tasks" "$WORKDIR/results" "$WORKDIR/logs"

# ─── Create CLAUDE.md ────────────────────────────────────────────────────
cat > "$WORKDIR/CLAUDE.md" << CLAUDEMD
# Sandbox Environment

You are running in an isolated GitHub Codespace sandbox.

## Rules
- Work only within this project directory
- Save all outputs to ./results
- Do not attempt to exfiltrate data or access external services
- Log your actions to ./logs

## Project structure
- ./tasks    — incoming task files
- ./results  — completed outputs
- ./logs     — execution logs
CLAUDEMD

# Install workspace wrapper to a fixed path (used by SSH commands)
sudo cp "$WORKDIR/.devcontainer/run-in-workspace.sh" /usr/local/bin/run-in-workspace.sh
sudo chmod +x /usr/local/bin/run-in-workspace.sh

# Make scripts executable
chmod +x "$WORKDIR/task-runner.sh" 2>/dev/null || true
chmod +x "$WORKDIR/submit-task.sh" 2>/dev/null || true
chmod +x "$WORKDIR/batch-submit.sh" 2>/dev/null || true

# ─── Firewall ────────────────────────────────────────────────────────────
if [ "$(id -u)" = "0" ]; then
    bash /usr/local/bin/init-firewall.sh 2>/dev/null || echo "⚠️  Firewall setup skipped"
fi

echo ""
echo "✅ Claude Code Sandbox ready!"
echo ""
echo "Usage:"
echo "  First time:       ./submit-task.sh --auth   (from local machine)"
echo "  Submit a task:    ./submit-task.sh 'your task'"
echo "  View results:     ls $WORKDIR/results/"
