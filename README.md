# Claude Code Sandbox — Max Plan + HTTP API

Run Claude Code tasks in an isolated GitHub Codespace. No SSH — a lightweight Express API runs inside the codespace and you submit tasks via `curl` over a forwarded port.

## Architecture

```
┌──────────────────┐    port forward (7680)    ┌──────────────────────────┐
│   Your Machine   │ ◀══════════════════════▶  │   GitHub Codespace       │
│                  │                           │                          │
│  submit-task.sh  │──── POST /tasks ────────▶ │  Express API (server.js) │
│  (uses curl)     │                           │         │                │
│                  │◀─── JSON response ─────── │         ▼                │
│                  │                           │  Claude Code (headless)  │
│                  │                           │         │                │
│                  │                           │    results/ + logs/      │
│                  │                           │                          │
│                  │                           │  🔒 Codespace isolation  │
└──────────────────┘                           └──────────────────────────┘
```

## Quick Start

### 1. Push to GitHub

```bash
gh repo create my-claude-sandbox --public --clone
# copy files in
git add -A && git commit -m "Initial setup" && git push
```

### 2. Create the Codespace

```bash
gh codespace create --repo you/my-claude-sandbox --machine basicLinux32gb
```

### 3. Authenticate with Max plan (one time)

```bash
./submit-task.sh --auth
```

This opens the codespace in your browser. In the VS Code terminal, run `claude`, authenticate, then exit.

### 4. Forward the port

```bash
gh codespace ports forward 7680:7680 &
```

### 5. Check it's working

```bash
./submit-task.sh --health
```

### 6. Submit tasks

```bash
# Async
./submit-task.sh "Write a Python fibonacci function with tests"

# Wait for result
./submit-task.sh "Create a FastAPI REST API" --wait

# Use a specific model
./submit-task.sh "Review this codebase" claude-opus-4-6

# List all tasks
./submit-task.sh --list

# Get a specific result
./submit-task.sh --get task-1709012345678-a1b2c3
```

### 7. Batch tasks

```bash
cat > tasks.txt << EOF
Write unit tests for the API endpoints
Create a comprehensive README
Add input validation to all form handlers
EOF

./batch-submit.sh tasks.txt
```

## API Endpoints

| Method | Path | Description |
|---|---|---|
| `POST` | `/tasks` | Submit a task `{"task": "...", "model": "..."}` |
| `GET` | `/tasks` | List all tasks |
| `GET` | `/tasks/:id` | Get task result |
| `GET` | `/tasks/:id/files` | List files in task result dir |
| `GET` | `/health` | Health + auth status |

## Cleanup

```bash
gh codespace stop     # pause
gh codespace delete   # destroy
```
