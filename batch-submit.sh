#!/bin/bash
# batch-submit.sh — Submit multiple tasks from a file via the HTTP API
# Usage: ./batch-submit.sh tasks.txt
set -e

API="http://localhost:7680"
TASKS_FILE="${1:-tasks.txt}"

if [ ! -f "$TASKS_FILE" ]; then
    echo "❌ Tasks file not found: $TASKS_FILE"
    echo "Usage: $0 <tasks-file>"
    echo ""
    echo "One task per line, lines starting with # are skipped."
    exit 1
fi

if ! curl -s --max-time 3 "$API/health" > /dev/null 2>&1; then
    echo "❌ API not reachable. Run: gh codespace ports forward 7680:7680"
    exit 1
fi

TOTAL=$(grep -c '[^[:space:]]' "$TASKS_FILE" || echo 0)
echo "📋 Submitting $TOTAL tasks..."
echo ""

CURRENT=0
while IFS= read -r task; do
    [[ -z "$task" || "$task" =~ ^# ]] && continue
    CURRENT=$((CURRENT + 1))

    result=$(curl -s -X POST "$API/tasks" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg t "$task" '{task: $t}')")

    task_id=$(echo "$result" | jq -r '.task_id')
    echo "[$CURRENT/$TOTAL] $task_id — $task"
done < "$TASKS_FILE"

echo ""
echo "✅ All $TOTAL tasks submitted!"
echo "Check progress: ./submit-task.sh --list"
