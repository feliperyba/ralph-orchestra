---
name: polling-protocol
description: Core polling rules and exit conditions for all Ralph agents
category: orchestration
depends-on: [ralph-core]
---

# Polling Protocol

> "All agents poll forever - no natural exit until session completes."

## Universal Polling Rules

**All agents follow these rules:**

1. **Poll every 30 seconds** when idle
2. **Never stop polling** - this is an infinite loop
3. **Update heartbeat** on every poll cycle
4. **Continue polling** after completing any action

## Exit Conditions

Only these conditions allow agents to exit:

| Condition | Action |
|-----------|--------|
| Coordinator status is "completed" | Exit gracefully |
| Coordinator status is "terminated" | Exit gracefully |
| Coordinator status is "max_iterations_reached" | Exit gracefully |
| Detected `<promise>RALPH_COMPLETE</promise>` | Exit gracefully |

**No other exit conditions exist.** If you complete a task, poll again. If you have no work, poll again.

## Idle Behavior

When you have **no active task**:

1. **Update your heartbeat** with current timestamp
2. **Wait 30 seconds**
3. **Poll again** - read state file to check for work
4. **Repeat forever**

```
FOREVER:
  UPDATE heartbeat
  WAIT 30 seconds
  READ coordinator-state.json
  CHECK for work/exit conditions
  REPEAT
```

## Working Behavior

When you are **actively working**:

1. **Set status to "working"** and update heartbeat
2. **Focus on the task** - no polling needed during work
3. **Update heartbeat every 60 seconds** while working (quick timestamp update)
4. **When complete**, set status to "idle", update heartbeat, **then poll again**

## Quick Heartbeat Update

```json
{
  "agents": {
    "{{AGENT_TYPE}}": {
      "lastSeen": "2026-01-19T12:30:45Z",  // Update to NOW
      "status": "working"  // Keep current status
    }
  }
}
```

## Critical Reminders

- ✅ Poll every 30 seconds when idle
- ✅ Update heartbeat on every poll
- ✅ After ANY action → POLL AGAIN
- ❌ NO natural exit except completion/termination
- ❌ DON'T stop polling just because you're idle
- ❌ DON'T assume work is finished without checking state

## Agent-Specific Polling Triggers

| Agent | Poll For | Action When Found |
|-------|---------|-------------------|
| PM | Incomplete PRD items | Assign next task |
| Developer | `assignedAgent: "developer"` | Implement feature |
| QA | `status: "ready_for_qa"` | Validate work |

## Reference

- [ralph-core.md](ralph-core.md) — Session structure and heartbeat format
- [polling-loop.md](polling-loop.md) — Main polling loop implementation
