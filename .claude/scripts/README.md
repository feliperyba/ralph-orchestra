# Ralph Orchestra Scripts Reference

This directory contains all orchestration scripts for the Ralph multi-agent system.

## 📋 Script Overview

| Script                       | Purpose                           | Mode         |
| ---------------------------- | --------------------------------- | ------------ |
| `ralph-event-session.ps1`    | Launch event-driven parallel mode | Event-driven |
| `ralph-single-session.ps1`   | Launch sequential orchestration   | Sequential   |
| `ralph-multi-session.ps1`    | Launch polling parallel mode      | Polling      |
| `watchdog-event.ps1`         | Message broker for event mode     | Event-driven |
| `watchdog-single.ps1`        | Orchestrate agent handoffs        | Sequential   |
| `watchdog.ps1`               | Monitor agent health (polling)    | Polling      |
| `message-queue.ps1`          | Message queue functions           | Event-driven |
| `ralph-config.ps1`           | Shared configuration              | All          |
| `test-handoff-detection.ps1` | Debug handoff signals             | Sequential   |

## 🎯 Mode Selection Guide

```
┌─────────────────────────────────────────────────────────────────────┐
│                     ORCHESTRATION MODE DECISION                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Need parallel execution?                                            │
│     ├── YES → Need message history/debugging?                        │
│     │          ├── YES → Event-Driven (ralph-event-session.ps1)     │
│     │          └── NO  → Polling (ralph-multi-session.ps1)          │
│     │                                                                │
│     └── NO  → Minimize token usage?                                  │
│               ├── YES → Sequential (ralph-single-session.ps1)       │
│               └── NO  → HITL (/ralph-hitl command)                  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Sequential Mode (Handoff-Based)

### ralph-single-session.ps1

**Purpose:** Launch the sequential orchestration system where only one agent runs at a time.

**Usage:**

```powershell
# Basic usage - starts with PM agent
.\.claude\scripts\ralph-single-session.ps1

# Start with a specific agent
.\.claude\scripts\ralph-single-session.ps1 -InitialAgent developer

# Disable dashboard
.\.claude\scripts\ralph-single-session.ps1 -NoDashboard

# Custom settings
.\.claude\scripts\ralph-single-session.ps1 `
    -InitialAgent pm `
    -GracefulShutdownSeconds 30 `
    -MaxRestarts 3
```

**Parameters:**
| Parameter | Default | Description |
|-----------|---------|-------------|
| `-InitialAgent` | `"pm"` | Which agent starts first (pm, developer, qa) |
| `-GracefulShutdownSeconds` | `30` | Seconds to wait for agent graceful shutdown |
| `-MaxRestarts` | `3` | Retries before waiting longer (never gives up) |
| `-NoDashboard` | `$false` | Disable live dashboard output |

**What it does:**

1. Creates session directory structure
2. Initializes `prd.json.session` (session state)
3. Starts `watchdog-single.ps1`

---

### watchdog-single.ps1

**Purpose:** Core orchestrator that monitors the active agent and handles handoffs.

**Key Features:**

- **Never exits on its own** - runs until Ctrl+C or RALPH_COMPLETE
- Monitors `handoff-signal.json` for agent switch requests
- Gracefully stops current agent before starting next
- Passes context via `pending-handoff.json`
- Displays live dashboard with current status

**Handoff Detection:**

The watchdog checks two sources for handoff requests:

1. **Primary: Signal File** (`.claude/session/handoff-signal.json`)

   ```json
   {
     "targetAgent": "developer",
     "context": "Implement feat-001",
     "timestamp": "2024-01-20T12:00:00Z"
   }
   ```

2. **Fallback: Log Pattern** (agent terminal output)
   ```
   HANDOFF:developer:Implement feat-001
   ```

**Handoff Flow:**

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Agent writes handoff-signal.json                             │
│ 2. Watchdog detects signal file                                 │
│ 3. Watchdog stops current agent (graceful 30s timeout)          │
│ 4. Watchdog writes pending-handoff.json with context            │
│ 5. Watchdog starts target agent                                 │
│ 6. New agent reads pending-handoff.json on startup              │
└─────────────────────────────────────────────────────────────────┘
```

**Exit Conditions:**

- `Ctrl+C` pressed
- Agent signals `<promise>RALPH_COMPLETE</promise>`
- Complete signal in `handoff-signal.json`: `{"type": "complete"}`

---

### test-handoff-detection.ps1

**Purpose:** Debug utility to verify handoff detection is working.

**Usage:**

```powershell
# Run all tests
.\.claude\scripts\test-handoff-detection.ps1

# Create a test signal file
.\.claude\scripts\test-handoff-detection.ps1 -CreateTestSignal
```

**What it tests:**

- Signal file detection (`handoff-signal.json`)
- Log pattern matching (`HANDOFF:agent:context`)
- Completion pattern detection
- Actual agent log files

---

## 📨 Event-Driven Mode ⭐ Recommended

### ralph-event-session.ps1

**Purpose:** Launch the event-driven multi-agent system. All agents run in parallel with message-based communication (no polling).

**Usage:**

```powershell
# Basic usage
.\.claude\scripts\ralph-event-session.ps1

# With debug output
.\.claude\scripts\ralph-event-session.ps1 -Debug

# Disable dashboard
.\.claude\scripts\ralph-event-session.ps1 -NoDashboard
```

**Parameters:**
| Parameter | Default | Description |
|-----------|---------|-------------|
| `-NoDashboard` | `$false` | Disable live dashboard output |
| `-Debug` | `$false` | Enable verbose debug output |
| `-ProjectRoot` | auto | Custom project root path |

**Key Features:**

- **Parallel Execution** - All 3 agents run simultaneously
- **Message Queue** - Agents communicate via file-based messages
- **No Polling** - Agents work until done, check messages when idle
- **PM Prioritization** - Bug reports go to PM for priority decisions
- **Git Worktrees** - Developer can work on multiple tasks in parallel

---

### watchdog-event.ps1

**Purpose:** Message broker that routes messages between agents and manages health.

**Key Features:**

- Routes messages via `.claude/session/messages/` directories
- Each agent has an inbox folder
- Monitors agent processes, restarts if crashed
- Displays dashboard with agent statuses and message counts

**Message Flow:**

```
┌─────────────────────────────────────────────────────────────────┐
│                    WATCHDOG (Message Broker)                     │
└───────────────────────────┬─────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
   ┌─────────┐        ┌───────────┐       ┌─────────┐
   │   PM    │◄──────►│ Developer │◄─────►│   QA    │
   └─────────┘        └───────────┘       └─────────┘
```

---

### message-queue.ps1

**Purpose:** PowerShell module providing message queue functions.

**Key Functions:**

```powershell
# Initialize the queue
Initialize-MessageQueue -SessionDir ".claude/session"

# Send a message
Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{...}

# Get pending messages
Get-PendingMessages -Agent "developer"

# Acknowledge a message (deletes it)
Invoke-AcknowledgeMessage -MessageId "msg-xxx"
```

**Message Types:**

| Type                  | Description                      |
| --------------------- | -------------------------------- |
| `task_assign`         | PM assigns task to developer     |
| `validation_request`  | Developer requests QA validation |
| `bug_report`          | QA reports bugs (goes to PM)     |
| `task_complete`       | QA confirms task passed          |
| `question` / `answer` | Q&A between agents               |

---

## 🔀 Polling Mode (Legacy)

### ralph-multi-session.ps1

**Purpose:** Launch all three agents simultaneously in separate windows with polling-based coordination.

**Usage:**

```powershell
# Basic usage
.\.claude\scripts\ralph-multi-session.ps1

# Wait for completion
.\.claude\scripts\ralph-multi-session.ps1 -Wait

# Custom agents
.\.claude\scripts\ralph-multi-session.ps1 -Agents "pm","developer"
```

**Parameters:**
| Parameter | Default | Description |
|-----------|---------|-------------|
| `-Agents` | `@("pm","developer","qa")` | Which agents to run |
| `-Wait` | `$false` | Wait for all agents to complete |
| `-IdleTimeoutSeconds` | `120` | Restart if no activity |
| `-NoDashboard` | `$false` | Disable live dashboard |

> **Note:** Consider using Event-Driven mode instead for better message handling and debugging.

---

### watchdog.ps1

**Purpose:** Monitor all running agents, restart crashed or idle ones.

**Key Features:**

- Monitors multiple agent windows simultaneously
- Detects idle agents (no log activity for timeout period)
- Auto-restarts crashed or stuck agents
- Displays dashboard with all agent statuses

**Health Checks:**

- Log file size changes (activity detection)
- Process existence
- Heartbeat timestamps in `prd.json.agents.{agent}`

**Usage:**

```powershell
# Run directly (usually called by ralph-multi-session.ps1)
.\.claude\scripts\watchdog.ps1 `
    -IdleTimeoutSeconds 120 `
    -CheckIntervalMs 2000 `
    -MaxRestarts 5 `
    -Agents "pm","developer","qa"
```

---

## ⚙️ Configuration

### ralph-config.ps1

**Purpose:** Shared configuration and utility functions used by all scripts.

**Key Functions:**

```powershell
# Get Ralph configuration
$config = Get-RalphConfig
# Returns: @{
#     IdleTimeoutSeconds = 120
#     StartupGraceSeconds = 60
#     CheckIntervalMs = 2000
#     MaxRestarts = 5
#     Agents = @("pm", "developer", "qa")
# }

# Get file paths
$paths = Get-RalphPaths -ProjectRoot "C:\MyProject"
# Returns: @{
#     SessionDir = "C:\MyProject\.claude\session"
#     PrdJson = "C:\MyProject\prd.json"
#     LogDir = "C:\MyProject\.claude\session\logs"
# }
```

**Extending Configuration:**

Add custom paths or settings by modifying `ralph-config.ps1`:

```powershell
function Get-RalphPaths {
    param([string]$ProjectRoot)

    $sessionDir = Join-Path $ProjectRoot ".claude\session"

    return @{
        SessionDir = $sessionDir
        PrdJson = Join-Path $ProjectRoot "prd.json"
        LogDir = Join-Path $sessionDir "logs"
        # Add custom paths:
        CustomConfig = Join-Path $sessionDir "my-custom-config.json"
    }
}
```

---

## 📁 Session Directory Structure

```
.claude/session/
├── handoff-signal.json      # Agent switch signal (sequential)
├── pending-handoff.json     # Context for next agent (sequential)
├── handoff-log.json         # History of handoffs
├── progress.txt             # Human-readable progress log
├── messages/                # Event-driven message queues
│   ├── pm/                  # PM inbox
│   ├── developer/           # Developer inbox
│   ├── qa/                  # QA inbox
│   └── watchdog/            # Watchdog inbox
└── logs/
    ├── pm.log               # PM agent output
    ├── pm-runner.ps1        # PM runner script
    ├── developer.log        # Developer agent output
    ├── developer-runner.ps1 # Developer runner script
    ├── qa.log               # QA agent output
    ├── qa-runner.ps1        # QA runner script
    └── watchdog-summary.log # Session summary

# Project root
├── prd.json                 # SINGLE SOURCE OF TRUTH: tasks, session, agents
```

---

## 🔍 Debugging

### Common Issues

**Agent window closes immediately:**

```powershell
# Check the runner script for errors
cat .\.claude\session\logs\pm-runner.ps1

# Check if Claude CLI is installed
claude --version
```

**Handoffs not working:**

```powershell
# Test handoff detection
.\.claude\scripts\test-handoff-detection.ps1

# Check signal file
cat .\.claude\session\handoff-signal.json
```

**Watchdog exits unexpectedly:**

```powershell
# Check the summary log
cat .\.claude\session\logs\watchdog-summary.log

# Run with no dashboard for clearer error output
.\.claude\scripts\ralph-single-session.ps1 -NoDashboard
```

### Verbose Logging

Add debug output to watchdog:

```powershell
# In watchdog-single.ps1, find the main loop and add:
Write-Host "[DEBUG] Iteration $($Script:TotalIterations)" -ForegroundColor DarkGray
Write-Host "[DEBUG] Active: $($Script:ActiveAgent)" -ForegroundColor DarkGray
Write-Host "[DEBUG] Process: $($Script:AgentProcess.Id)" -ForegroundColor DarkGray
```

---

## 🧩 Extending Scripts

### Adding a New Agent

1. **Update watchdog-single.ps1:**

   ```powershell
   # In Start-SingleAgent function
   $slashCommand = switch ($AgentName) {
       "pm" { "/ralph-coordinator-single" }
       "developer" { "/ralph-worker-single --agent developer" }
       "qa" { "/ralph-worker-single --agent qa" }
       "designer" { "/ralph-designer-single" }  # Add new agent
   }
   ```

2. **Update ralph-config.ps1:**

   ```powershell
   function Get-RalphConfig {
       return @{
           Agents = @("pm", "developer", "qa", "designer")  # Add here
           # ...
       }
   }
   ```

3. **Create command file:**
   ```
   .claude/commands/ralph-designer-single.md
   ```

### Custom Handoff Logic

Override the `Invoke-Handoff` function in watchdog-single.ps1:

```powershell
function Invoke-Handoff {
    param(
        [string]$FromAgent,
        [string]$ToAgent,
        [string]$Context
    )

    # Custom pre-handoff logic
    if ($FromAgent -eq "developer" -and $ToAgent -eq "qa") {
        # Run tests before QA takes over
        Write-Host "Running pre-QA tests..." -ForegroundColor Cyan
        & npm run test
    }

    # Standard handoff logic
    Stop-SingleAgent -Graceful -Reason "handoff_to_$ToAgent"
    Start-Sleep -Seconds 2
    Start-SingleAgent -AgentName $ToAgent -HandoffContext $Context
}
```

### Custom Health Checks

Add to the main loop in watchdog-single.ps1:

```powershell
# After handoff check, before process exit check
if ($Script:ActiveAgent -eq "developer") {
    # Custom check: verify no TypeScript errors
    $tsErrors = & npx tsc --noEmit 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[WATCHDOG] TypeScript errors detected!" -ForegroundColor Yellow
        # Could trigger a handoff back to developer
    }
}
```

---

## 📊 Metrics

The watchdog tracks several metrics:

```powershell
$Script:TotalIterations   # Number of check cycles
$Script:TotalHandoffs     # Number of agent switches
$Script:HandoffLog        # Array of handoff history
$Script:WatchdogStartTime # Session start time
```

Access these in the dashboard or summary:

```powershell
# In Show-SingleAgentDashboard
Write-Host "Handoffs: $Script:TotalHandoffs"
Write-Host "Uptime: $([DateTime]::UtcNow - $Script:WatchdogStartTime)"
```

---

## 🔗 Related Files

- [Main README](../../README.md) - Project overview
- [CLAUDE.md](../../CLAUDE.md) - Claude context documentation
- [Commands](../commands/) - Slash command definitions
- [Skills](../skills/) - Orchestration skill documentation (YAML frontmatter)
- [Agent Definitions](../../agents/) - Per-agent behavior docs
  - [PM Skills](../../agents/pm/skills/) - Task selection, retrospective, scale-adaptive
  - [Developer Skills](../../agents/developer/skills/) - R3F, feedback loops, TypeScript
  - [QA Skills](../../agents/qa/skills/) - Validation, browser testing, bug reporting
