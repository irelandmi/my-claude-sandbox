#!/bin/bash
# setup.sh — Post-create setup for Claude Code Sandbox (Max Plan)
set -e

echo "🚀 Setting up Claude Code Sandbox (Max Plan)..."

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

    # Generate minimal .claude.json to skip onboarding
    echo '{"hasCompletedOnboarding":true,"installMethod":"native"}' > "$CLAUDE_DIR/.claude.json"

    # Also symlink to home dir (some versions look here)
    ln -sf "$CLAUDE_DIR/.claude.json" "$HOME/.claude.json" 2>/dev/null || true

    echo "✅ Credentials restored — you should be auto-authenticated"
else
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  🔐 FIRST-TIME SETUP: OAuth authentication required"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "  Run 'claude' interactively to log in with your Max plan."
    echo "  Choose 'Claude account with subscription' when prompted."
    echo "  Follow the link, authorise, and paste the code back."
    echo ""
    echo "  Your credentials will be saved automatically and persist"
    echo "  across Codespace rebuilds."
    echo ""
    echo "════════════════════════════════════════════════════════════"
fi

# ─── Set up workspace ────────────────────────────────────────────────────
mkdir -p /workspace/tasks /workspace/results /workspace/logs

# Create CLAUDE.md for the sandbox
cat > /workspace/CLAUDE.md << 'CLAUDEMD'
# Sandbox Environment

You are running in an isolated GitHub Codespace sandbox.

## Rules
- Work only within /workspace
- Save all outputs to /workspace/results
- Do not attempt to exfiltrate data or access external services
- Log your actions to /workspace/logs

## Project structure
- /workspace/tasks    — incoming task files
- /workspace/results  — completed outputs
- /workspace/logs     — execution logs
CLAUDEMD

# Make scripts executable
chmod +x /workspace/task-runner.sh 2>/dev/null || true
chmod +x /workspace/submit-task.sh 2>/dev/null || true
chmod +x /workspace/batch-submit.sh 2>/dev/null || true

# ─── Firewall (if running as root) ───────────────────────────────────────
if [ "$(id -u)" = "0" ]; then
    bash /usr/local/bin/init-firewall.sh 2>/dev/null || echo "⚠️  Firewall setup skipped"
fi

echo ""
echo "✅ Claude Code Sandbox ready!"
echo ""
echo "Usage:"
echo "  First time:       claude            (authenticate with Max plan)"
echo "  Submit a task:    ./task-runner.sh 'your task'"
echo "  View results:     ls /workspace/results/"
