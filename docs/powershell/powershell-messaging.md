# Message System Documentation

The message system uses **Actor Model with Event Sourcing** for reliable, fast inter-agent communication via bidirectional named pipes.

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MESSAGE SYSTEM ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌──────────────┐                    ┌─────────────────────────────────┐   │
│   │   Agent A    │────────────────────│        ACTOR SUPERVISOR         │   │
│   │              │   Named Pipe       │       (Watchdog)                │   │
│   └──────────────┘   (<10ms delivery)  │                                 │   │
│           │                           │  ┌───────────────────────────┐  │   │
│           │                           │  │    EVENT LOG (JSONL)      │  │   │
│           │                           │  │  - Append-only             │  │   │
│   ┌───────┴──────────────────────────│  │  - Single source of truth  │  │  │   │
│   │              │                   │  └───────────────────────────┘  │   │
│   │              ▼                   │                                 │   │
│   │   ┌──────────────────┐          │  ┌───────────────────────────┐  │   │
│   │   │  Event Replay    │◄─────────┤  │  Materialized View        │  │   │
│   │   │  (State Derive)  │          │  │  agent-status.json        │  │   │
│   │   └──────────────────┘          │  └───────────────────────────┘  │   │
│   │                                 │                                 │   │
│   └─────────────────────────────────┘                                 │   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Architecture Components

| Component | Script | Purpose |
|-----------|--------|---------|
| **ActorSupervisor** | `supervisor.ps1` | Spawns agents, monitors health, auto-restarts |
| **Event Log** | `eventlog.ps1` | Append-only log of all events (source of truth) |
| **Event Bus** | `event-bus.ps1` | Bidirectional named pipe transport |
| **Message Protocol** | `message-protocol.ps1` | 12 core message type definitions |
| **Agent Runtime** | `agent-runtime.ps1` | Standard library for agent connection |

## Key Characteristics

| Aspect | Implementation |
|--------|----------------|
| Message delivery | Named pipes only |
| State management | Single event log |
| Message types | 12 core types |
| Agent lifecycle | ActorSupervisor with auto-restart |
| Delivery latency | <10 milliseconds |
| Crash recovery | Automatic (exponential backoff) |

## Session Directory

```
.claude/session/
├── eventlog.jsonl             # Append-only event log (source of truth)
├── agent-status.json          # Materialized view from event log
├── undelivered.jsonl          # Failed delivery fallback queue
└── logs/
    ├── pm.log
    ├── developer.log
    ├── qa.log
    ├── techartist.log
    ├── gamedesigner.log
    └── watchdog.log
```

## Message Format

```json
{
  "id": "msg-20250125-120000-001",
  "seq": 42,
  "type": "WorkAssign",
  "from": "pm",
  "to": "developer",
  "timestamp": "2025-01-25T12:00:00Z",
  "payload": {
    "taskId": "feat-001",
    "workType": "implementation",
    "title": "Implement user authentication"
  },
  "inReplyTo": "msg-20250125-115500-042"
}
```

## Message Types

### 12 Core Types

| Type | From → To | Purpose |
|------|-----------|---------|
| `WorkAssign` | PM → Workers | All work assignments |
| `WorkComplete` | Workers → PM | All completions |
| `ValidationRequest` | Worker → QA | Validation requests |
| `ValidationResult` | QA → PM | Validation results |
| `ProblemReport` | QA → PM | Bug reports, issues |
| `Query` | Any → Any | Questions |
| `Response` | Any → Any | Answers |
| `Retrospective` | PM ↔ Workers | Retrospective events |
| `Playtest` | PM ↔ GameDesigner | Playtesting |
| `DesignUpdate` | GameDesigner → PM | Design docs |
| `ResearchUpdate` | GameDesigner → PM | Research findings |
| `System` | Watchdog → All | Shutdown, errors |

### Consolidated Legacy Types

These types have been consolidated into the 12 core types above:

| Original Types | Consolidated To |
|----------------|-----------------|
| `task_assign`, `asset_assign` | `WorkAssign` |
| `task_complete`, `implementation_complete`, `work_complete`, `asset_ready` | `WorkComplete` |
| `validation_request`, `test_plan_request`, `regression_request` | `ValidationRequest` |
| `bug_report`, `quality_concern`, `work_blocked` | `ProblemReport` |
| `question`, `asset_question`, `design_question`, `reference_request` | `Query` |
| `answer`, `design_answer`, `design_guidance`, `priority_response`, `research_response` | `Response` |
| `agent_ready`, `status_update` | `AgentStatus` |
| `shutdown`, `error` | `System` |

## Named Pipe Transport

### Pipe Creation

**Location:** [`.claude/scripts/event-bus.ps1`](../.claude/scripts/event-bus.ps1)

Pipes are bidirectional - one per agent:

| Pipe Name | Direction |
|-----------|-----------|
| `ralph-pm-main` | Bidirectional |
| `ralph-developer-main` | Bidirectional |
| `ralph-qa-main` | Bidirectional |
| `ralph-gamedesigner-main` | Bidirectional |
| `ralph-techartist-main` | Bidirectional |

### Agent Connection

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
        }
        "Query" {
            # Handle question
        }
        "System" {
            if ($Message.payload.systemEvent -eq "shutdown") {
                # Loop will exit automatically
            }
        }
    }
}
```

### Sending Messages

```powershell
# Send work complete
Send-WorkComplete -TaskId "feat-001" -Result "success" -Notes "Implementation complete"

# Send query
Send-Message -To "pm" -Type "Query" -Payload @{
    question = "How should I handle this edge case?"
}

# Send problem report
Send-ProblemReport -TaskId "feat-001" -ProblemType "bug" -Description "Found issue"
```

## Event Log (Event Sourcing)

### Event Log Operations

**Location:** [`.claude/scripts/eventlog.ps1`](../.claude/scripts/eventlog.ps1)

```powershell
# Initialize event log
Initialize-EventLog -SessionDir ".\.claude\session"

# Write event
Write-Event -Type "AgentStarted" -Data @{
    agent = "developer"
    pid = 1234
}

# Read events since sequence
$events = Get-EventsSince -FromSeq 100

# Rebuild agent status from events
$status = Rebuild-AgentStatus
Export-AgentStatus -OutputPath ".\.claude\session\agent-status.json"
```

### Event Types

| Event Type | Data | Purpose |
|------------|------|---------|
| `AgentStarted` | agent, pid | Track agent spawn |
| `AgentExited` | agent, exitCode | Track agent exit |
| `AgentCrashed` | agent, exitCode | Track crashes for restart |
| `MessageSent` | from, to, messageId | Track all messages |
| `MessageDelivered` | to, messageId | Track delivery |

## Agent Runtime Library

### Core Functions

**Location:** [`.claude/scripts/agent-runtime.ps1`](../.claude/scripts/agent-runtime.ps1)

| Function | Purpose |
|----------|---------|
| `Connect-ToWatchdog` | Connect agent to watchdog via named pipe |
| `Enter-AgentLoop` | Enter message processing loop |
| `Send-Message` | Send message to another agent |
| `Send-WorkComplete` | Send work completion notification |
| `Send-ProblemReport` | Send bug report |
| `Send-Query` | Send question |
| `Send-Response` | Send answer |

## ActorSupervisor Pattern

### Supervisor Functions

**Location:** [`.claude/scripts/supervisor.ps1`](../.claude/scripts/supervisor.ps1)

```powershell
# Create supervisor
$supervisor = [ActorSupervisor]::new($sessionDir)

# Start agent (creates pipe, spawns process, waits for connection)
$supervisor.StartActor("developer")

# Supervise (check for crashed agents, restart with backoff)
$supervisor.Supervise()

# Stop all agents gracefully
$supervisor.StopAll()
```

### Restart Strategy

| Condition | Action |
|-----------|--------|
| Exit code 0 or 42 | Graceful exit, no restart |
| Crash (other exit code) | Restart with exponential backoff |
| Max restarts exceeded | Give up, mark agent stopped |

**Backoff sequence:** 5s, 10s, 20s, 40s, 60s (max)

## Undelivered Message Queue

### Fallback Delivery

When pipe delivery fails, messages are queued for retry:

```powershell
# File: .claude/session/undelivered.jsonl
{"agent":"developer","message":{...},"timestamp":"2025-01-25T12:00:00Z"}

# Retry delivery when agent reconnects
Retry-Undelivered -AgentName "developer"
```

## Message Flow Example

```
┌──────────┐                              ┌──────────┐
│    PM    │                              │ Developer│
└─────┬────┘                              └─────┬────┘
      │                                        │
      │ Send-WorkAssign                        │
      │   -To: developer                       │
      │   -Type: WorkAssign                    │
      │   -Payload: {taskId: "feat-001"}      │
      │                                        │
      ▼                                        │
┌──────────────────────────────────────────────┐
│  Message written to eventlog.jsonl          │
│  Delivered via named pipe (<10ms)           │
└──────────────────────────────────────────────┘
      │                                        │
      │                                        │ Enter-AgentLoop receives
      │                                        │
      │◄───────────────────────────────────────┤
      │                                        ▼
┌──────────────────────────────────────────────┐
│  Developer processes WorkAssign             │
│  Performs work...                           │
└──────────────────────────────────────────────┘
      │                                        │
      │                                        │ Send-WorkComplete
      │                                        │
      │◄───────────────────────────────────────┤
      │                                        ▼
┌──────────────────────────────────────────────┐
│  Event logged: WorkComplete                 │
│  Agent exits (supervisor may restart)       │
└──────────────────────────────────────────────┘
```

## Performance

| Metric | Value |
|--------|-------|
| Message delivery | <10ms |
| Agent restart time | <500ms |
| State files | 1 event log |
| Message types | 12 |
| Crash recovery | Automatic |

## Troubleshooting

### Messages Not Delivered

**Symptoms:** Agent doesn't receive messages

**Solutions:**
1. Check pipe connection: `Get-ChildItem .\.claude\session\pipes\`
2. Verify watchdog is running
3. Check undelivered queue: `Get-Content .\.claude\session\undelivered.jsonl`
4. Review watchdog logs

### Agent Won't Connect

**Symptoms:** `Connect-ToWatchdog` fails

**Solutions:**
1. Verify watchdog is running
2. Check `.claude/session/` exists
3. Verify pipe name format: `ralph-{agent}-main`

### Event Log Issues

**Symptoms:** State not syncing, events missing

**Solutions:**
1. Check event log exists: `Test-Path .\.claude\session\eventlog.jsonl`
2. Verify append-only (no deletions)
3. Rebuild materialized view: `Export-AgentStatus`

## See Also

- [Architecture Overview](./powershell-architecture.md) - System architecture
- [Event-Driven Mode](./powershell-event-mode.md) - Event-driven mode details
- [Configuration Reference](./powershell-configuration.md) - Environment variables
- [`.claude/skills/shared-message-handling/`](../.claude/skills/shared-message-handling/) - Agent messaging skill
