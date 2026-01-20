---
name: task-handoff
description: Checklist for handing off tasks between agents
category: coordination
---

# Task Handoff Checklist

## PM → Developer Handoff

Before assigning task to Developer:

- [ ] Task passes PRD validation (see prd-validation.md)
- [ ] All dependencies have `passes: true`
- [ ] Developer heartbeat is fresh (< 60 seconds)
- [ ] No current task in progress (`currentTask === null` or `status === "passed"`)
- [ ] Retrospective complete (if previous task existed)

**Create current-task.json:**

```json
{
  "prdId": "{{TASK_ID}}",
  "title": "{{TASK_TITLE}}",
  "assignedTo": "developer",
  "assignedAt": "{{ISO_TIMESTAMP}}",
  "category": "{{CATEGORY}}",
  "priority": "{{PRIORITY}}",
  "specifications": "{{FULL_DESCRIPTION}}",
  "acceptanceCriteria": [...],
  "verificationSteps": [...],
  "context": {
    "relatedFiles": [...],
    "similarFeatures": "...",
    "risks": "..."
  },
  "status": "assigned"
}
```

**Update coordinator-state.json:**

```json
{
  "currentTask": {
    "id": "{{TASK_ID}}",
    "assignedAgent": "developer",
    "status": "assigned",
    "assignedAt": "{{ISO_TIMESTAMP}}"
  }
}
```

**Log handoff:**

```json
// handoff-log.json
{
  "handoffs": [
    {
      "timestamp": "{{ISO_TIMESTAMP}}",
      "from": "pm",
      "to": "developer",
      "task": "{{TASK_ID}}",
      "reason": "task_assignment"
    }
  ]
}
```

## Developer → QA Handoff

Developer updates when implementation complete:

- [ ] All feedback loops passed (type-check, lint, test, build)
- [ ] Code committed with Ralph format
- [ ] Status set to `ready_for_qa`

**Update current-task.json:**

```json
{
  "status": "ready_for_qa",
  "implementedAt": "{{ISO_TIMESTAMP}}",
  "commit": "{{COMMIT_HASH}}"
}
```

## QA → PM Handoff (Pass)

QA updates when validation passes:

- [ ] All validation checks passed
- [ ] PRD item `passes` set to `true`
- [ ] Status set to `passed`

**Update current-task.json:**

```json
{
  "status": "passed",
  "validatedAt": "{{ISO_TIMESTAMP}}"
}
```

**Update prd.json:**

```json
{
  "items": [
    {
      "id": "{{TASK_ID}}",
      "passes": true,
      "status": "passed"
    }
  ]
}
```

## QA → Developer Handoff (Fail)

QA updates when validation fails:

- [ ] Bug notes documented
- [ ] Status set to `needs_fixes`
- [ ] Retry count incremented

**Update current-task.json:**

```json
{
  "status": "needs_fixes",
  "bugNotes": "{{DETAILED_BUG_DESCRIPTION}}",
  "retryCount": {{PREVIOUS + 1}}
}
```

## PM → All Agents (Retrospective)

PM initiates retrospective after task passes:

- [ ] Create retrospective.txt
- [ ] Set status to `in_retrospective`
- [ ] Set agent statuses to `awaiting_retrospective`

**Update coordinator-state.json:**

```json
{
  "currentTask": {
    "status": "in_retrospective",
    "retrospectiveFile": ".claude/session/retrospective.txt"
  },
  "agents": {
    "developer": { "status": "awaiting_retrospective" },
    "qa": { "status": "awaiting_retrospective" },
    "pm": { "status": "facilitating_retrospective" }
  }
}
```
