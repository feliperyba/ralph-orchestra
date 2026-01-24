# Orchestration Modes

Ralph Orchestra supports **four orchestration modes** for different use cases.

## Mode Comparison

| Mode             | Agents Running | Communication                | Token Usage | Parallelism | Best For                  |
| ---------------- | -------------- | ---------------------------- | ----------- | ----------- | ------------------------- |
| **Event-Driven** | 5 simultaneous | Named pipes + message queues | Medium      | Full        | Production, complex tasks |
| **Sequential**   | 1 at a time    | Handoff files                | Lowest      | None        | Learning, debugging       |
| **Polling**      | 5 simultaneous | Polling (30s)                | High        | Full        | Legacy, simple projects   |
| **HITL**         | 1 at a time    | User-controlled              | Lowest      | None        | Learning before going AFK |

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
   │ (inbox) │            │ (pipes) │            │ (pipes) │
   └────┬────┘            └────┬────┘            └────┬────┘
        │                      │                      │
        │                      └──────────┬───────────┤
        │                                 │         │
        ▼                                 ▼         ▼
   ┌──────────┐                   ┌───────────┐      ┌──────────┐
   │   Game   │                   │   Tech     │      │          │
   │ Designer │◄──────────────────►│   Artist   │      │ (All via │
   │ (pipes)  │                   │  (pipes)   │      │  pipes)  │
   └──────────┘                   └────────────┘      └──────────┘
```

**Additional Agents** participate via messages:

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

### Named Pipe Messaging (Phase 2)

Event-Driven mode uses named pipes for ultra-fast communication:

- **< 10ms** message delivery (vs 2-5 seconds with file queue)
- Watchdog creates named pipes for each agent on startup
- Workers (Developer, QA, Tech Artist, Game Designer) connect to pipes
- PM (coordinator) continues with file queue for simplicity
- Automatic fallback to file queue if pipes unavailable

### Message Types

| Type                     | From → To                      | Purpose                        |
| ------------------------ | ------------------------------ | ------------------------------ |
| `task_assign`            | PM → Developer/TechArtist      | Assign task for implementation |
| `validation_request`     | Developer/TechArtist → QA      | Request validation             |
| `asset_ready`            | Tech Artist → QA               | Assets ready for validation    |
| `bug_report`             | QA → PM                        | Report bugs with priority      |
| `task_complete`          | QA → PM                        | Confirm task passed            |
| `question` / `answer`    | Any ↔ Any                      | Q&A between agents             |
| `gdd_ready`              | Game Designer → PM             | GDD is ready                   |
| `gdd_update`             | Game Designer → PM             | GDD has been updated           |
| `design_question`        | Any → Game Designer            | Ask design question            |
| `design_answer`          | Game Designer → Any            | Answer design question         |
| `playtest_request`       | PM → Game Designer             | Request playtest               |
| `playtest_report`        | Game Designer → PM             | Playtest results               |
| `asset_assign`           | PM → Tech Artist               | Assign visual task             |
| `asset_question`         | Tech Artist → PM/Game Designer | Clarification request          |
| `shader_request`         | Tech Artist → PM               | Propose shader work            |
| `reference_request`      | Tech Artist → Game Designer    | Request artistic references    |
| `message_ack`            | Worker → PM                    | Acknowledge message receipt    |
| `retrospective_initiate` | PM → All Workers               | Start retrospective            |
| `test_plan_request`      | PM → QA/GameDesigner           | Request test plan input        |

### Message Acknowledgment Protocol

**ALL worker agents MUST acknowledge received messages immediately.**

When a worker (Developer, QA, Tech Artist, or Game Designer) receives any message from PM:

1. **Send `message_ack` to PM immediately** (before processing)
2. **Process the message**
3. **Remove message from inbox**

This protocol:

- Prevents duplicate message delivery
- Enables PM to track which messages were actually received
- Allows deadlock recovery after agent crashes
- Provides delivery confirmation for reliable messaging

**Example acknowledgment payload:**

```json
{
  "originalMessageId": "msg-xxx",
  "originalMessageType": "task_assign",
  "acknowledgedAt": "2024-01-20T12:00:00Z",
  "status": "received"
}
```

### Benefits

- **Parallel execution** - All agents work simultaneously
- **Named pipe speed** - < 10ms message delivery
- **Message history** - Full audit trail in `.claude/session/messages/archive/`
- **PM prioritization** - Bug reports go to PM for priority decisions
- **Git worktrees** - Developer and Tech Artist can work in parallel without conflicts

### When to Use

- Production autonomous runs
- Complex tasks requiring agent collaboration
- When you need message history for debugging
- When performance is critical

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

### When to Use

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

| Factor           | Event-Driven       | Sequential          |
| ---------------- | ------------------ | ------------------- |
| Token efficiency | Medium             | Best (~70% savings) |
| Parallel speed   | Best               | N/A                 |
| Debug complexity | Medium             | Low                 |
| Message overhead | Low (< 10ms)       | None                |
| Message delivery | Named pipes + file | Handoff files       |

For most production use cases, **Event-Driven mode** provides the best balance of performance, debuggability, and features.
