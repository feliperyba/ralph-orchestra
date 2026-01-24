# Agent Handoff Protocol

This document defines the protocol for handoffs between PM, Developer, and QA agents in the Ralph multi-session system.

> **NOTE**: All session state is now in `prd.json`. Previous versions used separate `coordinator-state.json` and `current-task.json` files.

## Handoff Types

### 1. PM → Developer (Task Assignment)

**Trigger**: PM selects next task from PRD

**PM Action**:

```json
// Update: prd.json (atomic update with all three sections)
{
  "session": {
    "currentTask": {
      "id": "feat-001",
      "status": "assigned",
      "assignedAt": "2026-01-19T10:05:00Z"
    }
  },
  "agents": {
    "developer": {
      "status": "working",
      "currentTaskId": "feat-001",
      "lastSeen": "2026-01-19T10:05:00Z"
    }
  },
  "items": [{
    "id": "feat-001",
    "status": "assigned",
    "agent": "developer",
    "assignedAt": "2026-01-19T10:05:00Z"
  }]
}
```

**Task details** are stored in `prd.json.items[{taskId}]`:
- `specifications` - Full task description from PRD
- `acceptanceCriteria` - Array of acceptance criteria
- `verificationSteps` - Array of verification steps
- `dependencies` - Array of task dependencies

**Log**: `.claude/session/handoff-log.json`

```json
{
  "handoffs": [
    {
      "timestamp": "2026-01-19T10:05:00Z",
      "from": "pm",
      "to": "developer",
      "task": "feat-001",
      "reason": "task_assignment"
    }
  ]
}
```

**Developer Detects**: On next poll or message receipt

1. Sees `prd.json.session.currentTask.assignedAgent === "developer"`
2. Reads task details from `prd.json.items[{taskId}]`
3. Updates own `prd.json.agents.developer.status` to "working"
4. Begins implementation

### 2. Developer → QA (Validation Request)

**Trigger**: Developer completes implementation and all feedback loops pass

**Developer Action**:

```bash
# Commit the work
git add .
git commit -m "[ralph] [developer] feat-001: Implement vehicle physics

- Added Rapier physics body to Vehicle component
- Connected keyboard input to vehicle controls
- Configured physics materials for floor interaction

PRD: feat-001 | Agent: developer | Iteration: 3"
```

**Update**: `prd.json`

```json
{
  "session": {
    "currentTask": {
      "id": "feat-001",
      "status": "ready_for_qa",
      "completedAt": "2026-01-19T10:15:00Z"
    }
  },
  "agents": {
    "developer": {
      "status": "idle",
      "currentTaskId": null,
      "lastSeen": "2026-01-19T10:15:00Z"
    }
  },
  "items": [{
    "id": "feat-001",
    "status": "ready_for_qa",
    "lastCommit": "a1b2c3d"
  }]
}
```

**Log**: `.claude/session/handoff-log.json`

```json
{
  "handoffs": [
    {
      "timestamp": "2026-01-19T10:15:00Z",
      "from": "developer",
      "to": "qa",
      "task": "feat-001",
      "reason": "ready_for_validation",
      "commit": "a1b2c3d"
    }
  ]
}
```

**QA Detects**: On next poll or message receipt

1. Sees `prd.json.session.currentTask.status === "ready_for_qa"`
2. Reads task details from `prd.json.items[{taskId}]`
3. Updates own `prd.json.agents.qa.status` to "working"
4. Begins validation

### 3. QA → PM (Pass - Task Complete)

**Trigger**: All validation checks pass

**QA Action**:

```bash
# Commit validation results
git commit --allow-empty -m "[ralph] [qa] feat-001: Validation PASSED

- TypeScript: pass
- Lint: pass
- Tests: pass
- Build: pass
- Manual browser test: pass

PRD: feat-001 | Agent: qa | Iteration: 4"
```

**Update**: `prd.json`

```json
{
  "session": {
    "currentTask": {
      "id": "feat-001",
      "status": "passed",
      "validationPassed": true,
      "completedAt": "2026-01-19T10:20:00Z"
    }
  },
  "items": [{
    "id": "feat-001",
    "passes": true,
    "status": "completed",
    "qaValidatedAt": "2026-01-19T10:20:00Z",
    "validationResults": {
      "typescript": "pass",
      "lint": "pass",
      "test": "pass",
      "build": "pass",
      "manual": "pass"
    }
  }],
  "agents": {
    "qa": {
      "status": "idle",
      "currentTaskId": null,
      "lastSeen": "2026-01-19T10:20:00Z"
    }
  }
}
```

**PM Detects**: On next poll

1. Sees `prd.json.session.currentTask.status === "passed"`
2. Enters retrospective phase
3. After retrospective, updates stats and selects next task

### 4. QA → Developer (Fail - Bug Fix Required)

**Trigger**: Any validation check fails

**QA Action**:

```bash
# Commit validation failure
git commit --allow-empty -m "[ralph] [qa] feat-001: Validation FAILED

- TypeScript: pass
- Lint: pass
- Tests: FAIL: 2 tests failing
- Build: pass
- Manual: FAIL: vehicle falls through floor

Bug: feat-001 | Agent: qa | Iteration: 4"
```

**Update**: `prd.json`

```json
{
  "session": {
    "currentTask": {
      "id": "feat-001",
      "status": "needs_fixes",
      "validationPassed": false
    }
  },
  "items": [{
    "id": "feat-001",
    "passes": false,
    "status": "needs_fixes",
    "notes": "Bugs: Vehicle falls through floor after 5 seconds (critical)",
    "bugs": [
      {
        "severity": "critical",
        "description": "Vehicle falls through floor after 5 seconds",
        "steps": "Press W for 5 seconds",
        "expected": "Vehicle stays on floor",
        "actual": "Vehicle falls through"
      }
    ]
  }],
  "agents": {
    "qa": {
      "status": "idle",
      "currentTaskId": null
    },
    "developer": {
      "status": "working",
      "currentTaskId": "feat-001",
      "lastSeen": "2026-01-19T10:20:00Z"
    }
  }
}
```

**Log**: `.claude/session/handoff-log.json`

```json
{
  "handoffs": [
    {
      "timestamp": "2026-01-19T10:20:00Z",
      "from": "qa",
      "to": "developer",
      "task": "feat-001",
      "reason": "validation_failed_bugs",
      "bugs": 1
    }
  ]
}
```

**Developer Detects**: On next poll or message receipt

1. Sees `prd.json.items[{taskId}].status === "needs_fixes"`
2. Reads bug details from `prd.json.items[{taskId}].notes` or `.bugs`
3. Fixes bugs and re-runs validation
4. Updates status back to "ready_for_qa"

### 5. PM → All (Session Complete)

**Trigger**: All PRD items have `passes: true`

**PM Action**:

```bash
# Final validation
npm run type-check && npm run lint && npm run test && npm run build

# If all pass, output completion promise
echo "<promise>RALPH_COMPLETE</promise>"
```

**Update**: `prd.json.session`

```json
{
  "session": {
    "status": "completed",
    "completedAt": "2026-01-19T12:00:00Z",
    "stats": {
      "totalTasks": 10,
      "completed": 10,
      "failed": 0,
      "commits": 15
    }
  }
}
```

**Create**: `.claude/session/final-report.md`

```markdown
# Ralph Session Report

Session: threejs-sprint-1-20260119
Started: 2026-01-19T10:00:00Z
Completed: 2026-01-19T12:00:00Z
Duration: 2 hours
Iterations: 15

## Summary

✓ All 10 tasks completed successfully
✓ 15 commits made
✓ 0 validation failures
✓ All feedback loops passing

## Completed Tasks

- feat-001: Vehicle Physics Implementation
- feat-002: Camera Follow System
- feat-003: Loading Screen with Progress
- feat-004: Phase-Based Game Loop
- test-001: E2E Test Suite Setup
- test-002: Unit Tests for Game Store
  ...

## Validation Summary

- TypeScript: 100% pass rate
- Lint: 0 warnings
- Test Coverage: 82%
- Build: Successful
```

**Signal**: All workers detect `prd.json.session.status === "completed"` and exit gracefully.

## State Transition Diagram

```
                    ┌─────────────┐
                    │   pending   │
                    └──────┬──────┘
                           │ PM assigns
                           ▼
                    ┌─────────────┐
                    │  assigned   │
                    └──────┬──────┘
                           │ Developer accepts
                           ▼
                    ┌─────────────┐
                    │ in_progress │
                    └──────┬──────┘
                           │ Developer completes
                           ▼
                    ┌─────────────┐
                    │ready_for_qa │
                    └──────┬──────┘
                           │
                  ┌────────┴────────┐
                  │                 │
             QA PASS          QA FAIL
                  │                 │
                  ▼                 ▼
            ┌──────────┐      ┌──────────┐
            │  passed  │      │needs_fix │
            └────┬─────┘      └────┬─────┘
                 │                 │
                 │                 └─> Returns to in_progress
                 │
                 ▼
            ┌──────────┐
            │completed │
            └──────────┘
```

## Commit Message Standards

All commits in a Ralph session MUST follow this format:

### Developer Commits

```
[ralph] [developer] feat-XXX: Brief description

- Change 1
- Change 2
- Change 3

PRD: feat-XXX | Agent: developer | Iteration: N
```

### QA Commits (Pass)

```
[ralph] [qa] feat-XXX: Validation PASSED

- TypeScript: pass
- Lint: pass
- Tests: pass
- Build: pass
- Manual: pass

PRD: feat-XXX | Agent: qa | Iteration: N
```

### QA Commits (Fail)

```
[ralph] [qa] feat-XXX: Validation FAILED

- TypeScript: pass
- Lint: pass
- Tests: fail: [details]
- Build: pass
- Manual: fail: [details]

Bug: feat-XXX | Agent: qa | Iteration: N
```

### PM Commits

```
[ralph] [pm] feat-XXX: Task assignment

Assigned [task description] to Developer.

PRD: feat-XXX | Agent: pm | Iteration: N
```

## Handoff Timeout Handling

If an agent doesn't pick up a task within timeout:

1. **Coordinator detects timeout**: 60 seconds after assignment
2. **Log warning**: Add to handoff log
3. **Reassign task**: Return to pending, reassign to same or different agent
4. **Track retries**: Track retries in `prd.json.items[{taskId}]`

After 3 failed assignments, coordinator may:

- Log critical error
- Suggest manual intervention
- Or skip task and continue with others

## Atomic State Updates

All agents must use atomic file updates to prevent corruption:

```bash
# Read current state
STATE=$(cat prd.json)

# Modify (using jq or similar)
NEW_STATE=$(echo "$STATE" | jq '.session.iteration += 1')

# Write atomically
echo "$NEW_STATE" > prd.json.tmp
mv prd.json.tmp prd.json
```

This ensures that concurrent reads never see partially-written state files.
