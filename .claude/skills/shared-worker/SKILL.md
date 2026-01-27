---
name: shared-worker
description: Base worker behavior for all Ralph agents - worker pool model, exit conditions, heartbeat. Extend for agent-specific behavior.
category: orchestration
---

# Shared Worker

> "Complete work, send message, exit. Watchdog orchestrates by spawning agents on demand."

---

## Worker Pool Model

**In event-driven mode, agents do NOT run continuously.**

```
┌─────────────────────────────────────────────────────────────────┐
│                      WATCHDOG (Orchestrator)                     │
│                                                                   │
│  1. Monitor message queues                                       │
│  2. Route messages between agents                                │
│  3. Spawn agent when messages exist in their queue               │
│  4. Wait for agent to exit                                       │
│  5. Respawn agent when new messages arrive                       │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                ┌───────────▼─────────────┐
                │  Message Flow:          │
                │  PM → Workers           │
                │  Workers → PM           │
                │  Workers → Watchdog     │
                └──────────────────────────┘
```

### Agent Lifecycle

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   START     │ ──▶ │  DO WORK     │ ──▶ │   EXIT      │
│ (read       │     │ (complete    │     │ (send       │
│  messages)  │     │  single task) │     │  message)   │
└─────────────┘     └──────────────┘     └─────────────┘
```

**Key Principle:** Each agent run does ONE unit of work, then exits. Watchdog restarts when needed.

---

## Mandatory Exit Check (First Step)

**On EVERY startup, check coordinator status FIRST:**

```bash
# Read YOUR state file (NOT prd.json)
Read: .claude/session/current-task-{your-agent}.json

# Check session.state.status in the JSON:
# session.state.status: "running" | "completed" | "terminated" | "max_iterations_reached"
```

**If session.state.status is `completed`, `terminated`, or `max_iterations_reached`:**

1. Update your status to `"exiting"`
2. Log exit to handoff-log.json
3. Output: `<promise>WORKER_EXIT</promise>`
4. Stop

**If session.state.status is `running`:** Continue normal workflow.

---

## Startup Workflow

### 1. Check for Pending Messages (MANDATORY)

```bash
# Use Glob to find messages in your inbox
Glob: .claude/session/messages/{your-agent}/msg-*.json

# Read each message using Read tool
# Process based on message type
```

### 2. Send Acknowledgment (MANDATORY)

After reading ANY message, send acknowledgment to watchdog:

```json
{
  "id": "msg-watchdog-{timestamp}-{seq}",
  "from": "{your-agent}",
  "to": "watchdog",
  "type": "message_acknowledged",
  "priority": "normal",
  "payload": {
    "originalMessageId": "{original-message-id}",
    "status": "processed"
  },
  "timestamp": "{ISO-8601-UTC}",
  "status": "pending"
}
```

### 3. Update Heartbeat (v2.0 - State File Pattern)

**DO NOT read prd.json** - Update your state file instead:

```bash
# Read your state file
Read: .claude/session/current-task-{your-agent}.json

# Update the "state" object in the JSON:
{
  "state": {
    "status": "working",
    "lastSeen": "{ISO-8601-UTC}",
    "currentTaskId": "{taskId or null}",
    "pid": 0
  },
  // ... rest of the file remains unchanged
}

# Write back
Write: .claude/session/current-task-{your-agent}.json
```

### 4. Process Messages

| Message Type             | Action                      |
| ------------------------ | --------------------------- |
| `task_assign`            | Begin implementation        |
| `bug_report`             | Fix bugs, re-submit         |
| `answer`                 | Apply response, continue    |
| `validation_request`     | Run validation              |
| `wake_up`                | Resume if idle              |
| `retrospective_initiate` | Contribute to retrospective |

---

## Working State

### When You Start Working

**Update YOUR state file** (not prd.json):

```json
{
  "state": {
    "status": "working",
    "lastSeen": "{NOW}",
    "currentTaskId": "{taskId}",
    "pid": 0
  }
}
```

### Heartbeat While Working

**Update heartbeat every 60 seconds** while actively working:

```json
{
  "state": {
    "status": "working",
    "lastSeen": "{NOW}",
    "currentTaskId": "{taskId}",
    "pid": 0
  }
}
```

**Quick update pattern:**

1. Read: `.claude/session/current-task-{your-agent}.json`
2. Update `state.lastSeen` timestamp
3. Write back

**DO NOT skip heartbeat** - PM needs to know you're alive!

---

## Idle Behavior

**When you have NO assigned task:**

### 1. Update Heartbeat (Every 30 seconds)

```json
{
  "state": {
    "status": "idle",
    "lastSeen": "{NOW}",
    "currentTaskId": null,
    "pid": 0
  }
}
```

### 2. Poll for Coordinator Status

Read `sessionStatus` from your state file:

- If `running` → Continue waiting
- If `completed/terminated/max_iterations_reached` → Exit

### 3. Wait 30 Seconds

Repeat until:

- Messages arrive in your queue
- Coordinator status changes to terminal state
- Watchdog spawns you with work

---

## Sending Completion

### When Work Is Complete

**Step 1:** Send completion message to PM

```json
{
  "id": "msg-pm-{timestamp}-{seq}",
  "from": "{your-agent}",
  "to": "pm",
  "type": "task_complete",
  "priority": "normal",
  "payload": {
    "taskId": "{taskId}",
    "success": true,
    "summary": "Implementation complete"
  },
  "timestamp": "{ISO-8601-UTC}",
  "status": "pending"
}
```

**Step 2:** Update YOUR state file status to idle

```json
{
  "state": {
    "status": "idle",
    "lastSeen": "{NOW}",
    "currentTaskId": null,
    "pid": 0
  }
}
```

**Step 3:** Exit

Watchdog will respawn you when new messages arrive.

**What happens next (PM handles this):**

- **PM will HANDOFF your task to the next agent in workflow:**
  - Developer → QA: Your task JSON copied to current-task-qa.json
  - Tech Artist → QA: Your task JSON copied to current-task-qa.json
  - QA → Archive: Task added to prd_completed.txt

- **PM will update your state file:**
  - Task moved to your "Completed Tasks" array
  - Task cleared from "Active Task" section (null/unassigned)

- **After full completion and archival:**
  - Task removed from your "Completed Tasks" array
  - Task permanently archived in prd_completed.txt

---

## When Blocked

**If you need clarification:**

### 1. Send Question to PM

```json
{
  "id": "msg-pm-{timestamp}-{seq}",
  "from": "{your-agent}",
  "to": "pm",
  "type": "question",
  "priority": "high",
  "payload": {
    "question": "How should I handle X?",
    "context": "Current situation..."
  },
  "timestamp": "{ISO-8601-UTC}",
  "status": "pending"
}
```

### 2. Update Status to Awaiting (in YOUR state file)

```json
{
  "state": {
    "status": "awaiting_pm",
    "lastSeen": "{NOW}",
    "currentTaskId": "{taskId}",
    "pid": 0
  }
}
```

### 3. Exit

Watchdog has 10-minute timeout (configurable via `RALPH_AWAITING_TIMEOUT`) before alerting PM.

---

## Single Source of Truth (v2.0 - Per-Agent State Files)

**IMPORTANT: Architecture changed in v2.0**

**OLD (v1.x):** All agents read prd.json
**NEW (v2.0):** Workers read ONLY their state file

### What You Update

Update `.claude/session/current-task-{your-agent}.json`:

| Field           | Description                                     |
| --------------- | ----------------------------------------------- |
| `status`        | `idle`, `working`, `awaiting_pm`, `awaiting_gd` |
| `lastSeen`      | ISO timestamp of last update                    |
| `currentTaskId` | Task you're working on (null if idle)           |

**DO NOT read or write prd.json** - PM handles that.

### What PM Controls

- PM reads all agent state files to monitor worker status
- PM syncs changes to prd.json for session tracking
- `items[{taskId}].status` — PM updates based on your messages
- `items[{taskId}].passes` — PM updates based on QA validation

---

## Status Reference Summary

**For complete status values, see `shared-core` skill.**

Quick reference:

| Your Status   | When to Use                        |
| ------------- | ---------------------------------- |
| `idle`        | No task assigned, monitoring       |
| `working`     | Actively working on task           |
| `awaiting_pm` | Waiting for PM response            |
| `awaiting_gd` | Waiting for Game Designer response |

---

## Event-Driven vs Sequential Mode

| Aspect           | Event-Driven                         | Sequential                           |
| ---------------- | ------------------------------------ | ------------------------------------ |
| Agent spawning   | Watchdog spawns when messages exist  | One agent at a time, handoff between |
| Message delivery | JSON files in queues                 | Handoff signal file                  |
| Parallel work    | Yes - multiple agents simultaneously | No - agents take turns               |
| Communication    | Read/Write tools with JSON           | File-based handoff                   |

---

## Exit Conditions

**Workers MUST check coordinator status in THEIR state file and exit when:**

| Condition                                              | Action          |
| ------------------------------------------------------ | --------------- |
| `current-task-{agent}.json` shows `session.state.status: "completed"` | Exit gracefully |
| `current-task-{agent}.json` shows `session.state.status: "terminated"` | Exit gracefully |
| `current-task-{agent}.json` shows `session.state.status: "max_iterations_reached"` | Exit gracefully |

**Output:** `<promise>WORKER_EXIT</promise>`

**Do NOT read prd.json** - Check your state file instead.

---

## Context Window Management

**CRITICAL:** Reset context when reaching ~70% capacity.

**Detection:** After large work chunks, check context usage.

**Reset Procedure (Automatic):**

1. Read and save your state file content
2. Note your current task
3. Stop-hook will detect reset and continue with fresh context

**After Reset:**

- Re-read `.claude/session/current-task-{your-agent}.json`
- Continue from where you left off
- Do NOT repeat completed work

**Do NOT read prd.json** - It's 110KB and will bloat your context.

---

## Anti-Patterns

| Don't                       | Do Instead                 |
| --------------------------- | -------------------------- |
| Stay running after work     | Exit immediately           |
| Use loops to poll           | Let watchdog spawn you     |
| Skip heartbeat update       | Update every 30-60 seconds |
| Forget acknowledgment       | Always send to watchdog    |
| Use PowerShell for file ops | Use Glob/Read/Write tools  |
| **Read prd.json**          | **Read your state file only** |

---
