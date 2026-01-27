---
name: shared-messaging
description: File-based message queues for agent communication. Uses Glob/Read/Write tools - no PowerShell.
category: coordination
---

# Shared Messaging

> "Agents communicate via file-based message queues using Glob, Read, and Write tools."

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    WATCHDOG (Message Broker)                     │
│  - Routes messages between agents                                │
│  - Monitors agent health                                         │
│  - Restarts agents with messages                                 │
│  - Tracks message acknowledgments                                │
└─────────────────────────────────────────────────────────────────┘
           │                    │                    │
           ▼                    ▼                    ▼
    ┌───────────┐        ┌───────────┐        ┌───────────┐
    │    PM     │◄──────►│ Developer │◄──────►│    QA     │
    │(Coordinator)       │ (Worker)  │        │ (Worker)  │
    └───────────┘        └───────────┘        └───────────┘
```

## Message Queue Directory

```
.claude/session/messages/
├── pm/                 # PM's inbox
├── developer/          # Developer's inbox
├── qa/                 # QA's inbox
├── techartist/         # Tech Artist's inbox
├── gamedesigner/       # Game Designer's inbox
└── watchdog/           # Watchdog's inbox (acknowledgments)
```

**Pattern:** `.claude/session/messages/{recipient}/msg-{recipient}-{timestamp}-{seq}.json`

---

## Message Format (Single Definition)

```json
{
  "id": "msg-developer-20260126-120000-001",
  "from": "pm",
  "to": "developer",
  "type": "task_assign",
  "priority": "normal",
  "payload": {
    "taskId": "feat-001",
    "title": "Feature title",
    "acceptanceCriteria": ["Criterion 1", "Criterion 2"]
  },
  "timestamp": "2026-01-26T12:00:00.000Z",
  "status": "pending"
}
```

### Fields

| Field       | Type   | Description                                                                      |
| ----------- | ------ | -------------------------------------------------------------------------------- |
| `id`        | string | `msg-{recipient}-{YYYYMMDD-HHMMSS}-{seq}`                                        |
| `from`      | string | Sender agent (`pm`, `developer`, `qa`, `techartist`, `gamedesigner`, `watchdog`) |
| `to`        | string | Recipient agent                                                                  |
| `type`      | string | Message type (see catalog below)                                                 |
| `priority`  | string | `low`, `normal`, `high`, `urgent`                                                |
| `payload`   | object | Type-specific data                                                               |
| `timestamp` | string | ISO 8601 UTC format                                                              |
| `status`    | string | `pending`, `processing`, `completed`                                             |

---

## Reading Messages

**Use Glob + Read tools:**

```
1. Glob: .claude/session/messages/{your-agent}/msg-*.json
2. For each file: Read the content
3. Parse JSON and extract fields
4. Process based on message type
5. Send acknowledgment to watchdog
6. Delete the file
```

### Complete Example

```bash
# Step 1: Find messages
Glob: .claude/session/messages/pm/msg-*.json

# Step 2: Read each file
Read: .claude/session/messages/pm/msg-pm-20260126-120000-001.json

# Step 3: Parse and process
{
  "id": "msg-pm-001",
  "from": "developer",
  "to": "pm",
  "type": "task_complete",
  "payload": { "taskId": "feat-001", "success": true },
  "timestamp": "2026-01-26T12:00:00.000Z"
}

# Step 4: Process by type
# task_complete → Trigger retrospective
# bug_report → Reassign to worker
# question → Research and respond

# Step 5: Send acknowledgment (see below)

# Step 6: Delete the file
```

---

## Message Acknowledgment (P1 Fix - Critical)

**After processing ANY message, you MUST send acknowledgment to watchdog:**

```json
{
  "id": "msg-watchdog-20260126-120500-001",
  "from": "developer",
  "to": "watchdog",
  "type": "message_acknowledged",
  "priority": "normal",
  "payload": {
    "originalMessageId": "msg-developer-20260126-120000-001",
    "status": "processed"
  },
  "timestamp": "2026-01-26T12:05:00.000Z",
  "status": "pending"
}
```

**Write acknowledgment to:** `.claude/session/messages/watchdog/msg-watchdog-{timestamp}-{seq}.json`

### Why Acknowledgment is Required

- Watchdog marks messages "delivered" when sending
- Watchdog waits for acknowledgment before deleting
- Without acknowledgment → watchdog may re-deliver (duplicates)
- With acknowledgment → watchdog knows you processed successfully

---

## Sending Messages

**Use Write tool to create message file in recipient's queue:**

### Task Assignment (PM → Worker)

```json
{
  "id": "msg-developer-20260126-120000-001",
  "from": "pm",
  "to": "developer",
  "type": "task_assign",
  "priority": "normal",
  "payload": {
    "taskId": "feat-001",
    "title": "Feature title",
    "acceptanceCriteria": ["Criterion 1", "Criterion 2"]
  },
  "timestamp": "2026-01-26T12:00:00.000Z",
  "status": "pending"
}
```

### Task Completion (Worker → PM)

```json
{
  "id": "msg-pm-20260126-120200-001",
  "from": "developer",
  "to": "pm",
  "type": "task_complete",
  "priority": "normal",
  "payload": {
    "taskId": "feat-001",
    "success": true,
    "summary": "Implementation complete"
  },
  "timestamp": "2026-01-26T12:02:00.000Z",
  "status": "pending"
}
```

### Question (Any → PM)

```json
{
  "id": "msg-pm-20260126-120100-001",
  "from": "developer",
  "to": "pm",
  "type": "question",
  "priority": "high",
  "payload": {
    "question": "How should I handle X?",
    "context": "Current situation..."
  },
  "timestamp": "2026-01-26T12:01:00.000Z",
  "status": "pending"
}
```

### Bug Report (QA → PM)

```json
{
  "id": "msg-pm-20260126-120300-001",
  "from": "qa",
  "to": "pm",
  "type": "bug_report",
  "priority": "high",
  "payload": {
    "taskId": "feat-001",
    "bugs": [{ "file": "src/App.tsx", "line": 42, "issue": "Type error" }]
  },
  "timestamp": "2026-01-26T12:03:00.000Z",
  "status": "pending"
}
```

---

## Message Types Catalog

### Core Types

| Type                 | Direction         | Purpose               |
| -------------------- | ----------------- | --------------------- |
| `task_assign`        | PM → Worker       | Assign a task         |
| `task_complete`      | Worker → PM       | Report completion     |
| `validation_request` | PM → QA           | Request validation    |
| `bug_report`         | QA → PM           | Report bugs           |
| `question`           | Any → PM          | Ask for clarification |
| `answer`             | PM → Worker       | Respond to question   |
| `wake_up`            | PM → Worker       | Wake idle worker      |

### PM Receives

| Type                         | From         | Action                           |
| ---------------------------- | ------------ | -------------------------------- |
| `task_complete`              | qa/developer | Trigger retrospective if success |
| `bug_report`                 | qa           | Reassign to developer            |
| `question`                   | any          | Research and respond             |
| `retrospective_contribution` | any          | Collect for synthesis            |
| `playtest_report`            | gamedesigner | Review findings                  |

### Workers Receive

| Type                     | From | Action                      |
| ------------------------ | ---- | --------------------------- |
| `task_assign`            | pm   | Read task, begin work       |
| `bug_report`             | qa   | Fix bugs, re-submit         |
| `answer`                 | pm   | Apply response, continue    |
| `validation_request`     | pm   | Run validation              |
| `wake_up`                | pm   | Resume if idle              |
| `retrospective_initiate` | pm   | Contribute to retrospective |

### Watchdog Receives

| Type                   | From | Action                          |
| ---------------------- | ---- | ------------------------------- |
| `message_acknowledged` | any  | Mark message processed, delete  |
| `status_update`        | any  | Update agent status in prd.json |

### Watchdog Sends

| Type                     | To  | Purpose                           |
| ------------------------ | --- | --------------------------------- |
| `retrospective_complete` | pm  | All workers contributed           |
| `agent_timeout`          | pm  | Agent timed out awaiting response |

---

## Priority Levels

| Priority | Use Case                             |
| -------- | ------------------------------------ |
| `urgent` | Critical failures, agent timeouts    |
| `high`   | Questions, bug reports               |
| `normal` | Task assignments, completions        |
| `low`    | Status updates, heartbeats           |

### Processing Order

1. **URGENT** - Handle immediately (e.g., `agent_timeout`)
2. **HIGH** - Respond promptly (e.g., `question`, `bug_report`)
3. **NORMAL** - Process in order (e.g., `task_assign`, `task_complete`)
4. **LOW** - Log and continue (e.g., `wake_up`, status updates)

---

## Message Flow Patterns

### Task Completion Flow

```
PM → task_assign → Developer
Developer → task_complete → PM
PM → validation_request → QA
QA → task_complete (pass) OR bug_report (fail) → PM
```

### Question/Answer Flow

```
Worker → question → PM
PM → answer → Worker
```

### Retrospective Flow

```
PM → retrospective_initiate → Workers
Workers → retrospective_contribution → PM
Watchdog (tracks all contributions) → retrospective_complete → PM
```

---

## Processing Rules

1. **Priority First** - Process urgent before normal
2. **FIFO within Priority** - Older messages before newer
3. **Acknowledge Before Delete** - Send `message_acknowledged`, then watchdog deletes
4. **Idempotent Handlers** - Safe to reprocess (check status before acting)
5. **Exit When Done** - Don't stay running idle

### Idempotent Processing

Since messages may be reprocessed, always check state first:

```json
// Example: Idempotent task handler
// 1. Read prd.json
// 2. Check if already processing this task
// 3. If currentTask == taskId, skip (already processing)
// 4. Otherwise, start working
// 5. Update prd.json.agents.{your-agent}.status = "working"
```

---

## Worker Pool Model

**In event-driven mode, agents do NOT run continuously.**

**Pattern:**

```
1. Watchdog spawns agent (when messages exist)
2. Agent processes messages / does work
3. Agent sends completion/status message
4. Agent EXITS
5. Watchdog spawns again when needed
```

**Exit after work** - Watchdog will restart you when new messages arrive.

---

## Troubleshooting

### No Messages Found

- Glob returns empty → No messages waiting
- Continue normal workflow or exit (watchdog will spawn you when messages arrive)

### Messages Not Being Delivered

- Verify writing to correct recipient's queue
- Check JSON format is valid
- Ensure timestamp is ISO-8601 format
- **Send acknowledgment** - watchdog won't delete without it

### Message Cleanup

- Send acknowledgment BEFORE deleting
- Don't leave processed messages (prevents re-processing)

---

## Anti-Patterns

| Don't                         | Do Instead                     |
| ----------------------------- | ------------------------------ |
| Use PowerShell helper scripts | Use Glob/Read/Write tools      |
| Modify other agents' messages | Only write to recipient queues |
| Forget acknowledgment         | Always send to watchdog        |
| Delete without acknowledging  | Acknowledge first, then delete |
| Stay running idle             | Exit after work completes      |

---

## References

- `shared-core` — Session structure, status values, heartbeat
- `shared-worker` — Worker pool behavior, exit conditions
- `shared-coordinator` — PM coordinator specifics
