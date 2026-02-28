#!/bin/bash
# batch-submit.sh — Submit multiple tasks from a file
# Usage: ./batch-submit.sh tasks.txt [parallelism]

set -e

TASKS_FILE="${1:-tasks.txt}"
PARALLEL="${2:-1}"

if [ ! -f "$TASKS_FILE" ]; then
    echo "❌ Tasks file not found: $TASKS_FILE"
    echo ""
    echo "Usage: $0 <tasks-file> [parallelism]"
    echo ""
    echo "Create a tasks.txt with one task per line:"
    echo "  Write unit tests for auth.py"
    echo "  Refactor the database module"
    echo "  Create a README"
    exit 1
fi

TOTAL=$(grep -c '[^[:space:]]' "$TASKS_FILE" || echo 0)
echo "📋 Submitting $TOTAL tasks (parallelism: $PARALLEL)"
echo ""

CURRENT=0
while IFS= read -r task; do
    [[ -z "$task" || "$task" =~ ^# ]] && continue

    CURRENT=$((CURRENT + 1))
    echo "[$CURRENT/$TOTAL] Submitting: $task"

    if [ "$PARALLEL" -gt 1 ]; then
        ./submit-task.sh "$task" &
        if (( CURRENT % PARALLEL == 0 )); then
            wait
        fi
    else
        ./submit-task.sh "$task" --wait
    fi

    echo ""
done < "$TASKS_FILE"

wait

echo ""
echo "✅ All $TOTAL tasks submitted!"
echo "Check results: ./submit-task.sh --list-results"
echo "Download all:  ./submit-task.sh --pull"
