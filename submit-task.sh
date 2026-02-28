#!/bin/bash
# submit-task.sh — Submit tasks to Claude Code in a GitHub Codespace (Max Plan)
#
# First time: run --auth to authenticate with your Max plan
# Then: submit tasks normally
#
# Prerequisites:
#   - gh cli installed and authenticated
#   - A codespace running with Claude Code installed

set -e

CODESPACE_NAME=""  # Leave empty to auto-detect

# Remote commands use ~/run-in-workspace.sh to cd to the correct directory
# (installed by .devcontainer/setup.sh)
RW="run-in-workspace.sh"

# ─── Colours ─────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

info()  { echo -e "${BLUE}ℹ️  $*${NC}"; }
ok()    { echo -e "${GREEN}✅ $*${NC}"; }
warn()  { echo -e "${YELLOW}⚠️  $*${NC}"; }
err()   { echo -e "${RED}❌ $*${NC}" >&2; }
header(){ echo -e "${CYAN}$*${NC}"; }

# ─── Find or create codespace ───────────────────────────────────────────
get_codespace() {
    if [ -n "$CODESPACE_NAME" ]; then
        echo "$CODESPACE_NAME"
        return
    fi

    local cs
    cs=$(gh codespace list --json name,state,repository \
        -q '.[] | select(.state=="Available") | .name' | head -1)

    if [ -z "$cs" ]; then
        warn "No running codespace found."
        echo ""
        info "Your codespaces:"
        gh codespace list
        echo ""
        read -rp "Enter codespace name (or 'new' to create one): " cs

        if [ "$cs" = "new" ]; then
            read -rp "Repository (owner/repo): " REPO
            info "Creating codespace for $REPO..."
            cs=$(gh codespace create --repo "$REPO" --machine basicLinux32gb \
                --devcontainer-path .devcontainer/devcontainer.json \
                --json -q '.name')
            ok "Created codespace: $cs"
            info "Waiting for setup to complete..."
            sleep 30
        fi
    fi

    echo "$cs"
}

# ─── Auth ────────────────────────────────────────────────────────────────
do_auth() {
    local cs
    cs=$(get_codespace)
    [ -z "$cs" ] && { err "No codespace available"; exit 1; }

    header ""
    header "════════════════════════════════════════════════════════"
    header "  🔐 Max Plan Authentication"
    header "════════════════════════════════════════════════════════"
    echo ""
    info "Opening an interactive SSH session to your codespace."
    info "Claude Code will start and prompt you to authenticate."
    echo ""
    echo "  1. Select 'Claude account with subscription'"
    echo "  2. A login URL will appear — open it in your browser"
    echo "  3. Authorise the app"
    echo "  4. Copy the auth code and paste it back in the terminal"
    echo "  5. Once authenticated, type /exit or Ctrl+C to close"
    echo ""
    info "Your credentials will persist across codespace rebuilds."
    echo ""
    read -rp "Press Enter to continue..." _

    # SSH in, resolve the workdir, then launch claude
    gh codespace ssh -c "$cs" -- "$RW" claude

    # Trigger credential backup
    gh codespace ssh -c "$cs" -- "$RW" bash .devcontainer/save-creds.sh 2>/dev/null || true

    echo ""
    ok "Authentication complete! Credentials saved."
    info "You can now submit tasks with: $0 'your task description'"
}

# ─── Check auth ──────────────────────────────────────────────────────────
check_auth() {
    local cs
    cs=$(get_codespace)
    [ -z "$cs" ] && { err "No codespace available"; exit 1; }

    info "Checking authentication status..."

    gh codespace ssh -c "$cs" -- bash -c '
        echo ""
        if [ -f "$HOME/.claude/.credentials.json" ]; then
            echo "✅ OAuth credentials found at ~/.claude/.credentials.json"
        else
            echo "❌ No credentials at ~/.claude/.credentials.json"
        fi
        if [ -f "$HOME/.claude-persist/.credentials.json" ]; then
            echo "✅ Persistent backup exists (survives rebuilds)"
        else
            echo "⚠️  No persistent backup yet"
        fi
        if [ -f "$HOME/.config/claude-code/auth.json" ]; then
            echo "✅ Auth token at ~/.config/claude-code/auth.json"
        fi
        if [ -f "$HOME/.sandbox-workdir" ]; then
            echo "📁 Workspace: $(cat "$HOME/.sandbox-workdir")"
        else
            echo "⚠️  Workspace path not saved (setup may not have completed)"
        fi
        echo ""
    '
}

# ─── Submit task ─────────────────────────────────────────────────────────
submit_task() {
    local task="$1"
    local wait_flag="$2"
    local cs

    cs=$(get_codespace)
    [ -z "$cs" ] && { err "No codespace available"; exit 1; }

    info "Submitting task to codespace: $cs"
    echo ""
    echo "📋 Task: $task"
    echo ""

    # Escape single quotes in the task for safe shell passing
    local escaped_task="${task//\'/\'\\\'\'}"

    if [ "$wait_flag" = "--wait" ]; then
        gh codespace ssh -c "$cs" -- "$RW" bash task-runner.sh "$escaped_task"
    else
        gh codespace ssh -c "$cs" -- "$RW" bash -c "nohup bash task-runner.sh '$escaped_task' > /dev/null 2>&1 &"
        ok "Task submitted in background."
        info "Check results with: $0 --list-results"
    fi
}

# ─── List results ────────────────────────────────────────────────────────
list_results() {
    local cs
    cs=$(get_codespace)
    [ -z "$cs" ] && { err "No codespace available"; exit 1; }

    info "Results from codespace: $cs"
    echo ""

    gh codespace ssh -c "$cs" -- "$RW" bash -c '
        for dir in results/task-*/; do
            [ -d "$dir" ] || continue
            meta="$dir/task-meta.json"
            if [ -f "$meta" ]; then
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                jq -r "\"📋 \(.task_id) [\(.status)]\n   Task: \(.task)\n   Duration: \(.duration_seconds // \"running\")s\"" "$meta" 2>/dev/null
            fi
        done
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    '
}

# ─── Fetch specific result ───────────────────────────────────────────────
fetch_result() {
    local task_id="$1"
    local cs
    cs=$(get_codespace)
    [ -z "$cs" ] && { err "No codespace available"; exit 1; }

    info "Fetching result for: $task_id"
    echo ""
    gh codespace ssh -c "$cs" -- "$RW" cat "results/$task_id/response.txt"
}

# ─── Interactive ─────────────────────────────────────────────────────────
open_interactive() {
    local cs
    cs=$(get_codespace)
    [ -z "$cs" ] && { err "No codespace available"; exit 1; }

    info "Opening interactive Claude Code session..."
    gh codespace ssh -c "$cs" -- "$RW" claude
}

# ─── Pull results ───────────────────────────────────────────────────────
pull_results() {
    local cs
    cs=$(get_codespace)
    [ -z "$cs" ] && { err "No codespace available"; exit 1; }

    # Get the remote workspace path
    local remote_workdir
    remote_workdir=$(gh codespace ssh -c "$cs" -- bash -c 'cat "$HOME/.sandbox-workdir" 2>/dev/null || find /workspaces -maxdepth 1 -mindepth 1 -type d | head -1')

    local dest="./codespace-results"
    mkdir -p "$dest"

    info "Downloading results from $remote_workdir/results/..."
    gh codespace cp -c "$cs" -r "remote:${remote_workdir}/results/" "$dest/"
    ok "Results downloaded to $dest"
}

# ─── Main ────────────────────────────────────────────────────────────────
case "${1:-}" in
    --auth|-a)
        do_auth
        ;;
    --check|-c)
        check_auth
        ;;
    --list-results|-l)
        list_results
        ;;
    --fetch|-f)
        fetch_result "$2"
        ;;
    --interactive|-i)
        open_interactive
        ;;
    --pull|-p)
        pull_results
        ;;
    --help|-h)
        echo ""
        header "Claude Code Codespace Task Submitter (Max Plan)"
        echo ""
        echo "First-time setup:"
        echo "  $0 --auth                   Log in with your Max plan"
        echo "  $0 --check                  Verify auth status"
        echo ""
        echo "Submit tasks:"
        echo "  $0 'task description'        Submit task (async)"
        echo "  $0 'task' --wait             Submit and wait for result"
        echo ""
        echo "Manage results:"
        echo "  $0 --list-results            List completed tasks"
        echo "  $0 --fetch <task-id>         Fetch a specific result"
        echo "  $0 --pull                    Download all results locally"
        echo ""
        echo "Other:"
        echo "  $0 --interactive             Open interactive Claude session"
        echo "  $0 --help                    Show this help"
        echo ""
        ;;
    "")
        err "No task provided. Use --help for usage."
        exit 1
        ;;
    *)
        submit_task "$1" "$2"
        ;;
esac
