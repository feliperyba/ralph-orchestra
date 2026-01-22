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
| `pipe-transport.ps1`         | Named pipe messaging layer        | Event-driven |
| `message-queue.ps1`          | Message queue functions           | Event-driven |
| `message-state-manager.ps1`  | Message state tracking            | Event-driven |
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
```

**Parameters:**
| Parameter | Default | Description |
|-----------|---------|-------------|
| `-InitialAgent` | `"pm"` | Which agent starts first (pm, developer, techartist, qa, gamedesigner) |
| `-GracefulShutdownSeconds` | `30` | Seconds to wait for agent graceful shutdown |
| `-MaxRestarts` | `3` | Retries before longer wait (never gives up) |
| `-NoDashboard` | `$false` | Disable live dashboard output |

---

### watchdog-single.ps1

**Purpose:** Core orchestrator that monitors the active agent and handles handoffs.

**Key Features:**

- **Never exits on its own** - runs until Ctrl+C or RALPH_COMPLETE
- Monitors `handoff-signal.json` for agent switch requests
- Gracefully stops current agent before starting next
- Passes context via `pending-handoff.json`
- Displays live dashboard with current status

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

**Key Features:**

- **Parallel Execution** - All 5 agents run simultaneously
- **Named Pipe Messaging** - < 10ms message delivery
- **Message Queue** - Agents communicate via file-based messages with pipe transport
- **No Polling** - Agents work until done, check messages when idle
- **PM Prioritization** - Bug reports go to PM for priority decisions
- **Git Worktrees** - Developer and Tech Artist can work on multiple tasks in parallel

---

### watchdog-event.ps1

**Purpose:** Message broker that routes messages between agents and manages health.

**Key Features:**

- Creates named pipes for each agent on startup
- Routes messages via `.claude/session/messages/` directories
- Each agent has an inbox folder
- Monitors agent processes, restarts if crashed
- Displays dashboard with agent statuses and message counts
- Automatic fallback to file queue if pipes fail

---

### pipe-transport.ps1

**Purpose:** Named pipe messaging layer for ultra-fast message delivery.

**Benefits:**

- **< 10ms** message delivery (vs 2-5 seconds with file queue)
- No process restarts needed
- True event-driven behavior
- Automatic fallback to file queue

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

---

### message-state-manager.ps1

**Purpose:** Tracks message idempotency and prevents duplicate processing.

**Features:**

- Message ID generation
- Duplicate detection
- State persistence
- Automatic cleanup of old state

---

## 🔀 Polling Mode (Legacy)

### ralph-multi-session.ps1

**Purpose:** Launch all five agents simultaneously in separate windows with polling-based coordination.

**Usage:**

```powershell
# Basic usage
.\.claude\scripts\ralph-multi-session.ps1

# Wait for completion
.\.claude\scripts\ralph-multi-session.ps1 -Wait
```

> **Note:** Consider using Event-Driven mode instead for better message handling and debugging.

---

## ⚙️ Configuration

### ralph-config.ps1

**Purpose:** Shared configuration and utility functions used by all scripts.

**Agent Configuration:**

```powershell
$Script:AgentConfig = @{
    "pm" = @{
        Type = "coordinator"
        Command = "/ralph-coordinator-event"
        DisplayName = "PM (Coordinator)"
        Color = "Magenta"
    }
    "developer" = @{
        Type = "worker"
        Command = "/ralph-worker-event --agent developer"
        DisplayName = "Developer"
        Color = "Cyan"
    }
    "techartist" = @{
        Type = "worker"
        Command = "/ralph-worker-event --agent techartist"
        DisplayName = "Tech Artist"
        Color = "Green"
    }
    "qa" = @{
        Type = "worker"
        Command = "/ralph-worker-event --agent qa"
        DisplayName = "QA"
        Color = "Yellow"
    }
    "gamedesigner" = @{
        Type = "worker"
        Command = "/ralph-worker-event --agent gamedesigner"
        DisplayName = "Game Designer"
        Color = "Blue"
    }
}
```

---

## 📁 Session Directory Structure

```
.claude/session/
├── state/                   # Split state files (Phase 2)
│   ├── agents.json          # Agent statuses (watchdog primary writer)
│   ├── prd.json             # PRD state (PM primary writer)
│   ├── current-task.json    # Active task (shared)
│   └── metrics.json         # Performance metrics (watchdog)
├── pipes/                   # Named pipe endpoints
├── coordinator-state.json   # Main coordination state
├── current-task.json        # Active task details
├── handoff-signal.json      # Agent switch signal (sequential)
├── pending-handoff.json     # Context for next agent (sequential)
├── handoff-log.json         # History of handoffs
├── progress.txt             # Human-readable progress log
├── messages/                # Event-driven message queues
│   ├── pm/                  # PM inbox
│   ├── developer/           # Developer inbox
│   ├── techartist/          # Tech Artist inbox
│   ├── qa/                  # QA inbox
│   ├── gamedesigner/        # Game Designer inbox
│   └── watchdog/            # Watchdog inbox
└── logs/
    ├── pm.log               # PM agent output
    ├── developer.log        # Developer agent output
    ├── techartist.log       # Tech Artist agent output
    ├── qa.log               # QA agent output
    ├── gamedesigner.log     # Game Designer agent output
    └── watchdog-summary.log # Session summary
```

---

## 🔗 Related Files

- [Main README](../../README.md) - Project overview
- [CLAUDE.md](../../CLAUDE.md) - Claude context documentation
- [Commands](../commands/) - Slash command definitions
- [Skills](../skills/) - Orchestration skills (YAML frontmatter)
- [Agent Definitions](../../agents/) - Per-agent behavior docs
