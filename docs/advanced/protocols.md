# Ralph Orchestra Protocols

This document provides an overview of the communication and operational protocols used in Ralph Orchestra.

## Overview

Ralph Orchestra uses formal protocols to define how agents communicate and coordinate:

| Protocol | Purpose | Location |
|----------|---------|----------|
| **Event-Driven** | Parallel agent coordination via named pipes | [`.claude/protocols/event-driven.md`](../.claude/protocols/event-driven.md) |
| **Sequential** | Token-efficient handoff-based coordination | [`.claude/protocols/sequential.md`](../.claude/protocols/sequential.md) |
| **Worktree Setup** | Git worktree management for parallel development | [`.claude/protocols/worktree-setup.md`](../.claude/protocols/worktree-setup.md) |

## Protocol Directory

All protocol documentation is stored in `.claude/protocols/`:

```
.claude/protocols/
├── event-driven.md      # Event-driven orchestration protocol
├── sequential.md        # Sequential agent coordination
└── worktree-setup.md    # Git worktree setup protocol
```

## Event-Driven Protocol

The **event-driven protocol** enables parallel agent coordination using Actor Model + Event Sourcing for ultra-fast messaging (< 10ms delivery) with automatic crash recovery.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│              ACTOR SUPERVISOR (Event Sourcing)                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │           EVENT LOG (Append-Only JSONL)                 │   │
│  │  - Single source of truth                               │   │
│  │  - All events persisted                                 │   │
│  │  - State derived by replay                              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  - Auto-restart with exponential backoff                        │
│  - Bidirectional named pipes                                    │
│  - Manages session lifecycle                                    │
└─────────────────────────────────────────────────────────────────┘
           │                    │                    │
           ▼                    ▼                    ▼
    ┌───────────┐        ┌───────────┐        ┌───────────┐
    │    PM     │◄──────►│ Developer │◄──────►│    QA     │
    │  (Pipe)   │        │  (Pipe)   │        │  (Pipe)   │
    └───────────┘        └───────────┘        └───────────┘
```

### Worker Pool Model

**CRITICAL:** In event-driven mode, agents do NOT run continuously.

**Pattern:**
```
1. ActorSupervisor spawns agent via StartActor()
2. Agent connects via agent-runtime.ps1 to named pipe
3. Agent processes messages / does work
4. Agent sends completion/status message
5. Agent EXITS (exit code 0 or 42)
6. ActorSupervisor auto-restarts if crashed (exponential backoff)
```

### Session Structure

```
.claude/session/
├── eventlog.jsonl       # Append-only event log (source of truth)
├── agent-status.json    # Materialized view from event log
├── undelivered.jsonl    # Failed delivery queue (retry)
└── pipes/               # Named pipe endpoints
    ├── ralph-pm-main
    ├── ralph-developer-main
    ├── ralph-qa-main
    └── ...
```

### Message Format

```json
{
  "id": "msg-20250125-120000-001",
  "type": "WorkAssign",
  "from": "pm",
  "to": "developer",
  "timestamp": "2025-01-25T12:00:00Z",
  "payload": {
    "taskId": "feat-001",
    "workType": "implementation",
    "title": "Implement user auth"
  },
  "inReplyTo": "msg-20250125-115500-042"
}
```

**V2 Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | `msg-{yyyyMMdd-HHmmss}-{seq}` |
| `type` | string | V2 message type (12 core types) |
| `from` | string | Sender agent |
| `to` | string | Recipient agent |
| `timestamp` | string | ISO 8601 UTC |
| `payload` | object | Type-specific data |
| `inReplyTo` | string | Optional: Message ID being replied to |

### When to Use Event-Driven

| Scenario | Recommendation |
|----------|----------------|
| Multiple independent tasks | ✅ Use event-driven |
| Need maximum parallelism | ✅ Use event-driven |
| Token budget is limited | ❌ Use sequential instead |
| Simple single-agent workflow | ❌ Use sequential instead |

For complete documentation, see [event-driven.md](../.claude/protocols/event-driven.md).

## Sequential Protocol

The **sequential protocol** enables token-efficient agent coordination using handoff-based messaging.

### Architecture

```
   ┌─────────┐            ┌─────────┐            ┌─────────┐
   │   PM    │ ─handoff─▶ │Developer│ ─handoff─▶│TechArtist│ ─handoff─▶
   │  Agent  │            │  Agent  │            │  Agent   │
   └─────────┘            └─────────┘            └─────────┘
        ▲                                              │
        └──────────────────────────────────────────────┘
                        (one at a time)
```

### Handoff Mechanism

Agents pass control via handoff signals:

1. Current agent completes work
2. Agent writes `handoff-signal.json` with next agent
3. Agent exits
4. Watchdog spawns next agent

### State Files

```
.claude/session/
├── handoff-signal.json      # Current handoff state
├── pending-handoff.json     # Queued handoffs
└── coordinator-state.json   # PM coordination state
```

### When to Use Sequential

| Scenario | Recommendation |
|----------|----------------|
| Token budget is limited | ✅ Use sequential |
| Linear task dependencies | ✅ Use sequential |
| Need maximum speed | ❌ Use event-driven instead |
| Multiple parallel workstreams | ❌ Use event-driven instead |

For complete documentation, see [sequential.md](../.claude/protocols/sequential.md).

## Worktree Setup Protocol

The **worktree setup protocol** enables parallel development without merge conflicts by using Git worktrees.

### How It Works

```
project/
├── .git/
├── src/                    # Main working tree (Developer)
└── worktrees/
    ├── dev-feature-001/    # Developer worktree
    └── ta-visuals-002/     # Tech Artist worktree
```

### Benefits

- **No merge conflicts** - Each agent has isolated workspace
- **Parallel development** - Developer and Tech Artist work simultaneously
- **Independent testing** - Changes tested before merge
- **Clean main branch** - Only merged code reaches main branch

### Worktree Creation

Automatically managed by agents:

```bash
# Developer creates worktree for feature
git worktree add ../worktrees/dev-feature-001 feature/dev-feature-001

# Tech Artist creates worktree for visuals
git worktree add ../worktrees/ta-visuals-002 feature/ta-visuals-002
```

### Worktree Cleanup

After work is complete and merged:

```bash
git worktree remove ../worktrees/dev-feature-001
```

### When to Use Worktrees

| Scenario | Recommendation |
|----------|----------------|
| Developer + Tech Artist parallel work | ✅ Use worktrees |
| Single agent development | ❌ Not needed |
| Shared file modifications | ⚠️ Requires coordination |

For complete documentation, see [worktree-setup.md](../.claude/protocols/worktree-setup.md).

## V2 Message Type Reference

V2 uses 12 core message types (reduced from 47+ V1 types):

| V2 Type | From → To | Purpose |
|---------|-----------|---------|
| `WorkAssign` | PM → Workers | Assign any work (implementation, validation, playtest) |
| `WorkComplete` | Workers → PM | Work completion notification |
| `Query` | Any ↔ Any | Ask questions |
| `Response` | Any ↔ Any | Answer questions |
| `ProblemReport` | QA → PM | Report bugs/issues |
| `ValidationResult` | QA → PM | Validation results (passed/failed) |
| `Retrospective` | PM ↔ Workers | Retrospective events |
| `Playtest` | PM ↔ Game Designer | Playtesting activities |
| `DesignUpdate` | Game Designer → PM | GDD updates, acceptance criteria |
| `ResearchUpdate` | Game Designer → PM | PRD analysis, skill improvements |
| `AgentStatus` | Workers → Watchdog | Agent lifecycle and health |
| `System` | Watchdog → All | Shutdown, errors |

## Priority Levels

| Priority | Description | Use Case |
|----------|-------------|----------|
| `urgent` | Immediate attention | Critical bugs, shutdown commands |
| `high` | Needs attention | Questions, bug reports |
| `normal` | Standard | Task assignments, validation requests |
| `low` | Status updates | Periodic status reports |

## See Also

- [Architecture](../core/architecture.md) - System architecture overview
- [Configuration](../core/configuration.md) - Agent settings and PRD format
- [Getting Started](../quick-start/getting-started.md) - Installation and first run
- [Extending](./extending.md) - Adding custom agents and skills
