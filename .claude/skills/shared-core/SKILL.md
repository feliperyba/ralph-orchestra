---
name: shared-core
description: Core orchestration concepts - session structure, status values, heartbeat, commit format. Single source of truth for all Ralph agents.
category: orchestration
keywords: [core, session, prd, status, heartbeat, commit, exit-conditions]
---

# Shared Core

> "This is the canonical reference for shared Ralph behavior. Agent-specific docs should reference these rules, not duplicate them."

---

## Shared Skills Index

| Skill | Purpose |
|-------|---------|
| `shared-messaging` | File-based message queues using Read/Write |
| `shared-worker` | Base worker behavior (polling, exit, heartbeat) |
| `shared-coordinator` | PM coordinator (task assignment, worker health) |
| `shared-state` | File ownership, atomic updates (Edit tool) |
| `shared-context` | Context window auto-reset procedures |
| `shared-retrospective` | Task memory + retrospective contributions |
| `shared-worktree` | Git worktree setup |
| `shared-lifecycle` | Process cleanup, script management |
| `shared-validation-feedback-loops` | Type-check, lint, test, build validation |

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

## Single Source of Truth (prd.json)

**prd.json is the single source of truth for ALL status information.**

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
├── handoff-log.json           # Task handoff history
├── continue-loop.flag         # Restart signal
├── work-in-progress.json      # Saved state for resume
├── coordinator-progress.txt   # Human-readable log
└── messages/                  # Message queues (event-driven)
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

| Status | Used By | Meaning | passes |
|--------|---------|---------|--------|
| `pending` | PM | Task not yet started | false |
| `assigned` | PM | Task assigned to worker, waiting to start | false |
| `in_progress` | Worker (self-report) | Worker actively working | false |
| `awaiting_qa` | PM | Worker finished, waiting for QA | false |
| `passed` | QA (set), PM (reads) | **QA PASSED** - triggers retrospective | true |
| `needs_fixes` | PM (after QA fail) | QA found bugs, reassign | false |
| `blocked` | PM | Max attempts, manual escalation | false |
| `in_retrospective` | PM | Worker retrospective active | true |
| `retrospective_synthesized` | PM | Retrospective complete, committed | true |
| `playtest_phase` | PM | Game Designer playtest active | true |
| `playtest_complete` | PM | Playtest findings reviewed | true |
| `prd_refinement` | PM | PRD reorganization in progress | true |
| `task_ready` | PM | Ready for skill research | true |
| `skill_research` | PM | PM improving ALL skills | true |
| `completed` | PM | All phases complete, archived | true |

### Agent Status Values (`prd.json.agents.{agent}.status`)

| Status | Meaning | Who Sets |
|--------|---------|----------|
| `idle` | Agent not working | Self/PM |
| `working` | Agent actively working | Self |
| `working_on_retrospective` | Contributing to retrospective | Self |
| `awaiting_pm` | Waiting for PM response | Self |
| `awaiting_gd` | Waiting for Game Designer | Self |
| `waiting` | General waiting state | Self |

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

| Status | Description | Exit? |
|--------|-------------|-------|
| `in_retrospective` | Workers contribute retrospective | Yes |
| `retrospective_synthesized` | PM committed findings | Yes |
| `playtest_phase` | Game Designer playtesting | Yes |
| `playtest_complete` | Playtest reviewed | Yes |
| `prd_refinement` | PRD reorganized | Yes |
| `task_ready` | Ready for research | Yes |
| `skill_research` | PM improving skills | Yes |
| `completed` | All phases done | - |

**⚠️ CRITICAL:** Each phase ends with agent exit for context reset. Watchdog restarts for next phase.

---

## Heartbeat Protocol

> "Your heartbeat proves you're alive - update it or PM thinks you're dead."

### When to Update

| Situation | Set `status` to | Update `lastSeen` |
|-----------|-----------------|-------------------|
| Start working on task | `"working"` | ✅ Yes, to NOW |
| Finish a task | `"idle"` | ✅ Yes, to NOW |
| Blocked/waiting for PM | `"awaiting_pm"` | ✅ Yes, to NOW |
| Idle/monitoring | `"idle"` | ✅ Yes, every 60s |

### Using Read/Write Tools

**Step 1:** Read current state with Read tool
```
Read: prd.json
```

**Step 2:** Update your agent's section
```json
{
  "agents": {
    "developer": {
      "status": "working",
      "currentTaskId": "feat-001",
      "lastSeen": "2026-01-26T12:00:00.000Z"
    }
  }
}
```

**Step 3:** Write updated state with Write tool
```
Write: prd.json
```

### Update Frequency

| Agent | Frequency | Notes |
|-------|-----------|-------|
| PM | Every action | Before each exit |
| Developer | Every 60s while working | While implementing |
| Tech Artist | Every 60s while working | While implementing |
| QA | Every 60s while working | While validating |
| Game Designer | Every 60s while working | While designing |

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

| Agent | Idle | Working |
|-------|------|---------|
| PM | 30s | 30s |
| Developer | 30s | No polling (focus on work) |
| QA | 30s | No polling (focus on validation) |
| Tech Artist | 30s | No polling (focus on work) |
| Game Designer | 30s | No polling (focus on design) |

---

## Exit Conditions

**Workers MUST check coordinator status every poll and exit when:**

| Condition | Action |
|-----------|--------|
| `prd.json.session.status === "completed"` | Exit gracefully |
| `prd.json.session.status === "terminated"` | Exit gracefully |
| `prd.json.session.status === "max_iterations_reached"` | Exit gracefully |
| Detected `<promise>RALPH_COMPLETE</promise>` | Exit gracefully |

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

| When | Must Commit? |
|------|-------------|
| Source file modifications | ✅ Yes |
| Configuration changes | ✅ Yes |
| PRD updates | ✅ Yes |
| Documentation changes | ✅ Yes |
| Skill file updates | ✅ Yes |
| Heartbeat updates (lastSeen only) | ❌ No |
| Temporary message files | ❌ No |

### Each Agent's Commit Scope

| Agent | Must Commit These Files |
|-------|------------------------|
| **PM** | `prd.json`, `.claude/session/coordinator-progress.txt`, skill files, retrospectives |
| **Developer** | Source files, tests, own progress files |
| **Tech Artist** | Assets, shaders, visual components, own progress files |
| **QA** | `prd.json` (validation fields), bug reports, own progress files |
| **Game Designer** | `docs/design/`, GDD, own progress files |

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
