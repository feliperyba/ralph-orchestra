---
name: worker-protocol
description: Worker pool architecture - agents complete work and exit, watchdog orchestrates
category: orchestration
version: 2.0
keywords: [worker, pool, exit, complete, watchdog, message, task, orchestration]
---

# Worker Protocol

> "The heartbeat of Ralph agents - complete work, send message, exit."

## Overview

The **Worker Protocol** is the underlying pattern for all Ralph agents in both event-driven and sequential modes:

- **Agents** are workers that complete assigned tasks and exit
- **Watchdog** orchestrates by spawning agents based on message delivery
- **Message queues** provide communication for task assignment and completion signaling
- **NO polling** - agents do not continuously check state
- **NO infinite loops** - agents complete work and exit

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    WATCHDOG (Orchestrator)                       │
│                                                                   │
│  1. Spawn agent with task (or pending messages)                │
│  2. Wait for agent to exit                                       │
│  3. Check for new messages in agent inboxes                     │
│  4. Decide next agent based on message types                    │
│  5. Repeat until session complete                               │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                ┌───────────▼─────────────┐
                │  Message Flow:          │
                │  PM → Workers           │
                │  Workers → PM           │
                │  Workers → Watchdog     │
                └──────────────────────────┘
```

## Agent Lifecycle

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   START     │ ──▶ │  DO WORK     │ ──▶ │   EXIT      │
│ (check for  │     │ (complete    │     │ (send pipe  │
│  messages)  │     │  single task) │     │  message)   │
└─────────────┘     └──────────────┘     └─────────────┘
```

**Key Principle:** Each agent run does ONE unit of work, then exits. Watchdog restarts when needed.

## Message Format

```json
{
  "type": "task_assign|task_complete|question|answer",
  "from": "pm|developer|qa|techartist|gamedesigner",
  "to": "pm|developer|qa|techartist|gamedesigner",
  "payload": {
    "taskId": "feat-001",
    "status": "completed|needs_fixes|passed|failed"
  },
  "id": "msg-{recipient_agent}-{timestamp}-{seq}",
  "timestamp": "2026-01-21T10:15:30Z"
}
```

**Message ID format:** `msg-{recipient_agent}-{timestamp}-{seq}`
- `recipient_agent`: The agent receiving the message (pm, developer, qa, etc.)
- `timestamp`: Compact format `yyyyMMdd-HHmmss` (e.g., `20250123-101530`)
- `seq`: 3-digit sequence number (001, 002, etc.) prevents collisions

## Event-Driven vs Sequential Mode

| Aspect | Event-Driven Mode | Sequential Mode |
|--------|-------------------|-----------------|
| **Agent spawning** | Watchdog detects inbox messages, spawns agent | One agent at a time, handoff between agents |
| **Message delivery** | Inbox files + agent restart | Handoff signal file |
| **Parallel work** | Yes - multiple agents can run simultaneously | No - agents take turns |
| **Startup command** | `/ralph-coordinator-event` + worker skills | `/ralph-coordinator-single` + worker skills |

## Agent Workflow

### 1. Startup

```
Check for messages: .claude/session/messages/{agent}/msg-{agent}-{yyyyMMdd-HHmmss}-{seq}.json
```

### 2. Receive Task

If `task_assign` message in agent's message directory:
```
- Extract task details from message payload
- Begin implementation
```

### 3. Complete Work

```
- Do the assigned work (implement feature, run validation, etc.)
- Update status in prd.json.agents.{agent}
```

### 4. Send Completion Message

```
Write: .claude/session/messages/pm/msg-pm-{timestamp}-{seq}.json
```

### 5. Exit

```
- Clean up, send status_update to watchdog
- Exit - watchdog will spawn again when needed
```

## Watchdog Workflow

### 1. Initialize Session

```
Initialize prd.json.session with iteration=0, phase=initializing
```

### 2. Spawn PM Agent First

```
PM reads state, determines which workers need messages
PM sends task messages to worker inboxes
PM exits
```

### 3. Spawn Workers Based on Messages

```
Check .claude/session/messages/{worker}/ for pending messages
Spawn corresponding worker agents
Wait for workers to exit
```

### 4. Process Completion Messages

```
Check .claude/session/messages/pm/ for completion/status messages
Decide next action:
  - task_complete from worker → assign next task or send to QA
  - task_complete from QA (passed) → trigger retrospective
  - bug_report from QA → reassign to worker
```

### 5. Repeat or Complete

```
if (all PRD tasks complete) {
    signal session complete
    exit
} else {
    repeat from step 2
}
```

## Key Differences from Polling

| Aspect | Polling (Legacy) | Worker Pool (Current) |
| ------- | ---------------- | --------------------- |
| Agent lifecycle | Infinite loop | Complete work and exit |
| State checking | Every 30 seconds | Once per task |
| Watchdog role | Route messages | Orchestrate agent spawning |
| Message delivery | Restart agent with pending messages | Detect inbox messages |

## Message Types and Workflow

| Message Type | From | When Sent | Next Agent | Payload |
| ------------ | ---- | --------- | ---------- | ------- |
| `task_assign` | pm | Task selected | developer/techartist | Task details |
| `task_complete` | developer | Implementation done | qa | taskId, summary |
| `task_complete` | techartist | Asset work done | qa | taskId, summary |
| `task_complete` | qa | Validation complete | pm | taskId, validationPassed |
| `bug_report` | qa | Validation failed | pm | taskId, bugs |
| `question` | any | Needs clarification | pm | question, context |
| `answer` | pm | Response to question | requester | answer |
| `retrospective_initiate` | pm | QA passed validation | all | taskId |
| `playtest_request` | pm | Retrospective started | gamedesigner | taskId |
| `session_complete` | pm | All tasks done | watchdog | {} |

## File-Based Communication

**Sending messages:** Use Write tool to create files

```
.claude/session/messages/{recipient}/{message-id}.json
```

**Receiving messages:** Watchdog checks for message files

```
.claude/session/messages/{agent}/msg-{agent}-*.json
```

**State tracking:**

```
prd.json.session (session state)
prd.json.agents.{agent} (agent status)
prd.json.items[{taskId}] (task details)
```

## Exit Conditions

Agents exit under these conditions:

1. **Work completed** → Send completion message → Exit
2. **Need PM clarification** → Send `question` message → Exit
3. **Blocking issue** → Send `work_blocked` message → Exit
4. **Session complete** → PM sends `session_complete` → All exit

Watchdog exits when:

1. All PRD items have `passes: true`
2. PM sends `session_complete` message
3. `/cancel-ralph` invoked

## See Also

- [`.claude/skills/ralph-core.md`](ralph-core.md) — Session structure
- [`.claude/skills/ralph-event-protocol.md`](ralph-event-protocol.md) — Event-driven architecture
- [`.claude/skills/message-handling.md`](message-handling.md) — Message processing
