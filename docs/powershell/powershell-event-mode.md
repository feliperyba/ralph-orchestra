# Event-Driven Mode - Deep Dive

Event-driven mode is the **recommended orchestration mode** for Ralph Orchestra. Uses **Actor Model with Event Sourcing** for reliable parallel agent execution.

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       EVENT-DRIVEN ARCHITECTURE                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────────────────┐                                  │
│   │        ACTOR SUPERVISOR            │                                  │
│   │       (Watchdog)                   │                                  │
│   │                                     │  ┌───────────────────────────┐  │
│   │  - Spawns agents                   │  │    EVENT LOG (JSONL)      │  │
│   │  - Monitors health                 │  │  - Append-only             │  │
│   │  - Auto-restart on crash           │  │  - Single source of truth  │  │
│   │  - Routes messages                 │  └───────────────────────────┘  │
│   └─────────────┬───────────────────────┘                                  │
│                 │                                                      │
│    ┌────────────┴────────┬──────────┬──────────┬──────────┐              │
│    ▼                   ▼          ▼          ▼          ▼              │
│ ┌────────┐        ┌────────┐   ┌──────┐ ┌──────┐ ┌──────────┐           │
│ │   PM   │        │  Dev   │   │  QA  │ │  GD  │ │   TA     │           │
│ │ Agent  │        │ Agent  │   │Agent │ │Agent │ │  Agent   │           │
│ └────────┘        └────────┘   └──────┘ └──────┘ └──────────┘           │
│     │                 │            │        │        │                    │
│     └─────────────────┴────────────┴────────┴────────┴────────────        │
│                           Bidirectional Named Pipes                         │
│                                 (< 10ms delivery)                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Key Characteristics

| Feature | Description |
|---------|-------------|
| **Parallelism** | All 5 agents run simultaneously |
| **Message Delivery** | <10ms via bidirectional named pipes |
| **Token Usage** | Medium (baseline efficiency) |
| **Crash Recovery** | Automatic with exponential backoff |
| **Best For** | Production use, speed-critical projects |

## Session Startup

### ralph-event-v2-session.ps1

**Location:** [`.claude/scripts/ralph-event-v2-session.ps1`](../.claude/scripts/ralph-event-v2-session.ps1:1)

**Parameters:**
```powershell
-Debug                # Enable verbose debug output
-MaxIterations <n>    # Maximum iterations (default: 200)
```

**Startup Sequence:**

1. **Create session directories:**
   ```
   .claude/session/
   ├── eventlog.jsonl          # Created on initialization
   ├── agent-status.json       # Auto-generated from event log
   ├── undelivered.jsonl       # Failed delivery queue
   └── logs/
   ```

2. **Initialize event log** (append-only)

3. **Launch watchdog** (watchdog-event-v2.ps1)

## Watchdog Orchestrator

### watchdog-event-v2.ps1

**Location:** [`.claude/scripts/watchdog-event-v2.ps1`](../.claude/scripts/watchdog-event-v2.ps1:1)

**Architecture:**

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        WATCHDOG MAIN LOOP                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌────────────────┐    ┌────────────────┐    ┌────────────────┐       │
│  │ SUPERVISE      │───►│ READ PIPES     │───►│ DELIVER        │       │
│  │ (Check Crashes)│    │ (Get Messages) │    │ UNDELIVERED    │       │
│  └────────────────┘    └────────────────┘    └────────────────┘       │
│         │                      │                      │                  │
│         └──────────────────────┴──────────────────────┴──────────────┐  │
│                                                                     │  │
│  ┌────────────────────────────────────────────────────────────────┐ │  │
│  │                    WRITE EVENT LOG                             │ │ │  │
│  │              (All events persisted)                             │ │ │  │
│  └────────────────────────────────────────────────────────────────┘ │  │
│                                                                     │  │
└─────────────────────────────────────────────────────────────────────────┘
```

### Main Loop

```powershell
# Import modules
. "$PSScriptRoot\eventlog.ps1"
. "$PSScriptRoot\event-bus.ps1"
. "$PSScriptRoot\supervisor.ps1"

# Initialize
Initialize-EventLog -SessionDir $paths.SessionDir
$supervisor = [ActorSupervisor]::new($paths.SessionDir)

# Start PM first
$supervisor.StartActor("pm")

# Main loop
while ($iteration -lt $MaxIterations) {
    $iteration++

    # 1. Supervise (check for crashed agents)
    $supervisor.Supervise()

    # 2. Read messages from all agent pipes (non-blocking)
    foreach ($agentName in $supervisor.Actors.Keys) {
        while ($msg = Receive-MessageFromAgent -AgentName $agentName) {
            Process-Message -Message $msg -Supervisor $supervisor
        }
    }

    # 3. Deliver undelivered messages
    foreach ($agentName in $supervisor.Actors.Keys) {
        Retry-Undelivered -AgentName $agentName
    }

    # Brief CPU throttle (not polling)
    Start-Sleep -Milliseconds 100
}

# Shutdown
$supervisor.StopAll()
```

## ActorSupervisor Pattern

### Supervisor Class

**Location:** [`.claude/scripts/supervisor.ps1`](../.claude/scripts/supervisor.ps1:1)

The ActorSupervisor manages agent lifecycle:

```powershell
class ActorSupervisor {
    [Dictionary[string,object]]$Actors
    [string]$SessionDir
    [string]$EventLogFile

    # Start an agent (creates pipe, spawns process, waits for connection)
    [void] StartActor([string]$AgentName)

    # Check health, restart crashed agents with exponential backoff
    [void] Supervise()

    # Handle agent exit (graceful vs crash)
    [void] HandleAgentExit([object]$Actor, [int]$ExitCode)

    # Stop all agents gracefully
    [void] StopAll()
}
```

### Agent Lifecycle

| State | Description |
|-------|-------------|
| **Starting** | Pipe created, process spawning |
| **Running** | Connected, processing messages |
| **Crashed** | Exited with non-zero/non-42 code |
| **Stopped** | Graceful exit or max restarts exceeded |

### Restart Strategy

| Condition | Action |
|-----------|--------|
| Exit code 0 or 42 | Graceful exit, no restart |
| Crash (other code) | Restart with backoff: 5s → 10s → 20s → 40s → 60s (max) |
| Max restarts (3) exceeded | Give up, mark agent stopped |

## Named Pipe Transport

### Bidirectional Pipes

**Location:** [`.claude/scripts/event-bus.ps1`](../.claude/scripts/event-bus.ps1:1)

**Pipe Names:**
- `ralph-pm-main` (bidirectional)
- `ralph-developer-main` (bidirectional)
- `ralph-qa-main` (bidirectional)
- `ralph-gamedesigner-main` (bidirectional)
- `ralph-techartist-main` (bidirectional)

### Connection Flow

```
┌──────────────┐                    ┌──────────────┐
│ SUPERVISOR   │                    │    AGENT     │
│              │                    │              │
│ Create Pipe  │                    │              │
│ (Server)     │                    │              │
│      │       │                    │              │
│      │ Wait  │◄───────────────────│ Connect      │
│      │       │                    │ (Client)     │
│      ▼       │                    │              │
│ Connected    │                    │ Block Read   │
│      │       │                    │              │
│ Write Msg    │────────────────────►│             │
│      │       │  (<10ms delivery)  │             │
│      │       │                    │ Process     │
│      │       │                    │      │      │
│      │       │◜─────────────────────│ Send Reply  │
│      │       │                    │             │
└──────────────┘                    └──────────────┘
```

### Event Bus Functions

| Function | Purpose |
|----------|---------|
| `New-BidirectionalPipe` | Create pipe for agent |
| `Wait-PipeConnection` | Wait for agent to connect |
| `Send-MessageToAgent` | Send message via pipe |
| `Receive-MessageFromAgent` | Read message from pipe (non-blocking) |

## Agent Connection

### Agent Runtime Library

**Location:** [`.claude/scripts/agent-runtime.ps1`](../.claude/scripts/agent-runtime.ps1:1)

Agents use the runtime library to connect:

```powershell
# Source the runtime library
. "$PSScriptRoot\agent-runtime.ps1"

# Connect to watchdog
Connect-ToWatchdog -AgentName "developer" -SessionDir ".\.claude\session"

# Enter message processing loop
Enter-AgentLoop -MessageHandler {
    param($Message)

    switch ($Message.type) {
        "WorkAssign" {
            # Handle work assignment
            $taskId = $Message.payload.taskId
            # ... do work ...
            Send-WorkComplete -TaskId $taskId -Result "success"
        }
        "Query" {
            # Handle question
            Send-Response -Payload @{
                answer = "Here's the answer..."
            }
        }
        "System" {
            if ($Message.payload.systemEvent -eq "shutdown") {
                # Loop will exit automatically
            }
        }
    }
}
```

## Event Log (Event Sourcing)

### Event Log Operations

**Location:** [`.claude/scripts/eventlog.ps1`](../.claude/scripts/eventlog.ps1:1)

All state is derived from the event log:

```powershell
# Initialize (creates eventlog.jsonl)
Initialize-EventLog -SessionDir ".\.claude\session"

# Write event
Write-Event -Type "AgentStarted" -Data @{
    agent = "developer"
    pid = 1234
}

# Read events
$events = Get-EventsSince -FromSeq 100

# Rebuild agent status
$status = Rebuild-AgentStatus
Export-AgentStatus -OutputPath ".\.claude\session\agent-status.json"
```

### Session Directory

```
.claude/session/
├── eventlog.jsonl             # Append-only event log (source of truth)
├── agent-status.json          # Materialized view (auto-generated)
├── undelivered.jsonl          # Failed delivery fallback
└── logs/
    ├── watchdog.log           # Watchdog output
    ├── pm.log
    ├── developer.log
    ├── qa.log
    ├── techartist.log
    └── gamedesigner.log
```

## Undelivered Message Queue

When pipe delivery fails, messages are queued:

```powershell
# File: .claude/session/undelivered.jsonl
{"agent":"developer","message":{...},"timestamp":"2025-01-25T12:00:00Z"}

# Automatically retried when agent reconnects
Retry-Undelivered -AgentName "developer"
```

## Message Types

12 core message types:

| Type | Purpose |
|------|---------|
| `WorkAssign` | All work assignments |
| `WorkComplete` | All completions |
| `Query` / `Response` | Q&A |
| `ProblemReport` | Bugs, issues |
| `ValidationResult` | Validation results |
| `Retrospective` | Retrospective events |
| `System` | Shutdown, errors |

See [Message System](./powershell-messaging.md) for complete reference.

## Dashboard

Event-driven mode displays a simplified dashboard:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    RALPH EVENT-DRIVEN MODE                             │
├─────────────────────────────────────────────────────────────────────────┤
│  PM:        ● working     Developer: ● idle      QA:        ● working │
│  Game Des.: ● idle       Tech Art.:  ● working                             │
├─────────────────────────────────────────────────────────────────────────┤
│  Events: 42    |    Agents: 5/5     |    Uptime: 01:23:45                  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RALPH_MAX_ITERATIONS` | 200 | Maximum loop iterations |
| `RALPH_IDLE_TIMEOUT` | 60 | Idle timeout before stale |
| `RALPH_STALE_THRESHOLD` | 90 | Seconds before agent marked stale |

## Troubleshooting

### Agents Not Connecting

**Symptoms:** Pipe connection timeout

**Solutions:**
1. Verify watchdog is running
2. Check `.claude/session/` exists
3. Check pipe name format: `ralph-{agent}-main`

### Event Log Issues

**Symptoms:** State not syncing

**Solutions:**
1. Check `eventlog.jsonl` exists
2. Verify append-only (no deletions)
3. Rebuild status: `Export-AgentStatus`

### Crash Loop

**Symptoms:** Agent restarts repeatedly

**Solutions:**
1. Check agent logs for errors
2. Verify skill files are valid
3. Max restarts (3) will stop the loop

## See Also

- [Message System](./powershell-messaging.md) - Complete message protocol
- [Architecture Overview](./powershell-architecture.md) - System architecture
- [Sequential Mode](./powershell-sequential-mode.md) - Token-efficient alternative
- [Configuration](./powershell-configuration.md) - Environment variables
