---
name: shared-heartbeat-protocol
description: Heartbeat update protocol for Ralph agents. Use proactively every 30-60 seconds during long operations and when status changes.
category: infrastructure
tags: [heartbeat, status, monitoring, lifecycle]
dependencies: [shared-ralph-core, shared-file-permissions]
---

# Heartbeat Protocol

> "Your heartbeat proves you're alive – update it or PM thinks you're dead."

## When to Use This Skill

Use **proactively**:
- Every 30-60 seconds during long-running operations
- **IMMEDIATELY** when your status changes
- When starting work on a task
- When completing a task

---

## Quick Start

<examples>
Example 1: Update heartbeat when starting work
```json
// prd.json.agents.developer
{
  "status": "working",
  "currentTaskId": "feat-001",
  "lastSeen": "2026-01-23T12:00:00Z"
}
```

Example 2: Update heartbeat when blocked
```json
// prd.json.agents.developer
{
  "status": "awaiting_pm",
  "currentTaskId": "feat-001",
  "lastSeen": "2026-01-23T12:30:00Z"
}
```

Example 3: Idle heartbeat (every 60s)
```json
// prd.json.agents.qa
{
  "status": "idle",
  "lastSeen": "2026-01-23T13:00:00Z"
}
```
</examples>

---

## When to Update

| Situation | Set `status` to | Update `lastSeen` |
|-----------|-----------------|-------------------|
| Start working on task | `"working"` | ✅ Yes, to NOW |
| Finish task | `"idle"` | ✅ Yes, to NOW |
| Blocked/waiting for PM | `"awaiting_pm"` | ✅ Yes, to NOW |
| Idle/monitoring | `"idle"` | ✅ Yes, every 60s |

---

## Status Values

### PM
| Status | When to Use |
|--------|-------------|
| `"idle"` | No active task, monitoring |
| `"facilitating_retrospective"` | Running retrospective |
| `"researching"` | Skill improvement research |

### Workers (Developer, Tech Artist, QA, Game Designer)
| Status | When to Use |
|--------|-------------|
| `"idle"` | No task assigned, monitoring |
| `"working"` | Actively working on task |
| `"awaiting_pm"` | Blocked, need clarification |
| `"awaiting_gd"` | Waiting for Game Designer input |
| `"working_on_retrospective"` | Contributing to retrospective |

---

## Complete Update Example

**Step 1: Read current state**
```
Read prd.json
```

**Step 2: Update the file**
```json
{
  "agents": {
    "developer": {
      "status": "working",
      "currentTaskId": "feat-001",
      "lastSeen": "2026-01-23T12:00:00Z"
    }
  }
}
```

**Step 3: Write the updated state**
```
Write prd.json
```

---

## Update Frequency

| Agent | Frequency | Notes |
|-------|-----------|-------|
| **PM** | Every action | Before each exit |
| **Workers** | Every 60s while working | During implementation |

---

## Consequences of NOT Updating

❌ **If you don't update:**
- PM thinks you're disconnected
- Tasks won't be assigned
- QA won't pick up your completed work
- Session stalls indefinitely

---

## Anti-Patterns

❌ **DON'T**:
- Go more than 60 seconds without updating while working
- Forget to update `lastSeen` timestamp
- Set status that doesn't match actual state
- Update other agents' sections

✅ **DO**:
- Use UTC format: `yyyy-MM-ddTHH:mm:ssZ`
- Update immediately when status changes
- Only modify your agent's section
- Emit heartbeat markers during long operations

---

## Related Skills

| Skill | Purpose |
|-------|---------|
| `shared-ralph-core` | Session structure, status values |
| `shared-file-permissions` | File update permissions |
| `shared-message-handling` | V2 messaging via named pipes |
