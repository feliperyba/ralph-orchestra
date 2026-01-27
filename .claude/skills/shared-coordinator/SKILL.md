---
name: shared-coordinator
description: PM coordinator for both event-driven and single-agent orchestration modes
category: orchestration
keywords: [pm, coordinator, event-driven, single-agent, task-assignment, orchestration]
---

# Shared Coordinator

> "PM coordinates tasks, assigns work, monitors health, runs retrospectives."

**This skill covers coordinator behavior for both orchestration modes:**
- Event-driven mode — Parallel agents, message-based communication
- Single-agent mode — Sequential agents, handoff-based communication

**For complete PM workflow, see `pm-workflow` skill.**

---

## Coordinator Role Overview

As PM coordinator, you:

1. **Select tasks** from PRD based on priority and dependencies
2. **Assign tasks** to workers (Developer, QA, TechArtist, GameDesigner)
3. **Monitor worker health** via heartbeat timestamps in prd.json
4. **Track completion** through task status and QA validation
5. **Run retrospectives** after each completed task
6. **Detect session completion** when all tasks pass

---

## Mode Selection

The orchestration mode is set in `prd.json.session.orchestrationMode`:

| Mode | Parallel Work | Communication | Spawning |
|------|---------------|---------------|----------|
| `event-driven` | Yes | Message queues | Watchdog spawns on demand |
| `single-agent` | No | Handoff phrases | One agent at a time |

---

## Event-Driven Mode

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    WATCHDOG (Message Broker)                     │
│  - Spawns agents when messages exist in their queues               │
│  - Routes messages via file queues                                 │
│  - Monitors agent health                                           │
└─────────────────────────────────────────────────────────────────┘
        ▲
        │ (reads/writes message files)
        │
┌───────────────┐
│  PM (You)     │ ← Uses Glob/Read/Write tools
└───────────────┘
```

### Startup (First Run)

Create session directory and initialize state files:

```bash
# Create session directory
mkdir -p .claude/session/messages/{pm,developer,qa,techartist,gamedesigner,watchdog}

# Initialize handoff-log.json
{ "handoffs": [] }

# Initialize coordinator-progress.txt
# (See Progress Logging section below)
```

### Idle Behavior (When No Active Task)

**When `prd.json.session.currentTask` is null OR `status === "passed"`:**

1. **Update heartbeat** (every 30 seconds):
   ```json
   {
     "agents": {
       "pm": {
         "lastSeen": "{NOW}",
         "status": "idle"
       }
     }
   }
   ```

2. **Check worker heartbeats** — Log warning if worker not seen in 60+ seconds

3. **Check for completion** — All PRD items `passes: true`?

4. **Select next task** — See Task Selection below

### Task Assignment Flow

**Step 1:** Select task from PRD (see Task Selection Algorithm)

**Step 2:** Update PRD atomically:
```json
{
  "items": [{
    "id": "{taskId}",
    "status": "assigned",
    "agent": "developer",
    "assignedAt": "{NOW}"
  }],
  "agents": {
    "developer": {
      "status": "working",
      "currentTaskId": "{taskId}",
      "lastSeen": "{NOW}"
    }
  },
  "session": {
    "currentTask": {
      "id": "{taskId}",
      "status": "assigned",
      "assignedAt": "{NOW}"
    }
  }
}
```

**Step 3:** Send message to worker's queue:
```json
{
  "id": "msg-developer-{NOW}-001",
  "from": "pm",
  "to": "developer",
  "type": "task_assign",
  "priority": "normal",
  "payload": {
    "taskId": "{taskId}",
    "title": "{TITLE}",
    "acceptanceCriteria": ["..."]
  },
  "timestamp": "{NOW}",
  "status": "pending"
}
```

**Step 4:** Log handoff to `handoff-log.json`

### Worker Health Monitoring

Check `prd.json.agents.{agent}.lastSeen`:

| Condition | Action |
|-----------|--------|
| Not seen in 60+ seconds | Log warning |
| Not seen in 120+ seconds | Log concern, consider reassign |
| Worker dies during task | Note for reassignment |

### Completion Detection

**A task is ONLY complete when:**
1. Developer → `status: "awaiting_qa"`
2. QA validates → `status: "passed"`
3. PM runs retrospective → `currentTask: null`
4. PM marks `prd.json.items[{taskId}].passes: true`

**Session complete when:** ALL PRD items have `passes: true`

---

## Single-Agent Mode

### Key Differences

| Aspect | Event-Driven | Single-Agent |
|--------|--------------|--------------|
| Your role | Poll continuously | Work, then handoff |
| Other agents | Running in parallel | Only started when needed |
| Communication | File polling | Handoff phrases |
| Your exit | Never (poll forever) | Handoff to another agent |

### Handoff Protocol

When you need another agent, output:

```
HANDOFF:agent_name:base64_context
```

**See `shared-handoff` skill for full protocol details.**

### Startup (First Run)

```bash
# Create session directory
mkdir -p .claude/session

# Initialize prd.json.session
{
  "sessionId": "ralph-single-{TIMESTAMP}",
  "startedAt": "{ISO_TIMESTAMP}",
  "maxIterations": 200,
  "iteration": 0,
  "status": "running",
  "orchestrationMode": "single-agent",
  "currentAgent": "pm",
  "stats": {
    "totalTasks": "{COUNT FROM PRD}",
    "completed": 0,
    "failed": 0
  }
}

# Initialize handoff-log.json
{ "handoffs": [], "orchestrationMode": "single-agent" }
```

### Receiving Handoff Context

If you receive handoff context (from QA or Developer):

1. **Acknowledge** the handoff:
   ```
   Received handoff from [agent]: [reason]
   ```

2. **Read current state files**:
   - `prd.json.session`
   - `prd.json.items` (for task details)
   - `prd.json.agents` (for agent status)

3. **Process based on reason**:

   | Handoff Reason | Action |
   |----------------|--------|
   | `validation_passed` | Mark complete, select next task |
   | `validation_failed` | Review bugs, re-assign to developer |
   | `need_clarification` | Answer questions, update specs |
   | `error` | Investigate, decide next steps |

### Task Assignment Flow

1. **Select next task** from PRD
2. **Update `prd.json.items[{taskId}]`**: `status: "assigned"`, `assignedTo: "developer"`
3. **Update `prd.json.session.currentAgent`**: `"developer"`
4. **Update `prd.json.agents.developer`**: `status: "active"`, `currentTask: "{taskId}"`
5. **Save state completely** (CRITICAL before handoff)
6. **Signal ready:** `AGENT_READY_FOR_HANDOFF`
7. **Output handoff phrase:** `HANDOFF:developer:{BASE64_CONTEXT}`

### Processing Validation Results

**When QA hands off with `validation_passed`:**

1. Increment `prd.json.session.iteration`
2. Check max iterations — if `iteration >= maxIterations`: Set `status = "max_iterations_reached"`, output `<promise>RALPH_COMPLETE</promise>`
3. Run retrospective (required before next task)
4. Mark PRD item complete: `passes: true`, `completedAt: "{NOW}"`
5. Check for completion — if ALL items `passes: true`: Output `<promise>RALPH_COMPLETE</promise>`
6. Otherwise: Select and assign next task

**When QA hands off with `validation_failed`:**

1. Increment iteration counter
2. Check max iterations
3. Read bugs from handoff context
4. Update `prd.json.items[{taskId}]` with bug details
5. Handoff to Developer with fix instructions

### Complete PM Action Cycle

```
START
  │
  ▼
┌─────────────────────────────────┐
│ 1. Check handoff context        │
└─────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────┐
│ 2. Read current state files     │
└─────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────┐
│ 3. Determine action needed      │
└─────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────┐
│ 4. Execute action               │
└─────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────┐
│ 5. Save ALL state               │
└─────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────┐
│ 6. Signal ready                 │
│    AGENT_READY_FOR_HANDOFF      │
└─────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────┐
│ 7. Output handoff phrase        │
│    HANDOFF:agent:context        │
└─────────────────────────────────┘
```

---

## Task Selection Algorithm

**Applicable to both modes:**

```javascript
// Filter incomplete items
const incomplete = prd.items.filter(item => !item.passes);

// Filter unblocked (all dependencies passed)
const unblocked = incomplete.filter(item =>
  item.dependencies.every(dep =>
    prd.items.find(p => p.id === dep)?.passes === true
  )
);

// Sort by priority
const priority = {
  architectural: 1,
  integration: 2,
  spike: 3,
  unknown: 3,
  functional: 4,
  polish: 5
};
const sorted = unblocked.sort((a, b) => priority[a.category] - priority[b.category]);

// Select top item
const selected = sorted[0];
```

**Why this order?** Tackle hard problems first before easy wins bury you in technical debt.

---

## Common to Both Modes

### Status Values

**For complete status reference, see `shared-core` skill.**

Quick reference — `prd.json.session.status`:
- `running` — Session active
- `completed` — All tasks done
- `terminated` — Cancelled
- `max_iterations_reached` — Hit iteration limit

### Iteration Counting

**Each development cycle (assignment → completion) counts as 1 iteration:**

1. Increment `prd.json.session.iteration` after QA validation
2. Check if `iteration >= maxIterations`
3. If at limit, output `<promise>RALPH_COMPLETE</promise>` and set `status = "max_iterations_reached"`

### Progress Logging

Append to `.claude/session/coordinator-progress.txt`:

```markdown
### [{TIMESTAMP}] {TASK_ID}: {TITLE} - COMPLETE

- Implemented by: developer
- Validated by: qa
- Commit: {HASH}

Acceptance criteria:
✓ {CRITERION_1}
✓ {CRITERION_2}
```

### Handoff Logging

Append to `.claude/session/handoff-log.json`:

```json
{
  "handoffs": [{
    "timestamp": "{ISO_TIMESTAMP}",
    "from": "pm",
    "to": "developer",
    "task": "{TASK_ID}",
    "reason": "task_assignment",
    "iteration": {N}
  }]
}
```

### Session Completion Report

When all tasks complete, generate `.claude/session/final-report.md`:

```markdown
# Ralph Session Report

Session: {SESSION_ID}
Started: {START_TIME}
Completed: {END_TIME}
Duration: {DURATION}
Iterations: {TOTAL}

## Summary

✓ {COMPLETED} tasks completed successfully
✓ {COMMITS} commits made
✓ {PASS_RATE}% validation pass rate

## Completed Tasks

{LIST}

## Next Steps

{RECOMMENDATIONS}
```

---

## What PM Controls

| Field | You Control | Notes |
|-------|-------------|-------|
| `prd.json.session` | ✅ Full ownership | Session state |
| `prd.json.items[{taskId}].status` | ✅ Yes | Task flow management |
| `prd.json.items[{taskId}].passes` | ✅ Yes | Based on QA validation |
| `prd.json.items[{taskId}].agent` | ✅ Yes | Task assignment |
| `prd.json.agents.{agent}` | ✅ Yes | Coordinator privilege |
| `prd.json.agents.{agent}.status` | ✅ Yes | All agents |
| `prd.json.agents.{agent}.currentTaskId` | ✅ Yes | For assignment/reassignment |

---

## Exit Conditions

Output `<promise>RALPH_COMPLETE</promise>` when:

- All PRD items have `passes: true`
- QA has completed validation
- **OR** `iteration >= maxIterations`

Stop gracefully when `/cancel-ralph` is invoked.

---

## References

- `pm-workflow` — Complete PM workflow with decision framework
- `shared-core` — Status values, session structure
- `shared-messaging` — Event-driven message protocol
- `shared-handoff` — Single-agent handoff protocol
- `shared-state` — File ownership, atomic updates
