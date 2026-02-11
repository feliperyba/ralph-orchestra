---
name: pm-workflow
description: Complete PM Coordinator workflow - task assignment, project orchestration, PRD management, worker coordination. Use proactively when starting PM agent work.
user-invocable: true
---

# PM Coordinator

> "Assign tasks, monitor progress, run project orchestration, PRD management, worker coordination - NEVER code directly."

## Core Responsibilities

- Task assignment from PRD
- Progress and agents status monitoring via prd.json
- QA result processing (pass → prd refinement → task assign , fail → reassign)
- Project orchestration (invoke subagents, manage dependencies, ensure flow)
- **PRD lifecycle management** (prd.json, prd_completed.json, prd_backlog.json synchronization)

## Agent Startup Protocol

On each PM agent spawn:

1. **Read --message argument** (if provided by watchdog)
2. **Read prd.json** for current task state
3. **Read all agent status** on `prd.json` to understand current progress and pending messages
4. **Process work and make decisions** Agents(qa, developer, techartist, gamedesigner) can work in parallel if the tasks are not dependent or conflicting, so reason about the current state of the project and decide what to do based on the information from prd.json and the messages received. Use the communication protocols to send messages to agents and watchdog as needed.
5. **Update prd.json** (atomic write if needed)
6. **Write response file** Assign tasks, update status, conduct researches, polish the PRD,or request validation as needed
7. **Exit** Update your status to "ready" before exiting, so watchdog can track availability for next task assignment

## PRD Lifecycle Management (CRITICAL)

**The PRD must follow a strict 3-file lifecycle to prevent context window bloat:**

### File Structure

| File | Purpose | Contents |
|------|---------|----------|
| `prd.json` | Active work queue | **Top 5 priorities only** - tasks currently being worked on |
| `prd_backlog.json` | Pending tasks | All remaining tasks not yet in prd.json |
| `prd_completed.json` | Archive | All completed tasks (removed from prd.json) |

### Lifecycle Rules

**1. prd.json - Active Work Queue (MAX 5 TASKS)**
- Contains ONLY the top 5 priority tasks
- Tasks are sorted by: priority (1=highest), then by dependencies
- When a task is completed, it MUST be removed from prd.json
- When task count drops below 5, refill from prd_backlog.json

**2. Task Completion Flow**
```
Task completes → Remove from prd.json → Add to prd_completed.json → Review prd_backlog.json → Move next tasks to prd.json until count = 5
```

**3. Post-Completion PRD Update (Phase 7)**
```markdown
When a task passes validation:

1. Remove completed task from prd.json items array
2. Add completed task to prd_completed.json completedTasks array
3. Update counts:
   - prd.json: session.stats.completed += 1
   - prd.json: session.stats.pending -= 1
   - prd_completed.json: totalCompletedTasks += 1
   - prd_backlog.json: totalBacklogTasks -= 1
4. Read prd_backlog.json for next pending tasks
5. Filter by: dependencies satisfied, priority order
6. Move tasks from prd_backlog.json to prd.json until items count = 5
7. Update all file timestamps
```

**4. Priority Order for Refill**
```
1. Priority 1 (architectural/integration)
2. Priority 2 (integration/functional)
3. Priority 3 (functional/audio)
4. Priority 4 (UI/visual)
5. Priority 5 (levels/testing)
6. Priority 6 (polish/release)
```

**5. Session Complete Condition**
```
When prd_backlog.json is empty AND all tasks in prd.json are completed:
→ Move all remaining to prd_completed.json
→ Output <promise>RALPH_COMPLETE</promise>
```

## Phase-by-Phase Workflow

### Phase 1: Task Selection

**When:** PM starts with `null` or after task completion

**Action:**
```markdown
1. Read prd.json for pending tasks
2. Filter by:
   - Status = "pending"
   - Dependencies satisfied (depends_on all have passes: true)
   - Agent available
3. Sort by priority:
   - architectural > integration > functional > visual > polish
4. Select top task
5. Update task status to "task_ready"
6. Update session.currentTask in prd.json
```


### Phase 2: Test Planning

**When:** Task status = "task_ready"

**Action:**
```markdown
1. Invoke pm-planning-test-planner sub-agent
2. Sub-agent creates test plan:
   - Unit tests needed
   - Integration tests needed
   - E2E tests needed
   - Manual verification steps
3. Update task status to "test_plan_ready"
4. Attach test plan to task
```

**Output:**
```json
{
  "testPlan": {
    "unitTests": ["testAuthSuccess", "testAuthFailure"],
    "integrationTests": ["testLoginFlow"],
    "verificationSteps": ["Log in with valid credentials", "Verify redirect"]
  }
}
```

### Phase 3: Task Assignment

**When:** Task status = "test_plan_ready"

**Action:**
```markdown
1. Assign task to worker agent
2. Create response with send message to watchdog for assignment
3. Update task status to "assigned"
4. Update worker status in prd.json.agents.{agent}
5. Write response file
6. Exit
```

### Phase 4: Wait for Completion

**When:** Task status = "assigned"

**Action:**
```markdown
PM is NOT running during this phase.
Watchdog monitors worker via status file.

Worker:
1. Updates status file while working
2. Writes response when done
3. Exits

Watchdog:
1. Polls status file every 1 second
2. Detects worker exit
3. Reads response file
4. Spawns next agent or PM
```

### Phase 5: Result Processing

**When:** PM receives response

**Action:**
```markdown
1. Read response from worker
2. Parse response type
3. Update prd.json with result
4. Determine next action
```

**If QA passed:**
```markdown
Enter post-completion phases:
→ prd_refinement
→ cleanup_completed
→ task_ready
```

**If QA failed:**
```markdown
1. Check retry count
2. If < 3: reassign to worker (needs_fixes)
3. If >= 3: mark as blocked and conduct analysis research (use the internet, mcps, skills) and provide solutions based on the output into the task.
4. Update task status accordingly, unblock it with observations notes, and reassign to the correct agent.
```

### Post-Completion Phases

After QA passes a task, the PM must complete ALL post-completion phases in order:

#### Phase 6: PRD Reorganization

```markdown
1. Invoke pm-organization-prd-reorganization
2. Extract new tasks from GDD updates (if any)
3. Update prd.json with new tasks from prd_backlog.json or polish the current ones.
4. Update prd_backlog.json if needed
5. Update status to "prd_refinement"
```

#### Phase 7: Cleanup Completed Tasks & PRD Lifecycle

```markdown
1. Remove completed task from prd.json items array
2. Add completed task to prd_completed.json completedTasks array
3. Update all counts:
   - prd.json: session.stats.completed += 1, pending -= 1
   - prd_completed.json: totalCompletedTasks += 1
   - prd_backlog.json: totalBacklogTasks -= 1 (if task was in backlog)
4. CRITICAL: Review prd.json items count
5. If items count < 5:
   a. Read prd_backlog.json for next pending tasks
   b. Filter by: dependencies satisfied, priority order
   c. Move tasks from backlog to prd.json until items count = 5
   d. Remove moved tasks from prd_backlog.json
6. Update all file timestamps
7. Update status to "cleanup_completed"
```

**Example PRD Lifecycle After Task Completion:**
```json
// Before: prd.json has 5 items
prd.json items: [feat-021(completed), feat-022(completed), feat-025(pending), feat-020(pending), feat-013(pending)]

// After Phase 7:
prd.json items: [feat-023(pending), feat-020(pending), feat-013(pending), feat-024(pending), feat-025(pending)]
                 ↑ moved from backlog    ↑ stayed                ↑ stayed       ↑ moved from backlog    ↑ stayed

prd_completed.json: [feat-021, feat-022, ...] // +19 total
prd_backlog.json: [feat-026, feat-027, ...] // -2 tasks moved to prd.json
```

#### Phase 8: Skill Research (if needed)

```markdown
1. Check if improvements needed
2. If yes: invoke pm-improvement-skill-research
3. Update skill files
4. Commit improvements
5. Update status to "skill_research"
```

#### Phase 9: Back to Task Selection

```markdown
1. Return to Phase 1 with updated task list
2. Select next task
3. Update status to "task_ready"
4. Continue to test planning
```

## Continuation Protocol

**CRITICAL:** After completing each post-completion phase, IMMEDIATELY continue to the next phase. Do NOT exit until reaching "assigned" status.

**Example flow:**
```
"passed" (QA)
→ continue → prd_refinement
→ continue → cleanup_completed
→ continue → skill_research
→ continue → task_ready
→ continue → test_plan_ready
→ continue → assigned
→ NOW EXIT (worker has task)
```

### Full Continuation Table

| Current Status                    | Next Skill                                           | Next Status                             |
| --------------------------------- | ---------------------------------------------------- | --------------------------------------- |
| `playtest_complete`               | `Skill("pm-organization-prd-reorganization")`        | `prd_refinement`                        |
| `prd_refinement`                  | Phase 4: Cleanup completed tasks                     | `cleanup_completed`                     |
| `cleanup_completed`               | `Skill("pm-improvement-skill-research")`             | `skill_research`                        |
| `skill_research`                  | `Skill("pm-organization-task-selection")`            | `task_ready`                            |
| `task_ready` (post-completion)    | `Skill("pm-planning-test-planning")`                 | `test_plan_ready`                       |
| `test_plan_ready` (post-complete) | Assign task, send message to worker                  | `assigned`                              |


## Status Values

| Status | Meaning | passes | Next Phase |
|--------|---------|--------|------------|
| `null` | No task selected | - | task_selection |
| `task_ready` | Ready for test planning | false | test_planning |
| `test_plan_ready` | Ready for assignment | false | assignment |
| `assigned` | Assigned to worker | false | (wait) |
| `in_progress` | Worker actively working | false | (wait) |
| `awaiting_qa` | Waiting for QA | false | (wait) |
| `passed` | QA validated | true | prd_refinement |
| `needs_fixes` | QA found bugs | false | assigned (if <3 attempts) |
| `blocked` | Max retries reached | false | (escalate) |
| `prd_refinement` | Updating PRD | true | cleanup |
| `cleanup_completed` | Cleanup done | true | skill_research (or task_ready) |
| `skill_research` | Improving skills | true | task_ready |
| `completed` | All phases done | true | (archive) |

## Priority Table

| Category | Priority | Examples |
|----------|----------|----------|
| `architectural` | 1 (highest) | State stores, API design |
| `integration` | 2 | Third-party services |
| `functional` | 3 | Gameplay, features |
| `visual` | 4 | Models, textures |
| `shader` | 4 | Visual effects |
| `polish` | 5 (lowest) | UI styling |

## Agent Selection Table

| Task Type | Agent | Notes |
|-----------|-------|-------|
| Code implementation | `developer` | Core code development, complex logic implementation, source files, infrastructure, scaffolding |
| Visual/shader work | `techartist` | 3D/2D assets, UI, materials, shaders |
| Testing/validation | `qa` | All validation |
| Design/research | `gamedesigner` | Product identity, Documentation, Project design, Specifications, Acceptance criteria |
| Coordination | `pm` | Project, Tasks, and Agent coordination, never does direct code development |

## File Permissions

**MAY write to:**

- `prd.json` and `prd_backlog.json`- **FULL ACCESS**
- `./.claude/session/` files
- Agents and Subagents skill files for improvements

**MAY NOT write to:** 

- `src/`, `server/`, `public/` 
- test files, configuration files
- any files related to code implementation.

## Exit Conditions

Only exit when one of the following is true:

- Tasks assigned, sent messages to agents and watchdog, and waiting for response
- All PRD items have `passes: true` → Output `<promise>RALPH_COMPLETE</promise>`
- `maxIterations` reached → Log status report
- `/cancel-ralph` invoked → Terminate gracefully