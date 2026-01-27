---
name: shared-coordinator
description: PM coordinator for both event-driven and single-agent orchestration modes
category: orchestration
---

# Shared Coordinator

> "PM coordinates tasks, assigns work, monitors health, runs retrospectives."

**This skill covers coordinator behavior for both orchestration modes:**

- Event-driven mode — Parallel agents, message-based communication
- Single-agent mode — Sequential agents, handoff-based communication

**For complete PM workflow, see `pm-workflow` skill.**

---

## Coordinator Role Overview (v2.0)

As PM coordinator, you:

1. **Select tasks** from PRD based on priority and dependencies
2. **Assign tasks** to workers (Developer, QA, TechArtist, GameDesigner)
3. **Monitor worker health** via agent state files (`current-task-*.md`)
4. **Sync state** between agent files and prd.json (PM-ONLY access)
5. **Track completion** through task status and QA validation
6. **Run retrospectives** after each completed task
7. **Detect session completion** when all tasks pass

**Key Change (v2.0):**
- Workers update their own `current-task-{agent}.md` files
- PM reads all agent state files to monitor status
- PM syncs changes to `prd.json.agents.*` section
- Workers NEVER read prd.json (saves ~109KB per read)

---

## Mode Selection

The orchestration mode is set in `prd.json.session.orchestrationMode`:

| Mode           | Parallel Work | Communication   | Spawning                  |
| -------------- | ------------- | --------------- | ------------------------- |
| `event-driven` | Yes           | Message queues  | Watchdog spawns on demand |
| `single-agent` | No            | Handoff phrases | One agent at a time       |

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

### Task Assignment Flow (v2.0 - Complete Task Copy)

**Step 1:** Select task from PRD (see Task Selection Algorithm)

**Step 2:** Read the COMPLETE task from prd.json.items[{taskId}]

**Step 3:** Update agent's state file with FULL task details:

```json
// Read agent's state file
Read: .claude/session/current-task-developer.json

// Update state object
{
  "state": {
    "status": "working",
    "lastSeen": "{NOW}",
    "currentTaskId": "{taskId}",
    "pid": 0
  },
  // Update task fields with COMPLETE task from PRD
  "id": "{taskId}",
  "title": "{FULL_TITLE_FROM_PRD}",
  "description": "{FULL_DESCRIPTION_FROM_PRD}",
  "category": "{category}",
  "priority": "{priority}",
  "tier": "{tier}",
  "status": "assigned",
  "passes": false,
  "agent": "developer",
  "dependencies": [...],
  "gddReference": "{gddReference}",
  "gddVersion": "{gddVersion}",
  "acceptanceCriteria": [...],
  "verificationSteps": [...],
  "retryCount": 0,
  "bugs": [],
  "assignedAt": "{NOW}",
  "completedAt": null
}
```

**Step 4:** Update PRD atomically:

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

**Step 5:** Send message to worker's queue:

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

### Worker Health Monitoring (v2.0)

**Read all agent state files** to check worker health:

```bash
# Read all worker state files
Read: .claude/session/current-task-developer.json
Read: .claude/session/current-task-qa.json
Read: .claude/session/current-task-techartist.json
Read: .claude/session/current-task-gamedesigner.json

# Update Worker Status Summary in current-task-pm.json
```

| Condition                | Action                         |
| ------------------------ | ------------------------------ |
| Not seen in 60+ seconds  | Log warning                    |
| Not seen in 120+ seconds | Log concern, consider reassign |
| Worker dies during task  | Note for reassignment          |

**PM also syncs to prd.json.agents.{agent} after checking state files:**

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

| Aspect        | Event-Driven         | Single-Agent             |
| ------------- | -------------------- | ------------------------ |
| Your role     | Poll continuously    | Work, then handoff       |
| Other agents  | Running in parallel  | Only started when needed |
| Communication | File polling         | Handoff phrases          |
| Your exit     | Never (poll forever) | Handoff to another agent |

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

   | Handoff Reason       | Action                              |
   | -------------------- | ----------------------------------- |
   | `validation_passed`  | Mark complete, select next task     |
   | `validation_failed`  | Review bugs, re-assign to developer |
   | `need_clarification` | Answer questions, update specs      |
   | `error`              | Investigate, decide next steps      |

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
const incomplete = prd.items.filter((item) => !item.passes);

// Filter unblocked (all dependencies passed)
const unblocked = incomplete.filter((item) =>
  item.dependencies.every((dep) => prd.items.find((p) => p.id === dep)?.passes === true)
);

// Sort by priority
const priority = {
  architectural: 1,
  integration: 2,
  spike: 3,
  unknown: 3,
  functional: 4,
  polish: 5,
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

## What PM Controls (v2.0)

| Field                                   | You Control       | Notes                                  |
| --------------------------------------- | ----------------- | -------------------------------------- |
| `prd.json.session`                      | ✅ Full ownership | Session state                          |
| `prd.json.items[{taskId}].status`       | ✅ Yes            | Task flow management                   |
| `prd.json.items[{taskId}].passes`       | ✅ Yes            | Based on QA validation                  |
| `prd.json.items[{taskId}].agent`        | ✅ Yes            | Task assignment                        |
| `prd.json.agents.{agent}`               | ✅ Yes            | **SYNCED from agent state files**       |
| `current-task-pm.json`                    | ✅ Full ownership | PM coordinator state                    |
| `current-task-{worker}.md`              | ✅ Read/Write     | **READ** all, **WRITE** on assignment  |

**PM's Sync Pattern (v2.0):**

1. **After processing each message:**
   - Read all agent state files
   - Update Worker Status Summary in current-task-pm.json
   - Sync changes to prd.json.agents section

2. **When assigning a task:**
   - Copy COMPLETE task JSON to worker's task fields
   - Update worker's state object
   - Update both state file AND prd.json
   - Send task message

3. **When receiving completion (HANDOFF pattern):**
   - Read agent state file for status
   - **HAND OFF task to next agent's state file** (see below)
   - Update prd.json accordingly

4. **When archiving completed task:**
   - Add to prd_completed.txt
   - **CLEAR task from ALL agent state files**
   - Delete from prd.json.items

## Task Handoff Pattern (v2.0)

**CRITICAL: Tasks move between agent state files as they progress through workflow.**

### Developer → QA Handoff

When Developer completes implementation:

```bash
# 1. Read developer state file, copy task JSON
# 2. HAND OFF to QA:
Read: .claude/session/current-task-qa.json
# Paste task JSON to QA's "Active Task" section
# Update QA YAML: status=working, currentTaskId={taskId}

# 3. Clear from developer:
# Move task to developer's "Completed Tasks" array
# Clear developer's "Active Task" (null/unassigned)
# Update developer YAML: status=idle, currentTaskId=null

# 4. Update PRD:
prd.json.items[{taskId}].status = "awaiting_qa"
prd.json.agents.developer.status = "idle"
prd.json.agents.qa.status = "working"
```

### QA → Archive Handoff

When QA validates (passes) and retrospective complete:

```bash
# 1. Move QA task to "Completed Tasks" array
# 2. Clear QA's "Active Task"

# 3. PM archives:
# - Add to prd_completed.txt
# - CLEAR task from ALL agent state files (remove from "Completed Tasks" arrays)
# - Delete from prd.json.items
```

### Handoff Summary Table

| Event              | From    | To      | PM Action                                        |
| ------------------ | ------- | ------- | ------------------------------------------------ |
| Impl complete      | Dev     | QA      | Copy task to QA state file, clear from Dev       |
| Asset complete     | TA      | QA      | Copy task to QA state file, clear from TA          |
| Validation pass    | QA      | Archive | Move to completed, clear from all state files      |
| Validation fail    | QA      | Dev     | Update bugs, reassign, keep in QA state file       |

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
