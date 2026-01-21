---
name: ralph-event-protocol
description: Message-based communication protocol for event-driven multi-agent orchestration
category: orchestration
depends-on: [ralph-core]
---

# Ralph Event-Driven Protocol

This document defines the message-based communication protocol for event-driven multi-agent orchestration.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    WATCHDOG (Message Broker)                     │
│  - Routes messages between agents                                │
│  - Monitors agent health                                         │
│  - Restarts crashed agents                                       │
│  - Manages session lifecycle                                     │
└─────────────────────────────────────────────────────────────────┘
           │                    │                    │
           ▼                    ▼                    ▼
    ┌───────────┐        ┌───────────┐        ┌───────────┐
    │    PM     │◄──────►│ Developer │◄──────►│    QA     │
    │(Coordinator)       │ (Worker)  │        │ (Worker)  │
    └───────────┘        └───────────┘        └───────────┘
           │                    │                    │
           └────────────────────┴────────────────────┘
                         MESSAGE QUEUE
                   .claude/session/messages/
```

## Message Queue Structure

```
.claude/session/messages/
├── pm/                 # PM's inbox
│   └── msg-xxx.json
├── developer/          # Developer's inbox
│   └── msg-xxx.json
├── qa/                 # QA's inbox
│   └── msg-xxx.json
└── watchdog/           # Watchdog's inbox
    └── msg-xxx.json
```

**Note**: Processed messages are deleted immediately after processing, not archived. An audit log is written to `.claude/session/messages.log` for tracking.

## Message Format

```json
{
  "id": "msg-20240120-120000-a1b2c3d4",
  "from": "pm",
  "to": "developer",
  "type": "task_assign",
  "priority": "normal",
  "payload": {
    "taskId": "feat-001",
    "title": "Implement user auth",
    "description": "..."
  },
  "timestamp": "2024-01-20T12:00:00Z",
  "status": "pending",
  "replyTo": null
}
```

### Fields

| Field     | Type   | Description                                     |
| --------- | ------ | ----------------------------------------------- |
| id        | string | Unique message ID: `msg-{date}-{time}-{random}` |
| from      | string | Sender: `pm`, `developer`, `qa`, `watchdog`     |
| to        | string | Recipient: `pm`, `developer`, `qa`, `watchdog`  |
| type      | string | Message type (see below)                        |
| priority  | string | `low`, `normal`, `high`, `urgent`               |
| payload   | object | Type-specific data                              |
| timestamp | string | ISO 8601 UTC timestamp                          |
| status    | string | `pending`, `processing`, `completed`, `failed`  |
| replyTo   | string | Original message ID (for responses)             |

## Message Types

### PM Sends

| Type                    | To              | Payload                                                           |
| ----------------------- | --------------- | ----------------------------------------------------------------- |
| `task_assign`           | developer       | `{ taskId, title, description, acceptanceCriteria[], worktree? }` |
| `retrospective_initiate`| developer/qa    | `{ taskId, retrospectiveFile }`                                    |
| `priority_response`     | developer/qa    | `{ decision, reasoning }`                                         |
| `prd_update`            | developer/qa    | `{ taskId, changes }`                                             |
| `regression_request`    | qa              | `{ scope, focus }`                                                |
| `answer`                | any             | `{ answer }`                                                      |

### Developer Sends

| Type                 | To       | Payload                                      |
| -------------------- | -------- | -------------------------------------------- |
| `validation_request` | qa       | `{ taskId, description, branch, worktree? }` |
| `question`           | pm       | `{ question, context, taskId }`              |
| `skill_request`      | pm       | `{ requestType, description, reason, taskId }` |
| `status_update`      | watchdog | `{ status, currentTask, details }`           |

### QA Sends

| Type            | To       | Payload                                           |
| --------------- | -------- | ------------------------------------------------- |
| `task_complete` | pm       | `{ taskId, summary, validationPassed }`           |
| `bug_report`    | pm       | `{ taskId, bugs[], severity, recommendedAction }` |
| `question`      | pm       | `{ question, context, taskId }`                   |
| `skill_request` | pm       | `{ requestType, description, reason, taskId }`     |
| `status_update` | watchdog | `{ status, currentTask, details }`                |

### Any Agent Sends

| Type            | To       | Payload                        |
| --------------- | -------- | ------------------------------ |
| `agent_ready`   | watchdog | `{ agent, startTime }`         |
| `work_complete` | watchdog | `{ type: "session_complete" }` |
| `error`         | watchdog | `{ error, context }`           |

### Watchdog Sends

| Type       | To  | Payload      |
| ---------- | --- | ------------ |
| `shutdown` | any | `{ reason }` |

## Priority Levels

| Priority | Description                | Use Case                              |
| -------- | -------------------------- | ------------------------------------- |
| `low`    | Status updates, non-urgent | Periodic status reports               |
| `normal` | Standard communication     | Task assignments, validation requests |
| `high`   | Needs attention            | Questions, bug reports                |
| `urgent` | Immediate action           | Critical bugs, shutdown commands      |

## Message Trigger Reference

Quick reference of WHEN to send each message type:

| Trigger | Message | From | To | Priority |
|---------|---------|------|-----|----------|
| **Lifecycle** |
| Agent starts | `agent_ready` | agent | watchdog | low |
| Agent changes status | `status_update` | agent | watchdog | low |
| Agent crashes | `error` | watchdog | pm | urgent |
| Session complete | `work_complete` | pm | watchdog | normal |
| **Development Flow** |
| Task assigned | (state file only) | pm | developer | — |
| Developer starts work | `status_update:working` | developer | watchdog | low |
| Developer finishes | `implementation_complete` | developer | qa | high |
| QA starts validation | `status_update:working` | qa | watchdog | low |
| QA validation passes | `task_complete` | qa | pm | normal |
| QA validation fails | `bug_report` | qa | pm | high |
| **Issues & Blocking** |
| Needs clarification | `question` | any | pm | high |
| Work blocked | `work_blocked` | worker | pm | urgent |
| Giving up on task | `task_abandoned` | worker | pm | urgent |
| Quality concern (non-blocking) | `quality_concern` | qa | pm | normal |
| **Coordination** |
| Retrospective ready | `retrospective_initiate` | pm | all | normal |
| Skill improvement needed | `skill_request` | worker | pm | normal |
| PM decision made | `answer` / `priority_response` | pm | requester | high |

## State vs Message Coordination

### When to Use State Files (coordinator-state.json)

| Action | File | Reason |
|--------|-----|-------|
| Heartbeat updates | `coordinator-state.json` | Polling-based health check |
| Task status changes | `coordinator-state.json` | Persistent state for recovery |
| Completion tracking | `prd.json` | PRD task completion status |

**State files are the source of truth** - they survive restarts and enable recovery.

### When to Use Messages

| Action | Message Type | Reason |
|--------|--------------|-------|
| Announce work complete | `implementation_complete` | Trigger QA to start |
| Report blocker | `work_blocked` | Immediate PM attention |
| Ask question | `question` | Asynchronous communication |
| Session completion | `work_complete` | Signal watchdog to shutdown |

**Messages are event notifications** - they trigger immediate action in other agents.

### Key Principle

**State files = Persistent truth** (survives restarts)
**Messages = Event notifications** (triggers immediate action)

Update BOTH when state changes:

1. **Update coordinator-state.json** (persistent record)
   ```powershell
   $state = Get-Content ".claude/session/coordinator-state.json" -Raw | ConvertFrom-Json
   $state.agents.developer.status = "working"
   $state | ConvertTo-Json -Depth 10 | Set-Content ".claude/session/coordinator-state.json"
   ```

2. **Send message** (notify other agents)
   ```powershell
   Send-AgentMessage -From "developer" -To "qa" -Type "implementation_complete" -Payload @{
       taskId = "feat-001"
       commit = "abc123"
       summary = "Implemented feature"
   } -Priority "high"
   ```

### Why Both Are Required

| Scenario | State File Only | Message Only | Both |
|----------|----------------|--------------|------|
| Agent crash during work | ✅ Can recover | ❌ Lost notification | ✅ Best of both |
| Real-time coordination | ❌ Requires polling | ✅ Immediate trigger | ✅ Best of both |
| Session restart | ✅ State preserved | ❌ Messages deleted | ✅ Best of both |

**Best Practice**: Always update state file AND send message when significant events occur.

## Workflow Patterns

### Task Completion Flow (with Retrospective)

```
PM                    Developer               QA
 │                        │                    │
 ├──task_assign──────────►│                    │
 │                        │                    │
 │                        ├──validation_request────►│
 │                        │                    │
 │◄─────────────────────────────task_complete──┤
 │     (validationPassed=true)                   │
 │                                                │
 │ [PM triggers retrospective]                    │
 │ ├──creates retrospective.txt─────────────────►│
 │ └────────────────────────────────────────────►│
 │                                                │
 │◄────[Developer contribution]──────────────────┤
 │◄────[QA contribution]──────────────────────────┤
 │                                                │
 │ [PM synthesizes, completes retrospective]      │
 │                                                │
 │──task_assign──────────►│ (next task)          │
 │                                                │
```

**CRITICAL**: PM must NOT assign the next task until retrospective completes. The flow is:
1. QA sends `task_complete` with `validationPassed: true`
2. PM creates `retrospective.txt` and waits for contributions
3. Developer and QA contribute their perspectives
4. PM synthesizes and completes retrospective
5. Only THEN does PM assign the next task

### Bug Fix Flow

```
PM                    Developer               QA
 │                        │                    │
 │◄────────────────────────────bug_report──────┤
 │                        │                    │
 │  (PM analyzes priority)│                    │
 │                        │                    │
 ├──task_assign──────────►│                    │
 │  (with bug details)    │                    │
 │                        │                    │
 │                        ├──validation_request────►│
 │                        │                    │
```

### Question/Answer Flow

```
Developer               PM
    │                    │
    ├──question─────────►│
    │                    │
    │◄─────────answer────┤
    │                    │
```

## Parallel Work Support

### Developer Worktrees

Developer can work on multiple tasks using git worktrees:

```bash
# PM assigns task-a and task-b

# Developer creates worktrees
git worktree add ../RalphOrchestra-task-a -b task-a
git worktree add ../RalphOrchestra-task-b -b task-b

# Work in parallel
# Each worktree can have separate validation_request
```

When PM assigns a task with `worktree` field:

```json
{
  "type": "task_assign",
  "payload": {
    "taskId": "feat-002",
    "worktree": "../RalphOrchestra-feat-002"
  }
}
```

### PM Research

While developer is coding, PM can:

- Research upcoming tasks
- Refine requirements
- Answer questions

### QA Regression

PM can request regression testing while developer works:

```json
{
  "type": "regression_request",
  "to": "qa",
  "payload": {
    "scope": "full",
    "focus": "authentication"
  }
}
```

## Processing Rules

1. **Priority First**: Process urgent messages before normal
2. **FIFO within Priority**: Older messages before newer
3. **Acknowledge After Processing**: Delete immediately after processing (do not archive)
4. **PM Decides Priorities**: Bug reports go to PM, not directly to developer

## Session Lifecycle

### Startup

1. Watchdog starts
2. Watchdog initializes message queue
3. Watchdog starts all agents
4. Each agent sends `agent_ready` to watchdog
5. PM reads PRD, assigns first task

### Running

1. Agents work on tasks
2. Agents check inbox periodically
3. Agents send/receive messages
4. Watchdog monitors health

### Completion

1. PM marks all PRD tasks as complete
2. PM sends `work_complete` with `type: "session_complete"`
3. Watchdog signals shutdown to all agents
4. Agents exit gracefully

## Error Handling

### Agent Crash

1. Watchdog detects process exit
2. If pending messages exist, restart agent
3. If multiple crashes, increase wait time

### Message Processing Failure

1. Set message status to `failed`
2. Send `error` to watchdog
3. PM can retry or reassign

## File-Based Signaling

For critical signals, use files instead of messages:

| File                     | Purpose                     |
| ------------------------ | --------------------------- |
| `session-complete.flag`  | Session complete signal     |
| `coordinator-state.json` | Current orchestration state |
| `current-task.json`      | Active task details         |

## Best Practices

1. **Small, Focused Messages**: One concern per message
2. **Include Context**: TaskId, references in payload
3. **Use replyTo**: Link responses to questions
4. **Status Updates**: Send periodically so watchdog knows you're alive
5. **Delete Promptly**: Remove processed messages immediately to avoid reprocessing
