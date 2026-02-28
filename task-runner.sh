#!/bin/bash
# task-runner.sh — Execute a task with Claude Code (Max Plan) in headless mode
# Usage: ./task-runner.sh "task description" [model]

set -e

TASK="$1"
MODEL="${2:-claude-sonnet-4-5-20250929}"
TASK_ID="task-$(date +%Y%m%d-%H%M%S)-$$"
RESULT_DIR="/workspace/results/${TASK_ID}"
LOG_FILE="/workspace/logs/${TASK_ID}.log"

if [ -z "$TASK" ]; then
    echo "Usage: ./task-runner.sh 'task description' [model]"
    echo ""
    echo "Models:"
    echo "  claude-sonnet-4-5-20250929  (default, fast)"
    echo "  claude-opus-4-6             (most capable)"
    echo ""
    echo "Examples:"
    echo "  ./task-runner.sh 'Write a Python fibonacci function with tests'"
    echo "  ./task-runner.sh 'Review all .py files and create a summary' claude-opus-4-6"
    exit 1
fi

# ─── Check authentication ────────────────────────────────────────────────
CRED_FILE="$HOME/.claude/.credentials.json"
AUTH_FILE="$HOME/.config/claude-code/auth.json"

if [ ! -f "$CRED_FILE" ] && [ ! -f "$AUTH_FILE" ] && [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "❌ Not authenticated. Run 'claude' interactively first to log in"
    echo "   with your Max plan, then try again."
    echo ""
    echo "   Steps:"
    echo "   1. Run: claude"
    echo "   2. Select 'Claude account with subscription'"
    echo "   3. Follow the auth link and paste the code"
    echo "   4. Exit Claude (Ctrl+C) and re-run this script"
    exit 1
fi

# ─── Set up output dirs ──────────────────────────────────────────────────
mkdir -p "$RESULT_DIR" "$(dirname "$LOG_FILE")"

echo "╔════════════════════════════════════════════════════╗"
echo "║        Claude Code Task Runner (Max Plan)          ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "📋 Task ID:  $TASK_ID"
echo "📝 Task:     $TASK"
echo "🤖 Model:    $MODEL"
echo "📁 Output:   $RESULT_DIR"
echo "📄 Log:      $LOG_FILE"
echo ""
echo "⏳ Executing..."
echo ""

# Record metadata
cat > "${RESULT_DIR}/task-meta.json" << EOF
{
  "task_id": "${TASK_ID}",
  "task": $(echo "$TASK" | jq -Rs .),
  "model": "${MODEL}",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "running"
}
EOF

# ─── Run Claude Code in headless print mode ──────────────────────────────
START_TIME=$(date +%s)

claude --print \
    --dangerously-skip-permissions \
    --model "$MODEL" \
    --output-format json \
    "$TASK" \
    2>"$LOG_FILE" | tee "${RESULT_DIR}/raw-output.json" || {
        echo "⚠️  Claude Code exited with non-zero status"
    }

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Extract text response
if [ -f "${RESULT_DIR}/raw-output.json" ]; then
    jq -r '.result // .content // .message // .' "${RESULT_DIR}/raw-output.json" \
        > "${RESULT_DIR}/response.txt" 2>/dev/null || \
        cp "${RESULT_DIR}/raw-output.json" "${RESULT_DIR}/response.txt"
fi

# Update metadata
cat > "${RESULT_DIR}/task-meta.json" << EOF
{
  "task_id": "${TASK_ID}",
  "task": $(echo "$TASK" | jq -Rs .),
  "model": "${MODEL}",
  "started_at": "$(date -u -d "@$START_TIME" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)",
  "completed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "duration_seconds": ${DURATION},
  "status": "completed"
}
EOF

# Back up credentials after successful run
bash /workspace/.devcontainer/save-creds.sh 2>/dev/null || \
    bash .devcontainer/save-creds.sh 2>/dev/null || true

echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║              Task Complete                         ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "⏱️  Duration:  ${DURATION}s"
echo "📁 Results:   $RESULT_DIR"
echo ""
echo "Files produced:"
ls -la "$RESULT_DIR"
echo ""
echo "Response preview:"
head -20 "${RESULT_DIR}/response.txt" 2>/dev/null || echo "(no text response)"
