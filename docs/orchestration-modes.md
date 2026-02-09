# Orchestration Modes

Ralph Orchestra supports **three orchestration modes** for different use cases.

## Mode Comparison

| Mode             | Agents Running            | Communication   | Token Usage | Parallelism | Best For                  |
| ---------------- | ------------------------- | --------------- | ----------- | ----------- | ------------------------- |
| **Event-Driven** | PM + on-demand workers     | Message queues  | Medium      | Adaptive    | Production, complex tasks |
| **Sequential**   | 1 at a time                | Handoff files   | Lowest      | None        | Token-efficient runs      |
| **HITL**         | 1 at a time                | User-controlled | Lowest      | None        | Learning before going AFK |

---

## Event-Driven Mode (Recommended)

PM starts first. The watchdog launches workers on demand when they have pending messages. Workers are restarted with their pending messages (no polling loops).

### Running Event-Driven Mode

```powershell
.\.claude\scripts\ralph-event-session.ps1
```

### How It Works

```
┌───────────────────────────────────────────────────────────────────────────┐
│                        WATCHDOG (Message Broker)                          │
│                   (Routes messages, monitors health)                      │
└─────────────────────────────────┬─────────────────────────────────────────┘
                                  │
          ┌───────────────────────┼───────────────────────┐
          ▼                       ▼                       ▼
   ┌─────────────┐         ┌─────────────┐         ┌─────────────┐
   │     PM      │◄───────►│  DEVELOPER  │◄───────►│     QA      │
   │   (inbox)   │         │   (inbox)   │         │   (inbox)   │
   └─────────────┘         └─────────────┘         └─────────────┘
                                  │                       │
                                  ▼                       ▼
                           ┌─────────────┐         ┌─────────────┐
                           │GAME DESIGNER│         │ TECH ARTIST │
                           │   (inbox)   │         │   (inbox)   │
                           └─────────────┘         └─────────────┘
```

**Additional Agents** participate via messages:

**Game Designer Agent:**

- Creates GDD when none exists
- Answers design questions from Developer/QA/TechArtist
- Playtests via Playwright MCP during retrospective

**Tech Artist Agent:**

- Creates visual assets (materials, shaders, VFX, UI polish)
- Works with Game Designer for artistic direction
- Submits assets to QA for validation

### Message Types

| Type                      | From → To          | Purpose                          |
| ------------------------- | ------------------ | -------------------------------- |
| `task_assign`             | PM → Developer     | Assign task for implementation   |
| `validation_request`      | Developer → QA     | Request validation               |
| `bug_report`              | QA → PM            | Report bugs with priority        |
| `task_complete`           | QA → PM            | Confirm task passed              |
| `question`                | Varies             | Ask a question                   |
| `answer`                  | Varies             | Answer a question                |
| `research_update`         | Varies             | Share research findings          |
| `regression_request`      | PM → QA            | Request regression testing       |
| `prd_update`              | Varies             | Update PRD/spec details          |
| `status_update`           | Any → Watchdog     | Update agent work status         |
| `priority_review`         | Varies             | Request priority review          |
| `agent_ready`             | Worker → Watchdog  | Agent startup signal             |
| `work_complete`           | Varies             | Signal work completion           |
| `error`                   | Varies             | Report an error                  |
| `shutdown`                | Watchdog → Worker  | Graceful shutdown request        |
| `implementation_complete` | Varies             | Implementation finished          |
| `work_blocked`            | Varies             | Work is blocked                  |
| `task_abandoned`          | Varies             | Task abandoned                   |
| `quality_concern`         | Varies             | Quality concern raised           |
| `retrospective_initiate`  | PM → Any           | Start retrospective              |
| `retrospective_contribution` | Any → PM        | Retrospective input              |
| `research_request`        | Varies             | Request research                 |
| `research_response`       | Varies             | Respond to research request      |
| `prd_reorganized`         | Varies             | PRD reorganized                  |
| `skill_improvements`      | PM → Any           | Share skill improvements         |
| `priority_response`       | PM → Any           | Priority review response         |
| `skill_request`           | Varies             | Request skill update             |
| `gdd_ready`               | Game Designer → PM | GDD is ready                     |
| `gdd_update`              | Game Designer → PM | GDD has been updated             |
| `design_question`         | Any → Game Designer| Ask design question              |
| `design_answer`           | Game Designer → Any| Answer design question           |
| `playtest_request`        | PM → Game Designer | Request playtest                 |
| `playtest_report`         | Game Designer → PM | Playtest results                 |
| `mechanic_proposal`       | Game Designer → PM | Propose a mechanic               |
| `design_guidance`         | Game Designer → Any| Provide design guidance          |
| `design_guidance_request` | Any → Game Designer| Request design guidance          |
| `test_plan_request`       | PM → QA            | Request test plan                |
| `test_plan_contribution`  | QA → PM            | Provide test plan input          |
| `asset_assign`            | PM → Tech Artist   | Assign visual task               |
| `asset_ready`             | Tech Artist → QA   | Assets ready for validation      |
| `asset_question`          | Tech Artist → Varies | Clarification request         |
| `shader_request`          | Tech Artist → PM   | Propose shader work              |
| `reference_request`       | Tech Artist → Game Designer | Request artistic references |

### Benefits

- **Adaptive parallelism** - Workers only run when there is work
- **No polling overhead** - Watchdog delivers messages by restarting workers
- **Idempotent delivery** - Processed message IDs tracked in `.claude/session/message-state.json`
- **PM prioritization** - Bug reports go to PM for priority decisions

### When to Use

- Production autonomous runs
- Complex tasks requiring agent collaboration
- When you want PM-first orchestration with on-demand workers

---

## Sequential Mode (Token-Efficient)

Only one agent runs at a time. A watchdog orchestrates handoffs via signal files.

### Running Sequential Mode

```powershell
.\.claude\scripts\ralph-single-session.ps1
```

### Benefits

- **Lowest token usage** - One agent active at a time
- **Deterministic flow** - Explicit handoffs between agents
- **Simple debugging** - Clear, linear execution

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
