---
name: polling-loop
description: Main polling loop architecture with restart detection for Ralph agents
category: orchestration
depends-on: [polling-protocol, ralph-core]
---

# Polling Loop

> "The heartbeat of every Ralph agent - poll, check, act, repeat."

## Universal Polling Loop Structure

All agents use this basic loop structure:

```
FOREVER:
  WAIT 30 seconds

  # CHECK FOR RESTART SIGNAL (context reset)
  RUN: python scripts/restart-agent.py --agent {AGENT} --check
  IF exit code == 0 (signal detected):
    COMPLETE current work if in progress
    UPDATE coordinator-state.json with current state
    SAVE any pending work
    DELETE restart-flag-{AGENT}.json
    EXIT  # New terminal already launched

  # READ STATE
  READ coordinator-state.json

  # CHECK EXIT CONDITIONS
  IF status == "completed" OR "terminated" OR "max_iterations_reached":
    EXIT

  # CHECK FOR RETROSPECTIVE (all agents)
  IF agents.{agent}.status == "awaiting_retrospective":
    READ retrospective.txt
    ADD your contribution
    UPDATE completion checkbox
    SET own status to "idle"
    CONTINUE  # POLL AGAIN

  # AGENT-SPECIFIC TASK HANDLING
  {AGENT-SPECIFIC LOGIC HERE}

  # UPDATE HEARTBEAT
  UPDATE agents.{agent}.lastSeen to NOW
```

## Agent-Specific Task Handling

### PM Coordinator

```
IF currentTask == null:
  SELECT next task from PRD
  IF task available:
    ASSIGN to developer
    UPDATE coordinator-state.json
    LOG in coordinator-progress.txt
ELSE IF currentTask.status == "passed":
  CREATE retrospective.txt
  SET status to "in_retrospective"
ELSE IF currentTask.status == "in_retrospective":
  CHECK if both agents contributed
  IF yes:
    SYNTHESIZE and complete retrospective
    DELETE retrospective.txt
    SET currentTask = null
```

### Developer Worker

```
IF currentTask.assignedAgent == "developer" AND status == "assigned":
  SET own status to "working"
  READ current-task.json
  IMPLEMENT feature
  RUN type-check, lint, test
  IF all pass:
    COMMIT work
    SET task status to "ready_for_qa"
  SET own status to "idle"
ELSE IF currentTask.status == "needs_fixes" AND assignedTo == "developer":
  SET own status to "working"
  READ bug notes
  FIX bugs
  RUN all feedback loops
  COMMIT fixes
  SET task status to "ready_for_qa"
  SET own status to "idle"
```

### QA Worker

```
IF currentTask.status == "ready_for_qa":
  SET own status to "working"
  READ current-task.json
  RUN type-check, lint, test, build
  RUN browser tests
  IF all pass:
    UPDATE prd.json: passes = true
    SET task status to "passed"
    COMMIT validation results
  ELSE:
    ADD bug notes to prd.json
    SET task status to "needs_fixes"
    COMMIT bug report
  SET own status to "idle"
```

## Restart Detection

The polling loop checks for restart signals every cycle:

```bash
python scripts/restart-agent.py --agent {AGENT} --check
```

If a restart is triggered (exit code 0):
1. Complete any in-progress work
2. Save current state to `coordinator-state.json`
3. Commit any pending changes
4. Delete the restart flag file
5. Exit - new terminal will continue

## Atomic State Updates

When updating `coordinator-state.json`, always update atomically:

```bash
# Read, modify, write atomically
jq '.agents.developer.lastSeen = "2026-01-19T12:00:00Z"' coordinator-state.json > coordinator-state.json.tmp
mv coordinator-state.json.tmp coordinator-state.json
```

See [atomic-updates.md](atomic-updates.md) for more details.

## Heartbeat Update Format

```json
{
  "agents": {
    "{AGENT_TYPE}": {
      "lastSeen": "2026-01-19T12:00:00Z",
      "status": "idle|working|awaiting_pm|awaiting_retrospective"
    }
  }
}
```

## Error Handling

If state file is corrupted or unreadable:
1. Log error to progress file
2. Wait 30 seconds
3. Try again
3. If persists after 3 attempts, exit and notify PM

## Reference

- [polling-protocol.md](polling-protocol.md) — Core polling rules
- [ralph-core.md](ralph-core.md) — Session structure
- [context-management.md](context-management.md) — Context reset procedures
