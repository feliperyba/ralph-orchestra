---
name: ralph-event-protocol
description: Message-based communication protocol for event-driven multi-agent orchestration
category: orchestration
version: 2.0
---

# Ralph Event-Driven Protocol

This document defines the message-based communication protocol for event-driven multi-agent orchestration.

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
           │                    │                    │
    ┌───────────┐        ┌───────────┐
    │TechArtist │◄──────►│GameDesigner│
    │ (Worker)  │        │ (Worker)  │
    └───────────┘        └───────────┘
```

## Event-Driven Worker Pool Model

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

**Receiving messages:** Watchdog restarts you when messages exist in `.claude/session/messages/{agent}/`
- Message format: `msg-{agent}-{yyyyMMdd-HHmmss}-{seq}.json`
- Each message is a separate file

## Message Format

```json
{
  "id": "msg-developer-20240120-120000-001",
  "from": "pm",
  "to": "developer",
  "type": "task_assign",
  "priority": "normal",
  "payload": {
    "taskId": "feat-001",
    "title": "Implement user auth"
  },
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
| `type` | string | Message type (see below) |
| `priority` | string | `low`, `normal`, `high`, `urgent` |
| `payload` | object | Type-specific data |
| `timestamp` | string | ISO 8601 UTC |
| `status` | string | `pending`, `processing`, `completed` |

**Message ID format details:**
- `recipient_agent`: The agent receiving the message (pm, developer, qa, etc.)
- `timestamp`: Compact format `yyyyMMdd-HHmmss` (e.g., `20240120-120000`)
- `seq`: 3-digit sequence number (001, 002, etc.) prevents collisions

## Message Acknowledgment Protocol (P0-4 Fix)

**Purpose:** Prevent circular wait conditions, especially PM ↔ Game Designer communication.

### When to Send ACK

Send an ACK message when you receive:
1. **Critical messages** that require confirmation of receipt
2. **Messages from Game Designer** (prevents PM circular wait)
3. **Messages that start a new phase** (retrospective_initiate, playtest_session_request)
4. **Messages with explicit `requiresAck: true` in payload**

### ACK Message Format

```json
{
  "id": "msg-pm-20240120-120500-003",
  "from": "pm",
  "to": "gamedesigner",
  "type": "ack",
  "priority": "normal",
  "payload": {
    "acknowledges": "msg-gamedesigner-20240120-120455-001",
    "originalType": "prd_analysis_response",
    "timestamp": "2024-01-20T12:00:00.000Z"
  },
  "timestamp": "2024-01-20T12:05:00.000Z",
  "status": "completed"
}
```

### ACK Processing Pattern

**When receiving a message that requires ACK:**
1. Process the message content
2. Send ACK to confirm receipt
3. Exit (watchdog will restart you if needed)

**When you receive an ACK:**
- Update message status to `completed` (if tracking)
- No further action needed
- Continue processing other messages or exit

### Critical ACK Pairs

| Sender → Receiver | Message Type | ACK Required | ACK Type |
|-------------------|--------------|--------------|----------|
| Game Designer → PM | `prd_analysis_response` | Yes | `ack` |
| Game Designer → PM | `acceptance_criteria` | Yes | `ack` |
| Game Designer → PM | `playtest_session_report` | Yes | `ack` |
| PM → Game Designer | `prd_analysis_request` | Optional | `ack` |
| PM → Game Designer | `acceptance_criteria_request` | Optional | `ack` |
| Worker → PM | `question` | Yes | `ack` |
| PM → Worker | `priority_response` | Optional | `ack` |

### Preventing Circular Wait

**Problem:** PM sends `prd_analysis_request` to GD → GD responds → PM waits → no one moves forward.

**Solution with ACK:**
1. PM sends `prd_analysis_request` to GD
2. PM exits (doesn't wait)
3. GD receives, processes, sends `prd_analysis_response`
4. PM receives response, sends ACK immediately
5. PM exits to process response

## Message Types

### All Agents Send

| Type | To | Purpose |
|------|-----|---------|
| `ack` | any | Acknowledge message receipt (prevents circular wait) |

### PM Sends

| Type | To | Purpose |
|------|-----|---------|
| `task_assign` | developer | Assign task |
| `asset_assign` | techartist | Assign asset/shader task |
| `retrospective_initiate` | developer,techartist,qa | Start worker retrospective (NOT gamedesigner) |
| `playtest_session_request` | gamedesigner | Request playtest session (NEW) |
| `acceptance_criteria_request` | gamedesigner | Request acceptance criteria before task assignment (NEW) |
| `prd_analysis_request` | gamedesigner | Request PRD analysis and task recommendations (NEW) |
| `test_plan_request` | qa/gamedesigner | Request test plan |
| `success_criteria_request` | gamedesigner | Request success criteria (legacy) |
| `priority_response` | any | Answer question |
| `prd_reorganized` | all | Notify of PRD changes |

### Developer Sends

| Type | To | Purpose |
|------|-----|---------|
| `task_complete` | pm | Implementation done |
| `question` | pm/gamedesigner | Ask for clarification |
| `validation_request` | qa | Request QA validation |
| `status_update` | watchdog | Report status |

### Tech Artist Sends

| Type | To | Purpose |
|------|-----|---------|
| `task_complete` | pm | Asset/shader work done |
| `question` | pm/gamedesigner | Ask for clarification |
| `asset_question` | pm | Asset specs unclear |
| `status_update` | watchdog | Report status |

### QA Sends

| Type | To | Purpose |
|------|-----|---------|
| `task_complete` | pm | Validation passed |
| `bug_report` | pm | Validation failed, bugs found |
| `test_plan_contribution` | pm | Test plan input |
| `status_update` | watchdog | Report status |

### Game Designer Sends

| Type | To | Purpose |
|------|-----|---------|
| `playtest_session_report` | pm | Playtest results with Playwright MCP (NEW) |
| `acceptance_criteria` | pm | Success criteria and test plan for task (NEW) |
| `prd_analysis_response` | pm | PRD analysis and task recommendations (NEW) |
| `playtest_report` | pm | Playtest results (legacy) |
| `success_criteria` | pm | Success criteria for task (legacy) |
| `test_plan_contribution` | pm | Test plan input |
| `gdd_ready` | pm | GDD created/updated |
| `question` | pm | Design question |

## Workflow Patterns

### Task Completion Flow (New Phased Workflow)

```
# Phase 1: Implementation
PM → Developer: task_assign
     (Developer works, exits)
PM ← Developer: task_complete
PM → QA: validation_request
     (QA validates, exits)
PM ← QA: task_complete (validationPassed: true)

# Phase 2: Worker Retrospective (Workers Only)
PM → Developer, TechArtist, QA: retrospective_initiate
     (Workers contribute)
PM ← All: retrospective contributions
PM: Synthesize, commit, set retrospective_synthesized

# Phase 3: Playtest Session (Separate Phase)
PM → GameDesigner: playtest_session_request
     (GameDesigner playtests via Playwright MCP)
PM ← GameDesigner: playtest_session_report
PM: Review findings, commit if PRD updated

# Phase 4: PRD Refinement (Optional)
PM → GameDesigner: prd_analysis_request
PM ← GameDesigner: prd_analysis_response
PM: Select next task based on input

# Phase 5: Acceptance Criteria (MANDATORY Before Assignment)
PM → GameDesigner: acceptance_criteria_request
PM ← GameDesigner: acceptance_criteria
PM: Incorporate into task definition

# Phase 6: Skill Research
PM: Improve ALL skills, commit
PM: Set task status to completed

# Phase 7: Next Task Assignment
PM → Developer: next task_assign (NOW with proper acceptance criteria)
```

### Bug Fix Flow

```
PM ← QA: bug_report
PM → Developer: task_assign (with bug details)
     (Developer fixes, exits)
PM ← Developer: task_complete
PM → QA: validation_request
```

### Question/Answer Flow

```
Developer → PM: question
PM → Developer: priority_response
```

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

## Session Lifecycle

### Startup (PM-First Initialization)

1. Watchdog starts
2. Watchdog starts ONLY PM agent
3. PM clears stale messages, reads state files
4. PM determines which workers need activation
5. PM sends activation messages to worker inboxes
6. Watchdog detects messages and starts workers

### Running (Event-Driven Loop)

1. Watchdog spawns agent (when messages exist in their inbox)
2. Agent checks for message files in `.claude/session/messages/{agent}/`
3. Agent processes messages / does work
4. Agent sends completion/status message
5. Agent exits
6. Repeat when watchdog has more work

### Completion

1. PM marks all PRD tasks complete
2. PM sends `session-complete.flag`
3. Watchdog signals shutdown to all agents
4. All agents exit gracefully

## Best Practices

1. **Small, Focused Messages**: One concern per message
2. **Include Context**: TaskId, references in payload
3. **Exit When Done**: Don't stay running idle
4. **Status Updates**: Send to watchdog so it knows you're alive
5. **Use ReplyTo**: Link responses to questions
