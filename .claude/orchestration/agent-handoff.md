# Agent Handoff Protocol

This document defines the protocol for handoffs between PM, Developer, and QA agents in the Ralph multi-session system.

## Handoff Types

### 1. PM → Developer (Task Assignment)

**Trigger**: PM selects next task from PRD

**PM Action**:

```json
// Update: .claude/session/coordinator-state.json
{
  "currentTask": {
    "id": "feat-001",
    "assignedAgent": "developer",
    "status": "assigned",
    "assignedAt": "2026-01-19T10:05:00Z"
  },
  "agents": {
    "developer": {
      "status": "assigned",
      "currentTask": "feat-001"
    }
  }
}
```

**Create**: `.claude/session/current-task.json`

```json
{
  "prdId": "feat-001",
  "title": "Vehicle Physics Implementation",
  "assignedTo": "developer",
  "assignedAt": "2026-01-19T10:05:00Z",
  "specifications": "Full task description from PRD...",
  "acceptanceCriteria": [...],
  "verificationSteps": [...],
  "context": {...}
}
```

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

**Developer Detects**: On next poll (within 30 seconds)

1. Sees `currentTask.assignedAgent === "developer"`
2. Reads `current-task.json` for details
3. Updates own status to "working"
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

**Update**: `.claude/session/coordinator-state.json`

```json
{
  "currentTask": {
    "status": "ready_for_qa",
    "completedAt": "2026-01-19T10:15:00Z",
    "commit": "a1b2c3d"
  },
  "agents": {
    "developer": {
      "status": "idle",
      "lastCompletedTask": "feat-001"
    }
  }
}
```

**Update**: `prd.json`

```json
{
  "items": [
    {
      "id": "feat-001",
      "status": "ready_for_qa",
      "lastCommit": "a1b2c3d"
    }
  ]
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

**QA Detects**: On next poll (within 30 seconds)

1. Sees `currentTask.status === "ready_for_qa"`
2. Reads `current-task.json` for validation requirements
3. Updates own status to "working"
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

**Update**: `.claude/session/coordinator-state.json`

```json
{
  "currentTask": {
    "status": "passed",
    "validatedAt": "2026-01-19T10:20:00Z",
    "validatedBy": "qa"
  },
  "agents": {
    "qa": {
      "status": "idle",
      "lastCompletedTask": "feat-001"
    }
  },
  "stats": {
    "completed": 1
  }
}
```

**Update**: `prd.json`

```json
{
  "items": [
    {
      "id": "feat-001",
      "passes": true,
      "status": "completed",
      "validatedAt": "2026-01-19T10:20:00Z",
      "validationResults": {
        "typescript": "pass",
        "lint": "pass",
        "test": "pass",
        "build": "pass",
        "manual": "pass"
      }
    }
  ]
}
```

**Append**: `.claude/session/progress.txt`

```markdown
### [2026-01-19T10:20:00Z] feat-001: Vehicle Physics Implementation - COMPLETE

Implemented by: developer
Validated by: qa
Commit: a1b2c3d

Acceptance criteria:
✓ Vehicle spawns at origin on game start
✓ WASD keys control vehicle movement
✓ Physics simulation runs smoothly at 60fps

Validation results:

- TypeScript: pass
- Lint: pass
- Tests: pass
- Build: pass
- Manual: pass
```

**PM Detects**: On next poll

1. Sees `currentTask.status === "passed"`
2. Updates PRD item `passes: true`
3. Checks if all items complete
4. If not, selects next task

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

**Update**: `.claude/session/coordinator-state.json`

```json
{
  "currentTask": {
    "status": "needs_fixes",
    "validatedAt": "2026-01-19T10:20:00Z",
    "validationResults": {
      "typescript": "pass",
      "lint": "pass",
      "test": "fail: 2 tests failing",
      "build": "pass",
      "manual": "fail: vehicle falls through floor"
    },
    "bugs": [
      {
        "severity": "critical",
        "description": "Vehicle falls through floor after 5 seconds",
        "steps": "Press W for 5 seconds",
        "expected": "Vehicle stays on floor",
        "actual": "Vehicle falls through"
      }
    ]
  },
  "agents": {
    "qa": {
      "status": "idle"
    }
  }
}
```

**Update**: `prd.json`

```json
{
  "items": [
    {
      "id": "feat-001",
      "passes": false,
      "status": "needs_fixes",
      "bugs": [
        {
          "severity": "critical",
          "description": "Vehicle falls through floor",
          "steps": "Press W for 5 seconds"
        }
      ],
      "validationResults": {
        "test": "fail",
        "manual": "fail"
      }
    }
  ]
}
```

**Update**: `.claude/session/current-task.json`

```json
{
  "prdId": "feat-001",
  "assignedTo": "developer",
  "status": "bug_fix",
  "bugs": [...],
  "retryCount": 1
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

**Developer Detects**: On next poll

1. Sees task reassigned with `status: "bug_fix"`
2. Reads bug details from `current-task.json`
3. Fixes bugs and re-runs validation
4. Increments `retryCount`

### 5. PM → All (Session Complete)

**Trigger**: All PRD items have `passes: true`

**PM Action**:

```bash
# Final validation
npm run type-check && npm run lint && npm run test && npm run build

# If all pass, output completion promise
echo "<promise>RALPH_COMPLETE</promise>"
```

**Update**: `.claude/session/coordinator-state.json`

```json
{
  "status": "completed",
  "completedAt": "2026-01-19T12:00:00Z",
  "stats": {
    "totalTasks": 10,
    "completed": 10,
    "failed": 0,
    "commits": 15
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

**Signal**: All workers detect `status: "completed"` and exit gracefully.

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
4. **Increment retry counter**: Track retries per task

```json
{
  "currentTask": {
    "assignmentRetries": 1,
    "lastAssignmentAttempt": "2026-01-19T10:05:00Z"
  }
}
```

After 3 failed assignments, coordinator may:

- Log critical error
- Suggest manual intervention
- Or skip task and continue with others

## Atomic State Updates

All agents must use atomic file updates to prevent corruption:

```bash
# Read current state
STATE=$(cat coordinator-state.json)

# Modify (using jq or similar)
NEW_STATE=$(echo "$STATE" | jq '.iteration += 1')

# Write atomically
echo "$NEW_STATE" > coordinator-state.json.tmp
mv coordinator-state.json.tmp coordinator-state.json
```

This ensures that concurrent reads never see partially-written state files.
