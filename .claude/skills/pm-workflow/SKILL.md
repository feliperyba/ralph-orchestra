---
name: pm-workflow
description: Complete PM Coordinator workflow - task assignment, retrospective orchestration, PRD management, worker coordination. Use proactively when starting PM agent work. MUST load before starting assignments.
category: workflow
version: 2.0
changelog: "MAJOR: Added PRD Status Synchronization as golden rule. PM must update PRD immediately on EVERY status change. Fixed skill references to match actual skill directories. Added keywords for discoverability."
keywords: [pm, workflow, coordinator, task-assignment, retrospective, prd, ralph]
user-invocable: true
---

# PM Coordinator Workflow

> "This skill contains the complete workflow for the PM Coordinator. Load this BEFORE starting any task."

##  Golden Rule: PRD Status Synchronization

**CRITICAL: The PRD is the SINGLE SOURCE OF TRUTH for all agents. Every status change MUST be immediately reflected in `prd.json`.**

**Whenever you make a decision that changes agent or task state, UPDATE THE PRD IMMEDIATELY.**

| When This Happens | Update PRD Like This | Why |
|-------------------|---------------------|-----|
| **Selecting a task** | `prd.json.session.currentTask = {taskId, title, category}` | Workers know what's being worked on |
| **Assigning to worker** | `prd.json.items[{taskId}].status = "assigned"` + `prd.json.agents[{agent}].status = "working"` | Worker sees assignment, knows to start |
| **Worker sends question** | Update notes, keep status as-is | Track blockers for visibility |
| **Worker sends implementation_complete** | `prd.json.items[{taskId}].status = "awaiting_qa"` + `prd.json.agents[{agent}].status = "idle"` | QA picks it up, no loop lock |
| **QA validation PASSED** | `prd.json.items[{taskId}].status = "completed"` + `passes = true` | Triggers retrospective |
| **QA validation FAILED** | `prd.json.items[{taskId}].status = "needs_fixes"` + `passes = false` | Reassign to worker |
| **Self-reporting** | `prd.json.agents.pm.lastSeen = {ISO_TIMESTAMP}` | Watchdog knows you're alive |

**If you don't update the PRD:**
- Workers don't know they have tasks assigned
- QA waits for tasks that are done
- Watchdog thinks you crashed
- Loop locks occur

**Rule of thumb: If you make a decision, PRD changes. IMMEDIATELY.**

## Startup Workflow

```
0. **MESSAGE QUEUE SETUP**
   . .\.claude\scripts\message-queue.ps1

1. CHECK PENDING MESSAGES
   - Read .claude/session/messages/pm/msg-*.json

2. READ PRD FOR CURRENT STATE
   - Read prd.json for top 5 active tasks
   - Read prd.backlogFile (defaults to "prd_backlog.json") for full picture
   - Check prd.json.session for current phase
   - Check prd.json.agents.pm for your status
   - Update your lastSeen timestamp

3. VALIDATE WORKER STATES (MANDATORY in event-driven mode)
   - Check if assigned worker has active task with status "working" or "needs_fixes"
   - Check worker's lastSeen timestamp (compare to current time)
   - Check if worker has pending messages in their inbox
   - If worker lastSeen > 15 minutes ago OR no messages in inbox: SEND WAKE_UP
   - See Worker State Validation below

4. PROCESS MESSAGES based on current state
   - See Decision Framework below

5. TAKE ACTION using skills/sub-agents

6. SEND STATUS_UPDATE to watchdog

7. EXIT (watchdog will restart you when needed)
```

## PRD Backlog Architecture (v3.1.0+)

Since v3.1.0, the PRD is split into two files:

| File | Contains | Purpose |
|------|----------|---------|
| `prd.json` | Top 5 active tasks | Workers read this for status |
| `prd_backlog.json` | ~70 backlog tasks | PM reads this for full picture |

**When reading PRD state:**
- Always read both files for complete task picture
- Workers only need prd.json (they read their assigned task by ID)
- PM must read prd.json + prd_backlog.json for task selection, counting, reorganization

**Automatic refill:**
- When prd.json.items.length < 5 after task completion
- PM pulls highest-priority unblocked task from backlog
- See `pm-organization-task-selection` skill for refill algorithm

## Worker State Validation (Event-Driven Mode)

**CRITICAL: In event-driven mode, workers may not be actively running. PM must validate and wake them.**

### Validation Steps (Run EVERY startup)

```bash
# 1. Check if worker has any pending messages
Get-ChildItem .claude/session/messages/{worker}/msg-*.json

# 2. Check worker's lastSeen timestamp in prd.json
# Compare to current time - if > 15 minutes, worker may be stopped

# 3. Send wake_up if needed
```

### Wake-Up Triggers

| Condition | Action |
|-----------|--------|
| Worker status = "working" AND lastSeen > 15 min | Send wake_up |
| Worker status = "idle" BUT has assigned task | Send wake_up |
| Task status = "needs_fixes" AND no messages in worker inbox | Send wake_up |
| Worker inbox is empty AND task assigned to them | Send wake_up |

### Wake-Up Message Template

**For Worker (Developer/TechArtist) with active task:**

```json
{
  "id": "msg-{worker}-{timestamp}-{seq}",
  "from": "pm",
  "to": "{worker}",
  "type": "wake_up",
  "priority": "high",
  "payload": {
    "message": "You are assigned {taskId}. Please continue working.",
    "taskId": "{taskId}",
    "taskTitle": "{Full task title}",
    "status": "{needs_fixes|assigned}",
    "acceptanceCriteria": ["Criteria 1", "Criteria 2"],
    "verificationSteps": ["Step 1", "Step 2"],
    "qaNote": "{Any QA feedback from previous attempt}"
  },
  "timestamp": "{ISO-timestamp}",
  "status": "pending"
}
```

### After Sending Wake-Up

1. Update prd.json agent status with current timestamp
2. Send status_update to watchdog
3. Exit - watchdog will deliver message and restart worker if needed

## Decision Framework

| Current State | Action | Next State |
|---------------|--------|------------|
| `null` | Use `pm-organization-task-selection` skill | `test_planning` |
| `test_planning` | Use Task with `pm-test-planner` sub-agent | `assigned` |
| `assigned` | Send task message, exit | (wait for worker) |
| `awaiting_qa` | Wait for QA validation | (wait) |
| `passed` (QA) | Use Task with `pm-retrospective-facilitator` sub-agent | `in_retrospective` |
| `in_retrospective` | **Wait for `retrospective_complete` message from watchdog** (exit after initiating) | `retrospective_synthesized` |
| `retrospective_synthesized` | Use `pm-retrospective-playtest-session` skill | `playtest_phase` |
| `playtest_complete` | Use Task with `pm-prd-organizer` sub-agent | `prd_refinement` |
| `prd_analysis_with_gd` | Send prd_analysis_request | (wait for GD) |
| `task_ready` | Use Task with `pm-skill-researcher` sub-agent | `skill_research` |
| `completed` | Select next task | `test_planning` |
| `needs_fixes` | **Check attempts first**:<br>• If `attempts >= maxAttempts` → mark `blocked`, escalate<br>• If `attempts < maxAttempts` → reassign to worker | `assigned` or `blocked` |

## Task Status Lifecycle

| Status | When to Use | passes | Who Sets It |
|--------|-------------|--------|-------------|
| `"pending"` | Task not yet started | false | PM (initial) |
| `"assigned"` | Task assigned to worker | false | PM |
| `"awaiting_qa"` | Worker finished, sent to QA | false | PM (after worker) |
| `"completed"` | **QA PASSED validation** | true | PM (after QA pass) |
| `"needs_fixes"` | QA found bugs | false | PM (after QA fail) |
| `"in_progress"` | Worker actively working | false | Worker (self-report) |
| `"blocked"` | Max attempts reached, needs escalation | false | PM (after max attempts) |

**CRITICAL: When worker sends `implementation_complete`:**
- ✅ Set `status: "awaiting_qa"` + `passes: false`
- ❌ DO NOT set `status: "completed"` (only QA can mark complete)

## Atomic Task Assignment (5-Step Process)

**Complete ALL 5 steps before exiting:**

1. **Update PRD task status**

   ```json
   {
     "id": "{taskId}",
     "status": "assigned",
     "assignedAt": "{ISO_TIMESTAMP}",
     "agent": "{developer|qa|techartist}",
     "attempts": {N},
     "maxAttempts": 3,
     "firstAssignedAt": "{ISO_TIMESTAMP}",
     "lastAttemptAt": "{ISO_TIMESTAMP}"
   }
   ```

   **For reassignment after `needs_fixes`:** Increment `attempts`, update `lastAttemptAt`

2. **Update session currentTask**

   ```json
   {
     "session": {
       "currentTask": {
         "id": "{taskId}",
         "title": "{title}",
         "category": "{category}"
       }
     }
   }
   ```

3. **Update agent status**

   ```json
   {
     "agents": {
       "{agent}": {
         "status": "working",
         "currentTaskId": "{taskId}",
         "lastSeen": "{ISO_TIMESTAMP}"
       }
     }
   }
   ```

4. **Send task message to agent**
   - File: `.claude/session/messages/{agent}/msg-{agent}-{timestamp}-{seq}.json`
   - Type: `task_assignment`
   - Include task details and acceptance criteria
   - For reassignments: include QA feedback and current attempt number

5. **Log to handoff-log**
   - File: `.claude/session/handoff-log.json`
   - Record: timestamp, from: "pm", to: "{agent}", taskId: "{taskId}"

## Task Attempts Tracking (P0-3 Fix)

**Purpose:** Prevent infinite reassignment loops when tasks repeatedly fail QA validation.

**Fields:**
| Field | Type | Description |
|-------|------|-------------|
| `attempts` | number | Current attempt count (starts at 1) |
| `maxAttempts` | number | Maximum allowed attempts (default: 3) |
| `firstAssignedAt` | string | ISO timestamp of first assignment |
| `lastAttemptAt` | string | ISO timestamp of most recent assignment |

**When reassigning after `needs_fixes`:**
1. Check if `attempts >= maxAttempts`
2. If yes → mark task as `blocked`, notify user for escalation
3. If no → increment `attempts`, update `lastAttemptAt`, reassign

**Example escalation:**
```json
{
  "id": "feat-001",
  "status": "blocked",
  "attempts": 3,
  "maxAttempts": 3,
  "blockReason": "Max attempts reached - requires manual review",
  "blockedAt": "{ISO_TIMESTAMP}"
}
```

## Priority Order for Task Selection

| Category | Priority | Examples |
|----------|----------|----------|
| `architectural` | 1 (Highest) | State stores, API design, core systems |
| `integration` | 2 | API integration, third-party services |
| `functional` | 3 | Gameplay mechanics, features |
| `visual` | 4 | 3D models, materials, textures |
| `shader` | 4 | Shaders, visual effects |
| `polish` | 5 (Lowest) | UI styling, visual refinement |

## Category to Agent Mapping

| Category | Default Agent |
|----------|---------------|
| `architectural` | developer |
| `functional` | developer |
| `integration` | developer |
| `visual` | techartist |
| `shader` | techartist |
| `polish` | techartist |

## Phased Retrospective Workflow

**Phased workflow** (each phase exits for context reset):

```
passed → in_retrospective (use pm-retrospective-facilitation)
       → retrospective_synthesized → playtest_phase
       → playtest_complete → prd_refinement
       → task_ready → skill_research
       → completed
```

### Phase 1: Worker Retrospective

1. Create `retrospective.txt` with template
2. Set `currentTask.status = "in_retrospective"`
3. Send `retrospective_initiate` to workers (NOT Game Designer)
4. **Exit - wait for `retrospective_complete` message from watchdog**
5. When watchdog restarts you with `retrospective_complete`: synthesize and commit

**IMPORTANT**: This is purely event-driven. Exit after initiating and wait for watchdog to deliver the completion message. Do NOT poll or loop.

### Phase 2: Playtest

1. Send `playtest_session_request` to Game Designer
2. Exit - process `playtest_session_report` when received

### Phase 3: PRD Refinement

1. Send `prd_analysis_request` to Game Designer
2. Exit - process `prd_analysis_response` when received
3. Select next task together

### Phase 4: Acceptance Criteria (MANDATORY before task assignment)

1. Send `acceptance_criteria_request` to Game Designer
2. Exit - process response when received
3. Incorporate into task definition

### Phase 5: Skill Research

1. Use Task with `pm-skill-researcher` sub-agent for improvements
2. Update ALL FIVE agents' skills
3. Commit improvements
4. Set `currentTask.status = "completed"`

## Sub-Agents (invoke via Task tool)

| Sub-Agent | Model | Purpose | When to Use |
|-----------|-------|---------|-------------|
| `pm-task-researcher` | Haiku | Codebase research before task assignment | Before assigning tasks |
| `pm-test-planner` | Inherit | Collaborative test planning with QA+GD | Before task assignment |
| `pm-retrospective-facilitator` | Inherit | Retrospective orchestration and synthesis | After task completion |
| `pm-prd-organizer` | Inherit | PRD reorganization from GDD/retrospectives | After retrospective |
| `pm-architecture-validator` | Haiku | Read-only architecture gap detection | Validate client vs server patterns |
| `pm-skill-researcher` | Haiku | Skill improvement research via web search | During skill_research phase |

**Invocation:** `Task({ subagent_type: "pm-task-researcher", description: "...", prompt: "...", timeout: 300000 })`

## Skills (invoke via `Skill("skill-name")`)

| Skill | Purpose |
|-------|---------|
| `pm-organization-task-selection` | Priority algorithm for selecting tasks |
| `pm-organization-scale-adaptive` | Scale-adaptive planning based on PRD size |
| `pm-planning-test-planning` | Collaborative test planning with QA and GD |
| `pm-retrospective-facilitation` | Retrospective facilitation |
| `pm-retrospective-playtest-session` | Playtest session management |
| `pm-organization-prd-reorganization` | GDD-to-PRD task extraction |
| `pm-improvement-skill-research` | Multi-agent skill improvements |
| `pm-improvement-self-improvement` | PM self-improvement |
| `pm-validation-architecture` | Architecture validation |
| `pm-configuration-vite-assets` | Vite 6 asset configuration |
| `pm-configuration-asset-coordination` | Asset coordination best practices |

## GDD Reference for Task Planning

**When planning or assigning tasks, reference:**

- `docs/design/gdd/index.md` - Modular GDD overview
- `docs/design/gdd/16_implementation_roadmap.md` - 3-phase plan, critical path
- `docs/design/gdd/{module}.md` - Feature-specific acceptance criteria:
  • `2_paint_friction_system.md` - DEC-100, friction specs
  • `4_territory_control.md` - Grid system, scoring
  • `13_multiplayer.md` - Colyseus architecture
  • `15_technical_specs.md` - Performance targets

## Message Types You Handle

### From QA

| Type | Action |
|------|--------|
| `task_complete` (PASS) | Trigger retrospective |
| `task_complete` (FAIL) | Reassign to worker |
| `bug_report` | Reassign to worker |
| `question` | Research and respond |

### From Workers

| Type | Action |
|------|--------|
| `implementation_complete` | Set `status: "awaiting_qa"`, send to QA |
| `question` | Research and respond |
| `work_blocked` | Assess and provide guidance |

### From Game Designer

| Type | Action |
|------|--------|
| `prd_analysis_response` | Review, select task together |
| `success_criteria` | Incorporate into task definition |
| `task_confirmed` | Enter skill_research phase |

### From Watchdog

| Type | Action |
|------|--------|
| `retrospective_complete` | All workers contributed → synthesize and move to next phase |
| `agent_timeout` | Worker stuck in awaiting_* state → assess and reassign or escalate |

### Handling `retrospective_complete` (Event-Driven - NO POLLING)

When you receive `retrospective_complete` from watchdog:

1. Read `retrospective.txt` - all contributions should be complete
2. Synthesize the retrospective into a structured format
3. Update PRD:
   - `prd.session.currentTask.status = "retrospective_synthesized"`
   - `prd.agents.pm.status = "idle"`
4. Move to next phase (playtest or skill_research)

**IMPORTANT**: Do NOT poll or check repeatedly. Exit and wait for watchdog to deliver this message.

### Handling `agent_timeout` (Watchdog Timeout Protection)

When you receive `agent_timeout` from watchdog:

1. **Extract timeout details** from message payload:
   - `agent`: Which worker timed out (developer, qa, techartist, gamedesigner)
   - `originalStatus`: What state they were stuck in (awaiting_pm, awaiting_gd, waiting)
   - `elapsedMinutes`: How long they were waiting
   - `taskId`: Task they were working on (if any)

2. **Assess the situation**:
   - Was the worker waiting for PM response? → Review pending messages, respond if needed
   - Was the worker waiting for Game Designer? → Check if GD response is still needed
   - Is the task still valid? → Reassign if yes, close if no

3. **Take action**:
   - If task still needs work: Reassign to appropriate worker
   - If waiting for response: Provide clarification or reassign with new context
   - If task no longer valid: Update status, log to handoff-log

4. **Update PRD**:
   - `prd.agents.{agent}.status = "idle"` (already reset by watchdog)
   - `prd.session.currentTask.status = "assigned"` if reassigning

**Timeout Threshold**: 10 minutes (configurable via `RALPH_AWAITING_TIMEOUT`)

## Commit Format

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

**Remember:** Send `status_update` to watchdog and exit after each action. Watchdog will restart you.
