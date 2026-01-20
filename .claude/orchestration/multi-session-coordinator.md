# Multi-Session Coordinator Protocol

This document describes the protocol for coordinating three Ralph agents (PM, Developer, QA) across multiple terminal sessions.

## Architecture Overview

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   PM Agent       │     │ Developer Agent  │     │    QA Agent      │
│  (Coordinator)   │     │    (Worker)      │     │    (Worker)      │
│                  │     │                  │     │                  │
│  Terminal 1      │     │  Terminal 2      │     │  Terminal 3      │
└────────┬─────────┘     └────────┬─────────┘     └────────┬─────────┘
         │                        │                        │
         │                        │                        │
         └────────────────────────┴────────────────────────┘
                                    │
                         ┌──────────▼──────────┐
                         │  Shared State Files │
                         │  .claude/session/   │
                         └─────────────────────┘
```

## Session State File

**Location**: `.claude/session/coordinator-state.json`

This is the single source of truth for all agent coordination.

### State Structure

```json
{
  "sessionId": "threejs-sprint-1-20260119",
  "startedAt": "2026-01-19T10:00:00Z",
  "maxIterations": 50,
  "iteration": 1,
  "completionPromise": "RALPH_COMPLETE",
  "status": "running",
  "currentTask": {
    "id": "feat-001",
    "title": "Vehicle Physics",
    "assignedAgent": "developer",
    "status": "in_progress",
    "assignedAt": "2026-01-19T10:05:00Z"
  },
  "agents": {
    "pm": {
      "status": "idle",
      "lastSeen": "2026-01-19T10:05:00Z",
      "terminal": "coordinator"
    },
    "developer": {
      "status": "working",
      "currentTask": "feat-001",
      "lastSeen": "2026-01-19T10:05:30Z",
      "terminal": "worker-1"
    },
    "qa": {
      "status": "waiting",
      "lastSeen": "2026-01-19T10:04:00Z",
      "terminal": "worker-2"
    }
  },
  "stats": {
    "totalTasks": 10,
    "completed": 2,
    "failed": 0,
    "commits": 5,
    "lastUpdate": "2026-01-19T10:05:30Z"
  }
}
```

### Status Values

**Overall Status** (`status` field):

- `running` - Normal operation
- `terminating` - Shutdown requested
- `terminated` - Shutdown complete
- `completed` - All tasks finished
- `max_iterations_reached` - Safety limit hit

**Agent Status** (`agents.{agent}.status`):

- `idle` - Available for work
- `working` - Actively processing a task
- `waiting` - Polling for assignments
- `error` - Encountered an error

**Task Status** (`currentTask.status`):

- `pending` - Not yet assigned
- `assigned` - Assigned to agent, not started
- `in_progress` - Agent is working on it
- `ready_for_qa` - Developer done, awaiting QA
- `qa_validating` - QA is testing
- `passed` - QA validation successful
- `failed` - QA validation failed, needs fixes

## Agent Roles

### PM Agent (Coordinator)

**Terminal**: Terminal 1
**Startup**: `/ralph --role coordinator`

## CRITICAL: PM Agent MUST NOT CODE

**YOU ARE NOT ALLOWED TO:**

- Edit source code files (.ts, .tsx, .js, .jsx, .css, .html, etc.)
- Edit configuration files (tsconfig.json, vite.config.ts, package.json, etc.)
- Run build commands or test commands
- Fix bugs or implement features
- Edit files in `src/`, `server/`, `public/` directories

**YOU ARE ALLOWED TO:**

- Edit `.claude/session/*` state files only
- Edit `prd.json` ONLY for task status updates (passes, status, assignment metadata)
- Read source files to understand context for task assignment
- Research online for technical specifications to improve PRD
- Coordinate between Developer and QA agents
- Check progress AFTER QA approval

**Responsibilities**:

1. Initialize session state on startup
2. Review `prd.json` for incomplete items
3. Select next task using priority algorithm
4. Assign tasks to workers via state file
5. Monitor worker status via heartbeat polling
6. Process QA validation results (AFTER QA completes testing)
7. Detect completion (all PRD items `passes: true`)
8. Output completion promise when done

**Polling Interval**: Every 30 seconds (unified)

**Priority Algorithm**:

```
1. Architectural (affects entire codebase)
2. Integration (reveals incompatibilities early)
3. Unknown/spike (exploratory work)
4. Functional (standard features)
5. Polish (UI, optimization, docs)
```

### Developer Agent (Worker)

**Terminal**: Terminal 2
**Startup**: `/ralph --role worker --agent developer`

**Responsibilities**:

1. Poll state file for tasks assigned to "developer"
2. On assignment, explore codebase and implement
3. Run feedback loops (type-check, lint)
4. Commit work with Ralph format
5. Update task status to "ready_for_qa"
6. Update own agent status to "idle"

**Polling Interval**: Every 30 seconds (unified)

**Commit Format**:

```
[ralph] [developer] feat-XXX: Brief description

- Change 1
- Change 2

PRD: feat-XXX | Agent: developer | Iteration: N
```

### QA Agent (Worker)

**Terminal**: Terminal 3
**Startup**: `/ralph --role worker --agent qa`

**Responsibilities**:

1. Poll state file for tasks with status "ready_for_qa"
2. On assignment, run full validation:
   - `npm run type-check`
   - `npm run lint`
   - `npm run test`
   - `npm run build`
   - Browser test with Playwright MCP
3. Update PRD item `passes` field
4. If fail, add bug notes, return task to "pending"
5. Commit validation results
6. Update own agent status to "idle"

**Polling Interval**: Every 30 seconds (unified)

**Commit Format**:

```
[ralph] [qa] feat-XXX: Validation PASSED

- TypeScript: pass
- Lint: pass
- Tests: pass
- Build: pass
- Manual: pass

PRD: feat-XXX | Agent: qa | Iteration: N
```

## Startup Sequence

### Step 1: Start Coordinator (PM Agent)

```bash
# Terminal 1
cd /path/to/threejs-examples
claude --agent pm --settings .claude/settings.pm.json
# Then run: /ralph --role coordinator --max-iterations 30
```

**Coordinator initializes**:

1. Creates `.claude/session/coordinator-state.json`
2. Reads `prd.json` for task list
3. Sets own status to "idle"
4. Waits for workers to connect

### Step 2: Start Developer Worker

```bash
# Terminal 2
cd /path/to/threejs-examples
claude --agent developer --settings .claude/settings.developer.json
# Then run: /ralph --role worker --agent developer
```

**Worker initializes**:

1. Registers presence in state file
2. Sets own status to "waiting"
3. Begins polling for assignments

### Step 3: Start QA Worker

```bash
# Terminal 3
cd /path/to/threejs-examples
claude --agent qa --settings .claude/settings.qa.json
# Then run: /ralph --role worker --agent qa
```

## Coordination Flow

### Normal Task Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          PM COORDINATOR                                 │
│                                                                         │
│  1. Review prd.json for incomplete items (passes: false)               │
│  2. Filter by unblocked dependencies                                    │
│  3. Sort by priority (architectural → integration → functional)         │
│  4. Select highest priority item                                       │
│  5. Create task assignment in current-task.json                         │
│  6. Update coordinator-state.json: currentTask = assigned              │
│  7. Set coordinator status: "idle" (waiting for workers)                │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         DEVELOPER WORKER                                │
│                                                                         │
│  1. Poll coordinator-state.json every 5 seconds                         │
│  2. Detect task assigned to "developer"                                 │
│  3. Read current-task.json for full specifications                      │
│  4. Set own status: "working"                                          │
│  5. Explore codebase, implement feature                                 │
│  6. Run: npm run type-check, npm run lint                              │
│  7. Commit: [ralph] [developer] feat-XXX: description                  │
│  8. Update task status: "ready_for_qa"                                  │
│  9. Set own status: "idle"                                              │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                            QA WORKER                                    │
│                                                                         │
│  1. Poll coordinator-state.json every 5 seconds                         │
│  2. Detect task status: "ready_for_qa"                                  │
│  3. Read current-task.json for validation requirements                  │
│  4. Set own status: "working"                                          │
│  5. Run validation:                                                    │
│     - npm run type-check                                                │
│     - npm run lint                                                      │
│     - npm run test                                                      │
│     - npm run build                                                     │
│     - Browser test with Playwright MCP                                  │
│  6. Update PRD item passes field                                       │
│  7. Commit: [ralph] [qa] feat-XXX: Validation PASSED/FAILED           │
│  8. Set own status: "idle"                                              │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
                PASS                            FAIL
                    │                               │
                    ▼                               ▼
┌───────────────────────────┐         ┌─────────────────────────────────┐
│   PM COORDINATOR          │         │   PM COORDINATOR                │
│                           │         │                                 │
│  1. Detect QA pass        │         │  1. Detect QA fail              │
│  2. Mark passes: true     │         │  2. Keep passes: false          │
│  3. Check if all done     │         │  3. Return task to pending      │
│  4. If yes, output        │         │  4. Re-assign to developer      │
│     <promise>COMPLETE</>  │         │                                 │
│  5. If no, select next    │         └─────────────┬───────────────────┘
│     task                  │                       │
└───────────────────────────┘                       ▼
                                         ┌─────────────────────────────────┐
                                         │   DEVELOPER WORKER (retry)      │
                                         │                                 │
                                         │  1. Receive failed task         │
                                         │  2. Read bug notes from QA      │
                                         │  3. Fix bugs                    │
                                         │  4. Re-run validation           │
                                         └─────────────────────────────────┘
```

## Heartbeat Protocol

Each agent updates its `lastSeen` timestamp in the state file during each poll cycle.

### Dead Agent Detection

**Coordinator checks** (every 30 seconds):

```javascript
const now = new Date();
for (const [agent, data] of Object.entries(state.agents)) {
  const lastSeen = new Date(data.lastSeen);
  const secondsSinceLastSeen = (now - lastSeen) / 1000;

  if (secondsSinceLastSeen > 60) {
    // Agent hasn't been seen in 60 seconds
    console.warn(`Agent ${agent} may be unresponsive`);
    // Could implement: reassign task, notify, etc.
  }
}
```

## Task Assignment File

**Location**: `.claude/session/current-task.json`

This file contains the full details of the currently assigned task.

```json
{
  "prdId": "feat-001",
  "title": "Vehicle Physics Implementation",
  "assignedTo": "developer",
  "assignedAt": "2026-01-19T10:05:00Z",
  "category": "architectural",
  "priority": "high",
  "specifications": "Implement player vehicle using @react-three/rapier...",
  "acceptanceCriteria": [
    "Vehicle spawns at origin on game start",
    "WASD keys control vehicle movement",
    "Physics simulation runs smoothly at 60fps"
  ],
  "verificationSteps": [
    "Start dev server: npm run dev",
    "Verify vehicle appears on screen",
    "Test all direction keys (WASD)"
  ],
  "context": {
    "relatedFiles": ["src/components/game/player/Vehicle.tsx"],
    "similarFeatures": "See Floor.tsx for R3F pattern",
    "risks": "Physics can be unstable, test edge cases"
  },
  "dependencies": [],
  "status": "in_progress"
}
```

## Handoff Log

**Location**: `.claude/session/handoff-log.json`

Records all handoffs between agents for debugging and audit.

```json
{
  "handoffs": [
    {
      "timestamp": "2026-01-19T10:05:00Z",
      "from": "pm",
      "to": "developer",
      "task": "feat-001",
      "reason": "task_assignment"
    },
    {
      "timestamp": "2026-01-19T10:15:00Z",
      "from": "developer",
      "to": "qa",
      "task": "feat-001",
      "reason": "ready_for_validation"
    },
    {
      "timestamp": "2026-01-19T10:20:00Z",
      "from": "qa",
      "to": "pm",
      "task": "feat-001",
      "reason": "validation_passed"
    }
  ]
}
```

## Completion Detection

The coordinator checks for completion after each QA validation:

```javascript
const allItems = prd.items;
const completedItems = allItems.filter(item => item.passes === true);

if (completedItems.length === allItems.length) {
  // All tasks complete!
  state.status = "completed";
  console.log("<promise>" + state.completionPromise + "</promise>");
} else {
  // Select next task and continue
  selectNextTask();
}

---

## Iteration Retrospective Process

**CRITICAL: After each task completion, run a retrospective before selecting the next task.**

### Triggering Retrospective

When QA marks a task as "passed":

1. **PM sets `mode` to "retrospective"** in coordinator-state.json
2. **All agents enter retrospective mode**
3. **PM facilitates discussion** with all agents
4. **Discussion covers**:
   - Task review (what was accomplished, time taken, challenges)
   - Quality assessment (code quality, maintainability, concerns)
   - Risk identification (technical, timeline, quality risks)
   - Iteration estimation (calculate remaining iterations)
   - QA quality gatekeeping (can request refactors)

5. **PM documents** in `progress.txt`
6. **PM updates PRD** with findings
7. **PM resets mode** to "normal"
8. **Continue** to next task selection

### Quality Over Speed Principles

**ALL AGENTS MUST PRIORITIZE**:
- **Working feature > Fast feature**
- **Code quality > Shipping speed**
- **Maintainability > Shortcuts**
- **No shallow solutions**

**QA HAS AUTHORITY TO**:
- Request refactors even if tests pass
- Reject low-quality work
- Demand maintainability
- Request refactors for code quality reasons

### Retrospective Participation

Each agent brings their perspective:

**PM (Facilitator)**:
- Facilitates the discussion
- Estimates iterations remaining
- Documents risks and problems
- Updates PRD based on findings
- Supports QA's quality decisions

**Developer (Participant)**:
- Technical challenges faced
- Honest quality assessment
- Areas for improvement
- Risks identified
- Time estimates

**QA (Quality Gatekeeper)**:
- Quality assessment
- Maintainability concerns
- CAN request refactors
- Honest feedback
- Quality gatekeeping authority

### When QA Requests Refactor

1. **PM discusses** with Developer and QA
2. **Estimates effort** for refactor
3. **Updates** `current-task.json` with refactor request
4. **Reassigns** to Developer with status "refactor_needed"
5. **Developer** implements refactor
6. **QA** re-validates

### Completion Condition

- Continue to next task only after retrospective completes
- Never skip retrospective for speed
- Quality gatekeeping is mandatory

---

## Context Window Management

**CRITICAL: Agent context will fill up after many iterations. Use this strategy to avoid hitting token limits.**

### Problem

After ~10-20 iterations, an agent's context window approaches capacity. This causes:
- Slower responses
- Truncated recent context
- Potential failure to continue

### Solution: State Files as External Memory

The `.claude/session/` files and `prd.json` ARE the persistent memory. Agents can "forget" conversation history and reload from state files.

### When to Clear Context

**Each agent should clear context when:**
- Context reaches ~70% capacity
- After completing a task
- When responses start slowing down

### Context Reset Procedure

When an agent needs to clear context:

1. **Before clearing**, ensure state is synchronized:
   - `coordinator-state.json` is up to date
   - `prd.json` has latest task status
   - `progress.txt` has current summary

2. **Clear context** (user can manually trigger, or agent can signal)

3. **After clearing**, reload essential state:
```

READ .claude/session/coordinator-state.json
READ .claude/session/progress.txt
READ prd.json

````

4. **Continue** from where you left off

### State File Checkpoint Format

State files contain all information needed to resume:

**coordinator-state.json**:
```json
{
"sessionId": "ralph-XXX",
"status": "running",
"currentTask": {"id": "iter1-002", ...},
"iteration": 15,
"stats": {"total": 36, "completed": 15, ...}
}
````

**prd.json**:

```json
{
  "items": [
    {"id": "iter1-001", "passes": true, ...},
    {"id": "iter1-002", "passes": false, ...},
    ...
  ],
  "estimatedIterationsRemaining": 25
}
```

**progress.txt**:

```markdown
## Completed

- iter1-001: Install and Configure Colyseus.js Server
- iter1-002: Implement ECS Architecture
  ...

## Current Task

iter1-003: Define Game State Schema (in progress)
```

### Agent-Specific Context Management

**PM Agent**:

- **Can clear most aggressively** - only needs current state files
- **Keep**: PRD structure, current task assignment, team status
- **Can forget**: Task implementation details, past discussions

**Developer Agent**:

- **Clear after each task completion**
- **Keep**: Current task specs, recently edited files context
- **Can forget**: Past task details, completed work context
- **Reload**: Read task from `current-task.json`, read related files

**QA Agent**:

- **Clear after each validation**
- **Keep**: Current task validation criteria
- **Can forget**: Past validation details
- **Reload**: Read task from `current-task.json`

### Minimal Context Needed to Resume

| Agent     | Essential Context to Keep                                                                  |
| --------- | ------------------------------------------------------------------------------------------ |
| PM        | `prd.json` (task list), `coordinator-state.json` (session state), `progress.txt` (summary) |
| Developer | `current-task.json` (current task), files being edited, `prd.json` (for context)           |
| QA        | `current-task.json` (task to validate), `prd.json` (acceptance criteria)                   |

### Context Reset Signals

Agents can signal when they need context reset:

**In progress.txt**:

```markdown
### [{{TIMESTAMP}}] Context Reset: {{AGENT}}

Agent: {{agent_name}}
Reason: Context at 70% capacity
Iteration: {{N}}
```

**Agent tells user**: "My context is at 70%. Please allow me to reset by clearing our conversation. I will reload from state files and continue."

### Automatic Context Recovery

If context is accidentally cleared:

1. Agent reloads from `.claude/session/` files
2. Reads `prd.json` for task list
3. Reads `progress.txt` for recent history
4. Continues from last known state

---

## Worker Errors

1. Update agent status to "error"
2. Add error details to state file
3. Coordinator detects error and may:
   - Log the error
   - Reassign the task
   - Terminate the session (for critical errors)

### State File Corruption

If state file is corrupted or unreadable:

1. Workers enter "safe mode" - stop processing
2. Coordinator detects via missing heartbeats
3. Coordinator can reinitialize state file from PRD

## File Locking

To prevent concurrent write issues, all agents should:

1. Read state file
2. Make modifications in memory
3. Write to temporary file
4. Atomic rename to actual state file

```bash
# Example atomic update pattern
jq '.iteration += 1' coordinator-state.json > coordinator-state.json.tmp
mv coordinator-state.json.tmp coordinator-state.json
```

## Session Cleanup

On normal completion:

1. Set status to "completed"
2. Write final summary to `progress.txt`
3. Archive handoff log with timestamp
4. Keep state file for reference

On cancellation:

1. Set status to "terminated"
2. Preserve current progress
3. Enable resume via `--session` parameter
