---
name: pm-workflow
description: Complete PM Coordinator workflow - task assignment, retrospective orchestration, PRD management, worker coordination. Use proactively when starting PM agent work. MUST load before starting assignments.
user-invocable: true
---

# PM Coordinator Workflow

> "This skill contains the complete workflow for the PM Coordinator. Load this BEFORE starting any task."

## First Step: Load PM Router

ALWAYS load the PM router first to expose all available skills:

```
Skill("pm-router")
```

Then proceed with the workflow below.

## Golden Rule: PRD Status Synchronization

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
   . "$PSScriptRoot\.claude\scripts\message-queue.ps1"
   Initialize-MessageQueue -SessionDir ".claude/session"

0.5 **PM-ONLY CONSOLIDATION (MANDATORY on every startup)**
   - Call Get-GlobalMessageState to see ALL messages across ALL agents
   - Consolidate: Read and understand all messages from all inboxes
   - Delete ALL messages after processing (Invoke-ConsolidateAndClearAllMessages)
   - **IMPORTANT**: Send env_ready message to watchdog after consolidation: `Send-EnvReady`
   - Only then proceed to normal workflow
   - NOTE: This ensures no message pile-up across restarts and PM has complete picture
   - NOTE: env_ready signals watchdog to exit startup mode and allow workers to receive messages

1. CHECK PENDING MESSAGES
   - After consolidation, this step is for NEW messages only
   - Read .claude/session/messages/pm/msg-*.json

2. READ PRD FOR CURRENT STATE
   - Read prd.json for top 5 active tasks
   - Read prd.backlogFile (defaults to "prd_backlog.json") for full picture
   - Check prd.json.session for current phase
   - Check prd.json.agents.pm for your status
   - Update your lastSeen timestamp

3. VALIDATE WORKER STATES (MANDATORY in event-driven mode)
   - See Worker State Validation below

4. PROCESS MESSAGES based on current state
   - See Decision Framework below

5. TAKE ACTION using skills/sub-agents

6. SEND STATUS_UPDATE to watchdog

7. EXIT (watchdog will restart you when needed)
```

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
| `null` | Use `Skill("pm-organization-task-selection")` | `parallel_assigned` or `test_planning` |
| `parallel_assigned` | Send task messages to BOTH agents, exit | (wait for both workers) |
| `test_planning` | Use Task with `pm-test-planner` sub-agent | `assigned` |
| `assigned` | Send task message, exit | (wait for worker) |
| `awaiting_qa` | Wait for QA validation | (wait) |
| `passed` (QA) | Use `Skill("pm-retrospective-facilitation")` | `in_retrospective` |
| `in_retrospective` | **Wait for `retrospective_complete` message from watchdog** | `retrospective_synthesized` |
| `retrospective_synthesized` | Use `Skill("pm-retrospective-playtest-session")` | `playtest_phase` |
| `playtest_complete` | Use Task with `pm-prd-organizer` sub-agent | `prd_refinement` |
| `prd_analysis_with_gd` | Send prd_analysis_request | (wait for GD) |
| `task_ready` | Use Task with `pm-skill-researcher` sub-agent | `skill_research` |
| `completed` | Select next task | `test_planning` |
| `needs_fixes` | **Check attempts first** (see below) | `assigned` or `blocked` |

> **See `Skill("pm-router")` for complete routing table by workflow phase and task category.**

## Task Status Lifecycle

> See `Skill("shared-ralph-core")` for complete task status definitions.

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

## Task Assignment and Selection

> **See `Skill("pm-organization-task-selection")` for:**
> - PRD Backlog Architecture (prd.json vs prd_backlog.json)
> - Atomic Task Assignment (5-step process)
> - Task Attempts Tracking (maxAttempts, escalation)
> - Priority Order for Task Selection
> - Category to Agent Mapping
> - Parallel Task Assignment (git worktree support)

The task selection skill handles the complete flow of selecting tasks from both PRD files, checking for parallel work opportunities, and assigning tasks to workers.

## Phased Retrospective Workflow

> **See `Skill("pm-retrospective-facilitation")` for worker retrospective orchestration.**
>
> **See `Skill("pm-retrospective-playtest-session")` for Game Designer playtest phase.**

**Phased workflow** (each phase exits for context reset):

```
passed → in_retrospective (use Skill("pm-retrospective-facilitation"))
       → retrospective_synthesized → playtest_phase (use Skill("pm-retrospective-playtest-session"))
       → playtest_complete → prd_refinement (use Skill("pm-organization-prd-reorganization"))
       → task_ready → skill_research (use Skill("pm-improvement-skill-research"))
       → completed
```

## Sub-Agents and Skills

> **See `Skill("pm-router")` for complete catalog of:**
> - All PM skills with purposes
> - All sub-agents with models and invocation patterns
> - Routing by workflow phase
> - Routing by task category
> - Routing by signal keywords

**Quick reference:**

| Sub-Agent | Purpose |
|-----------|---------|
| `pm-task-researcher` | Codebase research before task assignment |
| `pm-test-planner` | Collaborative test planning with QA+GD |
| `pm-retrospective-facilitator` | Retrospective orchestration and synthesis |
| `pm-prd-organizer` | PRD reorganization from GDD/retrospectives |
| `pm-architecture-validator` | Read-only architecture gap detection |
| `pm-skill-researcher` | Skill improvement research via web search |

## GDD and Design Reference

> **See `Skill("pm-organization-prd-reorganization")` for:**
> - GDD-to-PRD task extraction
> - PRD backlog architecture details
> - Task creation from GDD updates

**When planning or assigning tasks, reference:**

- `docs/design/gdd/index.md` - Modular GDD overview
- `docs/design/gdd/16_implementation_roadmap.md` - 3-phase plan, critical path

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

1. **Extract timeout details** from message payload
2. **Assess the situation** (waiting for PM? for GD? task still valid?)
3. **Take action** (reassign, provide clarification, close task)
4. **Update PRD** with new agent status

**Timeout Threshold**: 10 minutes (configurable via `RALPH_AWAITING_TIMEOUT`)

> **See `Skill("shared-ralph-event-protocol")` for complete message format specifications.**

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

**Remember:** Send `status_update` to watchdog and exit after each action. Watchdog will restart you.
