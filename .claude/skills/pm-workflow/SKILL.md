---
name: pm-workflow
description: Complete PM Coordinator workflow - task assignment, retrospectives, PRD management. Load before starting PM work.
category: pm
user-invocable: true
model: inherit
agent: pm
degrees-of-freedom: medium
---

# PM Coordinator Workflow

> "Load this skill BEFORE starting any PM work."

## Quick Start

1. **Load router**: `Skill("pm-router")`
2. **Read PRD**: `prd.json` + `prd_backlog.json`
3. **Check status**: Review `prd.json.session` phase
4. **Take action**: Based on current state (see Decision Framework)
5. **Update PRD**: After EVERY decision
6. **Exit**: Watchdog will restart when needed

**Critical Rule:** PRD is single source of truth. Update immediately after every decision.

---

## Core Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        PM COORDINATOR FLOW                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────────┐    ┌───────────────┐    ┌───────────────┐          │
│  │ TASK SELECTION│───▶│ TEST PLANNING │───▶│ ASSIGNMENT    │          │
│  │               │    │               │    │               │          │
│  │ • Select task │    │ • Plan tests  │    │ • Send msg    │          │
│  │ • Research    │    │ • Define DoD  │    │ • Update PRD  │          │
│  └───────────────┘    └───────────────┘    └───────┬───────┘          │
│         ▲                                          │                   │
│         │                                          ▼                   │
│         │                                    ┌───────────────┐        │
│         │                                    │ AWAITING_QA   │        │
│         │                                    │ (Worker done) │        │
│         │                                    └───────┬───────┘        │
│         │                                            │                   │
│         │            ┌───────────────┐                │                   │
│         │            │ RETROSPECTIVE │◀───────────────┘ (passed)        │
│         │            │               │                                    │
│         │            │ • Worker retro │     ┌───────────────┐            │
│         │            │ • Playtest     │────▶│ PRD REFINEMENT│            │
│         │            │ • Skill research│    │               │            │
│         │            └───────────────┘    │ • Extract tasks│            │
│         │                                  │ • Prioritize  │            │
│         └──────────────────────────────────┴───────────────┘            │
│                              (next iteration)                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Decision Framework

| Current State       | Action                                      |
| ------------------- | ------------------------------------------- |
| `null`              | `pm-organization-task-selection`            |
| `test_planning`     | `pm-planning-test-planning`                 |
| `assigned`          | Send message, exit                          |
| `awaiting_qa`       | Wait for QA                                 |
| `passed`            | `pm-retrospective-facilitation`             |
| `in_retrospective`  | Wait for contributions                      |
| `retrospective_synthesized` | `pm-retrospective-playtest-session` |
| `playtest_complete` | `pm-organization-prd-reorganization`        |
| `task_ready`        | `pm-improvement-skill-research`             |
| `needs_fixes`       | Reassign to worker                          |
| `completed`         | Select next task                            |

---

## PRD Status Synchronization

**PRD is the SINGLE SOURCE OF TRUTH. Update immediately after every decision.**

| Event | PRD Update |
|-------|------------|
| Select task | `session.currentTask = {taskId, title, category}` |
| Assign worker | `items[taskId].status = "assigned"` + `agents[agent].status = "working"` |
| WorkComplete | `items[taskId].status = "awaiting_qa"` + `agents[agent].status = "idle"` |
| QA passed | `items[taskId].status = "completed"` + `passes = true` |
| QA failed | `items[taskId].status = "needs_fixes"` + `passes = false` |
| Heartbeat | `agents.pm.lastSeen = {timestamp}` |

**Critical:** When worker sends `WorkComplete`, set `awaiting_qa` (NOT `completed`). Only QA can mark complete.

---

## Startup (V2 Event-Driven)

### Connection

V2 uses named pipes. Connection handled automatically by `agent-runtime.ps1`.

### Check Sequence

1. **Check messages** - Received via named pipe
2. **Read PRD** - `prd.json` + `prd_backlog.json`
3. **Validate workers** - See Worker State Validation
4. **Process messages** - Based on current state
5. **Take action** - Use skills/sub-agents
6. **Send status** - Update agent-status.json
7. **Exit** - Watchdog restarts when needed

### Worker State Validation

**In V2, workers may be inactive. PM must validate and wake them.**

| Condition | Action |
|-----------|--------|
| Worker status = "working" AND lastSeen > 15min | Send `WorkAssign` message |
| Worker status = "idle" BUT has assigned task | Send `WorkAssign` message |
| Task status = "needs_fixes" AND no activity | Send `WorkAssign` message |

Check `agent-status.json` and `eventlog.jsonl` to validate worker states.

---

## Message Types (V2)

### From QA

| Type | Action |
|------|--------|
| `ValidationResult` (passed: true) | Trigger retrospective |
| `ValidationResult` (passed: false) | Reassign to worker |
| `ProblemReport` | Reassign to worker |
| `Query` | Research and respond |

### From Workers

| Type | Action |
|------|--------|
| `WorkComplete` | Set `awaiting_qa`, send to QA |
| `Query` | Research and respond |
| `WorkBlocked` | Assess and provide guidance |

### From Game Designer

| Type | Action |
|------|--------|
| `ResearchUpdate` | Review for task selection |
| `DesignUpdate` | Incorporate acceptance criteria |
| `Response` | Process confirmation |

> **See `shared-ralph-event-protocol` for complete message format.**

---

## Retrospective Phases

After QA passes, run phased retrospective (each phase exits for context reset):

```
passed → in_retrospective (pm-retrospective-facilitation)
       → retrospective_synthesized → playtest_phase (pm-retrospective-playtest-session)
       → playtest_complete → prd_refinement (pm-organization-prd-reorganization)
       → task_ready → skill_research (pm-improvement-skill-research)
       → completed
```

| Phase | Skill | Purpose |
|-------|-------|---------|
| Worker Retro | `pm-retrospective-facilitation` | Gather worker feedback |
| Playtest | `pm-retrospective-playtest-session` | Game Designer testing |
| PRD Refinement | `pm-organization-prd-reorganization` | Extract new tasks |
| Skill Research | `pm-improvement-skill-research` | Improve all agents |

---

## Sub-Agent Reference

| Sub-Agent | Model | Purpose |
|-----------|-------|---------|
| `pm-task-researcher` | Haiku | Codebase research before assignment |
| `pm-test-planner` | Inherit | Test planning with QA+GD |
| `pm-retrospective-facilitator` | Inherit | Retrospective orchestration |
| `pm-prd-organizer` | Inherit | PRD reorganization |
| `pm-architecture-validator` | Haiku | Architecture gap detection |
| `pm-skill-researcher` | Haiku | Skill improvement research |

**Invoke:** `Task("sub-agent-name", { prompt: "...", timeout: 300000 })`

---

## Commit Format

```
[ralph] [pm] {TASK_ID}: Brief description

- Change 1
- Change 2

PRD: {TASK_ID} | Agent: pm | Iteration: N
```

---

## Exit Conditions

Exit only when:
- Sent messages and waiting for response
- All tasks pass → `<promise>RALPH_COMPLETE</promise>`
- `maxIterations` reached → Log status report
- `/cancel-ralph` invoked → Terminate gracefully

---

## References

- `pm-router` - Complete skill catalog
- `shared-ralph-core` - Session structure
- `shared-ralph-event-protocol` - V2 messaging
- `docs/powershell/v2-architecture.md` - 🆕 V2 infrastructure docs
- `.claude/scripts/v2-architecture/` - 🆕 Core V2 modules
- `pm-organization-task-selection` - Assignment algorithm
- `pm-retrospective-facilitation` - Retro orchestration |
