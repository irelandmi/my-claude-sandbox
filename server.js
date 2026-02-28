const express = require("express");
const { execSync, spawn } = require("child_process");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const app = express();
app.use(express.json());

// ─── Config ─────────────────────────────────────────────────────────────
const PORT = 7680;
const WORKDIR = process.cwd();
const RESULTS_DIR = path.join(WORKDIR, "results");
const LOGS_DIR = path.join(WORKDIR, "logs");

fs.mkdirSync(RESULTS_DIR, { recursive: true });
fs.mkdirSync(LOGS_DIR, { recursive: true });

// Track running tasks
const tasks = new Map();

// ─── POST /tasks — submit a new task ────────────────────────────────────
app.post("/tasks", (req, res) => {
  const { task, model } = req.body;

  if (!task) {
    return res.status(400).json({ error: "Missing 'task' in request body" });
  }

  const taskId = `task-${Date.now()}-${crypto.randomBytes(3).toString("hex")}`;
  const taskModel = model || "claude-sonnet-4-5-20250929";
  const resultDir = path.join(RESULTS_DIR, taskId);
  const logFile = path.join(LOGS_DIR, `${taskId}.log`);

  fs.mkdirSync(resultDir, { recursive: true });

  const meta = {
    task_id: taskId,
    task: task,
    model: taskModel,
    started_at: new Date().toISOString(),
    status: "running",
  };

  fs.writeFileSync(
    path.join(resultDir, "task-meta.json"),
    JSON.stringify(meta, null, 2)
  );

  // Run Claude Code in headless mode
  const logStream = fs.createWriteStream(logFile);
  const child = spawn(
    "claude",
    [
      "--print",
      "--dangerously-skip-permissions",
      "--model",
      taskModel,
      "--output-format",
      "json",
      task,
    ],
    { cwd: WORKDIR, stdio: ["ignore", "pipe", "pipe"] }
  );

  let output = "";

  child.stdout.on("data", (chunk) => {
    output += chunk.toString();
  });

  child.stderr.on("data", (chunk) => {
    logStream.write(chunk);
  });

  child.on("close", (code) => {
    logStream.end();

    // Save raw output
    fs.writeFileSync(path.join(resultDir, "raw-output.json"), output);

    // Extract text response
    let responseText = output;
    try {
      const parsed = JSON.parse(output);
      responseText = parsed.result || parsed.content || parsed.message || output;
    } catch {
      // Keep raw output as response
    }
    fs.writeFileSync(path.join(resultDir, "response.txt"), responseText);

    // Update metadata
    meta.completed_at = new Date().toISOString();
    meta.duration_seconds = Math.round(
      (new Date(meta.completed_at) - new Date(meta.started_at)) / 1000
    );
    meta.status = code === 0 ? "completed" : "failed";
    meta.exit_code = code;

    fs.writeFileSync(
      path.join(resultDir, "task-meta.json"),
      JSON.stringify(meta, null, 2)
    );

    tasks.set(taskId, meta);

    console.log(
      `✅ ${taskId} ${meta.status} (${meta.duration_seconds}s) — ${task.substring(0, 60)}`
    );
  });

  tasks.set(taskId, meta);

  console.log(`📋 ${taskId} started — ${task.substring(0, 60)}`);

  res.status(202).json({
    task_id: taskId,
    status: "running",
    message: "Task submitted",
  });
});

// ─── GET /tasks — list all tasks ────────────────────────────────────────
app.get("/tasks", (req, res) => {
  const results = [];

  try {
    const dirs = fs.readdirSync(RESULTS_DIR).filter((d) => d.startsWith("task-"));

    for (const dir of dirs) {
      const metaPath = path.join(RESULTS_DIR, dir, "task-meta.json");
      if (fs.existsSync(metaPath)) {
        results.push(JSON.parse(fs.readFileSync(metaPath, "utf8")));
      }
    }
  } catch {
    // No results yet
  }

  // Sort by start time, newest first
  results.sort((a, b) => new Date(b.started_at) - new Date(a.started_at));

  res.json({ count: results.length, tasks: results });
});

// ─── GET /tasks/:id — get task result ───────────────────────────────────
app.get("/tasks/:id", (req, res) => {
  const taskId = req.params.id;
  const resultDir = path.join(RESULTS_DIR, taskId);

  if (!fs.existsSync(resultDir)) {
    return res.status(404).json({ error: "Task not found" });
  }

  const meta = JSON.parse(
    fs.readFileSync(path.join(resultDir, "task-meta.json"), "utf8")
  );

  let response = null;
  const responsePath = path.join(resultDir, "response.txt");
  if (fs.existsSync(responsePath)) {
    response = fs.readFileSync(responsePath, "utf8");
  }

  res.json({ ...meta, response });
});

// ─── GET /tasks/:id/files — list files created by task ──────────────────
app.get("/tasks/:id/files", (req, res) => {
  const taskId = req.params.id;
  const resultDir = path.join(RESULTS_DIR, taskId);

  if (!fs.existsSync(resultDir)) {
    return res.status(404).json({ error: "Task not found" });
  }

  const files = fs.readdirSync(resultDir);
  res.json({ task_id: taskId, files });
});

// ─── GET /health — health check ─────────────────────────────────────────
app.get("/health", (req, res) => {
  let claudeVersion = "unknown";
  try {
    claudeVersion = execSync("claude --version 2>/dev/null").toString().trim();
  } catch {
    // Claude not installed or not on path
  }

  let authenticated = false;
  const credPaths = [
    path.join(process.env.HOME, ".claude", ".credentials.json"),
    path.join(process.env.HOME, ".config", "claude-code", "auth.json"),
  ];
  for (const p of credPaths) {
    if (fs.existsSync(p)) {
      authenticated = true;
      break;
    }
  }

  const running = [...tasks.values()].filter(
    (t) => t.status === "running"
  ).length;

  res.json({
    status: "ok",
    claude_version: claudeVersion,
    authenticated,
    workspace: WORKDIR,
    running_tasks: running,
  });
});

// ─── Start server ───────────────────────────────────────────────────────
app.listen(PORT, "0.0.0.0", () => {
  console.log("");
  console.log("╔════════════════════════════════════════════════════╗");
  console.log("║        Claude Code Task API (Max Plan)             ║");
  console.log("╚════════════════════════════════════════════════════╝");
  console.log("");
  console.log(`  🌐 Listening on port ${PORT}`);
  console.log(`  📁 Workspace: ${WORKDIR}`);
  console.log("");
  console.log("  Endpoints:");
  console.log("    POST /tasks          Submit a task");
  console.log("    GET  /tasks          List all tasks");
  console.log("    GET  /tasks/:id      Get task result");
  console.log("    GET  /health         Health check");
  console.log("");
  console.log("  From your local machine:");
  console.log("    gh codespace ports forward 7680:7680");
  console.log('    curl http://localhost:7680/health');
  console.log("");
});
