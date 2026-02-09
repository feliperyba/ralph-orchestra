---
name: shared-core
description: Base instructions and guidelines for all agents in the system. This skill provides foundational behaviors and communication protocols that all agents should follow.
allowed-tools: Read File, Write File, Edit File, List Directory, Grep Search, Bash Command, Computer, mcp__gitkraken, Fetch, WebSearch
---

# Shared Core Skill

> "You are an agent utilizing the **Shared Core Skill**, which provides essential instructions and guidelines for all agents in the system."

## IMPORTANT: Use Claude Tools, Not Shell Commands

Instead, use Claude's built-in tools:
- **Read tool** - to read session files, state, messages
- **Write tool** - to write message files, update state
- **Grep tool** - to search code
- **Bash tool** - only for git commands, running tests, builds
- **Fetch tool** - to make HTTP requests
- **MCP Servers** - to interact with MCP services like GitKraken, Playwright, Web search, Vision, etc.

---

## Communication Protocols

There are 2 layers of communication: The **Watchdog** and **Agents Direct Messaging**. 

### FIRST: Check for Pending Messages

The watchdog delivers messages in two ways:

1. **PRIMARY**: Via `--message` CLI argument as a JSON array (`$arguments.message`)
2. **FALLBACK**: Via context file.

**Always check `$arguments.message` first on startup:**
- If `$arguments.message` is present and non-empty, parse it as JSON array of messages
- If `$arguments.message` is empty/missing, read the fallback file:
    Read `.claude/session/pending-messages-$arguments.agent.json` or `.claude/session/messages/$arguments.agent/*.json` to check for pending messages. If the file exists, read and parse it as JSON array of messages. Delete it after processing.

### SECOND: NEVER FORGET TO UPDATE A TASK STATUS AND WAKE UP THE NEEDED AGENTS

You are the glue that keep the development cycle running. You **must update a task status to the next agent** and send a message to watchdog wake them up.

---

## How Message Delivery Works

1. Read `pending-messages-$arguments.agent.json`
2. For each message in the array:
   a. Check if `message.id` exists in `message-state.json` → `processedMessages`
   b. If yes → Skip (already processed)
   c. If no → Process the message
   d. Delete the messages
   e. After processing, the watchdog will automatically mark it as processed

---

## Sending Messages (The Atomic Write Protocol)

To send a message, you must use an **Atomic Write Pattern** to prevent partial reads by the watchdog.

**Protocol:**
1. Generate ID: `msg-{yyyyMMdd-HHmmss}-{random8chars}`
2. Write content to: `.claude/session/messages/{recipient}/{id}.json.tmp`
3. Rename file to: `.claude/session/messages/{recipient}/{id}.json`

**Use the Bash tool for the rename to ensure atomicity.**

### Message Structure

```json
{
  "id": "msg-20260208-140000-a1b2c3d4",
  "from": "$arguments.agent",
  "to": "{recipient}",
  "type": "{message_type}",
  "priority": "normal",
  "payload": { ... },
  "timestamp": "2026-02-08T14:00:00Z",
  "status": "pending"
}
```

### Example: Sending a Status Update

1. Create the content (using Write tool):
   **File:** `.claude/session/messages/watchdog/msg-status-123.json.tmp`
   ```json
   {
     "id": "msg-status-20260208-120000-x9y8z7",
     "from": "developer",
     "to": "watchdog",
     "type": "status_update",
     "priority": "low",
     "payload": {
       "status": "working",
       "currentTask": "feat-001",
       "details": "Implementing feature"
     },
     "timestamp": "2026-02-08T12:00:00Z",
     "status": "pending"
   }
   ```

2. Atomic Rename (using Bash tool):
   ```bash
   mv .claude/session/messages/watchdog/msg-status-123.json.tmp .claude/session/messages/watchdog/msg-status-123.json
   ```

---

## Task Status Updates

**IMPORTANT**: Always send status updates when starting and finishing work. This ensures the dashboard shows accurate agent status.

### When You START Working on a Task

Send `status: "working"` immediately when you begin processing:

**Payload:**
```json
{
  "status": "working",
  "currentTask": "{taskId}",
  "details": "{brief description}"
}
```

### When You FINISH a Task

Send `status: "ready"` when complete and ready for next assignment:

**Payload:**
```json
{
  "status": "ready",
  "currentTask": null,
  "details": "Task complete, ready for next assignment"
}
```

### Standard Message Types

#### 1. Validation Request (Dev -> QA)
**Type:** `validation_request`
**Payload:**
```json
{
  "taskId": "{taskId}",
  "description": "Implementation complete",
  "branch": "main"
}
```

#### 2. Task Complete (QA -> PM)
**Type:** `task_complete`
**Payload:**
```json
{
  "taskId": "{taskId}",
  "summary": "All tests pass",
  "validationPassed": true
}
```

#### 3. Bug Report (QA -> PM)
**Type:** `bug_report`
**Priority:** `high`
**Payload:**
```json
{
  "taskId": "{taskId}",
  "bugs": ["List of bugs found"],
  "severity": "high"
}
```

#### 4. Research Request (Any -> PM)
**Type:** `research_request`
**Payload:**
```json
{
  "topic": "Topic to research",
  "context": "Why I need this",
  "needCodeExamples": true
}
```

#### 5. General Request (Any -> Any)
**Type:** `task_request`
**Payload:**
```json
{
  "topic": "Topic to research",
  "context": "Why I need this",
  "needCodeExamples": true
}
```

---

### Asking Questions

**Type:** `question`
**Payload:**
```json
{
  "question": "What is the requirement for X?",
  "context": "Implementing feat-Y",
  "taskId": "{taskId}"
}
```

## Signaling Work Complete

**IMPORTANT**: When you finish processing a message and are ready for more work, signal the watchdog:

```
File: .claude/session/messages/watchdog/msg-status-{timestamp}.json
Content:
{
  "id": "msg-status-{timestamp}",
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

---

## Universal Commit Rule

**CRITICAL: Every agent MUST commit their file changes.**

Any time an agent makes file changes, those changes MUST be committed with the Ralph format.

**When to Commit:**
- After any file modifications (source files, configs, PRD, docs, session files)
- Before sending completion messages
- After any skill file updates
- After any documentation changes

### Commit Format

```
[ralph] [{{AGENT}}] {{PRD_ID}}: {{Brief description}}

- Change 1
- Change 2

PRD: {{PRD_ID}} | Agent: {{AGENT}} | Iteration: {{N}}
```

---