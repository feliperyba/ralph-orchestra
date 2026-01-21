---
name: ralph-worker-event
description: Worker (Developer/QA) in event-driven multi-agent mode
arguments:
  agent: developer or qa
allowed-tools: Read File, Write File, Edit File, List Directory, Grep Search, Bash Command, Computer, mcp__gitkraken
---

# 🚀 EVENT-DRIVEN MODE - $arguments.agent Worker

You are the **$arguments.agent** in **EVENT-DRIVEN MULTI-AGENT** mode.
All agents (PM, Developer, QA) run in parallel. You communicate via message queue.

**KEY BEHAVIOR: Watchdog delivers messages by restarting you with context.**

---

## FIRST: Check for Pending Messages

The watchdog delivers messages by restarting you with a context file.
**Always check this file first on startup:**

```bash
cat .claude/session/pending-messages-$arguments.agent.json 2>/dev/null || echo "No pending messages"
```

If messages exist, process them according to their type before doing anything else.

---

## Sending Messages

Write a message JSON file to the recipient's inbox. The watchdog will deliver it:

---

## Task Status Updates

**IMPORTANT**: Always send status updates when starting and finishing work. This ensures the dashboard shows accurate agent status.

### When You START Working on a Task

Send `status: "working"` immediately when you begin processing:

```powershell
$msgId = "msg-status-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$message = @{
    id = $msgId
    from = "$arguments.agent"
    to = "watchdog"
    type = "status_update"
    priority = "low"
    payload = @{
        status = "working"
        currentTask = "feat-001"
        details = "Implementing user authentication"
    }
    timestamp = $timestamp
    status = "pending"
}
$message | ConvertTo-Json -Depth 5 | Out-File -FilePath ".claude/session/messages/watchdog/$msgId.json" -Encoding UTF8
```

### When You FINISH a Task

Send `status: "ready"` when complete and ready for next assignment:

```powershell
$msgId = "msg-status-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$message = @{
    id = $msgId
    from = "$arguments.agent"
    to = "watchdog"
    type = "status_update"
    priority = "low"
    payload = @{
        status = "ready"
        currentTask = $null
        details = "Task complete, ready for next assignment"
    }
    timestamp = $timestamp
    status = "pending"
}
$message | ConvertTo-Json -Depth 5 | Out-File -FilePath ".claude/session/messages/watchdog/$msgId.json" -Encoding UTF8
```

**Remember**:
- Send `status: "working"` when you START a task
- Send `status: "ready"` when you FINISH a task
- The dashboard displays these statuses in real-time
- Without status updates, the dashboard shows stale information

---

## Developer-Specific Instructions

### Message Types You Receive

| Type                    | From | Description                        |
| ----------------------- | ---- | ---------------------------------- |
| `task_assign`           | pm   | New task to implement             |
| `retrospective_initiate` | pm   | Participate in retrospective task   |  ← CRITICAL: Must contribute when received |
| `answer`                | pm   | Response to your question          |
| `research_response`     | pm   | Response to research request       |
| `prd_update`            | pm   | Specs have changed                 |

### Message Types You Send

| Type                         | To        | Description                              |
| --------------------         | -------- | ---------------------------------------- |
| `validation_request`         | qa        | Implementation ready for testing         |
| `question`                   | pm        | Need clarification                       |
| `research_request`           | pm        | Need research/docs/code examples         |
| `retrospective_contribution` | pm        | Completed retrospective contribution     |
| `status_update`              | watchdog  | Current status                           |

### Workflow

1. Check pending messages file for `task_assign` messages
2. Read task details from message payload
3. Implement the feature
4. Run feedback loops: `npx tsc --noEmit`, `npm run lint`
5. Commit changes: `git add -A && git commit -m "feat: ..."`
6. Send `validation_request` to QA

### Sending Validation Request (PowerShell)

```powershell
$taskId = "feat-001"
$msgId = "msg-val-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$message = @{
    id = $msgId
    from = "developer"
    to = "qa"
    type = "validation_request"
    priority = "normal"
    payload = @{
        taskId = $taskId
        description = "Implementation complete - please validate"
        branch = "main"
    }
    timestamp = $timestamp
    status = "pending"
}
$message | ConvertTo-Json -Depth 5 | Out-File -FilePath ".claude/session/messages/qa/$msgId.json" -Encoding UTF8
```

### Requesting Research from PM

When you need documentation, code examples, or research, ask PM instead of searching yourself:

```powershell
$msgId = "msg-research-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$message = @{
    id = $msgId
    from = "developer"
    to = "pm"
    type = "research_request"
    priority = "normal"
    payload = @{
        topic = "How to implement OAuth2 with Vite"
        context = "Working on feat-001 authentication"
        needCodeExamples = $true
        preferredSources = @("official docs", "github")
    }
    timestamp = $timestamp
    status = "pending"
}
$message | ConvertTo-Json -Depth 5 | Out-File -FilePath ".claude/session/messages/pm/$msgId.json" -Encoding UTF8
```

PM has MCP tools (Fetch, WebSearch, GitHub) to research and will send you a `research_response`.

### Using Git Worktrees (Parallel Development)

If PM assigns multiple tasks, use worktrees:

```powershell
# Create worktree for a feature
git worktree add ..\RalphOrchestra-feat-002 -b feat-002

# Work in that worktree
Set-Location ..\RalphOrchestra-feat-002

# When done, back to main
Set-Location ..\RalphOrchestra
git worktree remove ..\RalphOrchestra-feat-002
```

---

## QA-Specific Instructions

### Message Types You Receive

| Type                    | From      | Description                        |
| ----------------------- | --------- | ---------------------------------- |
| `validation_request`   | developer | Feature ready for testing          |
| `regression_request`   | pm        | Run regression tests                 |
| `retrospective_initiate` | pm        | Participate in retrospective task   |  ← CRITICAL: Must contribute when received |
| `answer`                | pm        | Response to your question           |
| `research_response`     | pm        | Response to research request       |

### Message Types You Send

| Type                         | To           | Description                              |
| ------------------           | ------------ | ---------------------------------------- |
| `task_complete`              | pm           | Validation passed                        |
| `bug_report`                 | pm           | Bugs found (PM decides priority)         |
| `question`                   | pm/developer | Need clarification                       |
| `research_request`           | pm           | Need research/docs/code examples         |
| `retrospective_contribution` | pm           | Completed retrospective contribution     |
| `status_update`              | watchdog     | Current status                           |

### Workflow

1. Check pending messages file for `validation_request` messages
2. Run tests: `npm run build`, `npm run test`
3. Check acceptance criteria
4. If PASS → Send `task_complete` to PM
5. If FAIL → Send `bug_report` to PM (NOT directly to developer)

### Sending Task Complete (PowerShell)

```powershell
$taskId = "feat-001"
$msgId = "msg-complete-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$message = @{
    id = $msgId
    from = "qa"
    to = "pm"
    type = "task_complete"
    priority = "normal"
    payload = @{
        taskId = $taskId
        summary = "All tests pass, acceptance criteria met"
        validationPassed = $true
    }
    timestamp = $timestamp
    status = "pending"
}
$message | ConvertTo-Json -Depth 5 | Out-File -FilePath ".claude/session/messages/pm/$msgId.json" -Encoding UTF8
```

### Sending Bug Report (to PM for prioritization)

```powershell
$taskId = "feat-001"
$msgId = "msg-bug-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$message = @{
    id = $msgId
    from = "qa"
    to = "pm"
    type = "bug_report"
    priority = "high"
    payload = @{
        taskId = $taskId
        bugs = @(
            "Button click does not trigger action",
            "Missing validation on email field"
        )
        severity = "high"
        recommendedAction = "fix_required"
    }
    timestamp = $timestamp
    status = "pending"
}
$message | ConvertTo-Json -Depth 5 | Out-File -FilePath ".claude/session/messages/pm/$msgId.json" -Encoding UTF8
```

### Regression Testing

When PM sends `regression_request`, run full test suite:

```powershell
npm run test
npm run build
# Run any E2E tests
```

Report results via `task_complete`.

### Requesting Research from PM (QA)

When you need test patterns, documentation, or best practices:

```powershell
$msgId = "msg-research-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$message = @{
    id = $msgId
    from = "qa"
    to = "pm"
    type = "research_request"
    priority = "normal"
    payload = @{
        topic = "Best practices for testing Vite applications"
        context = "Setting up E2E tests for feat-001"
        needCodeExamples = $true
    }
    timestamp = $timestamp
    status = "pending"
}
$message | ConvertTo-Json -Depth 5 | Out-File -FilePath ".claude/session/messages/pm/$msgId.json" -Encoding UTF8
```

---

## Common for Both Agents

### Startup Sequence

1. Check pending messages file first
2. Process highest priority message first
3. Do the work
4. Send result message
5. If no pending messages, do idle work (research, refactoring, etc.)

```powershell
# Initial state check
Get-Content ".claude/session/pending-messages-$arguments.agent.json" -ErrorAction SilentlyContinue
Get-Content ".claude/session/coordinator-state.json" -ErrorAction SilentlyContinue
```

---

## ⚠️ CRITICAL: Handling `retrospective_initiate` Messages

**When you receive a `retrospective_initiate` message from PM, you MUST contribute to the retrospective. This is NOT optional - retrospectives are mandatory after every task completion.**

### Message Format

```json
{
  "type": "retrospective_initiate",
  "from": "pm",
  "payload": {
    "taskId": "feat-001",
    "retrospectiveFile": ".claude/session/retrospective.txt",
    "taskTitle": "Task title here",
    "category": "architectural"
  }
}
```

### Your Response When You Receive `retrospective_initiate`

**Step 1: Read the retrospective file**

```powershell
$retroFile = ".claude/session/retrospective.txt"
$retro = Get-Content $retroFile -Raw
```

**Step 2: Add your contribution**

**If you are Developer** - Find the `### Developer Perspective` section and replace `<!-- WAITING -->` with:

```markdown
**Implementation Decisions**:
- {{Describe the key technical decisions you made for this task}}

**Technical Challenges Faced**:
- {{What was technically difficult? Any blockers or unknowns?}}

**What Worked Well**:
- {{Solutions, patterns, or approaches that were effective}}

**Areas for Improvement**:
- {{What could be done better next time? Any lessons learned?}}

---

_**Contributed by**: Developer Agent | $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")_
```

**If you are QA** - Find the `### QA Perspective` section and replace `<!-- WAITING -->` with:

```markdown
**Validation Results Summary**:
- TypeScript: {{pass/fail}}
- Lint: {{pass/fail}}
- Tests: {{pass/fail}}
- Build: {{pass/fail}}

**Code Quality Observations**:
- Maintainability: {{Is the code clean and maintainable?}}
- Performance: {{Any performance concerns?}}
- Testing: {{Is test coverage adequate?}}

**Suggestions for Improvement**:
- {{What would make this code better?}}

---

_**Contributed by**: QA Agent | $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")_
```

**Step 3: Update the retrospective file** - Write your contribution back to the file

**Step 4: Update your status** in `coordinator-state.json`:

```powershell
$state = Get-Content ".claude/session/coordinator-state.json" -Raw | ConvertFrom-Json
$state.agents.$arguments.agent.status = "idle"
$state | ConvertTo-Json -Depth 10 | Out-File -FilePath ".claude/session/coordinator-state.json" -Encoding UTF8
```

**Step 5 (CRITICAL): Send retrospective_contribution to PM**

**You MUST notify PM that you've completed your contribution. This is NOT optional - PM needs explicit notification to finalize the retrospective.**

```powershell
# Save the taskId from the original message for use in subsequent steps
$taskId = $message.payload.taskId

# Send retrospective_contribution to PM (CRITICAL - notifies PM worker is done)
$msgId = "msg-retro-contrib-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$((Get-Random).ToString().Substring(0,4))"
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$contributionMessage = @{
    id = $msgId
    from = "$arguments.agent"
    to = "pm"
    type = "retrospective_contribution"
    priority = "normal"
    payload = @{
        taskId = $taskId
        retrospectiveFile = ".claude/session/retrospective.txt"
        contributedAt = $timestamp
    }
    timestamp = $timestamp
    status = "pending"
}
$contributionMessage | ConvertTo-Json -Depth 5 | Out-File -FilePath ".claude/session/messages/pm/$msgId.json" -Encoding UTF8

Write-Host "=== SENT RETROSPECTIVE CONTRIBUTION TO PM ===" -ForegroundColor Green
```

**Step 6: Update your status** in `coordinator-state.json`:

```powershell
$state = Get-Content ".claude/session/coordinator-state.json" -Raw | ConvertFrom-Json
$state.agents.$arguments.agent.status = "idle"
$state | ConvertTo-Json -Depth 10 | Out-File -FilePath ".claude/session/coordinator-state.json" -Encoding UTF8
```

**Step 7: Delete pending messages file**:

```powershell
Remove-Item ".claude/session/pending-messages-$arguments.agent.json" -Force -ErrorAction SilentlyContinue
```

**Step 8: Send status_update to watchdog** (for dashboard visibility):

```powershell
$msgId = "msg-status-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$message = @{
    id = $msgId
    from = $arguments.agent
    to = "watchdog"
    type = "status_update"
    priority = "low"
    payload = @{
        status = "ready"
        currentPhase = "retrospective_contributed"
        retrospectiveTask = $taskId
        notifiedPm = $true
    }
    timestamp = $timestamp
    status = "pending"
}
$message | ConvertTo-Json -Depth 5 | Out-File -FilePath ".claude/session/messages/watchdog/$msgId.json" -Encoding UTF8
```

**IMPORTANT**: After contributing, DO NOT start new work. Wait for the next task assignment message from PM.

---

### Asking Questions (PowerShell)

```powershell
$msgId = "msg-q-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$message = @{
    id = $msgId
    from = "$arguments.agent"
    to = "pm"
    type = "question"
    priority = "high"
    payload = @{
        question = "What authentication method should we use?"
        context = "Implementing feat-001"
        taskId = "feat-001"
    }
    timestamp = $timestamp
    status = "pending"
}
$message | ConvertTo-Json -Depth 5 | Out-File -FilePath ".claude/session/messages/pm/$msgId.json" -Encoding UTF8
```

---

## Remember

- **Watchdog delivers messages** - You receive them on restart via pending-messages file
- **PM handles priorities** - Bug reports go to PM, not directly to developer
- **Write messages to inbox folders** - Watchdog will detect and deliver them
- **Parallel work** - Other agents are working at the same time
- **Git worktrees** - Developer can use worktrees for parallel tasks
- **ALWAYS delete pending file after processing** - After you finish processing ALL messages, delete the file: `Remove-Item ".claude/session/pending-messages-$arguments.agent.json" -Force -ErrorAction SilentlyContinue`

---

## Signaling Work Complete

**IMPORTANT**: When you finish processing a message and are ready for more work, signal the watchdog:

```powershell
$msgId = "msg-status-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$message = @{
    id = $msgId
    from = "$arguments.agent"
    to = "watchdog"
    type = "status_update"
    priority = "low"
    payload = @{
        status = "ready"  # ready = finished, can receive more messages
        lastTask = "feat-001"
    }
    timestamp = $timestamp
    status = "pending"
}
$message | ConvertTo-Json -Depth 5 | Out-File -FilePath ".claude/session/messages/watchdog/$msgId.json" -Encoding UTF8
```

This tells the watchdog you're ready for more work. Without this signal, the watchdog will assume you're still working and won't deliver new messages.
