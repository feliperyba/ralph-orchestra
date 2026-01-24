---
name: heartbeat-protocol
description: Heartbeat update protocol for Ralph agents - when/how to update prd.json.agents
category: coordination
version: 2.1
---

# Heartbeat Protocol Skill

> "Your heartbeat proves you're alive - update it or the PM thinks you're dead."

## When to Use This Skill

Use this when you need to update your agent status in prd.json.agents section.

## Quick Start

**Use Read tool to read current state, then Write tool to update:**

```
1. Read: prd.json
2. Update your agent's status and lastSeen fields in agents.{your-agent}
3. Write: prd.json
```

## When to Update

| Situation | Set `status` to | Update `lastSeen` |
|-----------|-----------------|------------------|
| You start working on a task | `"working"` | ✅ Yes, to NOW |
| You finish a task | `"idle"` | ✅ Yes, to NOW |
| You are blocked/waiting for PM | `"awaiting_pm"` | ✅ Yes, to NOW |
| You are idle/monitoring | `"idle"` | ✅ Yes, every 60 seconds |

## Status Values

### For PM Agent

| Status | When to Use |
|--------|------------|
| `"idle"` | No active task, monitoring for work |
| `"facilitating_retrospective"` | Running retrospective |
| `"researching"` | Doing skill improvement research |

### For Developer Agent

| Status | When to Use |
|--------|------------|
| `"idle"` | No task assigned, monitoring |
| `"working"` | Implementing a task |
| `"awaiting_pm"` | Blocked, need clarification |

### For QA Agent

| Status | When to Use |
|--------|------------|
| `"idle"` | No validation task, monitoring |
| `"working"` | Running validation |
| `"awaiting_pm"` | Need test plan or clarification |

### For Tech Artist Agent

| Status | When to Use |
|--------|------------|
| `"idle"` | No task assigned, monitoring |
| `"working"` | Implementing visual task |
| `"awaiting_pm"` | Blocked, need clarification |

### For Game Designer Agent

| Status | When to Use |
|--------|------------|
| `"idle"` | No active task, monitoring |
| `"working"` | Creating GDD, playtesting |
| `"awaiting_pm"` | Need clarification |

## Complete Update Example

### Using Read and Write Tools

**Step 1: Read current state**
```
Read: prd.json
```

**Step 2: Update the file**
```json
{
  "session": {
    "iteration": 1,
    "status": "running"
  },
  "agents": {
    "pm": {
      "status": "idle",
      "lastSeen": "2026-01-22T18:00:00.000Z"
    },
    "developer": {
      "status": "working",
      "currentTaskId": "feat-001",
      "lastSeen": "2026-01-22T18:00:00.000Z"
    }
  }
}
```

**Step 3: Write the updated state**
```
Write: prd.json
```

## Consequences of NOT Updating

❌ **If you don't update your heartbeat:**

- **PM thinks you are disconnected**
- **Tasks won't be assigned**
- **QA won't pick up your completed work**
- **Session stalls indefinitely**

## Update Frequency

| Agent | Frequency | Notes |
|-------|-----------|-------|
| **PM** | Every action | Before each exit |
| **Developer** | Every 60 seconds while working | While implementing |
| **Tech Artist** | Every 60 seconds while working | While implementing |
| **QA** | Every 60 seconds while working | While validating |
| **Game Designer** | Every 60 seconds while working | While designing |

## Anti-Patterns

❌ **DON'T:**
- Go more than 60 seconds without updating while working
- Forget to update `lastSeen` timestamp (use ISO format)
- Set status to a value that doesn't match your actual state
- Update other agents' sections (only update your own)

✅ **DO:**
- Update timestamp in UTC format: `yyyy-MM-ddTHH:mm:ssZ`
- Use Read tool / Write tool for updates
- Update immediately when your status changes
- Only modify your agent's section (`agents.{your-role}`)

## Reference

- [`.claude/skills/ralph-core.md`](ralph-core.md) — Complete session structure
- [`agents/pm/AGENT.md`](../../agents/pm/AGENT.md) — PM specific usage
- [`agents/developer/AGENT.md`](../../agents/developer/AGENT.md) — Developer specific usage
- [`agents/qa/AGENT.md`](../../agents/qa/AGENT.md) — QA specific usage
