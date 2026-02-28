# Claude Code Sandbox — Max Plan + GitHub Codespaces

Run Claude Code tasks in an isolated GitHub Codespace using your Max plan subscription. No API key needed — authenticate once with OAuth and credentials persist across rebuilds.

## Quick Start

### 1. Push to GitHub

```bash
gh repo create my-claude-sandbox --public --clone
# copy these files into the repo
git add -A && git commit -m "Initial sandbox setup" && git push
```

### 2. Create the Codespace

```bash
gh codespace create --repo yourname/my-claude-sandbox --machine basicLinux32gb
```

Wait ~1 minute for post-create setup to install Claude Code.

### 3. Authenticate with your Max plan (one time)

```bash
./submit-task.sh --auth
```

This SSHs into the codespace and launches Claude Code interactively. Select **"Claude account with subscription"**, follow the OAuth link, and paste the code back. Credentials are saved to a persistent Docker volume and restored automatically on rebuilds.

### 4. Submit tasks

```bash
./submit-task.sh "Write a Python web scraper for HN" --wait
./submit-task.sh "Create a FastAPI REST API"
./submit-task.sh --list-results
./submit-task.sh --fetch task-20250228-143022-1234
./submit-task.sh --pull
./submit-task.sh --interactive
```

## How It Works

All SSH commands resolve the workspace path dynamically via `~/.sandbox-workdir` (written by `setup.sh`). GitHub Codespaces place repos at `/workspaces/<repo-name>` — the scripts handle this automatically.

Auth credentials are stored in a persistent Docker volume mounted at `~/.claude-persist/`. On each codespace rebuild, `setup.sh` restores them so you don't have to re-login.

## Files

| File | Purpose |
|---|---|
| `.devcontainer/devcontainer.json` | Container config + persistent volume |
| `.devcontainer/Dockerfile` | Base image |
| `.devcontainer/setup.sh` | Installs Claude Code, restores credentials, saves workspace path |
| `.devcontainer/save-creds.sh` | Backs up OAuth tokens on every attach |
| `.devcontainer/init-firewall.sh` | Network allowlist firewall |
| `task-runner.sh` | Runs tasks headless inside the codespace |
| `submit-task.sh` | Local CLI for auth, task submission, results |
| `batch-submit.sh` | Batch task submission from file |

## Troubleshooting

**"Could not find workspace directory"**: The codespace may not have finished setup. Wait a moment and retry, or SSH in directly with `gh codespace ssh`.

**Re-authentication needed**: Run `./submit-task.sh --auth` again. If credentials aren't persisting, check that the Docker volume mounted correctly with `./submit-task.sh --check`.

**Firewall issues**: The firewall only runs if setup runs as root. In Codespaces it typically runs as `vscode`, so the firewall may be skipped. This is fine — Codespaces are already isolated.

## Cleanup

```bash
gh codespace stop     # pause (stops billing, keeps state)
gh codespace delete   # destroy entirely
```
