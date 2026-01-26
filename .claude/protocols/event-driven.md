# Event-Driven Protocol V2

Message-based communication protocol for V2 event-driven multi-agent orchestration using Actor Model with Event Sourcing.

## Architecture Overview (V2)

```
┌─────────────────────────────────────────────────────────────────┐
│              ACTOR SUPERVISOR (Event Sourcing)                   │
│  - Routes messages between agents via named pipes               │
│  - Monitors agent health with auto-restart                      │
│  - Event log as single source of truth                          │
│  - Manages session lifecycle                                     │
└─────────────────────────────────────────────────────────────────┘
           │                    │                    │
           ▼                    ▼                    ▼
    ┌───────────┐        ┌───────────┐        ┌───────────┐
    │    PM     │◄──────►│ Developer │◄──────►│    QA     │
    │  (Pipe)   │        │  (Pipe)   │        │  (Pipe)   │
    └───────────┘        └───────────┘        └───────────┘
```

## Worker Pool Model (V2)

**CRITICAL:** In V2 event-driven mode, agents do NOT run continuously.

**Pattern:**
```
1. ActorSupervisor spawns agent (creates pipe, starts process)
2. Agent connects via agent-runtime.ps1 to named pipe
3. Agent processes messages / does work
4. Agent sends completion/status message via pipe
5. Agent EXITS (exit code 0 or 42)
6. ActorSupervisor auto-restarts if crashed (exponential backoff)
```

**❌ DO NOT:**
- Stay running and monitor state continuously
- Use loops to poll for changes
- Use timers to wait

**✅ DO:**
- Connect via agent-runtime.ps1 and Enter-AgentLoop
- Process messages from named pipe
- Exit after completing work
- Send messages via Send-Message function

## Session Structure (V2)

```
.claude/session/
├── eventlog.jsonl       # Append-only event log (source of truth)
├── agent-status.json    # Materialized view from event log
├── undelivered.jsonl    # Failed delivery queue
└── pipes/               # Named pipe endpoints
    ├── ralph-pm-main
    ├── ralph-developer-main
    ├── ralph-qa-main
    └── ralph-gamedesigner-main
```

**Sending messages (V2):** Use `Send-Message` function from agent-runtime.ps1

**Receiving messages (V2):** Enter-AgentLoop automatically receives messages from named pipe

## Message Format (V2)

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
    "workType": "implementation"
  },
  "inReplyTo": "msg-20250125-115500-042"
}
```

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | `msg-{yyyyMMdd-HHmmss}-{seq}` |
| `seq` | number | Sequence number for ordering |
| `type` | string | V2 message type (12 core types) |
| `from` | string | Sender agent |
| `to` | string | Recipient agent |
| `timestamp` | string | ISO 8601 UTC |
| `payload` | object | Type-specific data |
| `inReplyTo` | string | Optional: Message ID being replied to |

## Message Types (V2 - 12 Core Types)

### PM Sends
| V2 Type | To | Purpose |
|---------|-----|---------|
| `WorkAssign` | developer, qa, gamedesigner | Assign work |
| `Query` | any | Answer question |
| `Response` | any | Answer response |
| `PlanUpdate` | all | Notify of PRD changes |

### Developer/TechArtist Sends
| V2 Type | To | Purpose |
|---------|-----|---------|
| `WorkComplete` | pm | Work done |
| `Query` | pm, gamedesigner | Ask for clarification |
| `WorkBlocked` | pm | Blocked on issue |

### QA Sends
| V2 Type | To | Purpose |
|---------|-----|---------|
| `ValidationResult` | pm | Validation results |
| `ProblemReport` | pm | Bugs found |

### Game Designer Sends
| V2 Type | To | Purpose |
|---------|-----|---------|
| `Playtest` | pm | Playtest results |
| `DesignUpdate` | pm | Design updates |
| `ResearchUpdate` | pm | Research findings |

### System
| V2 Type | To | Purpose |
|---------|-----|---------|
| `System` | all | Shutdown, errors |
| `AgentStatus` | watchdog | Agent lifecycle |

## Priority Levels (V2)

| Priority | Description | Use Case |
|----------|-------------|----------|
| `low` | Status updates | Periodic status reports |
| `normal` | Standard | Task assignments, validation requests |
| `high` | Needs attention | Questions, bug reports |
| `urgent` | Immediate | Critical bugs, shutdown commands |

## Processing Rules (V2)

1. **Message received via pipe**: Enter-AgentLoop delivers messages
2. **Process by type**: Switch on message type to handle
3. **Idempotent handlers**: Safe to receive same message twice
4. **Event log persistence**: All events logged before acknowledgment
5. **Undelivered queue**: Messages queued if pipe delivery fails

## Best Practices (V2)

1. **Use agent-runtime.ps1**: Standard connection library
2. **Exit when done**: Don't stay running idle
3. **Event log is source of truth**: State derived from replay
4. **Let-it-crash**: Supervisor will restart you
5. **V2 message types only**: Use 12 core types
