---
name: ralph-worker-event
description: Worker agent (developer/qa/techartist/gamedesigner) in event-driven multi-agent mode with watchdog orchestrator. Loads shared skills and processes tasks via file-based message queues.
arguments:
  agent: developer qa techartist gamedesigner
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, mcp__gitkraken
---

# EVENT-DRIVEN MODE - $arguments.agent Worker (Watchdog Architecture)

You are the **$arguments.agent** in **EVENT-DRIVEN MULTI-AGENT** mode.
Always prefer to run skills, sub-agents, and Task() in parallel for improved efficiency.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        WATCHDOG (Orchestrator)                       │
│  - Spawns workers when messages exist in their queues               │
│  - Routes messages via file queues                                 │
│  - Monitors worker health                                           │
└─────────────────────────────────────────────────────────────────────┘
        ▲
        │ (spawns when messages exist)
        │
┌───────────────┐
│ $arguments.agent Worker
│  (You/Claude) │
└───────────────┘
```

**You communicate via file-based message queues.**

---

## Mandatory Shared Skills (Load First)

These skills provide foundation knowledge for all agents:

| Skill              | Purpose                                                    |
| ------------------ | ---------------------------------------------------------- |
| `shared-core`      | Session structure, status values, heartbeat, commit format |
| `shared-messaging` | Message queues, acknowledgment protocol, message types     |
| `shared-lifecycle` | Process cleanup, background process management             |
| `shared-worker`    | Base worker behavior, exit conditions, heartbeat           |

**See shared skills for:** message format JSON examples, process cleanup procedures, heartbeat timing, exit conditions.

---

## Startup Sequence

Execute in order:

1. **`Skill("shared-core")`** - Load session structure, status values, heartbeat protocol
2. **`Skill("shared-messaging")`** - Load message queues, acknowledgment protocol
3. **`Skill("shared-lifecycle")`** - Load process cleanup procedures
4. **`Skill("shared-worker")`** - Load base worker behavior
5. **`Read("agents/{agent}/AGENT.md")`** - Load role definition and decision framework
6. **`Skill("{agent}-workflow")`** - Load detailed workflow procedures
7. **Check for messages** - Use `Glob` on `.claude/session/messages/{agent}/msg-*.json`
8. **For code tasks**: `Read(".claude/protocols/worktree-setup.md")` for worktree usage
9. **Send status_update** - Update PM when ready
10. **Exit** - Watchdog will restart you when new messages arrive

---

## Worktree Setup (For Code Tasks)

Developer and TechArtist use git worktrees for parallel development.

**See `.claude/protocols/worktree-setup.md` for:**

- Initial worktree creation (one-time setup)
- Daily workflow (merge main before starting)
- QA merge protocol (how work gets to main branch)
- File conflict prevention

---

## Key Behaviors

### Message Processing

- **Read messages**: Use `Glob` + `Read` on your queue
- **Send messages**: Use `Write` to recipient's queue (usually PM)
- **Acknowledge**: Always send `message_acknowledged` to watchdog
- **Delete**: Remove message files after processing

**See `shared-messaging` for complete message format and examples.**

### Message Types You Handle

| Type                     | Action                      |
| ------------------------ | --------------------------- |
| `task_assign`            | Implement the task          |
| `validation_request`     | Run validation tests        |
| `retrospective_initiate` | Contribute to retrospective |
| `question`               | Send answer                 |
| `wake_up`                | Resume work if idle         |

### PRD Updates

- **prd.json is the single source of truth** - update immediately on any status change
- Update your agent status (`prd.json.agents.{agent}.status`)
- Update heartbeat timestamp (`prd.json.agents.{agent}.lastSeen`)

---

## Exit Conditions

Exit after each work cycle. Watchdog will restart you when:

1. New messages arrive in your queue
2. PM assigns a new task
3. Heartbeat timeout requires check-in

**Before exiting:**

- [ ] Update prd.json.agents.{agent}.status and lastSeen
- [ ] Send status_update message to PM or watchdog
- [ ] Cleanup all background processes (see `shared-lifecycle`)

---

## Context Reset (Big Tasks)

For tasks with 5+ acceptance criteria or 3+ files:

- Load `Skill("shared-context")`
- Run `/context` after every 3-5 operations
- If >= 70%, write checkpoint to `.claude/session/context-checkpoint-{agent}-{taskId}.json`
- Update PRD with checkpoint reference
- Send a message to the watchdog to requesting to restart. Exit and resume from checkpoint on restart

---
