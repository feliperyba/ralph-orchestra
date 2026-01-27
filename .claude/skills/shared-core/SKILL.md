---
name: shared-core
description: Core orchestration concepts - session structure, status values, heartbeat, commit format. Single source of truth for all Ralph agents.
category: orchestration
---

# Shared Core

> "This is the canonical reference for shared Ralph behavior. Agent-specific docs should reference these rules, not duplicate them."

---

## Shared Skills Index

| Skill                              | Purpose                                         |
| ---------------------------------- | ----------------------------------------------- |
| `shared-messaging`                 | File-based message queues using Read/Write      |
| `shared-worker`                    | Base worker behavior (polling, exit, heartbeat) |
| `shared-coordinator`               | PM coordinator (task assignment, worker health) |
| `shared-state`                     | File ownership, atomic updates (Edit tool)      |
| `shared-context`                   | Context window auto-reset procedures            |
| `shared-retrospective`             | Task memory + retrospective contributions       |
| `shared-worktree`                  | Git worktree setup                              |
| `shared-lifecycle`                 | Process cleanup, script management              |
| `shared-validation-feedback-loops` | Type-check, lint, test, build validation        |

---

## Configuration (Environment Variables)

All timing is configurable via `.claude/hooks/hooks.json` or environment:

| Variable                   | Default | Description                           |
| -------------------------- | ------- | ------------------------------------- |
| `RALPH_IDLE_TIMEOUT`       | 60      | Seconds of no output before restart   |
| `RALPH_HEARTBEAT_INTERVAL` | 30      | How often to update heartbeat         |
| `RALPH_STALE_THRESHOLD`    | 90      | Seconds before agent considered stale |
| `RALPH_MAX_ITERATIONS`     | 200     | Maximum loop iterations               |
| `RALPH_CONTEXT_THRESHOLD`  | 70      | % context usage triggering reset      |

---

## Single Source of Truth (v2.0 - Per-Agent State Files)

**IMPORTANT: The architecture changed in v2.0 to reduce context window bloat.**

**OLD (v1.x):** All agents read prd.json (110KB+) for status
**NEW (v2.0):** Workers read lightweight state files, PM syncs with prd.json

### State File Architecture

| File                            | Who Reads         | Who Writes  | Size  | Purpose                          |
| ------------------------------- | ----------------- | ----------- | ----- | -------------------------------- |
| `current-task-developer.json`   | Developer, PM     | Developer   | ~1KB  | Developer's current task state   |
| `current-task-qa.json`          | QA, PM            | QA          | ~1KB  | QA's current task state          |
| `current-task-techartist.json`  | Tech Artist, PM   | Tech Artist | ~1KB  | Tech Artist's current task state |
| `current-task-gamedesigner.json | Game Designer, PM | Game Design | ~1KB  | Game Designer's current task state|
| `current-task-pm.json`          | PM                | PM          | ~2KB  | PM coordinator state             |
| `prd.json`                      | **PM only**       | PM only     | 110KB | Full PRD with all tasks          |

**Key Principle:** Workers NEVER read prd.json. They read only their own state file.

### State File Format (JSON)

```json
{
  "state": {
    "status": "working",
    "lastSeen": "2026-01-27T12:00:00.000Z",
    "currentTaskId": "feat-001",
    "pid": 0
  },
  "id": "feat-001",
  "title": "Task title",
  "description": "Full task description",
  "category": "architectural",
  "priority": "high",
  "tier": "TIER_0_BLOCKER",
  "status": "assigned",
  "passes": false,
  "agent": "developer",
  "dependencies": [],
  "acceptanceCriteria": ["Criterion 1", "Criterion 2"],
  "verificationSteps": ["Step 1", "Step 2"],
  "bugs": [],
  "assignedAt": "2026-01-27T12:00:00.000Z",
  "completedAt": null,
  "session": {
    "status": "running",
    "iteration": 59,
    "maxIterations": 200,
    "totalCompleted": 48
  },
  "completedTasks": []
}
```

### prd.json Role (v2.0)

**prd.json is now PM-ONLY.** It serves as:

1. **PM's task database** - All tasks, dependencies, priorities
2. **Session state record** - Iteration, max iterations, completion
3. **Sync source** - PM syncs between agent files and PRD

**Workers do NOT read prd.json** because:
- 110KB file bloats context windows
- Workers only need their current task info
- PM handles all coordination decisions

**PM reads both:**
- All agent state files (for worker status)
- prd.json (for task database)

---

## prd.json Schema (PM Reference Only)

**WARNING: This section is for PM agent only. Workers should read their state file instead.**

### prd.json Schema

```json
{
  "session": {
    "sessionId": "string",
    "startedAt": "ISO-8601",
    "maxIterations": 200,
    "iteration": 0,
    "status": "running|completed|terminated|max_iterations_reached",
    "currentTask": { "id": "string", "status": "string" } | null,
    "stats": { "totalTasks": 0, "completed": 0, "failed": 0, "commits": 0 }
  },
  "agents": {
    "pm": { "status": "idle", "lastSeen": "ISO-8601", "currentTaskId": "string|null" },
    "developer": { "status": "idle", "lastSeen": "ISO-8601", "currentTaskId": "string|null" },
    "qa": { "status": "idle", "lastSeen": "ISO-8601", "currentTaskId": "string|null" },
    "techartist": { "status": "idle", "lastSeen": "ISO-8601", "currentTaskId": "string|null" },
    "gamedesigner": { "status": "idle", "lastSeen": "ISO-8601", "currentTaskId": "string|null" }
  },
  "items": [
    {
      "id": "string",
      "title": "string",
      "category": "architectural|integration|functional|visual|shader|polish",
      "priority": "high|medium|low",
      "status": "pending|assigned|in_progress|awaiting_qa|passed|needs_fixes|blocked|in_retrospective|retrospective_synthesized|playtest_phase|playtest_complete|prd_refinement|task_ready|skill_research|completed",
      "passes": false,
      "agent": "developer|qa|techartist|gamedesigner",
      "dependencies": ["taskId1", "taskId2"],
      "acceptanceCriteria": [],
      "verificationSteps": [],
      "retryCount": 0,
      "bugs": []
    }
  ],
  "backlogFile": "prd_backlog.json"
}
```

### Session Directory

```
.claude/session/
├── current-task-developer.json   # Developer state (read by dev, PM)
├── current-task-qa.json          # QA state (read by qa, PM)
├── current-task-techartist.json  # Tech Artist state (read by ta, PM)
├── current-task-gamedesigner.json # Game Designer state (read by gd, PM)
├── current-task-pm.json          # PM coordinator state
├── handoff-log.json             # Task handoff history
├── continue-loop.flag           # Restart signal
├── work-in-progress.json        # Saved state for resume
├── coordinator-progress.txt     # Human-readable log
└── messages/                    # Message queues (event-driven)
    ├── pm/
    ├── developer/
    ├── qa/
    ├── techartist/
    └── gamedesigner/
```

---

## Unified Status Values (Single Source of Truth)

**This is the authoritative reference for ALL status values in Ralph.**

### Task Status Values (`prd.json.items[{taskId}].status`)

| Status                      | Used By              | Meaning                                   | passes |
| --------------------------- | -------------------- | ----------------------------------------- | ------ |
| `pending`                   | PM                   | Task not yet started                      | false  |
| `assigned`                  | PM                   | Task assigned to worker, waiting to start | false  |
| `in_progress`               | Worker (self-report) | Worker actively working                   | false  |
| `awaiting_qa`               | PM                   | Worker finished, waiting for QA           | false  |
| `passed`                    | QA (set), PM (reads) | **QA PASSED** - triggers retrospective    | true   |
| `needs_fixes`               | PM (after QA fail)   | QA found bugs, reassign                   | false  |
| `blocked`                   | PM                   | Max attempts, manual escalation           | false  |
| `in_retrospective`          | PM                   | Worker retrospective active               | true   |
| `retrospective_synthesized` | PM                   | Retrospective complete, committed         | true   |
| `playtest_phase`            | PM                   | Game Designer playtest active             | true   |
| `playtest_complete`         | PM                   | Playtest findings reviewed                | true   |
| `prd_refinement`            | PM                   | PRD reorganization in progress            | true   |
| `task_ready`                | PM                   | Ready for skill research                  | true   |
| `skill_research`            | PM                   | PM improving ALL skills                   | true   |
| `completed`                 | PM                   | All phases complete, archived             | true   |

### Agent Status Values (`prd.json.agents.{agent}.status`)

| Status                     | Meaning                       | Who Sets |
| -------------------------- | ----------------------------- | -------- |
| `idle`                     | Agent not working             | Self/PM  |
| `working`                  | Agent actively working        | Self     |
| `working_on_retrospective` | Contributing to retrospective | Self     |
| `awaiting_pm`              | Waiting for PM response       | Self     |
| `awaiting_gd`              | Waiting for Game Designer     | Self     |
| `waiting`                  | General waiting state         | Self     |

**⚠️ IMPORTANT:** `awaiting_*` statuses have watchdog timeout (configurable via `RALPH_AWAITING_TIMEOUT`, default 10 minutes).

### Status Transition Rules

1. **Only PM sets task status** (except `in_progress` - workers self-report)
2. **Only QA sets `passed`** (PM then transitions to `in_retrospective`)
3. **Only PM transitions to `completed`** (after skill_research)
4. **`blocked` is terminal** - requires manual intervention
5. **All `awaiting_*` have watchdog timeout protection**

---

## Task Status Flow Diagrams

### Core Task Flow (Implementation)

```
pending → assigned → in_progress → awaiting_qa → passed
                                        ↓
                                   needs_fixes
                                        ↓
                                   blocked (after max attempts)
```

### Post-Validation Phased Workflow

```
passed
  → in_retrospective (workers contribute)
  → retrospective_synthesized (PM commits findings)
  → playtest_phase (IF gameplay feature - optional)
  → playtest_complete
  → prd_refinement (PM reorganizes PRD)
  → task_ready
  → skill_research (PM improves skills)
  → completed (archived)
```

### Phase Descriptions

| Status                      | Description                      | Exit? |
| --------------------------- | -------------------------------- | ----- |
| `in_retrospective`          | Workers contribute retrospective | Yes   |
| `retrospective_synthesized` | PM committed findings            | Yes   |
| `playtest_phase`            | Game Designer playtesting        | Yes   |
| `playtest_complete`         | Playtest reviewed                | Yes   |
| `prd_refinement`            | PRD reorganized                  | Yes   |
| `task_ready`                | Ready for research               | Yes   |
| `skill_research`            | PM improving skills              | Yes   |
| `completed`                 | All phases done                  | -     |

**⚠️ CRITICAL:** Each phase ends with agent exit for context reset. Watchdog restarts for next phase.

---

## Heartbeat Protocol (v2.0)

> "Your heartbeat proves you're alive - update it or PM thinks you're dead."

### For Worker Agents (Developer, QA, Tech Artist, Game Designer)

**DO NOT read prd.json** - Update your state file instead.

**Step 1:** Read your state file

```
Read: .claude/session/current-task-{your-agent}.json
```

**Step 2:** Update the `state` object

```json
{
  "state": {
    "status": "working",
    "lastSeen": "2026-01-27T12:00:00.000Z",
    "currentTaskId": "feat-001",
    "pid": 0
  }
}
```

**Step 3:** Write updated state

```
Write: .claude/session/current-task-{your-agent}.json
```

### When to Update

| Situation              | Set `state.status` to | Update `state.lastSeen` |
| ---------------------- | -------------------- | ---------------------- |
| Start working on task  | `"working"`          | ✅ Yes, to NOW         |
| Finish a task          | `"idle"`        | ✅ Yes, to NOW    |
| Blocked/waiting for PM | `"awaiting_pm"` | ✅ Yes, to NOW    |
| Idle/monitoring        | `"idle"`        | ✅ Yes, every 60s |

### For PM Coordinator

**PM reads both agent state files AND prd.json.**

**After processing each message:**
1. Read all agent state files to update Worker Status Summary
2. Sync changes to prd.json.agents section
3. Update prd.json if task status changes

**PM heartbeat pattern:**
- Update current-task-pm.md with coordinator status
- Sync to prd.json.agents.pm
- Update lastSeen timestamp

### Update Frequency

| Agent         | Frequency               | Notes              |
| ------------- | ----------------------- | ------------------ |
| PM            | Every action            | Before each exit   |
| Developer     | Every 60s while working | While implementing |
| Tech Artist   | Every 60s while working | While implementing |
| QA            | Every 60s while working | While validating   |
| Game Designer | Every 60s while working | While designing    |

### Event-Driven Mode Exit Sequence

In event-driven mode, agents exit after work:

```
1. Complete your work
2. Determine exit status:
   - "idle" - Done
   - "awaiting_pm" - Sent question to PM
   - "awaiting_gd" - Sent question to Game Designer
3. Send status_update message
4. Exit
```

**The status_update message is critical** - tells supervisor your actual state.

---

## Unified Polling Interval

**All agents poll every 30 seconds when idle.**

| Agent         | Idle | Working                          |
| ------------- | ---- | -------------------------------- |
| PM            | 30s  | 30s                              |
| Developer     | 30s  | No polling (focus on work)       |
| QA            | 30s  | No polling (focus on validation) |
| Tech Artist   | 30s  | No polling (focus on work)       |
| Game Designer | 30s  | No polling (focus on design)     |

---

## Exit Conditions

**Workers MUST check coordinator status every poll and exit when:**

| Condition                                              | Action          |
| ------------------------------------------------------ | --------------- |
| `current-task-{agent}.json` shows `session.state.status: "completed"` | Exit gracefully |
| `current-task-{agent}.json` shows `session.state.status: "terminated"` | Exit gracefully |
| `current-task-{agent}.json` shows `session.state.status: "max_iterations_reached"` | Exit gracefully |
| Detected `<promise>RALPH_COMPLETE</promise>`           | Exit gracefully |

**For PM Coordinator:** Read `current-task-pm.json` for session status, or prd.json.session.

---

## Commit Format (Universal)

```
[ralph] [{{AGENT}}] {{PRD_ID}}: {{Brief description}}

- Change 1
- Change 2

PRD: {{PRD_ID}} | Agent: {{AGENT}} | Iteration: {{N}}
```

### Universal Commit Rule

**CRITICAL: Every agent MUST commit their file changes.**

### When to Commit

| When                              | Must Commit? |
| --------------------------------- | ------------ |
| Source file modifications         | ✅ Yes       |
| Configuration changes             | ✅ Yes       |
| PRD updates                       | ✅ Yes       |
| Documentation changes             | ✅ Yes       |
| Skill file updates                | ✅ Yes       |
| Heartbeat updates (lastSeen only) | ❌ No        |
| Temporary message files           | ❌ No        |

### Each Agent's Commit Scope

| Agent             | Must Commit These Files                                                             |
| ----------------- | ----------------------------------------------------------------------------------- |
| **PM**            | `prd.json`, `.claude/session/coordinator-progress.txt`, skill files, retrospectives |
| **Developer**     | Source files, tests, own progress files                                             |
| **Tech Artist**   | Assets, shaders, visual components, own progress files                              |
| **QA**            | `prd.json` (validation fields), bug reports, own progress files                     |
| **Game Designer** | `docs/design/`, GDD, own progress files                                             |

---

## File Ownership (Summary)

**For detailed file ownership matrix, see `shared-state` skill.**

Quick reference:

- **PM** owns task status, session state, coordinator files
- **Workers** own their `agents.{role}.*` fields and assigned task fields
- **Each agent** commits their own file changes
- **Use Edit tool** for atomic file updates (no manual temp files needed)

---

## References

- `shared-state` — File ownership, atomic updates (Edit tool)
- `shared-messaging` — Message queues, acknowledgment protocol
- `shared-worker` — Base worker behavior
- `shared-coordinator` — PM coordinator specifics
