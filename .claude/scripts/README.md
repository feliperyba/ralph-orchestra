# Ralph Orchestra Scripts Reference

This directory contains all orchestration scripts for the Ralph multi-agent system.

> **📘 Comprehensive Documentation:** For in-depth technical documentation covering architecture, orchestration modes, messaging, configuration, and troubleshooting, see:
> - **[PowerShell Architecture](../../docs/powershell-architecture.md)** - Complete orchestration architecture overview
> - **[Event-Driven Mode](../../docs/powershell-event-mode.md)** - Parallel orchestration deep dive
> - **[Sequential Mode](../../docs/powershell-sequential-mode.md)** - Handoff-based orchestration
> - **[Message System](../../docs/powershell-messaging.md)** - Message queue and pipe transport
> - **[Configuration Reference](../../docs/powershell-configuration.md)** - Environment variables and settings
> - **[Testing Guide](../../docs/powershell-testing.md)** - Test scripts and troubleshooting

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

---

## 🏗️ Architecture Modules

The `v2-architecture/` directory contains the next-generation orchestration infrastructure with event sourcing, Actor Model, and true parallel execution.

### Module Overview

| Module | Purpose | Status |
|--------|---------|--------|
| `concurrency.ps1` | Thread-safe primitives (Mutex, Event, AtomicCounter, ReadWriteLock) | ✅ PS 5.1 Compatible |
| `serialization.ps1` | Fast JSON message serialization | ✅ PS 5.1 Compatible |
| `metrics.ps1` | Performance tracking (p50/p95/p99 latencies) | ✅ PS 5.1 Compatible |
| `eventlog.ps1` | Event sourcing foundation with mutex-protected writes | ✅ PS 5.1 Compatible |
| `event-bus.ps1` | Bidirectional named pipe transport | ✅ PS 5.1 Compatible |
| `supervisor.ps1` | Actor lifecycle management (Erlang/OTP-style) | ✅ PS 5.1 Compatible |
| `actor.ps1` | Actor Model with mailboxes and selective receive | ✅ Experimental |
| `supervision-tree.ps1` | Hierarchical supervision with restart strategies | ✅ Experimental |
| `event-store.ps1` | Production event store with snapshots/compaction | ✅ Experimental |
| `event-versioning.ps1` | Event versioning and migration | ⚠️ PS 7+ Only |
| `projections.ps1` | CQRS read models (materialized views) | ⚠️ PS 7+ Only |
| `async-pipes.ps1` | Event-driven pipe I/O for sub-10ms latency | ✅ Experimental |
| `message-protocol.ps1` | Message format and routing | ✅ Stable |
| `agent-runtime.ps1` | Agent process lifecycle management | ✅ Stable |
| `cleanup-stale-ps.ps1` | Cleanup stale PowerShell processes | ✅ Stable |

### Key V2 Features

**Event Sourcing:**
- Append-only JSONL event log (`eventlog.jsonl`)
- Mutex-protected sequence numbers (prevents duplicates)
- Materialized views for fast queries (`agent-status.json`)
- Crash recovery via log replay

**Actor Model:**
- Named pipes as actor addresses
- Per-actor mailboxes with priority queues
- Selective receive (filter messages before processing)
- Supervision trees with restart strategies

**Performance:**
- < 10ms message delivery via named pipes
- Metrics tracking (p50, p95, p99 latencies)
- Throughput counters (ops/sec)
- Error rate tracking by type

**PowerShell 5.1 Compatibility:**
- All core modules use PS 5.1 compatible syntax
- `Monitor.Enter/Exit` instead of `lock()`
- `if ($null -ne $x)` instead of `$x?.Method()`
- ConvertTo-Json instead of System.Text.Json

### Testing

V2 modules are tested with Pester:

| Test File | Purpose | Pass Rate |
|-----------|---------|-----------|
| `Test-Concurrency.ps1` | Concurrency primitives and thread safety | 15/15 (100%) |
| `Test-Performance.ps1` | Performance benchmarks and targets | 14/14 (100%) |
| `Test-Reliability.ps1` | Integration and reliability tests | ⚠️ Requires PS 7+ |

Run tests:
```powershell
cd .claude\tests
Invoke-Pester Test-Concurrency.ps1
Invoke-Pester Test-Performance.ps1
```

### V2 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    V2 EVENT-DRIVEN ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌─────────────┐    ┌──────────────┐    ┌─────────────────────┐  │
│   │   Concurrency│    │ Serialization│    │      Metrics        │  │
│   │   Primitives │    │   Module     │    │      Tracking      │  │
│   └──────┬──────┘    └──────┬───────┘    └──────────┬──────────┘  │
│          │                  │                        │              │
│          └──────────────────┼────────────────────────┘              │
│                             │                                       │
│                    ┌────────▼─────────┐                            │
│                    │  Event Log (JSONL)│                           │
│                    │  - Sequence Numbers │                          │
│                    │  - Mutex Protection │                          │
│                    │  - Crash Recovery    │                          │
│                    └────────┬─────────┘                            │
│                             │                                       │
│          ┌──────────────────┼──────────────────┐                    │
│          │                  │                  │                    │
│    ┌─────▼─────┐     ┌──────▼──────┐   ┌─────▼──────┐             │
│    │ Event Bus │     │ Supervisor  │   │Event Store │             │
│    │ (Pipes)   │     │ (Actor Mgmt)│   │(Snapshots) │             │
│    └─────┬─────┘     └──────┬──────┘   └───────────┘             │
│          │                  │                                       │
│          └──────────────────┼──────────────────┐                    │
│                             │                  │                    │
│                    ┌────────▼─────────┐  ┌───▼──────┐             │
│                    │   Named Pipes    │  │Projections│             │
│                    │   PM/Dev/QA/etc  │  │(CQRS)    │             │
│                    └──────────────────┘  └──────────┘             │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```
