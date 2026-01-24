# Event-Driven Protocol

Message-based communication protocol for event-driven multi-agent orchestration.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    WATCHDOG (Message Broker)                     │
│  - Routes messages between agents                                │
│  - Monitors agent health                                         │
│  - Restarts agents with messages                                 │
│  - Manages session lifecycle                                     │
└─────────────────────────────────────────────────────────────────┘
           │                    │                    │
           ▼                    ▼                    ▼
    ┌───────────┐        ┌───────────┐        ┌───────────┐
    │    PM     │◄──────►│ Developer │◄──────►│    QA     │
    │(Coordinator)       │ (Worker)  │        │ (Worker)  │
    └───────────┘        └───────────┘        └───────────┘
```

## Worker Pool Model

**CRITICAL:** In event-driven mode, agents do NOT run continuously.

**Pattern:**
```
1. Watchdog spawns agent (with or without pending messages)
2. Agent processes messages / does work
3. Agent sends completion/status message
4. Agent EXITS
5. Watchdog spawns agent again when needed
```

**❌ DO NOT:**
- Stay running and monitor state continuously
- Use loops to poll for changes
- Use timers to wait

**✅ DO:**
- Use Read tool / Write tool for file operations
- Process pending messages on startup
- Exit after completing work
- Send status_update to watchdog before exiting

## Message Queue Structure

```
.claude/session/messages/
├── pm/                 # PM's inbox
├── developer/          # Developer's inbox
├── qa/                 # QA's inbox
├── gamedesigner/       # Game Designer's inbox
├── techartist/         # Tech Artist's inbox
└── watchdog/           # Watchdog's inbox
```

**Sending messages:** Use Write tool to create `.claude/session/messages/{recipient}/{message-id}.json`

**Receiving messages:** Watchdog restarts you when messages exist in your inbox

## Message Format

```json
{
  "id": "msg-developer-20240120-120000-001",
  "from": "pm",
  "to": "developer",
  "type": "task_assign",
  "priority": "normal",
  "payload": { "taskId": "feat-001" },
  "timestamp": "2024-01-20T12:00:00.000Z",
  "status": "pending"
}
```

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | `msg-{recipient_agent}-{timestamp}-{seq}` |
| `from` | string | Sender agent |
| `to` | string | Recipient agent |
| `type` | string | Message type |
| `priority` | string | `low`, `normal`, `high`, `urgent` |
| `payload` | object | Type-specific data |
| `timestamp` | string | ISO 8601 UTC |
| `status` | string | `pending`, `processing`, `completed` |

## Message Types

### PM Sends
| Type | To | Purpose |
|------|-----|---------|
| `task_assign` | developer | Assign task |
| `priority_response` | any | Answer question |
| `prd_reorganized` | all | Notify of PRD changes |

### Developer Sends
| Type | To | Purpose |
|------|-----|---------|
| `task_complete` | pm | Implementation done |
| `question` | pm | Ask for clarification |
| `validation_request` | qa | Request QA validation |
| `status_update` | watchdog | Report status |

### QA Sends
| Type | To | Purpose |
|------|-----|---------|
| `task_complete` | pm | Validation passed |
| `bug_report` | pm | Validation failed, bugs found |

## Priority Levels

| Priority | Description | Use Case |
|----------|-------------|----------|
| `low` | Status updates | Periodic status reports |
| `normal` | Standard | Task assignments, validation requests |
| `high` | Needs attention | Questions, bug reports |
| `urgent` | Immediate | Critical bugs, shutdown commands |

## Processing Rules

1. **Priority First**: Process urgent messages before normal
2. **FIFO within Priority**: Older messages before newer
3. **Delete After Processing**: Remove pending messages file immediately
4. **PM Decides Priorities**: Bug reports go to PM, not directly to developer

## Best Practices

1. **Small, Focused Messages**: One concern per message
2. **Include Context**: TaskId, references in payload
3. **Exit When Done**: Don't stay running idle
4. **Status Updates**: Send to watchdog so it knows you're alive
5. **Use ReplyTo**: Link responses to questions
