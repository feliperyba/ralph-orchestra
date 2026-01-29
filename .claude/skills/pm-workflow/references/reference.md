# PM Reference

> Decision tables, message formats, and reference material for PM Coordinator.

## Contents

- [Task Status Definitions](#task-status-definitions)
- [Decision Framework](#decision-framework)
- [Task Assignment Priority](#task-assignment-priority)
- [Message Handling Summary](#message-handling-summary)
- [Commit Format](#commit-format)

---

## Task Status Definitions

| Status          | When to Use                 | passes | Who Sets It  | Description                  |
| --------------- | --------------------------- | ------ | ------------ | ---------------------------- |
| `"pending"`     | Task not yet started        | false  | PM (initial) | Task exists but not assigned |
| `"assigned"`    | Task assigned to worker     | false  | PM           | Worker has received task     |
| `"awaiting_qa"` | Worker finished, sent to QA | false  | PM           | QA must validate             |
| `"completed"`   | QA PASSED validation        | true   | PM           | Task fully complete          |
| `"needs_fixes"` | QA found bugs               | false  | PM           | Worker must fix              |
| `"in_progress"` | Worker actively working     | false  | Worker       | Self-reported                |
| `"blocked"`     | Max attempts reached        | false  | PM           | Needs escalation             |

**CRITICAL:** When worker sends `implementation_complete`:

- ✅ Set `status: "awaiting_qa"` + `passes: false`
- ❌ DO NOT set `status: "completed"` (only QA can mark complete)

---

## Decision Framework

| Current State           | Action                                           | Next State                      |
| ----------------------- | ------------------------------------------------ | ------------------------------- |
| `null`                  | Use `Skill("pm-organization-task-selection")`    | `task_ready` or `test_planning` |
| `task_ready`            | Use Task with `pm-test-planner` sub-agent        | `test_plan_ready`               |
| `test_plan_ready`       | Assign task, send task message, exit             | `assigned`                      |
| `assigned`              | Send task message, exit                          | (wait for worker)               |
| `awaiting_qa`           | Wait for QA validation                           | (wait)                          |
| `passed` (QA)           | Use `Skill("pm-organization-task-selection")`    | `in_retrospective`              |
| `playtest_complete`     | Use Task with `pm-prd-organizer`                 | `prd_refinement`                |
| `prd_refinement`        | Move to cleanup                                  | `cleanup_completed`             |
| `cleanup_completed`     | DELETE retrospective, move to prd_completed.json | `skill_research`                |
| `skill_research`        | Use `Skill("pm-improvement-skill-research")`     | `skill_updates_applied`         |
| `skill_updates_applied` | Select next task                                 | `task_ready`                    |
| `completed`             | Select next task                                 | `task_ready`                    |
| `needs_fixes`           | Check attempts first                             | `assigned` or `blocked`         |

---

## Task Assignment Priority

| Category        | Priority    | Examples                               |
| --------------- | ----------- | -------------------------------------- |
| `architectural` | 1 (Highest) | State stores, API design, core systems |
| `integration`   | 2           | API integration, third-party services  |
| `functional`    | 3           | Gameplay mechanics, features           |
| `visual`        | 4           | 3D models, materials, textures         |
| `shader`        | 4           | Shaders, visual effects                |
| `polish`        | 5 (Lowest)  | UI styling, visual refinement          |

> **See `Skill("pm-organization-task-selection")` for complete priority algorithm.**

---

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

> **See `Skill("shared-messaging")` for complete message format specifications.**

---

## Message Format Reference

### task_assign Message

```json
{
  "id": "msg-{agent}-{timestamp}-001",
  "from": "pm",
  "to": "{agent}",
  "type": "task_assign",
  "priority": "normal",
  "payload": {
    "taskId": "{taskId}",
    "title": "{taskTitle}",
    "description": "{taskDescription}",
    "acceptanceCriteria": [...],
    "message": "You have been assigned this task."
  },
  "timestamp": "{ISO_TIMESTAMP}",
  "status": "pending"
}
```

### validation_request Message

```json
{
  "id": "msg-qa-{timestamp}-001",
  "from": "pm",
  "to": "qa",
  "type": "validation_request",
  "priority": "normal",
  "payload": {
    "taskId": "{taskId}",
    "message": "Worker completed implementation. Please validate."
  },
  "timestamp": "{ISO_TIMESTAMP}",
  "status": "pending"
}
```

### wake_up Message

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

### question Message (PM → Worker)

```json
{
  "id": "msg-{agent}-{timestamp}-001",
  "from": "pm",
  "to": "{agent}",
  "type": "question",
  "priority": "normal",
  "payload": {
    "question": "{your question here}",
    "context": "{relevant context}"
  },
  "timestamp": "{ISO_TIMESTAMP}",
  "status": "pending"
}
```

---

## Commit Format

> **See `Skill("dev-coordination-git-protocol")` for complete commit message standards.**

```
[ralph] [pm] {TASK_ID}: Brief description

- Change 1
- Change 2

PRD: {TASK_ID} | Agent: pm | Iteration: N
```

---

## State Transitions Summary

```
<transitions>
  <selection>
    null → task_ready → test_plan_ready → assigned
  </selection>

  <workflow>
    assigned → (worker works) → awaiting_qa
  </workflow>

  <validation>
    awaiting_qa → completed OR needs_fixes
    needs_fixes → assigned (if attempts < 3)
    needs_fixes → blocked (if attempts >= 3)
  </validation>

  <completion>
    completed → prd_refinement
    prd_refinement → cleanup_completed
    cleanup_completed → task_ready (back to selection)
  </completion>
</transitions>
```

---

## PM Ready Flag

After consolidation complete, create `.claude/session/pm-ready.flag`:

```json
"2026-01-27T00:00:00.000Z"
```

**Purpose:** Watchdog waits for this flag before allowing workers to start, ensuring proper message consolidation.

**When to skip:** If already in active session and have previously sent status.
