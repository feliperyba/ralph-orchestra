# Ralph Orchestra Scripts Reference

This directory contains all orchestration scripts for the Ralph multi-agent system.

## 📋 Script Overview

| Script                       | Purpose                           | Mode         |
| ---------------------------- | --------------------------------- | ------------ |
| `ralph-event-session.ps1`    | Launch event-driven mode          | Event-driven |
| `ralph-single-session.ps1`   | Launch sequential orchestration   | Sequential   |
| `watchdog-event.ps1`         | Message broker for event mode     | Event-driven |
| `watchdog-single.ps1`        | Orchestrate agent handoffs        | Sequential   |
| `message-queue.ps1`          | Message queue functions           | Event-driven |
| `ralph-config.ps1`           | Shared configuration              | All          |
| `test-handoff-detection.ps1` | Debug handoff signals             | Sequential   |

## 🎯 Mode Selection Guide

```
┌─────────────────────────────────────────────────────────────────────┐
│                     ORCHESTRATION MODE DECISION                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Need on-demand parallelism?                                         │
│     ├── YES → Event-Driven (ralph-event-session.ps1)                │
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
2. Initializes `coordinator-state.json`
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

1. **Primary: Signal File** (`./.claude/session/handoff-signal.json`)

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

**Purpose:** Launch the event-driven multi-agent system. PM starts first and workers are launched on demand with message delivery (no polling).

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

- **Adaptive Parallelism** - PM runs continuously, workers start when needed
- **Message Queue** - Agents communicate via file-based messages
- **No Polling** - Watchdog delivers messages by restarting workers
- **PM Prioritization** - Bug reports go to PM for priority decisions
- **Git Worktrees** - Developer can work on multiple tasks in parallel

---

### watchdog-event.ps1

**Purpose:** Message broker that routes messages between agents and manages health.

**Key Features:**

- Routes messages via `./.claude/session/messages/` directories
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
Initialize-MessageQueue -SessionDir "./.claude/session"

# Send a message
Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{...}

# Get pending messages
Get-PendingMessages -Agent "developer"

# Acknowledge a message (deletes it)
Invoke-AcknowledgeMessage -MessageId "msg-xxx"
```

**Message Types:**

| Type                      | Description                      |
| ------------------------- | -------------------------------- |
| `task_assign`             | PM assigns task to developer     |
| `validation_request`      | Developer requests QA validation |
| `bug_report`              | QA reports bugs (goes to PM)     |
| `task_complete`           | QA confirms task passed          |
| `question`                | Ask a question                   |
| `answer`                  | Answer a question                |
| `research_update`         | Share research findings          |
| `regression_request`      | Request regression testing       |
| `prd_update`              | Update PRD/spec details          |
| `status_update`           | Update agent work status         |
| `priority_review`         | Request priority review          |
| `agent_ready`             | Agent startup signal             |
| `work_complete`           | Signal work completion           |
| `error`                   | Report an error                  |
| `shutdown`                | Graceful shutdown request        |
| `implementation_complete` | Implementation finished          |
| `work_blocked`            | Work is blocked                  |
| `task_abandoned`          | Task abandoned                   |
| `quality_concern`         | Quality concern raised           |
| `retrospective_initiate`  | Start retrospective              |
| `retrospective_contribution` | Retrospective input           |
| `research_request`        | Request research                 |
| `research_response`       | Respond to research request      |
| `prd_reorganized`         | PRD reorganized                  |
| `skill_improvements`      | Share skill improvements         |
| `priority_response`       | Priority review response         |
| `skill_request`           | Request skill update             |
| `gdd_ready`               | GDD is ready                     |
| `gdd_update`              | GDD has been updated             |
| `design_question`         | Ask design question              |
| `design_answer`           | Answer design question           |
| `playtest_request`        | Request playtest                 |
| `playtest_report`         | Playtest results                 |
| `mechanic_proposal`       | Propose a mechanic               |
| `design_guidance`         | Provide design guidance          |
| `design_guidance_request` | Request design guidance          |
| `test_plan_request`       | Request test plan                |
| `test_plan_contribution`  | Provide test plan input          |
| `asset_assign`            | Assign visual task               |
| `asset_ready`             | Assets ready for validation      |
| `asset_question`          | Clarification request            |
| `shader_request`          | Propose shader work              |
| `reference_request`       | Request artistic references      |

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
#     SessionDir = "C:\MyProject\.\.claude\session"
#     CoordinatorState = "C:\MyProject\.\.claude\session\coordinator-state.json"
#     CurrentTask = "C:\MyProject\.\.claude\session\current-task.json"
#     LogDir = "C:\MyProject\.\.claude\session\logs"
# }
```

**Extending Configuration:**

Add custom paths or settings by modifying `ralph-config.ps1`:

```powershell
function Get-RalphPaths {
    param([string]$ProjectRoot)

    $sessionDir = Join-Path $ProjectRoot ".\.claude\session"

    return @{
        SessionDir = $sessionDir
        CoordinatorState = Join-Path $sessionDir "coordinator-state.json"
        CurrentTask = Join-Path $sessionDir "current-task.json"
        LogDir = Join-Path $sessionDir "logs"
        # Add custom paths:
        CustomConfig = Join-Path $sessionDir "my-custom-config.json"
    }
}
```

---

## 📁 Session Directory Structure

```
./.claude/session/
├── coordinator-state.json   # Main coordination state
├── current-task.json        # Active task details
├── handoff-signal.json      # Agent switch signal (sequential)
├── pending-handoff.json     # Context for next agent (sequential)
├── handoff-log.json         # History of handoffs
├── progress.txt             # Human-readable progress log
├── message-state.json        # Processed message IDs
├── messages/                # Event-driven message queues
│   ├── pm/
│   ├── developer/
│   ├── qa/
│   ├── gamedesigner/
│   ├── techartist/
│   └── watchdog/
└── logs/
    ├── pm.log               # PM agent output
    ├── pm-runner.ps1        # PM runner script
    ├── developer.log        # Developer agent output
    ├── developer-runner.ps1 # Developer runner script
    ├── qa.log               # QA agent output
    ├── qa-runner.ps1        # QA runner script
    └── watchdog-summary.log # Session summary
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
   ./.claude/commands/ralph-designer-single.md
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
