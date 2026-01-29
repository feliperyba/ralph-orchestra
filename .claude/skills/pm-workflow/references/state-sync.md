# State Synchronization (v2.0)

> v2.0 Architecture: PM maintains DUAL sync - prd.json (PM-ONLY) + agent state files (workers).

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│  PM (reads EVERYTHING)                                      │
│  ├─ prd.json (110KB) - PM ONLY                              │
│  ├─ current-task-pm.json (1KB)                             │
│  ├─ current-task-developer.json (1KB)                      │
│  ├─ current-task-qa.json (1KB)                             │
│  ├─ current-task-techartist.json (1KB)                     │
│  └─ current-task-gamedesigner.json (1KB)                   │
└─────────────────────────────────────────────────────────────┘
         │
         │ Syncs to
         ▼
┌─────────────────────────────────────────────────────────────┐
│  Workers (read ONLY their own state file)                   │
│  ┌─────────────┐  ┌─────────────┐  ┌───────────────┐      │
│  │ Developer   │  │ QA          │  │ Tech Artist   │      │
│  │ reads ONLY  │  │ reads ONLY  │  │ reads ONLY    │      │
│  │ their .json │  │ their .json │  │ their .json   │      │
│  └─────────────┘  └─────────────┘  └───────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## When to Update What

| Event | Update Agent State File | Update prd.json | Why |
|-------|------------------------|----------------|-----|
| **Selecting a task** | N/A | `session.currentTask = {taskId, title, category}` | Workers know what's being worked on |
| **Assigning to worker** | Copy FULL task JSON + update state object | `items[{taskId}].status = "assigned"` + `agents[{agent}].status = "working"` | Worker sees assignment |
| **Worker sends question** | Keep as-is | Update notes, keep status | Track blockers |
| **Worker sends implementation_complete** | Move to completedTasks + clear task fields | `items[{taskId}].status = "awaiting_qa"` + `agents[{agent}].status = "idle"` | QA picks it up |
| **QA validation PASSED** | Move to completedTasks | `items[{taskId}].status = "completed"` + `passes = true` | Triggers retrospective |
| **QA validation FAILED** | Update task JSON with bugs | `items[{taskId}].status = "needs_fixes"` + `passes = false` | Reassign to worker |
| **Self-reporting** | Update Worker Status Summary | `agents.pm.lastSeen = {ISO_TIMESTAMP}` | Watchdog knows you're alive |

## Atomic Update Pattern

After EVERY decision, follow this pattern EXACTLY:

```bash
# 1. Read all agent state files
Read: .claude/session/current-task-developer.json
Read: .claude/session/current-task-qa.json
Read: .claude/session/current-task-techartist.json
Read: .claude/session/current-task-gamedesigner.json

# 2. Update Worker Status Summary in current-task-pm.json
# (table with status, currentTaskId, lastSeen for each agent)

# 3. Update prd.json
Update: prd.json.agents.{agent}.* sections
Update: prd.json.session if needed
Update: prd.json.items[{taskId}] if status changed

# 4. Update your own state
Update: current-task-pm.json state object
Update: prd.json.agents.pm.*
```

## Consequences of Improper Sync

- ❌ Workers don't see their task assignments
- ❌ Agent state files become out of sync with prd.json
- ❌ Watchdog thinks PM crashed
- ❌ Message loop locks occur

**Rule of thumb: If you make a decision, update BOTH agent state files AND prd.json. IMMEDIATELY.**

## State File Locations

| Agent | State File Path |
|-------|-----------------|
| PM | `.claude/session/current-task-pm.json` |
| Developer | `.claude/session/current-task-developer.json` |
| QA | `.claude/session/current-task-qa.json` |
| Tech Artist | `.claude/session/current-task-techartist.json` |
| Game Designer | `.claude/session/current-task-gamedesigner.json` |

## State Object Structure

Each agent state file contains:

```json
{
  "state": {
    "status": "idle" | "working" | "blocked",
    "currentTaskId": "task-id" | null,
    "lastSeen": "ISO_TIMESTAMP"
  },
  "task": {
    "id": "task-id",
    "title": "Task title",
    "description": "...",
    "acceptanceCriteria": [...],
    ...
  },
  "completedTasks": [...]
}
```
