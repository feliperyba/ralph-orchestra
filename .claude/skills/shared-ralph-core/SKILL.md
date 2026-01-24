---
name: ralph-core
description: Shared core instructions for all Ralph agents - single source of truth
category: orchestration
---

# Ralph Core Instructions

**This file is the canonical reference for shared Ralph behavior.**
Agent-specific docs (`agents/*/AGENT.md`) should reference these rules, not duplicate them.

---

## Shared Skills Index

The following shared skills contain detailed instructions for all agents:

| Skill | Purpose |
|-------|---------|
| [ralph-event-protocol.md](ralph-event-protocol.md) | Event-driven messaging protocol |
| [context-management.md](context-management.md) | Context window auto-reset procedures |
| [process-lifecycle.md](process-lifecycle.md) | Process lifecycle management, cleanup |
| [file-permissions.md](file-permissions.md) | File read/write permissions |
| [auxiliary-scripts.md](auxiliary-scripts.md) | Script management rules |
| [atomic-updates.md](atomic-updates.md) | File update atomicity patterns |

Agent-specific AGENT.md files should reference these shared skills instead of duplicating content.

---

## AFK Mode Support

Ralph is designed for **fully autonomous operation** (AFK mode). The system will:

1. **Detect idle agents** - If an agent produces no output for `RALPH_IDLE_TIMEOUT` seconds (default: 60s), it is forcibly restarted
2. **Track heartbeats** - External watchdog monitors agent health via heartbeat timestamps
3. **Save work-in-progress** - Before forced restart, current task state is preserved
4. **Auto-resume** - Restarted agents read work-in-progress and continue seamlessly

### Heartbeat Markers

**Agents MUST emit a heartbeat marker during long operations:**

```
[HEARTBEAT] Agent: {{AGENT_TYPE}} | Status: working | Task: {{TASK_ID}}
```

Emit this marker:

- Every 30 seconds during long-running operations
- When starting a new phase of work
- When waiting for external processes (builds, tests)

This prevents the idle detector from killing agents during legitimate work.

---

## Configuration (Environment Variables)

All timing is configurable via environment variables in `.claude/hooks/hooks.json`:

| Variable                   | Default | Description                           |
| -------------------------- | ------- | ------------------------------------- |
| `RALPH_IDLE_TIMEOUT`       | 60      | Seconds of no output before restart   |
| `RALPH_HEARTBEAT_INTERVAL` | 30      | How often to update heartbeat         |
| `RALPH_STALE_THRESHOLD`    | 90      | Seconds before agent considered stale |
| `RALPH_MAX_ITERATIONS`     | 200     | Maximum loop iterations               |
| `RALPH_CONTEXT_THRESHOLD`  | 70      | % context usage triggering reset      |

---

## Unified Polling Interval

**All agents poll every 30 seconds.** No exceptions.

| Agent     | Idle | Working                          |
| --------- | ---- | -------------------------------- |
| PM        | 30s  | 30s                              |
| Developer | 30s  | No polling (focus on work)       |
| QA        | 30s  | No polling (focus on validation) |

---

## Single Source of Truth (prd.json)

**prd.json is the single source of truth for ALL status information.**

### What prd.json Contains

- `agents.{agent}.status` - Each agent's current status
- `agents.{agent}.lastSeen` - ISO timestamp of last update
- `agents.{agent}.currentTaskId` - What task they're working on
- `items[{taskId}].status` - Task status (controlled by PM)
- `items[{taskId}].passes` - Validation result (controlled by PM)

### Ownership

- **Each agent** updates their own `agents.{agent}` entry in prd.json
- **PM** controls `items[{taskId}].status` and `passes`
- **Message system** unchanged - agents continue sending messages for coordination

### Session Directory

Other state files are stored in `.claude/session/`:

```
.claude/session/
├── handoff-log.json           # Task handoff history
├── continue-loop.flag         # Restart signal
├── work-in-progress.json      # Saved state for resume after restart
└── coordinator-progress.txt   # Human-readable log
```

**Note**: ALL session state is now stored in `prd.json.session` and `prd.json.agents.{role}`. Per-agent heartbeat files (agent-pm.json, etc.) are NOT used.

## Heartbeat Format

Each agent MUST update their heartbeat every **30 seconds** (unified interval):

```json
{
  "agents": {
    "{{AGENT_TYPE}}": {
      "lastSeen": "2026-01-19T12:00:00Z",
      "status": "idle|working|waiting"
    }
  }
}
```

## Task Status Flow

**Core Task Flow (during implementation):**

```
pending → assigned → in_progress → awaiting_qa → passed
                                        ↓
                                   needs_fixes
                                        ↓
                                   blocked (after max attempts)
```

**Post-Validation Phased Workflow (after QA validates):**

```
passed → in_retrospective → retrospective_synthesized → playtest_phase → playtest_complete → prd_refinement → task_ready → skill_research → completed
```

---

## Unified Status Values Reference (P1 Fix - Single Source of Truth)

**This is the authoritative reference for ALL status values used in Ralph.**

### Task Status Values (`prd.json.items[{taskId}].status`)

| Status | Used By | Meaning | passes |
|--------|---------|---------|--------|
| `pending` | PM | Task not yet started | false |
| `assigned` | PM | Task assigned to worker, waiting for worker to start | false |
| `in_progress` | Worker (self-report) | Worker actively working on task | false |
| `awaiting_qa` | PM | Worker finished implementation, waiting for QA validation | false |
| `passed` | QA (set), PM (reads) | **QA PASSED validation** - triggers retrospective | true |
| `needs_fixes` | PM (after QA fail) | QA found bugs, task must be reassigned | false |
| `blocked` | PM | Max attempts reached, requires manual escalation | false |
| `in_retrospective` | PM | Worker retrospective phase active | true |
| `retrospective_synthesized` | PM | Worker retrospective complete, committed | true |
| `playtest_phase` | PM | Game Designer playtest active | true |
| `playtest_complete` | PM | Playtest findings reviewed | true |
| `prd_refinement` | PM | PRD reorganization in progress | true |
| `task_ready` | PM | Acceptance criteria received, ready for skill research | true |
| `skill_research` | PM | PM improving ALL agents' skills | true |
| `completed` | PM | All phases complete, task archived | true |

### Agent Status Values (`prd.json.agents.{agent}.status`)

| Status | Meaning | Who Sets |
|--------|---------|----------|
| `idle` | Agent not working on any task | Self/PM |
| `working` | Agent actively working on task | Self |
| `working_on_retrospective` | Agent contributing to retrospective | Self |
| `awaiting_pm` | Worker waiting for PM response | Self |
| `awaiting_gd` | Worker waiting for Game Designer response | Self |
| `waiting` | General waiting state | Self |

**⚠️ IMPORTANT:** When a worker sets `awaiting_*` status, watchdog has 10-minute timeout (configurable via `RALPH_AWAITING_TIMEOUT`) before sending agent_timeout to PM.

### Status Transition Rules

1. **Only PM can set task status** (except `in_progress` which workers self-report)
2. **Only QA can set `passed` status** (PM then transitions to `in_retrospective`)
3. **Only PM can transition to `completed`** (after skill_research phase)
4. **`blocked` is terminal** - requires manual intervention to resolve
5. **All `awaiting_*` agent statuses** have watchdog timeout protection

---

**Phase Descriptions:**

| Status | Description | Who Acts | Exit? |
|--------|-------------|----------|-------|
| `in_retrospective` | Worker retrospective (Developer, Tech Artist, QA only) | Workers contribute, PM synthesizes | Yes |
| `retrospective_synthesized` | Worker retrospective complete, committed | PM sends playtest_session_request | Yes |
| `playtest_phase` | Game Designer playtesting via Playwright MCP | Game Designer validates | Yes |
| `playtest_complete` | Playtest findings reviewed, PRD updated if needed | PM sends prd_analysis_request (optional) | Yes |
| `prd_refinement` | PRD reorganization, task selection | PM + Game Designer collaborate | Yes |
| `task_ready` | Acceptance criteria received from Game Designer | PM proceeds to skill_research | Yes |
| `skill_research` | PM improves ALL agents' skills | PM commits skill improvements | Yes |
| `completed` | All phases complete, task may be archived | PM can now assign next task | - |

**⚠️ CRITICAL:** Each phase ends with an agent exit for context window reset. The watchdog restarts the agent for the next phase.

## Exit Conditions

Only these allow agents to exit:

- Coordinator status is "completed"
- Coordinator status is "terminated"
- Coordinator status is "max_iterations_reached"
- Detected `<promise>RALPH_COMPLETE</promise>`

**Workers MUST check coordinator status on every poll and exit when any exit condition is met.**

---

## File Ownership & Concurrency

**Single-writer principle**: Each file has a primary owner to avoid race conditions.

| File                       | Primary Owner          | Other Agents                                                       |
| -------------------------- | ---------------------- | ------------------------------------------------------------------ |
| `prd.json`                 | PM (session & status)  | Workers may update their own `agents.{role}.*` fields only         |
| `handoff-log.json`         | Any (append-only)      | All agents append handoff entries                                  |
| `coordinator-progress.txt` | PM                     | Workers append retrospective contributions                         |
| `agent-{name}.json`        | Respective agent only  | Others read-only (for heartbeat monitoring)                        |

Session state and agent status are now stored in `prd.json.session` and `prd.json.agents.{agent}`.

**Concurrency rules**:

1. **Read-modify-write atomically** (see atomic update pattern below)
2. **Only update fields you own** – never overwrite another agent's data
3. **Append-only for logs** – never delete or reorder entries
4. **Retry on conflict** – if write fails, re-read and retry once
5. **Use per-agent files** for frequently updated data (heartbeats) to reduce contention

---

## File Locking (CLI Mode)

The CLI scripts use `.lock` files to prevent concurrent writes:

```powershell
# Automatic locking via Update-JsonFile (PowerShell)
Update-JsonFile -FilePath $statePath -AgentName "developer" -UpdateScript {
    param($state)
    $state.currentTask.status = "in_progress"
    return $state
}
```

Lock behavior:

- Creates `{file}.lock` before writing
- Stale locks (>30s) are automatically removed
- Retries on lock contention with exponential backoff
- Use `Invoke-WithFileLock` for custom critical sections

---

## Optimistic Locking (Version-based)

For high-contention files, use version-based updates:

```powershell
Update-JsonFileOptimistic -FilePath $statePath -AgentName "pm" -UpdateScript {
    param($state)
    $state.iteration++
    return $state
}
```

This checks the `version` field before writing and fails if another process modified the file.

---

## Commit Format

```
[ralph] [{{AGENT}}] {{PRD_ID}}: {{Brief description}}

- Change 1
- Change 2

PRD: {{PRD_ID}} | Agent: {{AGENT}} | Iteration: {{N}}
```

## Universal Commit Rule (ALL AGENTS)

**CRITICAL: Every agent MUST commit their file changes.**

Any time an agent makes file changes, those changes MUST be committed with the Ralph format.

**When to Commit:**
- After any file modifications (source files, configs, PRD, docs, session files)
- Before sending completion messages
- After any skill file updates
- After any documentation changes

**No Commit Exceptions:**
- Heartbeat updates (prd.json.agents.{agent}.lastSeen timestamps)
- Temporary/pending message files (deleted after processing)

**Each Agent MUST Commit:**
| Agent | Must Commit These Files |
|-------|------------------------|
| **PM** | `prd.json`, `.claude/session/coordinator-progress.txt`, skill files, retrospective artifacts |
| **Developer** | Source files, tests, own progress files |
| **Tech Artist** | Asset files, visual components, shaders, styles |
| **QA** | `prd.json` (validation fields), bug reports, own progress files |
| **Game Designer** | `docs/design/`, GDD, design artifacts, own progress files |

## Common File Operations

Atomic update pattern:

```bash
# Read
STATE=$(cat file.json)
# Modify
NEW_STATE=$(echo "$STATE" | jq '.field = "value"')
# Write atomically
echo "$NEW_STATE" > file.json.tmp && mv file.json.tmp file.json
```
