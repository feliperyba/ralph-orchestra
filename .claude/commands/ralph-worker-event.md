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

## Startup Sequence

Execute in order:

1. **`Skill("shared-core")`** - Load session structure, status values, heartbeat protocol
2. **`Skill("shared-messaging")`** - Load message queues, acknowledgment protocol
3. **`Skill("shared-lifecycle")`** - Load process cleanup procedures
4. **`Skill("shared-worktree")`** - Load detailed information about worktree and branch work
5. **`Read("agents/{agent}/AGENT.md")`** - Load role definition and decision framework
6. **`Skill("{agent}-workflow")`** - Load detailed workflow procedures
7. **Check for messages** - Use `Glob` on `.claude/session/messages/{agent}/msg-*.json`
8. **Send status_update** - Update PM and watchdog when ready

---

## Exit Conditions

Exit after each work cycle. Watchdog will restart you when:

1. New messages arrive in your queue
2. PM assigns a new task
3. Heartbeat timeout requires check-in

**Before exiting:**

- [ ] Update prd.json.agents.{agent}.status and lastSeen
- [ ] Send status_update message to PM
- [ ] Send status_update message to watchdog - MAKE SURE TO SET TO `idle` to not block the pending messages
- [ ] Cleanup all background processes (see `shared-lifecycle`)

---
