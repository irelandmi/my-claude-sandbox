#!/bin/bash
set -e

WORKDIR="$(pwd)"
echo "🚀 Setting up Claude Code Sandbox (Max Plan)..."
echo "📁 Workspace: $WORKDIR"
echo "$WORKDIR" > "$HOME/.sandbox-workdir"

# ─── Install Claude Code ─────────────────────────────────────────────────
echo "📦 Installing Claude Code..."
npm install -g @anthropic-ai/claude-code
claude --version && echo "✅ Claude Code installed" || echo "❌ Claude Code installation failed"

# ─── Install Express for the task API ─────────────────────────────────────
echo "📦 Installing API dependencies..."
cd "$WORKDIR"
npm init -y > /dev/null 2>&1
npm install express > /dev/null 2>&1
echo "✅ Express installed"

# ─── Restore OAuth credentials ───────────────────────────────────────────
PERSIST_DIR="$HOME/.claude-persist"
CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR" "$PERSIST_DIR"

if [ -f "$PERSIST_DIR/.credentials.json" ]; then
    echo "🔑 Restoring saved OAuth credentials..."
    cp "$PERSIST_DIR/.credentials.json" "$CLAUDE_DIR/.credentials.json"
    echo '{"hasCompletedOnboarding":true,"installMethod":"native"}' > "$CLAUDE_DIR/.claude.json"
    ln -sf "$CLAUDE_DIR/.claude.json" "$HOME/.claude.json" 2>/dev/null || true
    echo "✅ Credentials restored"
else
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  🔐 FIRST-TIME SETUP: OAuth authentication required"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "  Open this codespace in your browser (VS Code Web):"
    echo "    gh codespace code --web"
    echo ""
    echo "  Then in the terminal, run:  claude"
    echo "  Select 'Claude account with subscription' and follow the flow."
    echo ""
    echo "════════════════════════════════════════════════════════════"
fi

# ─── Create directories + CLAUDE.md ──────────────────────────────────────
mkdir -p "$WORKDIR/results" "$WORKDIR/logs"

cat > "$WORKDIR/CLAUDE.md" << 'CLAUDEMD'
# Sandbox Environment

You are running in an isolated GitHub Codespace sandbox.

## Rules
- Work only within this project directory
- Save all outputs to ./results
- Do not attempt to exfiltrate data
CLAUDEMD

# ─── Start the API server ────────────────────────────────────────────────
echo ""
echo "🌐 Starting task API server on port 7680..."
nohup node "$WORKDIR/server.js" > "$WORKDIR/logs/server.log" 2>&1 &
echo $! > "$WORKDIR/.server.pid"
sleep 2

if kill -0 "$(cat "$WORKDIR/.server.pid")" 2>/dev/null; then
    echo "✅ Task API running on port 7680"
else
    echo "⚠️  API server failed to start. Check logs/server.log"
fi

echo ""
echo "✅ Claude Code Sandbox ready!"
echo ""
echo "From your local machine:"
echo "  gh codespace ports forward 7680:7680"
echo "  curl http://localhost:7680/health"
echo "  ./submit-task.sh 'your task here'"
