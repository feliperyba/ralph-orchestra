# Orchestration Modes

Ralph Orchestra supports **four orchestration modes** for different use cases.

## Mode Comparison

| Mode | Agents Running | Communication | Token Usage | Parallelism | Best For |
|------|----------------|---------------|-------------|-------------|----------|
| **Event-Driven** | 4 simultaneous | Message queues | Medium | Full | Production, complex tasks |
| **Sequential** | 1 at a time | Handoff files | Lowest | None | Learning, debugging |
| **Polling** | 4 simultaneous | Polling (30s) | High | Full | Legacy, simple projects |
| **HITL** | 1 at a time | User-controlled | Lowest | None | Learning before going AFK |

---

## Event-Driven Mode (Recommended)

All agents run in parallel with message-based communication (no polling).

### Running Event-Driven Mode

```powershell
.\.claude\scripts\ralph-event-session.ps1
```

### How It Works

```
┌─────────────────────────────────────────────────────────────────────┐
│                    WATCHDOG (Message Broker)                         │
│              (Routes messages, monitors health)                      │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        ▼                       ▼                       ▼
   ┌─────────┐            ┌─────────┐            ┌─────────┐
   │   PM    │◄──────────►│Developer│◄──────────►│   QA    │
   │ (inbox) │            │ (inbox) │            │ (inbox) │
   └─────────┘            └─────────┘            └─────────┘
        │                      │                      │
        └──────────────────────┼──────────────────────┘
                               ▼
                    ┌──────────────────┐
                    │  Message Queues  │
                    │   (File-based)   │
                    └──────────────────┘
```

**Game Designer Agent** participates via messages:
- Creates GDD when none exists
- Answers design questions from Developer/QA
- Playtests via Playwright MCP during retrospective

### Message Types

| Type | From → To | Purpose |
|------|-----------|---------|
| `task_assign` | PM → Developer | Assign task for implementation |
| `validation_request` | Developer → QA | Request validation |
| `bug_report` | QA → PM | Report bugs with priority |
| `task_complete` | QA → PM | Confirm task passed |
| `question` / `answer` | Any ↔ Any | Q&A between agents |
| `gdd_ready` | Game Designer → PM | GDD is ready |
| `gdd_update` | Game Designer → PM | GDD has been updated |
| `design_question` | Any → Game Designer | Ask design question |
| `design_answer` | Game Designer → Any | Answer design question |
| `playtest_request` | PM → Game Designer | Request playtest |
| `playtest_report` | Game Designer → PM | Playtest results |

### Benefits

- **Parallel execution** - All agents work simultaneously
- **No polling overhead** - Agents work until done, then check messages
- **Message history** - Full audit trail in `.claude/session/messages/archive/`
- **PM prioritization** - Bug reports go to PM for priority decisions

### When to Use

- Production autonomous runs
- Complex tasks requiring agent collaboration
- When you need message history for debugging

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
   │   PM    │ ─handoff─▶ │Developer│ ─handoff─▶ │   QA    │
   │  Agent  │            │  Agent  │            │  Agent  │
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

### When to Use

- Learning how Ralph works
- Token-constrained sessions
- When you want predictable, sequential execution

---

## Polling Mode (Legacy)

All agents run simultaneously, each polling for work every 30s.

### Running Polling Mode

```powershell
.\.claude\scripts\ralph-multi-session.ps1
```

### How It Works

```
┌─────────────────────────────────────────────────────────────────────┐
│                         WATCHDOG PROCESS                             │
│              (Monitors health, restarts crashed agents)              │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        ▼                       ▼                       ▼
   ┌─────────┐            ┌─────────┐            ┌─────────┐
   │   PM    │            │Developer│            │   QA    │
   │ (polls) │            │ (polls) │            │ (polls) │
   └────┬────┘            └────┬────┘            └────┬────┘
        │                      │                      │
        └──────────────────────┼──────────────────────┘
                               ▼
                    ┌──────────────────┐
                    │  Shared State    │
                    │   JSON Files     │
                    └──────────────────┘
```

### Benefits

- **Simple implementation** - Easy to understand
- **Concurrent work** - Agents can work on different tasks simultaneously
- **Established pattern** - Well-tested over time

### When to Use

- Legacy projects already using polling
- Simple projects where message history isn't needed

**Note:** Consider using Event-Driven mode instead for better message handling and debugging.

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

### When to Use

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
│     ├── YES → Need message history/debugging?                        │
│     │          ├── YES → Event-Driven (ralph-event-session.ps1)     │
│     │          └── NO  → Polling (ralph-multi-session.ps1)          │
│     │                                                                │
│     └── NO  → Minimize token usage?                                  │
│               ├── YES → Sequential (ralph-single-session.ps1)       │
│               └── NO  → HITL (/ralph-hitl command)                  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Performance Considerations

| Factor | Event-Driven | Sequential | Polling |
|--------|--------------|------------|---------|
| Token efficiency | Medium | Best (~70% savings) | Poor |
| Parallel speed | Best | N/A | Best |
| Debug complexity | Medium | Low | High |
| Message overhead | Low | None | High (polling) |

For most production use cases, **Event-Driven mode** provides the best balance of performance, debuggability, and features.
