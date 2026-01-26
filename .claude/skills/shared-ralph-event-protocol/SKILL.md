---
name: shared-ralph-event-protocol
description: Event-driven communication protocol using Actor Model with Event Sourcing for Ralph V2. Use proactively when implementing message handling or connecting agents via named pipes.
category: orchestration
tags: [event-driven, v2, actor-model, event-sourcing, messaging]
dependencies: [shared-message-handling, shared-message-acknowledgment, shared-ralph-core]
---

# Ralph Event-Driven Protocol (V2)

> "Actor Model with Event Sourcing – named pipes, auto-restart, single source of truth."

## When to Use This Skill

Use **when**:
- Implementing message handling for agents
- Understanding V2 message flow
- Connecting agents via named pipes
- Designing new message types

Use **proactively**:
- Reference this before implementing agent message loops
- Use `agent-runtime.ps1` for all agent connections

---

## Quick Start

<examples>
Example 1: Agent connection
```powershell
# Source runtime library
. "$PSScriptRoot\..\..\scripts\agent-runtime.ps1"

# Connect to watchdog
Connect-ToWatchdog -AgentName "developer" -SessionDir ".\.claude\session"

# Enter main loop
Enter-AgentLoop -MessageHandler {
    param($Message)
    switch ($Message.type) {
        "WorkAssign" { ... }
        "Query" { ... }
    }
}
```

Example 2: Send work complete
```powershell
Send-WorkComplete -TaskId "feat-001" -Result "success" -Notes "Complete"
```

Example 3: Send query to PM
```powershell
Send-Message -To "pm" -Type "Query" -Payload @{
    question = "How to handle edge case?"
    context = @{ taskId = "feat-001" }
}
```
</examples>

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│           WATCHDOG SUPERVISOR (Event Sourcing)                │
│  ┌─────────────────────────────────────────────────────┐    │
│  │         EVENT LOG (Append-Only JSONL)               │    │
│  │  - Single source of truth                           │    │
│  │  - All events persisted                             │    │
│  │  - State derived by replay                          │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐             │
│  │   PM   │  │  Dev   │  │   QA   │  │Design  │             │
│  │  Pipe  │  │  Pipe  │  │  Pipe  │  │  Pipe  │             │
│  └────┬───┘  └────┬───┘  └────┬───┘  └────┬───┘             │
└───────┼────────────┼────────────┼────────────┼──────────────┘
        │            │            │            │
        ▼            ▼            ▼            ▼
    PM Process   Developer    QA Process   Designer
```

---

## Key Features

| Feature | Implementation | Benefit |
|----------|----------------|---------|
| Message transport | Bidirectional named pipes | <10ms delivery |
| Message types | 12 core types | Simple protocol |
| Health management | ActorSupervisor with auto-restart | Let-it-crash |
| State management | Single event log | Single source of truth |
| Message processing | True event-driven | No polling overhead |

---

## V2 Message Format

```json
{
  "id": "msg-20250125-120000-001",
  "type": "WorkAssign",
  "from": "pm",
  "to": "developer",
  "timestamp": "2025-01-25T12:00:00Z",
  "payload": {
    "taskId": "feat-001",
    "workType": "implementation",
    "title": "Implement feature"
  },
  "inReplyTo": "msg-20250125-115500-042"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | `msg-{yyyyMMdd-HHmmss}-{seq}` |
| `type` | string | V2 message type (12 core types) |
| `from` | string | Sender agent |
| `to` | string | Recipient agent (or `*` for broadcast) |
| `timestamp` | string | ISO 8601 UTC |
| `payload` | object | Type-specific data |
| `inReplyTo` | string | Optional: Message ID being replied to |

---

## V2 Message Types (12 Core)

| V2 Type | From | To | Purpose |
|---------|------|-----|---------|
| `AgentStatus` | workers | pm | Agent lifecycle/health |
| `WorkAssign` | pm | workers | Assign task |
| `WorkComplete` | workers | pm | Task done |
| `WorkAbandoned` | workers | pm | Task abandoned |
| `WorkBlocked` | workers | pm | Task blocked |
| `ProblemReport` | workers | pm | Bug/blocker found |
| `Query` | any | any | Ask question |
| `Response` | any | any | Answer question |
| `ValidationRequest` | pm | qa | Run validation |
| `ValidationResult` | qa | pm | Validation results |
| `Retrospective` | any | pm | Retro events |
| `Playtest` | gamedesigner | pm | Playtest results |
| `DesignUpdate` | gamedesigner | pm | GDD updates |
| `PlanUpdate` | pm | all | PRD changes |
| `ResearchUpdate` | gamedesigner | pm | Research results |
| `System` | watchdog | all | Shutdown/errors |

---

## Message Reference

### PM Sends
| V2 Type | To | Purpose |
|---------|-----|---------|
| `WorkAssign` | developer | Implementation task |
| `WorkAssign` | techartist | Asset task (workType: "asset") |
| `WorkAssign` | qa | Validation task (workType: "validation") |
| `Retrospective` | all | Start retrospective |
| `Query` | gamedesigner | Request PRD analysis |
| `Response` | any | Answer question |
| `PlanUpdate` | all | Notify PRD changes |

### Developer Sends
| V2 Type | To | Purpose |
|---------|-----|---------|
| `WorkComplete` | pm | Implementation done |
| `Query` | pm/gamedesigner | Ask clarification |
| `ProblemReport` | pm | Bug found |

### QA Sends
| V2 Type | To | Purpose |
|---------|-----|---------|
| `ValidationResult` | pm | Validation results |
| `ProblemReport` | pm | Bugs found |

### Game Designer Sends
| V2 Type | To | Purpose |
|---------|-----|---------|
| `Playtest` | pm | Playtest results |
| `DesignUpdate` | pm | GDD updates |
| `Response` | pm | PRD analysis response |

---

## Workflow Patterns

### Task Completion Flow
```
PM → Developer: WorkAssign (workType: "implementation")
PM ← Developer: WorkComplete
PM → QA: WorkAssign (workType: "validation")
PM ← QA: ValidationResult (passed: true)
```

### Bug Fix Flow
```
PM ← QA: ProblemReport (type: "bug")
PM → Developer: WorkAssign (workType: "bug_fix")
PM ← Developer: WorkComplete
PM → QA: WorkAssign (workType: "validation")
```

### Question/Answer Flow
```
Developer → PM: Query
PM → Developer: Response (inReplyTo: original_query_id)
```

---

## Event Log

All events persisted to `.claude/session/eventlog.jsonl`:

```
{"seq":1,"type":"AgentStarted","timestamp":"2025-01-25T12:00:00Z","data":{"agent":"pm","pid":1234}}
{"seq":2,"type":"MessageSent","timestamp":"2025-01-25T12:00:01Z","data":{"from":"pm","to":"developer","type":"WorkAssign"}}
{"seq":3,"type":"AgentExited","timestamp":"2025-01-25T12:05:00Z","data":{"agent":"developer","exitCode":0}}
```

**Event Types:**
- `AgentStarted` - Agent spawned
- `AgentExited` - Agent exited (graceful or crash)
- `AgentCrashed` - Abnormal exit
- `MessageSent` - Message delivered
- `MessageReceived` - Message received
- `WorkAssigned` - Work assignment recorded
- `WorkCompleted` - Work completion recorded

---

## Agent Lifecycle

### Startup (PM-First)
1. Watchdog V2 starts
2. `ActorSupervisor` initializes event log
3. Supervisor starts ONLY PM agent
4. PM determines which workers need activation
5. PM sends `WorkAssign` messages
6. Supervisor starts workers on demand

### Running (Event-Driven)
1. Supervisor detects work assignment
2. `ActorSupervisor.StartActor()` creates pipe and spawns process
3. Agent connects via `agent-runtime.ps1`
4. Agent processes messages from pipe
5. Agent sends completion via pipe
6. Agent exits (supervisor will restart if needed)

### Shutdown
1. PM sends `System` (shutdown) to all agents
2. Supervisor waits up to 30 seconds for graceful exit
3. Supervisor forces termination if needed
4. Event log contains complete session history

---

## Best Practices

1. **Use `agent-runtime.ps1`** - Standard connection library
2. **Enter-AgentLoop** - Main message processing loop
3. **Exit when done** - Don't stay running idle
4. **V2 message types only** - Use 12 core types
5. **Event log is source of truth** - State derived from replay
6. **Let-it-crash** - Supervisor will restart you
7. **Idempotent handlers** - Safe to receive same message twice

---

## Related Skills

| Skill | Purpose |
|-------|---------|
| `shared-message-handling` | V2 message delivery via named pipes |
| `shared-message-acknowledgment` | Acknowledgment protocol |
| `shared-ralph-core` | Session structure, status values |
| `shared-worker-protocol` | Worker exit patterns |
