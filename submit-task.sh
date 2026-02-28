#!/bin/bash
# submit-task.sh — Submit tasks to Claude Code via HTTP API (no SSH needed)
#
# Setup:
#   1. Create codespace: gh codespace create --repo you/my-sandbox
#   2. First-time auth: gh codespace code --web (then run 'claude' in terminal)
#   3. Forward port:    gh codespace ports forward 7680:7680
#   4. Submit tasks:    ./submit-task.sh 'your task here'

set -e

API="http://localhost:7680"

# ─── Colours ─────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

info()  { echo -e "${BLUE}ℹ️  $*${NC}"; }
ok()    { echo -e "${GREEN}✅ $*${NC}"; }
warn()  { echo -e "${YELLOW}⚠️  $*${NC}"; }
err()   { echo -e "${RED}❌ $*${NC}" >&2; }
header(){ echo -e "${CYAN}$*${NC}"; }

# ─── Check API is reachable ──────────────────────────────────────────────
check_api() {
    if ! curl -s --max-time 3 "$API/health" > /dev/null 2>&1; then
        err "Can't reach the task API at $API"
        echo ""
        echo "  Make sure you're forwarding the port:"
        echo "    gh codespace ports forward 7680:7680"
        echo ""
        echo "  Or run it in the background:"
        echo "    gh codespace ports forward 7680:7680 &"
        echo ""
        exit 1
    fi
}

# ─── Health check ────────────────────────────────────────────────────────
do_health() {
    check_api
    local result
    result=$(curl -s "$API/health")
    echo ""
    header "Claude Code Sandbox Status"
    echo ""
    echo "$result" | jq -r '
        "  Status:         \(.status)",
        "  Claude Version:  \(.claude_version)",
        "  Authenticated:   \(.authenticated)",
        "  Workspace:       \(.workspace)",
        "  Running Tasks:   \(.running_tasks)"
    '
    echo ""
}

# ─── Submit task ─────────────────────────────────────────────────────────
submit_task() {
    local task="$1"
    local model="$2"
    local wait_flag="$3"

    check_api

    local body
    if [ -n "$model" ] && [ "$model" != "--wait" ]; then
        body=$(jq -n --arg t "$task" --arg m "$model" '{task: $t, model: $m}')
    else
        body=$(jq -n --arg t "$task" '{task: $t}')
        # If second arg was --wait, shift it
        if [ "$model" = "--wait" ]; then
            wait_flag="--wait"
        fi
    fi

    info "Submitting task..."
    echo "📋 $task"
    echo ""

    local result
    result=$(curl -s -X POST "$API/tasks" \
        -H "Content-Type: application/json" \
        -d "$body")

    local task_id
    task_id=$(echo "$result" | jq -r '.task_id')

    if [ "$task_id" = "null" ] || [ -z "$task_id" ]; then
        err "Failed to submit task"
        echo "$result" | jq .
        exit 1
    fi

    ok "Submitted: $task_id"

    if [ "$wait_flag" = "--wait" ]; then
        echo ""
        info "Waiting for completion..."

        while true; do
            sleep 3
            local status
            status=$(curl -s "$API/tasks/$task_id" | jq -r '.status')

            if [ "$status" = "completed" ] || [ "$status" = "failed" ]; then
                echo ""
                local full
                full=$(curl -s "$API/tasks/$task_id")

                local duration
                duration=$(echo "$full" | jq -r '.duration_seconds')
                echo "$full" | jq -r '.status' | xargs -I{} echo "  Status:   {}"
                echo "  Duration: ${duration}s"
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "$full" | jq -r '.response // "No response"' | head -40
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                break
            fi

            printf "."
        done
    else
        info "Running in background. Check with: $0 --get $task_id"
    fi
}

# ─── List tasks ──────────────────────────────────────────────────────────
list_tasks() {
    check_api

    local result
    result=$(curl -s "$API/tasks")

    local count
    count=$(echo "$result" | jq -r '.count')

    header "Tasks ($count)"
    echo ""

    echo "$result" | jq -r '.tasks[] |
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        "📋 \(.task_id)  [\(.status)]",
        "   \(.task)",
        "   Duration: \(.duration_seconds // "running")s",
        ""'

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ─── Get task result ─────────────────────────────────────────────────────
get_task() {
    local task_id="$1"
    check_api

    if [ -z "$task_id" ]; then
        err "Usage: $0 --get <task-id>"
        exit 1
    fi

    local result
    result=$(curl -s "$API/tasks/$task_id")

    local status
    status=$(echo "$result" | jq -r '.status')

    if [ "$status" = "null" ]; then
        err "Task not found: $task_id"
        exit 1
    fi

    header "Task: $task_id [$status]"
    echo ""

    echo "$result" | jq -r '
        "  Task:     \(.task)",
        "  Model:    \(.model)",
        "  Status:   \(.status)",
        "  Duration: \(.duration_seconds // "running")s",
        ""'

    if [ "$status" = "completed" ] || [ "$status" = "failed" ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$result" | jq -r '.response // "No response"'
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
}

# ─── Forward port (convenience) ──────────────────────────────────────────
do_forward() {
    info "Forwarding port 7680 from codespace..."
    info "Press Ctrl+C to stop"
    gh codespace ports forward 7680:7680
}

# ─── Auth instructions ───────────────────────────────────────────────────
do_auth() {
    header ""
    header "════════════════════════════════════════════════════════"
    header "  🔐 Max Plan Authentication"
    header "════════════════════════════════════════════════════════"
    echo ""
    echo "  1. Open your codespace in the browser:"
    echo ""
    echo "     gh codespace code --web"
    echo ""
    echo "  2. In the VS Code terminal (Ctrl+\`), run:"
    echo ""
    echo "     claude"
    echo ""
    echo "  3. Select 'Claude account with subscription'"
    echo "  4. Follow the OAuth link and paste the code back"
    echo "  5. Exit Claude (Ctrl+C)"
    echo ""
    echo "  6. Restart the API server to pick up credentials:"
    echo "     In the codespace terminal, run:"
    echo ""
    echo "     kill \$(cat .server.pid) 2>/dev/null; node server.js &"
    echo ""
    echo "  Your credentials will persist across rebuilds."
    echo ""
    header "════════════════════════════════════════════════════════"

    echo ""
    read -rp "Open codespace in browser now? [Y/n] " yn
    if [ "$yn" != "n" ] && [ "$yn" != "N" ]; then
        gh codespace code --web
    fi
}

# ─── Main ────────────────────────────────────────────────────────────────
case "${1:-}" in
    --auth|-a)
        do_auth
        ;;
    --health|-h)
        do_health
        ;;
    --list|-l)
        list_tasks
        ;;
    --get|-g)
        get_task "$2"
        ;;
    --forward|-f)
        do_forward
        ;;
    --help)
        echo ""
        header "Claude Code Task Submitter (Max Plan — HTTP API)"
        echo ""
        echo "Setup:"
        echo "  $0 --auth                     Authenticate with Max plan"
        echo "  $0 --forward                  Forward port from codespace"
        echo "  $0 --health                   Check API + auth status"
        echo ""
        echo "Tasks:"
        echo "  $0 'task description'          Submit task (async)"
        echo "  $0 'task' --wait               Submit and wait for result"
        echo "  $0 'task' claude-opus-4-6      Submit with specific model"
        echo "  $0 --list                      List all tasks"
        echo "  $0 --get <task-id>             Get task result"
        echo ""
        ;;
    "")
        err "No task provided. Use --help for usage."
        exit 1
        ;;
    *)
        submit_task "$1" "$2" "$3"
        ;;
esac
