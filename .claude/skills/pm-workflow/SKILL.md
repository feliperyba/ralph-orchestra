---
name: pm-workflow
description: Complete PM Coordinator workflow - task assignment, retrospective orchestration, PRD management, worker coordination. Use proactively when starting PM agent work.
category: coordination
user-invocable: true
---

# PM Coordinator Workflow

> "This skill contains the complete workflow for the PM Coordinator. Load pm-router first, then this skill."

## First Step: Load PM Router

ALWAYS load the PM router first to expose all available skills:

```
Skill("pm-router")
```

Then proceed with the workflow below.

## Golden Rule: PRD Status Synchronization

**CRITICAL: The PRD is the SINGLE SOURCE OF TRUTH for all agents. Every status change MUST be immediately reflected in `prd.json`.**

**Whenever you make a decision that changes agent or task state, UPDATE THE PRD IMMEDIATELY.**

| When This Happens                        | Update PRD Like This                                                                           | Why                                    |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------- | -------------------------------------- |
| **Selecting a task**                     | `prd.json.session.currentTask = {taskId, title, category}`                                     | Workers know what's being worked on    |
| **Assigning to worker**                  | `prd.json.items[{taskId}].status = "assigned"` + `prd.json.agents[{agent}].status = "working"` | Worker sees assignment, knows to start |
| **Worker sends question**                | Update notes, keep status as-is                                                                | Track blockers for visibility          |
| **Worker sends implementation_complete** | `prd.json.items[{taskId}].status = "awaiting_qa"` + `prd.json.agents[{agent}].status = "idle"` | QA picks it up, no loop lock           |
| **QA validation PASSED**                 | `prd.json.items[{taskId}].status = "completed"` + `passes = true`                              | Triggers retrospective                 |
| **QA validation FAILED**                 | `prd.json.items[{taskId}].status = "needs_fixes"` + `passes = false`                           | Reassign to worker                     |
| **Self-reporting**                       | `prd.json.agents.pm.lastSeen = {ISO_TIMESTAMP}`                                                | Watchdog knows you're alive            |

**If you don't update the PRD:**

- Workers don't know they have tasks assigned
- QA waits for tasks that are done
- Watchdog thinks you crashed
- Loop locks occur

**Rule of thumb: If you make a decision, PRD changes. IMMEDIATELY.**

## Startup Workflow

```
1. CHECK PENDING MESSAGES (MANDATORY - FIRST STEP)

Use Glob to find messages: .claude/session/messages/pm/msg-*.json
Read each message file (JSON fields: from, to, type, payload, timestamp)
Process each message based on type
Send acknowledgment to watchdog (REQUIRED - see shared-messaging)
Delete each message file after sending acknowledgment

Process each message type:
- task_complete → Trigger retrospective
- bug_report → Reassign to worker
- question → Research and respond
- status_update → Log and continue
- retrospective_complete → All workers contributed, proceed to synthesis

2. READ PRD FOR CURRENT STATE
   - Read prd.json for top 5 active tasks
   - Read prd.backlogFile (defaults to "prd_backlog.json") for full picture
   - Check prd.json.session for current phase
   - Check prd.json.agents.pm for your status
   - Update your lastSeen timestamp

3. SEND STATUS UPDATE TO WATCHDOG (via PRD)

CRITICAL: Update PRD status AFTER processing messages and reading PRD state.

This signals: "PM has finished startup, is ready to make decisions."

Update prd.json directly:
{
  "agents": {
    "pm": {
      "status": "ready",
      "lastSeen": "{ISO_TIMESTAMP}",
      "currentTask": "coordinator"
    }
  }
}

The watchdog reads prd.json.agents.pm.status to display your state.

When to skip: If you're already in an active session and have previously sent status.

4. VALIDATE WORKER STATES AND WAKE UP (MANDATORY - EVERY STARTUP)

CRITICAL: In event-driven mode, PM must ACTIVELY wake up workers!

Check worker's message queue: Glob `.claude/session/messages/{worker}/msg-*.json`
If queue is EMPTY AND task assigned to worker → SEND WAKE_UP MESSAGE

See shared-worker for complete validation flow and wake-up triggers.

DO NOT just "wait" - send wake_up message or workers will sit idle!

5. TAKE ACTION using skills/sub-agents
   - See Decision Framework below

6. SEND STATUS_UPDATE TO WATCHDOG (MANDATORY - Before exit)
   - Update: `prd.json.agents.pm.status = "coordinating" | "idle"`
   - Update: `prd.json.agents.pm.lastSeen = "{ISO_TIMESTAMP}"`
   - Send: `status_update` message to watchdog
   - ONLY THEN exit

7. EXIT (watchdog will restart you when needed)
```

## Decision Framework (Authoritative)

| Current State               | Action                                                      | Next State                             |
| --------------------------- | ----------------------------------------------------------- | -------------------------------------- |
| `null`                      | Use `Skill("pm-organization-task-selection")`               | `task_ready` or `test_planning`       |
| `task_ready`                 | Use Task with `pm-test-planner` sub-agent                   | `test_plan_ready`                      |
| `test_plan_ready`            | Assign task, send task message, exit                        | `assigned`                             |
| `assigned`                  | Send task message, exit                                        | (wait for worker)                      |
| `awaiting_qa`               | Wait for QA validation                                        | (wait)                                 |
| `passed` (QA)               | Use `Skill("pm-retrospective-facilitation")`                | `in_retrospective`                     |
| `in_retrospective`          | Wait for `retrospective_complete` message from watchdog       | `retrospective_synthesized`            |
| `retrospective_synthesized` | Use `Skill("pm-retrospective-playtest-session")`            | `playtest_phase`                       |
| `playtest_complete`         | Use Task with `pm-prd-organizer` sub-agent                  | `prd_refinement`                       |
| `prd_refinement`            | Move to cleanup completed tasks                              | `cleanup_completed`                    |
| `cleanup_completed`         | DELETE retrospective file, move tasks to prd_completed.txt   | `skill_research`                        |
| `skill_research`            | Use `Skill("pm-improvement-skill-research")`                 | `skill_updates_applied`                |
| `skill_updates_applied`     | Select next task                                             | `task_ready`                           |
| `completed`                 | Select next task                                              | `task_ready`                           |
| `needs_fixes`               | Check attempts first (see pm-organization-task-selection)    | `assigned` or `blocked`                |

> **See `Skill("pm-router")` for complete routing table by workflow phase and task category.**

## Task Status Lifecycle

> See `Skill("shared-core")` for complete task status definitions.

| Status          | When to Use                            | passes | Who Sets It             |
| --------------- | -------------------------------------- | ------ | ----------------------- |
| `"pending"`     | Task not yet started                   | false  | PM (initial)            |
| `"assigned"`    | Task assigned to worker                | false  | PM                      |
| `"awaiting_qa"` | Worker finished, sent to QA            | false  | PM (after worker)       |
| `"completed"`   | **QA PASSED validation**               | true   | PM (after QA pass)      |
| `"needs_fixes"` | QA found bugs                          | false  | PM (after QA fail)      |
| `"in_progress"` | Worker actively working                | false  | Worker (self-report)    |
| `"blocked"`     | Max attempts reached, needs escalation | false  | PM (after max attempts) |

**CRITICAL: When worker sends `implementation_complete`:**

- ✅ Set `status: "awaiting_qa"` + `passes: false`
- ❌ DO NOT set `status: "completed"` (only QA can mark complete)

## Task Assignment Priority

> See `Skill("pm-organization-task-selection")` for complete priority algorithm.

| Category        | Priority    | Examples                               |
| --------------- | ----------- | -------------------------------------- |
| `architectural` | 1 (Highest) | State stores, API design, core systems |
| `integration`   | 2           | API integration, third-party services  |
| `functional`    | 3           | Gameplay mechanics, features           |
| `visual`        | 4           | 3D models, materials, textures         |
| `shader`        | 4           | Shaders, visual effects                |
| `polish`        | 5 (Lowest)  | UI styling, visual refinement          |

## Phased Post-Completion Workflow (MANDATORY)

> **CRITICAL: After QA passes a task, you MUST complete ALL phases before selecting the next task.**

### The 6-Phase Workflow

After `status: "completed"` (QA passed), the workflow MUST follow these phases in order:

```
completed → retrospective_synthesized
         → CHECK: Playtest needed?
         │
         ├─ YES → playtest_phase → playtest_complete
         └─ NO  → playtest_skipped
         │
         ↓ (both paths merge here)
    prd_refinement (MANDATORY)
         → cleanup_completed (DELETE retrospective file, move to prd_completed.txt)
         → skill_research (MANDATORY - 5 agent minimum)
         → skill_updates_applied
         → task_ready
         → test_planning (use pm-test-planner sub-agent)
         → test_plan_ready
         → assigned (send to worker)
```

### Phase 1: Retrospective (Worker Contributions)

**When:** `status: "completed"` (QA just passed)

**Action:**

1. Use `Skill("pm-retrospective-facilitation")`
2. Request contributions from Developer, Tech Artist, QA
3. Wait for all workers to contribute
4. Synthesize retrospective into `retrospective.txt`

**Update PRD:**
- `prd.session.currentTask.status = "in_retrospective"`
- `prd.session.status = "in_retrospective"`

> See `pm-retrospective-facilitation` skill for complete retrospective workflow.

### Phase 2: Playtest Session (Game Designer)

**⚠️ MANDATORY: Check if playtest is needed FIRST!**

**When:** `status: "retrospective_synthesized"` (retro done)

**FIRST: Check if playtest is REQUIRED:**

```javascript
// Playtest IS required for:
- Gameplay mechanics (movement, shooting, physics)
- Visual features (shaders, materials, effects)
- UI/UX changes (HUD, menus, interactions)
- Character/weapon behavior
- Multiplayer features

// Playtest is NOT required for:
- Test infrastructure bugfixes (unit tests, E2E tests, build fixes)
- Non-gameplay tasks (CI/CD, tooling, documentation)
- Backend-only changes without visual impact
```

**If playtest IS required:**

1. Use `Skill("pm-retrospective-playtest-session")`
2. Send playtest request to Game Designer
3. Include: task details, retrospective findings, GDD reference
4. Wait for Game Designer to validate gameplay

**Update PRD:**
- `prd.session.currentTask.status = "playtest_phase"`
- `prd.session.status = "playtest_phase"`

**If playtest is NOT required:**

1. Document why playtest was skipped in retrospective
2. Set `prd.session.currentTask.status = "playtest_skipped"`
3. Move directly to Phase 3 (PRD Reorganization)

> See `pm-retrospective-playtest-session` skill for complete playtest workflow.

### Phase 3: PRD Reorganization (MANDATORY - EVERY RETROSPECTIVE)

**⚠️ CRITICAL: PRD reorganization is MANDATORY after EVERY retrospective!**

**When:** After retrospective synthesis (playtest or skip)

**Action:**

1. **ALWAYS** Use `Skill("pm-organization-prd-reorganization")` or Task with `pm-prd-organizer` sub-agent
2. Extract new tasks from GDD if design changed
3. Reorganize backlog based on retrospective findings
4. Update task priorities based on pain points
5. Document any new dependencies discovered

**Update PRD:**
- `prd.session.currentTask.status = "prd_refinement"`
- `prd.session.status = "prd_refinement"`
- Refill prd.json.items from backlog if < 5 tasks

**⚠️ DO NOT SKIP THIS PHASE - Even if no changes, you MUST verify and document!**

> See `pm-organization-prd-reorganization` skill for complete PRD reorganization workflow.

### Phase 4: Cleanup Completed Tasks (MANDATORY)

**⚠️ CRITICAL: Clean up completed tasks and DELETE retrospective file!**

**When:** After PRD reorganization

**Action:**

1. **DELETE the retrospective file** (`.claude/session/retrospective-*.txt`)
2. Identify all `status: "completed"` tasks
3. Move to `prd_completed.txt`
4. Remove from `prd.json.items`
5. Update counts (`completedTasks`, `activeQueueSize`)
6. Refill from backlog if < 5 tasks

**Update PRD:**
- `prd.session.stats.completedTasks += {count}`
- `prd.session.stats.activeQueueSize = prd.items.length`

**⚠️ ALWAYS delete retrospective files after cleanup - they contain sensitive debugging info!**

### Phase 5: Skill Research (Pain Points → Improvements)

**When:** After PRD reorganization and cleanup

**Action:**

1. Read retrospective notes for pain points (retrospective file is deleted, so check PRD notes)
2. Use `Skill("pm-improvement-skill-research")`
3. Research web for best practices
4. Update skill files for affected agents
5. At minimum: Update 5 agent skills (PM, Developer, Tech Artist, QA, Game Designer)

**Update PRD:**
- `prd.session.currentTask.status = "skill_research"`
- `prd.session.status = "skill_research"`

> See `pm-improvement-skill-research` skill for complete skill improvement workflow.

### Phase 6: Select Next Task

**When:** After skill research

**Action:**

1. Use `Skill("pm-organization-task-selection")` to select next task
2. Check if test planning needed
3. If yes, use Task with `pm-test-planner` sub-agent
4. Assign task to worker

**Update PRD:**
- `prd.session.currentTask = {newTaskId, title, category}`
- `prd.session.currentTask.status = "task_ready"` or `test_planning"`

---

## Complete Post-Retrospective Workflow (MANDATORY ORDER)

```
completed → retrospective_synthesized
         → CHECK: Playtest needed?
         │
         ├─ YES → playtest_phase → playtest_complete
         └─ NO  → playtest_skipped
         │
         ↓ (both paths merge here)
    prd_refinement (MANDATORY)
         → cleanup_completed (DELETE retrospective file, move to prd_completed.txt)
         → skill_research (MANDATORY - 5 agent minimum)
         → skill_updates_applied
         → task_ready
         → test_planning (use pm-test-planner sub-agent)
         → test_plan_ready
         → assigned (send to worker)
```

**⚠️ MANDATORY STEPS - NO SHORTCUTS:**
1. ✅ Synthesize retrospective
2. ✅ Check if playtest needed (skip for non-gameplay)
3. ✅ PRD reorganization (ALWAYS - even if no changes)
4. ✅ Delete retrospective file + cleanup completed tasks
5. ✅ Skill research (5 agent minimum)
6. ✅ Select next task

## Message Handling Summary

| From          | Type                   | Action                                |
| ------------- | ---------------------- | ------------------------------------- |
| **QA**        | `task_complete` (PASS) | Trigger retrospective                 |
| **QA**        | `task_complete` (FAIL) | Reassign to worker                    |
| **QA**        | `bug_report`           | Reassign to worker                    |
| **QA**        | `question`             | Research and respond                   |
| **Workers**    | `implementation_complete` | Set `status: "awaiting_qa"`, send to QA |
| **Workers**    | `question`             | Research and respond                   |
| **Workers**    | `work_blocked`         | Assess and provide guidance            |
| **Game Designer** | `prd_analysis_response` | Review, select task together           |
| **Game Designer** | `success_criteria`     | Incorporate into task definition       |
| **Game Designer** | `task_confirmed`       | Enter skill_research phase             |
| **Watchdog**    | `retrospective_complete` | All workers contributed → synthesize    |
| **Watchdog**    | `agent_timeout`        | Worker stuck → assess and reassign      |

> See `Skill("shared-messaging")` for complete message format specifications.

## Commit Format

> **See `Skill("dev-coordination-git-protocol")` for complete commit message standards.**

```
[ralph] [pm] {TASK_ID}: Brief description

- Change 1
- Change 2

PRD: {TASK_ID} | Agent: pm | Iteration: N
```

## Exit Conditions

Only exit when:

- Sent messages and waiting for response
- All PRD items have `passes: true` → Output `<promise>RALPH_COMPLETE</promise>`
- `maxIterations` reached → Log status report
- `/cancel-ralph` invoked → Terminate gracefully

## Sub-Agents and Skills

> **See `Skill("pm-router")` for complete catalog of:**
>
> - All PM skills with purposes
> - All sub-agents with models and invocation patterns
> - Routing by workflow phase
> - Routing by task category
> - Routing by signal keywords

**Quick reference:**

| Sub-Agent                      | Purpose                                    |
| ------------------------------ | ------------------------------------------ |
| `pm-task-researcher`           | Codebase research before task assignment   |
| `pm-test-planner`              | Collaborative test planning with QA+GD     |
| `pm-retrospective-facilitator` | Retrospective orchestration and synthesis  |
| `pm-prd-organizer`             | PRD reorganization                       |
| `pm-architecture-validator`    | Read-only architecture gap detection       |
| `skill-researcher`             | Skill improvement research via web search  |

## References

- [pm-router](./pm-router/SKILL.md) - Skill routing tables
- [shared-core](./shared-core/SKILL.md) - Session structure, status values, heartbeat
- [shared-messaging](./shared-messaging/SKILL.md) - Event-driven messaging, acknowledgment
- [shared-worker](./shared-worker/SKILL.md) - Base worker behavior
- [shared-coordinator](./shared-coordinator/SKILL.md) - PM coordinator specifics
- [shared-state](./shared-state/SKILL.md) - File ownership, atomic updates
