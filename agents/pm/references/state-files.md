# State Files Reference

## Overview

All Ralph session state is stored in `.claude/session/`. This document describes the structure and ownership of each file.

## File Ownership

| File                       | Owner      | Other Agents                       |
| -------------------------- | ---------- | ---------------------------------- |
| `coordinator-state.json`   | PM         | Developer/QA update heartbeat only |
| `current-task.json`        | PM creates | Developer/QA update status fields  |
| `handoff-log.json`         | PM         | All append                         |
| `retrospective.txt`        | PM creates | All contribute sections            |
| `progress.txt`             | PM         | All can append                     |
| `coordinator-progress.txt` | PM only    | Read only                          |
| `developer-progress.txt`   | Developer  | PM can add notes                   |
| `qa-progress.txt`          | QA         | PM can add notes                   |

## coordinator-state.json

Main session state file.

```json
{
  "sessionId": "ralph-20260119-120000",
  "startedAt": "2026-01-19T12:00:00Z",
  "maxIterations": 50,
  "iteration": 1,
  "scale": 2,
  "originalCommand": "/ralph --role coordinator --max-iterations 50",
  "completionPromise": "RALPH_COMPLETE",
  "status": "running",
  "currentTask": {
    "id": "feat-001",
    "title": "Task Title",
    "assignedAgent": "developer",
    "status": "assigned|working|ready_for_qa|passed|needs_fixes|in_retrospective",
    "assignedAt": "2026-01-19T12:00:00Z",
    "retryCount": 0
  },
  "agents": {
    "pm": {
      "status": "idle|facilitating_retrospective",
      "lastSeen": "2026-01-19T12:00:00Z",
      "terminal": "coordinator"
    },
    "developer": {
      "status": "idle|working|awaiting_pm|awaiting_retrospective",
      "lastSeen": "2026-01-19T12:00:00Z",
      "terminal": "worker-1"
    },
    "qa": {
      "status": "idle|working|awaiting_retrospective",
      "lastSeen": "2026-01-19T12:00:00Z",
      "terminal": "worker-2"
    }
  },
  "stats": {
    "totalTasks": 10,
    "completed": 3,
    "failed": 0,
    "commits": 5,
    "lastUpdate": "2026-01-19T12:00:00Z"
  }
}
```

### Status Values

**Session Status:**

- `running` — Normal operation
- `completed` — All PRD items passed
- `terminated` — Manually cancelled
- `max_iterations_reached` — Hit iteration limit

**Task Status:**

- `assigned` — Just assigned to agent
- `working` — Agent actively implementing
- `ready_for_qa` — Developer done, awaiting QA
- `passed` — QA validated successfully
- `needs_fixes` — QA found issues
- `in_retrospective` — Post-completion review

**Agent Status:**

- `idle` — Available for work
- `working` — Actively on a task
- `awaiting_pm` — Developer has question
- `awaiting_retrospective` — Waiting to contribute
- `facilitating_retrospective` — PM running retrospective

## current-task.json

Active task details.

```json
{
  "prdId": "feat-001",
  "title": "Implement Vehicle Physics",
  "assignedTo": "developer",
  "assignedAt": "2026-01-19T12:00:00Z",
  "category": "functional",
  "priority": "high",
  "specifications": "Full task description from PRD...",
  "acceptanceCriteria": ["Vehicle responds to WASD input", "Physics simulation runs at 60Hz"],
  "verificationSteps": ["Press WASD and verify vehicle moves", "Check physics runs smoothly"],
  "context": {
    "relatedFiles": ["src/components/Vehicle.tsx"],
    "similarFeatures": "See Player component for reference",
    "risks": "Physics performance on mobile"
  },
  "status": "assigned",
  "retryCount": 0,
  "implementedAt": null,
  "validatedAt": null,
  "commit": null,
  "bugNotes": null,
  "question": null,
  "pmClarification": null
}
```

## handoff-log.json

History of task handoffs between agents.

```json
{
  "handoffs": [
    {
      "timestamp": "2026-01-19T12:00:00Z",
      "from": "pm",
      "to": "developer",
      "task": "feat-001",
      "reason": "task_assignment"
    },
    {
      "timestamp": "2026-01-19T14:00:00Z",
      "from": "developer",
      "to": "qa",
      "task": "feat-001",
      "reason": "implementation_complete"
    }
  ]
}
```

## retrospective.txt

Temporary file for retrospective discussion.

See [retrospective.md](../skills/retrospective.md) for full template.

## prd.json

Product Requirements Document. Located at project root.

```json
{
  "projectName": "My Game",
  "version": "1.0.0",
  "items": [
    {
      "id": "feat-001",
      "title": "Vehicle Physics",
      "description": "Implement vehicle with Rapier physics...",
      "category": "functional",
      "priority": "high",
      "acceptanceCriteria": ["..."],
      "verificationSteps": ["..."],
      "dependencies": [],
      "passes": false,
      "status": "pending",
      "assignedAt": null,
      "completedAt": null,
      "estimatedIterations": 5
    }
  ]
}
```

### PRD Fields

| Field                 | Type      | PM Can Edit              |
| --------------------- | --------- | ------------------------ |
| `passes`              | boolean   | ✅ (after QA approval)   |
| `status`              | string    | ✅                       |
| `assignedAt`          | timestamp | ✅                       |
| `assignedTo`          | string    | ✅                       |
| `completedAt`         | timestamp | ✅                       |
| `description`         | string    | ✅ (clarifications only) |
| `acceptanceCriteria`  | array     | ✅ (clarifications only) |
| `verificationSteps`   | array     | ✅ (clarifications only) |
| `estimatedIterations` | number    | ✅                       |
