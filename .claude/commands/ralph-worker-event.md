---
name: ralph-worker-event
description: Worker (Developer/QA) in event-driven multi-agent mode
arguments:
  agent: developer qa techartist gamedesigner
allowed-tools: Read File, Write File, Edit File, List Directory, Grep Search, Bash Command, Computer, mcp__gitkraken
---

# EVENT-DRIVEN MODE - $arguments.agent Worker

You are the **$arguments.agent** in **EVENT-DRIVEN MULTI-AGENT** mode.
All agents run in parallel. You communicate via message queue.

**KEY BEHAVIOR: Watchdog delivers messages by restarting you with context.**

---

## FIRST: Load your AGENT.md file and understand your role and workflow.

## SECOND: Load your workflow skill - `Skill("{agent}-workflow")` - to see all available capabilities.

## THIRD: Use your skills and sub-agents to research about the task. Check the GDD and internet to find solutions for the problems before acting on them. Spawn parallel sub-agents using the built-in tool Task()

## FORTH: When working with Code Tasks, MUST use the Skill() `worker-worktree`

## FIFTH: Always update the PRD and send the status update message to the watchdog queue before exit

## SIXTH: Check for Pending Messages

The watchdog delivers messages by restarting you with a context file.
**Always check this file first on startup:**

- If you get "No pending messages", double check if you can still find .json files in your inbox. If so, keep the cycle normally and react to them.
- If you have more than 1 message on the pending queue, always solve all of them together, checking if they are still valid or stale. Delete all messages after that.
- If messages exist, process them according to their type before doing anything else.

## Context Window Monitoring (For Big Tasks)

**Step 1: Determine task size**
- Big task: 5+ acceptance criteria, 3+ files, architectural/integration category
- Small task: Single file, bug fix, simple refactor

**Step 2: For big tasks only**
- After every 3-5 significant operations (file write, edit, commit)
- Run `/context` to check token usage
- Calculate: (total_input_tokens + total_output_tokens) / 200,000 = percentage

**Step 3: If >= 70%**
- Write checkpoint to `.claude/session/context-checkpoint-{agent}-{taskId}.json`
- Send context_checkpoint message to watchdog (see format below)
- Exit gracefully

**Context checkpoint message format:**

```json
File: .claude/session/messages/watchdog/msg-watchdog-{timestamp}-{seq}.json
Content:
{
  "id": "msg-watchdog-{timestamp}-{seq}",
  "from": "$arguments.agent",
  "to": "watchdog",
  "type": "context_checkpoint",
  "priority": "high",
  "payload": {
    "reason": "context_limit_approached",
    "contextPercent": 72,
    "taskId": "{taskId}",
    "step": "{current_step}",
    "completedSteps": ["step1", "step2"],
    "remainingSteps": ["step3", "step4"],
    "filesModified": ["path1", "path2"],
    "nextAction": "{what to do next}"
  },
  "timestamp": "{ISO-timestamp}",
  "status": "pending"
}
```

**Step 4: After restart**
- Read checkpoint file from `.claude/session/context-checkpoint-{agent}-{taskId}.json`
- Resume from `nextAction`
- Skip `completedSteps`

---

## Message Processing Idempotency

- Register the messages ids you have processed as soon as you start to work with the related request from the message

**Example workflow:**

1. Check `.claude/session/messages/{agent}/` directory for message files
2. For each message file (format: `msg-{agent}-{yyyyMMdd-HHmmss}-{seq}.json`), process it
3. Delete each message file after processing
4. Send your response/result message

**Note:** If you crash mid-processing, on restart you may see the same message files again. This is expected behavior - simply reprocess and delete the files when done.

---

## Sending Messages

To send a message, use the **Write tool** to create a JSON file at:
`.claude/session/messages/{recipient}/{message-id}.json`

**Message ID format**: `msg-{recipient_agent}-{timestamp}-{seq}`

- `recipient_agent`: The agent receiving the message (pm, developer, qa, etc.)
- `timestamp`: Compact format `yyyyMMdd-HHmmss` (e.g., `20250123-120000`)
- `seq`: 3-digit sequence number (001, 002, etc.) prevents collisions

**Timestamp format**: Use UTC ISO 8601 in JSON: `2026-01-21T12:00:00Z`

**Example:**

```
File: .claude/session/messages/watchdog/msg-watchdog-20250123-120000-001.json
Content:
{
  "id": "msg-watchdog-20250123-120000-001",
  "from": "developer",
  "to": "watchdog",
  "type": "status_update",
  "priority": "low",
  "payload": {
    "status": "working",
    "currentTask": "feat-001",
    "details": "Implementing feature"
  },
  "timestamp": "2026-01-21T12:00:00Z",
  "status": "pending"
}
```

---

## Task Status Updates

**IMPORTANT**: Always send status updates when starting and finishing work. This ensures the dashboard shows accurate agent status.

### When You START Working on a Task

Send `status: "working"` immediately when you begin processing:

```
File: .claude/session/messages/watchdog/msg-watchdog-{timestamp}-{seq}.json
Content:
{
  "id": "msg-watchdog-{timestamp}-{seq}",
  "from": "$arguments.agent",
  "to": "watchdog",
  "type": "status_update",
  "priority": "low",
  "payload": {
    "status": "working",
    "currentTask": "{taskId}",
    "details": "{brief description of what you're doing}"
  },
  "timestamp": "{UTC-timestamp}",
  "status": "pending"
}
```

### When You FINISH a Task

Send `status: "ready"` when complete and ready for next assignment:

```
File: .claude/session/messages/watchdog/msg-watchdog-{timestamp}-{seq}.json
Content:
{
  "id": "msg-watchdog-{timestamp}-{seq}",
  "from": "$arguments.agent",
  "to": "watchdog",
  "type": "status_update",
  "priority": "low",
  "payload": {
    "status": "ready",
    "currentTask": null,
    "details": "Task complete, ready for next assignment"
  },
  "timestamp": "{UTC-timestamp}",
  "status": "pending"
}
```

**Remember**:

- Send `status: "working"` when you START a task
- Send `status: "ready"` when you FINISH a task
- The dashboard displays these statuses in real-time
- Without status updates, the dashboard shows stale information

---

### Sending Bug Report (to PM for prioritization)

```
File: .claude/session/messages/pm/msg-pm-{timestamp}-{seq}.json
Content:
{
  "id": "msg-pm-{timestamp}-{seq}",
  "from": "qa",
  "to": "pm",
  "type": "bug_report",
  "priority": "high",
  "payload": {
    "taskId": "{taskId}",
    "bugs": [
      "Button click does not trigger action",
      "Missing validation on email field"
    ],
    "severity": "high",
    "recommendedAction": "fix_required"
  },
  "timestamp": "{UTC-timestamp}",
  "status": "pending"
}
```

### Requesting Research from PM (QA)

When you need test patterns, documentation, or best practices:

```
File: .claude/session/messages/pm/msg-pm-{timestamp}-{seq}.json
Content:
{
  "id": "msg-pm-{timestamp}-{seq}",
  "from": "qa",
  "to": "pm",
  "type": "research_request",
  "priority": "normal",
  "payload": {
    "topic": "Best practices for testing Vite applications",
    "context": "Setting up E2E tests for feat-001",
    "needCodeExamples": true
  },
  "timestamp": "{UTC-timestamp}",
  "status": "pending"
}
```

---

**Step: Delete pending messages file**

Use the Bash tool:

```bash
rm -f .claude/session/{you}/*.json
```

**Step: Send status_update to watchdog**

```
File: .claude/session/messages/watchdog/msg-watchdog-{timestamp}-{seq}.json
Content:
{
  "id": "msg-watchdog-{timestamp}-{seq}",
  "from": "$arguments.agent",
  "to": "watchdog",
  "type": "status_update",
  "priority": "low",
  "payload": {
    "status": "ready",
    "currentPhase": "retrospective_contributed",
    "retrospectiveTask": "{taskId}",
    "notifiedPm": true
  },
  "timestamp": "{UTC-timestamp}",
  "status": "pending"
}
```

**IMPORTANT**: After contributing, DO NOT start new work. Wait for the next task assignment message from PM.

---

### Asking Questions

```
File: .claude/session/messages/pm/msg-pm-{timestamp}-{seq}.json
Content:
{
  "id": "msg-pm-{timestamp}-{seq}",
  "from": "$arguments.agent",
  "to": "pm",
  "type": "question",
  "priority": "high",
  "payload": {
    "question": "What authentication method should we use?",
    "context": "Implementing feat-001",
    "taskId": "feat-001"
  },
  "timestamp": "{UTC-timestamp}",
  "status": "pending"
}
```

### Tool Selection Priority (in order)

1. **Your Skills and Sub-Agents** - Use these FIRST
   - Review your AGENT.md for full list of skills and sub-agents and load them through the claude code cli
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

## ⚠️ MANDATORY: If you got stuck on some task (the same task gets rejected and returns to you more than twice), remember to use your MCP and Tools to a research about the problem, or ask help for the PM

---

## Remember

- **Watchdog delivers messages** - You receive them on restart via individual message files in `.claude/session/messages/{agent}/`
- **Write messages to inbox folders** - Watchdog will detect and deliver them
- **Parallel work** - Other agents are working at the same time
- **ALWAYS delete message files after processing** - Delete each `msg-{agent}-{timestamp}-{seq}.json` file after processing

---

## Signaling Work Complete

**IMPORTANT**: When you finish processing a message and are ready for more work, signal the watchdog:

```
File: .claude/session/messages/watchdog/msg-watchdog-{timestamp}-{seq}.json
Content:
{
  "id": "msg-watchdog-{timestamp}-{seq}",
  "from": "$arguments.agent",
  "to": "watchdog",
  "type": "status_update",
  "priority": "low",
  "payload": {
    "status": "ready",
    "lastTask": "{taskId}"
  },
  "timestamp": "{UTC-timestamp}",
  "status": "pending"
}
```

This tells the watchdog you're ready for more work. Without this signal, the watchdog will assume you're still working and won't deliver new messages.
