---
name: shared-ralph-worker-gamedesigner
description: Shared Game Designer worker orchestration - event-driven messaging, worker pool model, and agent lifecycle
category: shared
model: inherit
user-invocable: false
---

# Ralph Worker - Game Designer Agent

Shared orchestration layer for Game Designer worker in Ralph Wiggum event-driven system.

> **NOTE:** This file contains ONLY orchestration-specific content. For design workflows, see `gamedesigner-workflow` skill. For agent reference, see `agents/gamedesigner/AGENT.md`.

## Quick Start

```powershell
# Source the runtime library
. "$PSScriptRoot\..\..\scripts\core\agent-runtime.ps1"

# Connect to watchdog
Connect-ToWatchdog -AgentName "gamedesigner" -SessionDir ".\.claude\session"

# Enter message processing loop
Enter-AgentLoop -MessageHandler {
    param($Message)
    # ... handle messages ...
}
```

## Worker Pool Model

Game Designer operates in a **worker pool model**:

```
┌─────────────────────────────────────────────────────────────────┐
│  1. Watchdog spawns worker for task                              │
│  2. Worker connects via named pipe                               │
│  3. Worker enters message loop                                   │
│  4. Worker processes messages to completion                      │
│  5. Worker sends result message                                  │
│  6. Worker exits (NOT a loop - single task lifecycle)            │
│  7. Watchdog spawns new worker when next task arrives            │
└─────────────────────────────────────────────────────────────────┘
```

**Key characteristic:** Each worker instance processes ONE task cycle, then exits. The watchdog is responsible for spawning new workers.

## Key Differences from Other Workers

| Aspect         | Developer      | QA                | Game Designer              |
| -------------- | -------------- | ----------------- | -------------------------- |
| Primary Output | Code           | Test results      | Design documents           |
| Validation     | Feedback loops  | Browser tests     | Playtest via Playwright    |
| Collaboration  | PM/QA          | PM/Developer      | PM/Developer/QA            |
| Work Style     | Task-driven     | Validation-driven | Creative + validation      |
| Self-Iteration | No             | No                | **Yes** (can message self) |

## Message Handling (V2)

### Connect and Enter Message Loop

```powershell
Connect-ToWatchdog -AgentName "gamedesigner" -SessionDir ".\.claude\session"

Enter-AgentLoop -MessageHandler {
    param($Message)

    switch ($Message.type) {
        "WorkAssign" {
            # PM assigned a task
            $taskId = $Message.payload.taskId
            # ... handle task ...
        }
        "Query" {
            # Someone is asking a design question
            Send-Message -To $Message.from -Type "Response" -Payload @{
                inReplyTo = $Message.id
                answer = "Design answer here"
            }
        }
        "Retrospective" {
            # PM triggered retrospective
            # ... participate in retrospective ...
        }
    }
}
```

### V2 Message Types

| Type                  | From      | Action                               |
| --------------------- | --------- | ------------------------------------ |
| `WorkAssign`          | pm        | Process assigned task                |
| `design_question`     | pm/dev/qa | Research and answer                   |
| `reference_request`   | techartist| Provide artistic references          |
| `playtest_request`    | pm        | Run playtest via Playwright MCP       |
| `acceptance_criteria` | pm        | Define success criteria               |
| `Retrospective`       | pm        | Contribute design perspective         |
| `System` (shutdown)   | watchdog  | Exit gracefully                       |

## Sending Messages

```powershell
# Send to PM
Send-Message -To "pm" -Type "gdd_ready" -Payload @{
    gddPath = "docs/design/gdd.md"
    summary = "Initial GDD complete"
}

# Send to Tech Artist
Send-Message -To "techartist" -Type "visual_reference" -Payload @{
    feature = "Character model"
    references = @("url1", "url2")
}

# Send to self (self-iteration allowed)
Send-Message -To "gamedesigner" -Type "design_iteration" -Payload @{
    topic = "combat_balance"
    question = "Should we add critical hits?"
}
```

## Self-Iteration Pattern

Game Designer is **unique** in that it can message itself for independent creative work:

```powershell
# Example: Iterate on combat mechanics
Send-Message -From "gamedesigner" -To "gamedesigner" -Type "design_iteration" -Payload @{
    topic = "combat_balance"
    currentDraft = "Damage is 10-20 based on weapon tier"
    question = "Should we add critical hits?"
    personas = @("Marcus Chen", "Viktor Volkov")
}
```

This enables:
- **Independent creative work** - Don't wait for other agents
- **Parallel processing** - Work while Developer codes, QA tests
- **Thermite sessions** - Run internal design discussions
- **Iterative refinement** - Polish GDD before sharing

## Exit Conditions

**Worker lifecycle: Complete work → send message → exit**

| Condition              | Action                           |
| ---------------------- | -------------------------------- |
| GDD ready              | Send `gdd_ready` → exit          |
| Question answered      | Send `design_answer` → exit      |
| Playtest complete      | Send `playtest_report` → exit    |
| Retrospective done     | Write contribution → exit        |
| Need PM input          | Send `question` → exit           |
| Coordinator completed  | Exit gracefully                  |

**⚠️ IMPORTANT:** Always update `prd.json.agents.gamedesigner` before exiting:
```json
{
  "status": "idle",
  "currentTaskId": null,
  "lastSeen": "{UTC-timestamp}"
}
```

## State Files

| File                            | Purpose                          |
| ------------------------------- | -------------------------------- |
| `prd.json.agents.gamedesigner`  | Agent status, current task        |
| `docs/design/*.md`              | All GDD and design artifacts      |
| `.claude/session/gamedesigner-progress.txt` | Work progress log        |

## Related Skills

- `gamedesigner-workflow` - Complete design workflows
- `shared-ralph-core` - Session structure, exit conditions
- `shared-message-handling` - V2 messaging protocol
- `shared-worker-task-memory` - Task memory for retrospectives
- `agents/gamedesigner/AGENT.md` - Quick reference card
