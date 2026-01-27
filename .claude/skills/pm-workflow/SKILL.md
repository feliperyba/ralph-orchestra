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

## Golden Rule: PRD and State File Synchronization (v2.0)

**CRITICAL: The PM maintains DUAL sync - prd.json (PM-ONLY) + agent state files (workers).**

**v2.0 Architecture:**
- **Workers** read ONLY their `current-task-{agent}.json` (~1KB)
- **PM** reads ALL agent state files AND full prd.json (110KB)
- **PM** syncs between state files and prd.json

**Whenever you make a decision that changes agent or task state:**

1. **UPDATE agent state file** with full task details (workers read this)
2. **UPDATE prd.json** with status changes (for tracking/PM reference)
3. **UPDATE current-task-pm.json** with Worker Status Summary

| When This Happens                        | Update State File Like This                                                          | Update PRD Like This                                                                            | Why                                    |
| ---------------------------------------- | -------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | -------------------------------------- |
| **Selecting a task**                     | N/A                                                                                    | `prd.json.session.currentTask = {taskId, title, category}`                                     | Workers know what's being worked on    |
| **Assigning to worker**                  | Copy FULL task JSON to worker's state file + update state object         | `prd.json.items[{taskId}].status = "assigned"` + `prd.json.agents[{agent}].status = "working"` | Worker sees assignment in state file   |
| **Worker sends question**                | Update notes in PRD, keep state file as-is                                               | Update notes, keep status as-is                                                                | Track blockers for visibility          |
| **Worker sends implementation_complete** | Move task to "completedTasks" array + clear task fields                              | `prd.json.items[{taskId}].status = "awaiting_qa"` + `prd.json.agents[{agent}].status = "idle"` | QA picks it up, no loop lock           |
| **QA validation PASSED**                 | Move task to "completedTasks" array                                                   | `prd.json.items[{taskId}].status = "completed"` + `passes = true`                              | Triggers retrospective                 |
| **QA validation FAILED**                 | Update task JSON with bugs                                                             | `prd.json.items[{taskId}].status = "needs_fixes"` + `passes = false`                           | Reassign to worker                     |
| **Self-reporting**                       | Update `current-task-pm.json` Worker Status Summary + state object                  | `prd.json.agents.pm.lastSeen = {ISO_TIMESTAMP}`                                                | Watchdog knows you're alive            |

**PM's Sync Pattern (after EVERY message processing):**

```bash
# 1. Read all agent state files
Read: .claude/session/current-task-developer.json
Read: .claude/session/current-task-qa.json
Read: .claude/session/current-task-techartist.json
Read: .claude/session/current-task-gamedesigner.json

# 2. Update Worker Status Summary in current-task-pm.json
# (table with status, currentTaskId, lastSeen for each agent)

# 3. Sync to prd.json
Update: prd.json.agents.{agent}.* sections
Update: prd.json.session if needed
Update: prd.json.items[{taskId}] if status changed

# 4. Update your own state
Update: current-task-pm.json state object
Update: prd.json.agents.pm.*
```

**If you don't sync properly:**
- Workers don't see their task assignments
- State files become out of sync with PRD
- Watchdog thinks you crashed
- Loop locks occur

**Rule of thumb: If you make a decision, update BOTH state files AND prd.json. IMMEDIATELY.**

## Startup Workflow

````
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

2. READ PRD AND AGENT STATE FILES FOR CURRENT STATE (v2.0)
   - Read prd.json for top 5 active tasks (PM-ONLY access)
   - If prd.json have less than 5 active tasks, read the prd.backlogFile (defaults to "prd_backlog.json") for full picture and prd reorganization
   - **Read ALL agent state files:**
     * Read: .claude/session/current-task-developer.json
     * Read: .claude/session/current-task-qa.json
     * Read: .claude/session/current-task-techartist.json
     * Read: .claude/session/current-task-gamedesigner.json
   - **Update Worker Status Summary** in current-task-pm.json
   - Check prd.json.session for current phase
   - Check prd.json.agents.pm for your status
   - Update your lastSeen timestamp in current-task-pm.json AND prd.json

3. CONSOLIDATE ALL AGENT INBOXES (MANDATORY - CENTRALIZED DECISION MAKING)

CRITICAL: This is the CORE of PM's coordination - you gather ALL information, make decisions, then dispatch.

CONSOLIDATION PROCESS (execute EVERY startup):

For each agent (pm, developer, qa, techartist, gamedesigner):

a) Use Glob to find ALL messages: `.claude/session/messages/{agent}/msg-*.json`

b) READ every single message file:
   - Extract: from, to, type, payload, timestamp
   - Collect ALL information into memory

c) DELETE every message file after reading:
   - Workers will NOT process these messages directly
   - YOU (PM) will process the information and make decisions

d) Send acknowledgment to watchdog for each processed message

PROCESS THE CONSOLIDATED INFORMATION:

Now you have ALL the information from ALL agents. Process it:

1. CORRELATE messages with PRD state
2. ASSESS what each agent was working on / reporting
3. IDENTIFY completed tasks, blockers, questions
4. DETERMINE next actions based on PRD priorities

MAKE DECISIONS AND UPDATE BOTH STATE FILES AND PRD:

Based on consolidated information + PRD state + agent state files, decide:

- Does a task need assignment? → Select task, assign to worker
- Is a task complete? → Mark as awaiting_qa, notify QA
- QA passed a task? → Trigger retrospective workflow
- Worker stuck/blocked? → Reassign or provide guidance
- PRD needs reorganization? → Extract new tasks, adjust priorities

**UPDATE PATTERN (v2.0) - ATOMIC UPDATES:**

1. **Update agent state files** (if assigning/completing):
   - Copy FULL task JSON to worker's task fields (id, title, description, etc.)
   - Update worker's state object (status, currentTaskId, lastSeen)

2. **UPDATE prd.json** with ALL your decisions atomically:
   - Task status changes
   - Agent status changes
   - Session state changes

3. **UPDATE current-task-pm.json** with Worker Status Summary

SEND NEW MESSAGES (WAKE UP AGENTS):

Based on your decisions, send NEW messages to worker inboxes:

- Task assignment → Send task_assign to developer
- QA needed → Send validation_request to qa
- Question for worker → Send question response
- Retrospective needed → Send retrospective_initiate to all workers

ONLY AFTER consolidation complete, PRD updated, and wake messages sent, proceed to step 4.

4. SET PM-READY FLAG (COORDINATOR-FIRST STARTUP)

CRITICAL: AFTER consolidation (step 3) complete - all messages read, processed, decisions made, PRD updated, wake messages sent - signal ready.

Write to `.claude/session/pm-ready.flag` with current timestamp:
```json
"2026-01-27T00:00:00.000Z"
```

The watchdog waits for this flag before allowing workers to start, ensuring proper message consolidation.

When to skip: If you're already in an active session and have previously sent status.

5. WAKE UP ASSIGNED AGENTS (MANDATORY - AFTER pm-ready FLAG)

**CRITICAL: After setting pm-ready flag, you MUST wake up any agents who have tasks assigned but empty message queues.**

**Check each agent's state file:**
- Read `.claude/session/current-task-{agent}.json`
- Check if `status === "working"` AND `currentTaskId != null`
- BUT their message queue is empty (no msg-*.json files)
- **THEN send wake_up message**

**Wake up message format:**
```json
{
  "id": "msg-{agent}-{timestamp}-001",
  "from": "pm",
  "to": "{agent}",
  "type": "wake_up",
  "priority": "normal",
  "payload": {
    "taskId": "{taskId}",
    "message": "You have a task assigned. Please resume work."
  },
  "timestamp": "{ISO_TIMESTAMP}",
  "status": "pending"
}
```

**Why this is needed:** Workers may have stopped or not received their initial task message. The wake_up ensures active tasks are actually being worked on.

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

## Task Handoff Pattern Between Agents (v2.0)

**CRITICAL: When a task moves from one agent to another, the task JSON MUST move between state files.**

### Developer → QA Handoff (Most Common)

```bash
# When Developer sends implementation_complete:

1. Read developer state file
2. Copy task JSON from developer
3. **MOVE task to QA state file:**
   Read: .claude/session/current-task-qa.json
   Paste task JSON to QA's task fields (id, title, description, etc.)
   Update QA state: status=working, currentTaskId={taskId}, lastSeen={NOW}
4. Clear developer's task (set id=null, title="No active task")
5. Add task to developer's "completedTasks" array
6. Update developer state: status=idle, currentTaskId=null, lastSeen={NOW}
7. Update prd.json.items[{taskId}].status = "awaiting_qa"
8. Update prd.json.agents.developer.status = "idle"
9. Update prd.json.agents.qa.status = "working"
10. Send validation_request message to QA
```

### Tech Artist → QA Handoff

```bash
# When Tech Artist sends asset_complete:

1. Read techartist state file
2. Copy task JSON from techartist
3. **MOVE task to QA state file:** (same pattern as above)
4. Clear techartist's task fields (id=null, title="No active task")
5. Add task to techartist's "completedTasks" array
6. Update both state objects
7. Update prd.json
8. Send validation_request message to QA
```

### QA Completion → Task Archive

```bash
# When QA sends task_complete (PASS):

1. Read QA state file
2. Move task to QA's "Completed Tasks" array
3. Clear QA's "Active Task"
4. Update QA YAML: status=idle, currentTaskId=null
5. Update prd.json: passes=true, validatedAt={NOW}
6. Send task_complete message to PM

# PM then:
7. Run retrospective (see Phase 1 below)
8. After retrospective: Add task to prd_completed.txt
9. **CLEAR task from ALL agent state files:**
   - Remove from developer's "Completed Tasks"
   - Remove from QA's "Completed Tasks"
   - Remove from techartist's "Completed Tasks" (if applicable)
10. Delete task from prd.json.items
```

### Task Handoff Summary Table

| Handoff          | From Agent      | To Agent    | PM Action                                                                 |
| ----------------- | --------------- | ----------- | ------------------------------------------------------------------------ |
| Implementation   | Developer       | QA          | Copy task JSON to QA, clear from Developer, update PRD            |
| Asset Complete    | Tech Artist     | QA          | Copy task JSON to QA, clear from Tech Artist, update PRD        |
| Validation Pass   | QA              | PM          | Trigger retrospective, later clear from all state files       |
| Validation Fail   | QA              | Developer    | Update task with bugs, reassign to Developer, keep in QA       |
| Task Complete     | Any             | Archive      | Add to prd_completed.txt, clear from all agent state files     |

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
└─ NO → playtest_skipped
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

````

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
````

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

**⚠️ CRITICAL: Clean up completed tasks, DELETE retrospective file, and CLEAR agent state files!**

**When:** After PRD reorganization

**Action:**

1. **DELETE the retrospective file** (`.claude/session/retrospective-*.txt`)

2. **Identify all `status: "completed"` tasks** from prd.json

3. **For EACH completed task, CLEAR from agent state files:**
   ```bash
   # Read agent state file (where task was last processed)
   Read: .claude/session/current-task-{agent}.json

   # Remove task from "Completed Tasks" array OR clear entire array
   # Task details are now safely archived in prd_completed.txt
   ```

4. **Move completed tasks to `prd_completed.txt`:**
   - Append task summary with all details
   - Include: taskId, title, agent, completion date, commits

5. **Remove from `prd.json.items`** - Delete completed task entries

6. **Update counts:** `completedTasks`, `activeQueueSize`

7. **Refill from backlog** if < 5 tasks in prd.json.items

**Update PRD:**

- `prd.session.stats.completedTasks += {count}`
- `prd.session.stats.activeQueueSize = prd.items.length`

**⚠️ ALWAYS:**
- Delete retrospective files after cleanup (contain sensitive debugging info)
- Clear completed tasks from ALL agent state files (archived in prd_completed.txt)

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
         → cleanup_completed (DELETE retrospective file, move to prd_completed.txt, CLEAR from all agent state files)
         → skill_research (MANDATORY - 5 agent minimum)
         → skill_updates_applied
         → task_ready
         → test_planning (use pm-test-planner sub-agent)
         → test_plan_ready
         → assigned (send to worker)
```

**Task Handoff During Workflow:**

```
Developer (implementation) → HANDOFF → QA (validation)
  ├─ Copy task JSON from current-task-developer.json to current-task-qa.json
  ├─ Clear developer's task (id=null), add to "completedTasks" array
  └─ Update both state objects

QA (validation passes) → HANDOFF → Archive
  ├─ Move to QA's "completedTasks" array, clear task fields
  └─ After retrospective: Add to prd_completed.txt, CLEAR from all state files
```

**⚠️ MANDATORY STEPS - NO SHORTCUTS:**

1. ✅ Synthesize retrospective
2. ✅ Skill research - Check based on the task and retrospective context which agents, sub-agents, skills needs to be polish or created
3. ✅ Delete retrospective file + cleanup completed tasks
4. ✅ Check if playtest needed. Skip for non-gameplay/bugs/small fixes. Only needed for big milestones. If needed, collaborate with the Game Designer to Playtest and Review the GDD
5. ✅ PRD reorganization (ALWAYS - even if no changes)
6. ✅ Select next task
7. ✅ Based on the GDD, create a acceptance criteria and test plan in separated .md file, and reference in the task

## Message Handling Summary

| From              | Type                      | Action                                  |
| ----------------- | ------------------------- | --------------------------------------- |
| **QA**            | `task_complete` (PASS)    | Trigger retrospective                   |
| **QA**            | `task_complete` (FAIL)    | Reassign to worker                      |
| **QA**            | `bug_report`              | Reassign to worker                      |
| **QA**            | `question`                | Research and respond                    |
| **Workers**       | `implementation_complete` | Set `status: "awaiting_qa"`, send to QA |
| **Workers**       | `question`                | Research and respond                    |
| **Workers**       | `work_blocked`            | Assess and provide guidance             |
| **Game Designer** | `prd_analysis_response`   | Review, select task together            |
| **Game Designer** | `success_criteria`        | Incorporate into task definition        |
| **Game Designer** | `task_confirmed`          | Enter skill_research phase              |
| **Watchdog**      | `retrospective_complete`  | All workers contributed → synthesize    |
| **Watchdog**      | `agent_timeout`           | Worker stuck → assess and reassign      |

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
