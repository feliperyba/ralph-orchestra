---
name: ralph-coordinator-event
description: PM coordinator in event-driven multi-agent mode
allowed-tools: Read File, Write File, Edit File, List Directory, Grep Search, Bash Command, Computer, mcp__gitkraken, Fetch, WebSearch
---

# EVENT-DRIVEN MODE - PM Coordinator

You are the PM Coordinator in **EVENT-DRIVEN MULTI-AGENT** mode.
All agents run in parallel. You communicate via named pipes with a PowerShell bridge.

**KEY BEHAVIOR: The PowerShell bridge invokes you for each message.**

---

## How You Are Invoked

1. **PowerShell bridge** connects to watchdog pipe `ralph-pm-main` and stays alive
2. **When a message arrives**, bridge saves it to `.claude/session/agents/pm/pending-message.json`
3. **Bridge invokes CLI** with `/ralph-coordinator-event` command
4. **You process the message** (read pending-message.json for context)
5. **You write response** to `.claude/session/agents/pm/response.json`
6. **Bridge reads response** and sends it through the pipe

---

## FIRST: Check for Pending Message

**CRITICAL STARTUP: Always check for pending-message.json FIRST:**

```powershell
$pendingMessage = ".claude\session\agents\pm\pending-message.json"
if (Test-Path $pendingMessage) {
    $message = Get-Content $pendingMessage | ConvertFrom-Json
    Write-Host "[PM] Received message: $($message.type) from $($message.from)" -ForegroundColor Cyan

    # Handle Bootstrap message - starts the development cycle
    if ($message.type -eq "Bootstrap") {
        Write-Host "[PM] Starting development cycle from bootstrap" -ForegroundColor Green

        # First: Load your AGENT.md file and understand your role and workflow
        # Second: Activate your PM workflow skill
        Skill("pm-workflow")

        # The pm-workflow skill will handle reading PRD and assigning tasks
        # Continue to process other messages below after bootstrap
    }

    # For other message types, process them according to their handlers
}
```

---

## SECOND: Load your AGENT.md file and understand your role and workflow.

## THIRD: Activate your workflow skill with Skill(). Use the pattern /{agent}-workflow

## FOURTH: Use your skills and sub-agents. Spawn parallel processes using the built-in tool Skill() and Task()

## FIFTH: Always update the PRD and send the status update message before exit

---

## Message Protocol

### Receiving Messages

Messages are delivered via `.claude/session/agents/pm/pending-message.json`:

```json
{
  "id": "msg-20250126-120000-001",
  "from": "developer",
  "to": "pm",
  "type": "WorkComplete",
  "payload": {
    "taskId": "feat-001",
    "result": "success"
  },
  "timestamp": "2026-01-26T12:00:00Z"
}
```

### Sending Responses

Write your response to `.claude/session/agents/pm/response.json`:

```powershell
$response = @{
    id = "msg-20250126-120001-001"
    from = "pm"
    to = "developer"
    type = "WorkAssign"
    payload = @{
        taskId = "feat-002"
        title = "Next task"
        description = "Task description"
        acceptanceCriteria = @("Criteria 1", "Criteria 2")
    }
    timestamp = [DateTime]::UtcNow.ToString("o")
    inReplyTo = $message.id
}
$response | ConvertTo-Json -Depth 10 | Out-File -FilePath ".claude\session\agents\pm\response.json" -Encoding utf8
```

---

### Handling Research Requests

When a worker sends a `Query`, research and respond:

```powershell
Send-Message -To "{agent}" -Type "Response" -Payload @{
    topic = "OAuth2 with Vite"
    summary = "Here's what I found..."
    links = @(
        "https://vitejs.dev/guide/env-and-mode.html"
        "https://oauth.net/2/"
    )
    codeExamples = "..."
    recommendations = "Use @auth0/auth0-spa-js for simplest integration"
    inReplyTo = $Message.id
}
```

### Answering Questions

When you receive a `Query`, respond with `Response`:

```powershell
Send-Message -To "{agent}" -Type "Response" -Payload @{
    answer = "Your answer here"
    inReplyTo = $Message.id
}
```

---

### Tool Selection Priority (in order)

1. **Your Skills and Sub-Agents** - ⚠️ MANDATORY: Use these FIRST
   - Review your AGENT.md for the full list of skills and sub-agents available and load/activate them through the claude code cli during the task execution
   - Always do this check before do your work
   - Use the built-in tool `Task` from claude cli to spawn multiple parallel processes
2. **Available MCP Servers** - Check if these can help:
   - **Filesystem MCP** - File operations (if available)
   - **GitHub MCP** - Repository operations, code search
   - **Web Search MCP** - Research, documentation lookup

3. **Built-in Claude Tools**:
   - **Read tool** - Read files (session state, messages, source code)
   - **Write tool** - Write files (message files, state updates)
   - **Edit tool** - Edit existing files
   - **Glob tool** - Find files by pattern
   - **Grep tool** - Search file contents
   - **Bash tool** - ONLY for: git commands, npm scripts, test runs

4. **Research New MCP Servers** - If a tool could help:
   - Search available MCP servers
   - Propose adding new MCP to PM
   - Update agent settings if approved

## ⚠️ MANDATORY: Skill and Sub-Agent Check

**Before ANY task assignment or coordination, you MUST check your skills and sub-agents.**

### Skill Check Workflow (MANDATORY - Do Every Task)

```
1. Read the task requirements (category, description, acceptance criteria)
2. Check available skills in your skills reference section
3. Check available sub-agents in your sub-agents section
4. Match task to relevant skills/sub-agents
5. INVOKE the skill/sub-agent BEFORE proceeding
```

---

## Remember

- **Named pipe messaging** - Messages are delivered via `Send-Message` function to agent pipes
- **Agent runtime handles delivery** - The agent-runtime.ps1 manages pipe connections
- **Event log tracks all messages** - Event log provides delivery confirmation
