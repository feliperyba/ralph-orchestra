# Orchestration Modes

Ralph Orchestra supports **two orchestration modes** for different use cases.

## Mode Comparison

| Mode             | Agents Running | Communication                | Token Usage | Parallelism | Best For                  |
| ---------------- | -------------- | ---------------------------- | ----------- | ----------- | ------------------------- |
| **Event-Driven** | 5 simultaneous | Named pipes + Event Sourcing  | Medium      | Full        | Production, complex tasks |
| **Sequential**   | 1 at a time    | Handoff files                | Lowest      | None        | Learning, debugging       |
| **HITL**         | 1 at a time    | User-controlled              | Lowest      | None        | Learning before going AFK |

---

## Event-Driven Mode (Recommended)

All agents run in parallel with **Actor Model + Event Sourcing** architecture.

### Running Event-Driven Mode

```powershell
.\.claude\scripts\ralph-event-v2-session.ps1 -MaxIterations 200
```

### How It Works

```
┌─────────────────────────────────────────────────────────────────────┐
│              ACTOR SUPERVISOR (Event Sourcing)                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │           EVENT LOG (Append-Only JSONL)                     │   │
│  │  - Single source of truth                                     │   │
│  └─────────────────────────────────────────────────────────────┘   │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        ▼                       ▼                       ▼
   ┌─────────┐            ┌─────────┐            ┌─────────┐
   │   PM    │◄──────────►│Developer│◄──────────►│   QA    │
   │  Pipe   │            │  Pipe   │            │  Pipe   │
   └────┬────┘            └────┬────┘            └────┬────┘
        │                      │                      │
        │                      └──────────┬───────────┤
        │                                 │         │
        ▼                                 ▼         ▼
   ┌──────────┐                   ┌───────────┐      ┌──────────┐
   │   Game   │                   │   Tech     │      │          │
   │ Designer │◄──────────────────►│   Artist   │      │ (All via │
   │  Pipe    │                   │   Pipe     │      │  Pipes)  │
   └──────────┘                   └────────────┘      └──────────┘
```

### Architecture Components

| Component | Purpose |
|----------- |--------- |
| **ActorSupervisor** | Spawns agents, monitors health, auto-restarts crashes |
| **Event Log** | Append-only log of all events (single source of truth) |
| **Event Bus** | Bidirectional named pipes for fast messaging |
| **Agent Runtime** | Standard library for agents to connect |

### Named Pipe Messaging

Event-driven mode uses **bidirectional named pipes** for fast, reliable messaging:

- **< 10ms** message delivery
- ActorSupervisor creates named pipes: `ralph-{agent}-main`
- All agents connect via `agent-runtime.ps1`
- No file-based message queues
- Event-driven operation with automatic crash recovery

### Message Types (12 Core Types)

| Type | Purpose | From → To |
|------|---------|-----------|
| `WorkAssign` | All work assignments | PM → Workers |
| `WorkComplete` | All completions | Workers → PM |
| `Query` | Questions | Any → Any |
| `Response` | Answers | Any → Any |
| `ProblemReport` | Bugs, issues | QA → PM |
| `ValidationResult` | Validation results | QA → PM |
| `Retrospective` | Retrospective events | PM ↔ Workers |
| `Playtest` | Playtesting | PM ↔ Game Designer |
| `DesignUpdate` | Design docs | Game Designer → PM |
| `ResearchUpdate` | Research findings | Game Designer → PM |
| `System` | System events | Watchdog → All |
| `AgentStatus` | Agent lifecycle | Agents → Watchdog |

### Additional Agents

**Tech Artist Agent:**

- Creates visual assets (materials, shaders, VFX, UI polish)
- Works with Game Designer for artistic direction
- Submits assets to QA for validation
- Uses git worktrees for parallel development

**Game Designer Agent:**

- Creates GDD when none exists
- Answers design questions from Developer/QA/TechArtist
- Playtests via Playwright MCP during retrospective
- Uses thermite-design skill for structured design sessions

### Message Acknowledgment Protocol (V2)

V2 uses **pipe-based acknowledgment**:

When an agent receives a message via named pipe:
1. Pipe read confirms delivery (implicit ACK)
2. Agent processes the message
3. Agent sends `Response` if reply is needed

For critical operations requiring explicit confirmation:
- Use `Response` type with `inReplyTo` field
- Set `payload.acknowledges` to original message ID

### V2 Benefits

- **Parallel execution** - All agents work simultaneously
- **Named pipe speed** - < 10ms message delivery
- **Event sourcing** - Complete audit trail in event log
- **Auto-restart** - Crashed agents restarted with exponential backoff
- **Simplified protocol** - 12 message types vs 47+
- **Single source of truth** - Event log for all state

### When to Use Event-Driven V2

- Production autonomous runs
- Complex tasks requiring agent collaboration
- When you need message history for debugging
- When performance is critical
- When crash recovery is important

---

## Sequential Mode

Only one agent runs at a time. A watchdog process orchestrates handoffs.

### Running Sequential Mode

```powershell
.\.claude\scripts\ralph-single-session.ps1
```

### How It Works

```
┌─────────────────────────────────────────────────────────────────────┐
│                         WATCHDOG PROCESS                             │
│                    (Orchestrates agent switching)                    │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
        ▼                       ▼                       ▼
   ┌─────────┐            ┌─────────┐            ┌─────────┐
   │   PM    │ ─handoff─▶ │Developer│ ─handoff─▶ │TechArtist│ ─handoff─▶
   │  Agent  │            │  Agent  │            │  Agent   │
   └─────────┘            └─────────┘            └─────────┘
        ▲                                              │
        └──────────────────────────────────────────────┘
                        handoff (loop)
```

### Handoff Protocol

1. Agent writes to `handoff-signal.json` with target and context
2. Watchdog detects signal, gracefully stops current agent
3. Watchdog writes `pending-handoff.json` with context
4. Watchdog starts target agent, which reads pending context

### Benefits

- **~70% lower token usage** - Only one agent active at a time
- **Simpler debugging** - Clear execution flow, easy to trace
- **No race conditions** - Agents never work simultaneously

### When to Use Sequential

- Learning how Ralph works
- Token-constrained sessions
- When you want predictable, sequential execution

---

## HITL Mode (Human-in-the-Loop)

Run a single iteration with full visibility - ideal for learning.

### Running HITL Mode

```
/ralph-hitl
```

### How It Works

1. You run a single development cycle manually
2. Watch exactly what happens at each step
3. Learn the flow before going AFK
4. Can intervene at any point

### Benefits

- **Full visibility** - See agent reasoning in real-time
- **Learning focused** - Understand before automating
- **Low risk** - Single iteration, easy to stop

### When to Use HITL

- First time using Ralph Orchestra
- Debugging agent behavior
- Testing new skills or configurations
- When you want hands-on control

---

## Mode Selection Guide

```
┌─────────────────────────────────────────────────────────────────────┐
│                     ORCHESTRATION MODE DECISION                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Need parallel execution?                                            │
│     ├── YES → Event-Driven V2 (ralph-event-v2-session.ps1)            │
│     │                                                                │
│     └── NO  → Minimize token usage?                                  │
│               ├── YES → Sequential (ralph-single-session.ps1)       │
│               └── NO  → HITL (/ralph-hitl command)                  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Performance Considerations

| Factor           | Event-Driven V2     | Sequential          |
| ---------------- | -------------------- | ------------------- |
| Token efficiency | Medium               | Best (~70% savings) |
| Parallel speed   | Best                  | N/A                 |
| Debug complexity | Medium                | Low                 |
| Message overhead | Low (< 10ms)          | None                |
| Message delivery | Named pipes only      | Handoff files       |
| Crash recovery    | Automatic (backoff)   | Manual              |
| State persistence  | Event log (append-only) | Multiple files      |

For most production use cases, **Event-Driven V2 mode** provides the best balance of performance, reliability, and features.
