---
name: message-handling
description: Pending message delivery and processing for Ralph agents - watchdog restart, message reading
category: coordination
version: 2.0
keywords: [message, delivery, processing, startup, watchdog, queue, inbox, deletion]
---

# Message Handling Skill

> "The watchdog delivers messages by restarting your process - always check for pending messages on startup."

## When to Use This Skill

Use this when you are **any Ralph agent** (PM, Developer, QA) in event-driven mode.

## How Message Delivery Works

**IMPORTANT**: The watchdog delivers messages to you by **restarting your agent process**.

When the watchdog has messages for you, it:

1. Writes individual message files to `.claude/session/messages/{agent}/`
2. Restarts your agent process
3. You must read and process the message files on startup

**Message format:** `msg-{agent}-{yyyyMMdd-HHmmss}-{seq}.json`
- `agent`: Your agent name (pm, developer, qa, techartist, gamedesigner)
- `yyyyMMdd-HHmmss`: Timestamp (e.g., 20250123-120000)
- `seq`: 3-digit sequence number (001, 002, etc.)

## Startup Message Check (CRITICAL)

**On EVERY startup, check for delivered messages:**

```
Check directory: .claude/session/messages/{agent}/
Message pattern: msg-{agent}-*.json
```

**If messages exist:**
1. List all message files in the directory
2. Read each message file
3. Process each message type
4. Delete each processed message file

**If no messages:**
- No messages waiting, continue normal workflow

**Example for PM agent:**
```
Directory: .claude/session/messages/pm/
Files: msg-pm-20250123-120000-001.json, msg-pm-20250123-120500-002.json
```

## Message Types by Agent

### PM Agent Receives

| Type | From | Action Required |
|------|------|-----------------|
| `task_complete` | qa | Trigger retrospective if validationPassed: true |
| `bug_report` | qa | Reassign to worker |
| `question` | developer/qa | Research and respond |
| `work_blocked` | developer/qa | Assess severity, provide guidance |
| `playtest_session_report` | gamedesigner | **NEW: Review playtest findings, update PRD if needed, commit** |
| `acceptance_criteria` | gamedesigner | **NEW: Incorporate into task definition, proceed to skill_research** |
| `prd_analysis_response` | gamedesigner | **NEW: Review recommendations, select next task** |
| `retrospective_contribution` | any | Track for retrospective completion |
| `playtest_report` | gamedesigner | **LEGACY: Use playtest_session_report instead** |
| `success_criteria` | gamedesigner | **LEGACY: Use acceptance_criteria instead** |

### Developer Agent Receives

| Type | From | Action Required |
|------|------|-----------------|
| `task_assign` | pm | Read task, begin implementation |
| `priority_response` | pm | PM answered your question, continue work |
| `retrospective_initiate` | pm | Add contribution to retrospective.txt |
| `bug_report` | qa | Fix bugs, re-submit |

### QA Agent Receives

| Type | From | Action Required |
|------|------|-----------------|
| `validation_request` | pm | Run validation suite |
| `priority_response` | pm | PM answered your question, continue validation |
| `retrospective_initiate` | pm | Add contribution to retrospective.txt |

### Tech Artist Agent Receives

| Type | From | Action Required |
|------|------|-----------------|
| `asset_assign` | pm | Read asset/shader task, begin implementation |
| `priority_response` | pm | PM answered your question, continue work |
| `retrospective_initiate` | pm | Add contribution to retrospective.txt |

### Game Designer Agent Receives

| Type | From | Action Required |
|------|------|-----------------|
| `playtest_session_request` | pm | **NEW: Run Playwright playtest with screenshots, send playtest_session_report** |
| `acceptance_criteria_request` | pm | **NEW: Define success criteria and test plan for next task** |
| `prd_analysis_request` | pm | **NEW: Review retrospective findings, provide task recommendations** |
| `playtest_request` | pm | **LEGACY: Use playtest_session_request instead** |
| `retrospective_contribution_request` | pm | Add contribution to retrospective.txt |
| `success_criteria_request` | pm | **LEGACY: Use acceptance_criteria_request instead** |
| `design_guidance_request` | pm | Provide design input |

## Sending Messages

**To send a message, use the Write tool to create a JSON file:**

```
File: .claude/session/messages/{recipient}/{message-id}.json
```

**Message ID format:** `msg-{recipient_agent}-{timestamp}-{seq}`
- `recipient_agent`: The agent receiving the message (pm, developer, qa, etc.)
- `timestamp`: Compact format `yyyyMMdd-HHmmss` (e.g., `20250123-120000`)
- `seq`: 3-digit sequence number (001, 002, etc.) prevents collisions

**Timestamp format:** UTC ISO 8601 in JSON: `2026-01-22T12:00:00Z`

### Example: Send task assignment

```json
{
  "id": "msg-developer-20250123-120000-001",
  "from": "pm",
  "to": "developer",
  "type": "task_assign",
  "priority": "normal",
  "payload": {
    "taskId": "feat-001",
    "title": "Implement user authentication",
    "description": "See PRD for details",
    "acceptanceCriteria": ["Login works", "Logout works"]
  },
  "timestamp": "2026-01-22T12:00:00.000Z",
  "status": "pending"
}
```

### Example: Send completion message

```json
{
  "id": "msg-pm-20250123-120000-001",
  "from": "developer",
  "to": "pm",
  "type": "task_complete",
  "priority": "normal",
  "payload": {
    "taskId": "feat-001",
    "summary": "Implementation complete",
    "commit": "abc123"
  },
  "timestamp": "2026-01-22T12:30:00.000Z",
  "status": "pending"
}
```

## Message Processing Priority

Process in this order:

| Priority | Message Types | Action |
|----------|---------------|--------|
| URGENT | `work_blocked`, `task_abandoned` | Immediate attention |
| HIGH | `question`, `bug_report` | Respond promptly |
| NORMAL | `task_complete`, `skill_request` | Process in order |
| LOW | `status_update` | Log and continue |

## Individual Message File Format

Each message is stored as its own JSON file:

**File path:** `.claude/session/messages/{recipient}/msg-{recipient}-{timestamp}-{seq}.json`

**Example message file:**
```json
{
  "id": "msg-developer-20250123-120000-001",
  "from": "pm",
  "to": "developer",
  "type": "task_assign",
  "priority": "normal",
  "payload": {
    "taskId": "feat-001",
    "title": "Task Title",
    "description": "Task description here"
  },
  "timestamp": "2026-01-23T12:00:00.000Z",
  "status": "pending"
}
```

**Multiple messages** are represented as multiple files in the directory:
```
.claude/session/messages/developer/
├── msg-developer-20250123-120000-001.json
├── msg-developer-20250123-120500-002.json
└── msg-developer-20250123-121000-003.json
```

## Message Deletion Protocol (CRITICAL)

After processing each message, you **MUST** delete it using the message queue script:

**NOTE: In EVENT-DRIVEN mode, the message queue is PRE-LOADED by the runner script.**

**Recommended: Use Glob/Read tools (simplest):**
```
1. Glob: .claude/session/messages/{agent}/msg-*.json
2. Read each message file
3. Process based on message type
4. Delete: rm .claude/session/messages/{agent}/msg-{id}.json
```

**Alternative: Use pq-* helper functions:**
```bash
source ./.claude/scripts/pwsh-helper.sh
pq-get {agent}      # Get all messages
pq-remove {agent} msg-id  # Delete after processing
```

**Why deletion is required:**
- Prevents duplicate message processing
- Prevents queue bloat
- Prevents watchdog from re-delivering same messages
- Ensures clean message flow

## Troubleshooting

### No pending messages found

If the file doesn't exist:
- No messages waiting for you
- Continue with normal workflow

### Messages not processed

If you exit without processing:
- Messages will remain in the file
- Watchdog will restart you again
- You'll get the same messages

### File corrupted

If JSON is invalid:
- Log error to progress file
- Contact PM for help
- Do NOT modify the file yourself

## Anti-Patterns

❌ **DON'T:**
- Skip checking for messages on startup
- Process messages but forget to delete the individual message files
- Modify message files (only read/delete)
- Use PowerShell scripts for file operations (unless using message-queue.ps1)

✅ **DO:**
- Always check `.claude/session/messages/{agent}/` on startup (before any other work)
- Delete each message file immediately after processing it
- Use Read tool / Write tool for file operations
- Handle unexpected message types gracefully
- Use `message-queue.ps1` script for proper message handling

## Reference

- [`.claude/skills/ralph-core.md`](ralph-core.md) — Session structure
- [`.claude/skills/ralph-event-protocol.md`](ralph-event-protocol.md) — Complete message protocol
- [`.claude/skills/worker-protocol.md`](worker-protocol.md) — Worker pool workflow
