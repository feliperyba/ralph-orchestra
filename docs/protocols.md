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

The **event-driven protocol** enables parallel agent coordination using named pipes for ultra-fast messaging (< 10ms delivery).

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    WATCHDOG (Message Broker)                     │
│  - Routes messages between agents                                │
│  - Monitors agent health                                         │
│  - Restarts agents with messages                                 │
│  - Manages session lifecycle                                     │
└─────────────────────────────────────────────────────────────────┘
           │                    │                    │
           ▼                    ▼                    ▼
    ┌───────────┐        ┌───────────┐        ┌───────────┐
    │    PM     │◄──────►│ Developer │◄──────►│    QA     │
    │(Coordinator)       │ (Worker)  │        │ (Worker)  │
    └───────────┘        └───────────┘        └───────────┘
```

### Worker Pool Model

**CRITICAL:** In event-driven mode, agents do NOT run continuously.

**Pattern:**
```
1. Watchdog spawns agent (with or without pending messages)
2. Agent processes messages / does work
3. Agent sends completion/status message
4. Agent EXITS
5. Watchdog spawns agent again when needed
```

### Message Queue Structure

```
.claude/session/messages/
├── pm/                 # PM's inbox
├── developer/          # Developer's inbox
├── qa/                 # QA's inbox
├── gamedesigner/       # Game Designer's inbox
├── techartist/         # Tech Artist's inbox
└── watchdog/           # Watchdog's inbox
```

### Message Format

```json
{
  "id": "msg-developer-20240120-120000-001",
  "from": "pm",
  "to": "developer",
  "type": "task_assign",
  "priority": "normal",
  "payload": { "taskId": "feat-001" },
  "timestamp": "2024-01-20T12:00:00.000Z",
  "status": "pending"
}
```

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | `msg-{recipient_agent}-{timestamp}-{seq}` |
| `from` | string | Sender agent |
| `to` | string | Recipient agent |
| `type` | string | Message type |
| `priority` | string | `low`, `normal`, `high`, `urgent` |
| `payload` | object | Type-specific data |
| `timestamp` | string | ISO 8601 UTC |
| `status` | string | `pending`, `processing`, `completed` |

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

## Message Type Reference

Common message types across all protocols:

| Type | From → To | Purpose |
|------|-----------|---------|
| `task_assign` | PM → Worker | Assign task for implementation |
| `validation_request` | Worker → QA | Request validation |
| `bug_report` | QA → PM | Report bugs with priority |
| `task_complete` | QA → PM | Confirm task passed |
| `question` / `answer` | Any ↔ Any | Q&A between agents |
| `design_question` | Any → Game Designer | Ask design question |
| `design_answer` | Game Designer → Any | Answer design question |
| `handoff` | Any → Watchdog | Signal agent transition |
| `status_update` | Worker → PM/Watchdog | Report progress |

## Priority Levels

| Priority | Description | Use Case |
|----------|-------------|----------|
| `urgent` | Immediate attention | Critical bugs, shutdown commands |
| `high` | Needs attention | Questions, bug reports |
| `normal` | Standard | Task assignments, validation requests |
| `low` | Status updates | Periodic status reports |

## See Also

- [Architecture](./architecture.md) - System architecture overview
- [Configuration](./configuration.md) - Agent settings and PRD format
- [Getting Started](./getting-started.md) - Installation and first run
- [Extending](./extending.md) - Adding custom agents and skills
