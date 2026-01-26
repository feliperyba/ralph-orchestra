---
name: shared-message-acknowledgment
description: Message acknowledgment protocol for Ralph agents in V2 event-driven mode. Use when sending or receiving messages via named pipes.
category: infrastructure
tags: [messaging, acknowledgment, v2, pipes]
dependencies: [shared-ralph-event-protocol, shared-message-handling]
---

# Message Acknowledgment (V2)

> "Named pipes provide automatic acknowledgment – no separate ACK needed."

## When to Use This Skill

Use **when**:
- Connecting to watchdog via named pipes
- Processing messages in `Enter-AgentLoop`
- Sending messages to other agents

Use **proactively**:
- For critical operations requiring explicit confirmation
- When responding to `Query` messages

---

## Quick Start

<examples>
Example 1: Automatic acknowledgment (default)
```powershell
# Just processing the message acknowledges it
Enter-AgentLoop -MessageHandler {
    param($Message)

    switch ($Message.type) {
        "WorkAssign" {
            # Message is acknowledged by reading from pipe
            # Just process it
            Send-WorkComplete -TaskId $Message.payload.taskId
        }
    }
}
```

Example 2: Explicit acknowledgment for queries
```json
{
  "id": "msg-pm-20250125-120500-003",
  "type": "Response",
  "from": "pm",
  "to": "gamedesigner",
  "payload": {
    "acknowledges": "msg-gamedesigner-20250125-120455-001",
    "originalType": "Query",
    "status": "received"
  },
  "inReplyTo": "msg-gamedesigner-20250125-120455-001"
}
```

Example 3: Agent connection
```powershell
. "$PSScriptRoot\..\..\scripts\agent-runtime.ps1"
Connect-ToWatchdog -AgentName "developer" -SessionDir ".\.claude\session"
Enter-AgentLoop -MessageHandler { ... }
```
</examples>

---

## Automatic Acknowledgment

**IMPORTANT**: V2 uses **bidirectional named pipes**. Acknowledgment is automatic:

1. Pipe connection proves agent is alive
2. Messages are read from pipe (confirming delivery)
3. No separate acknowledgment message needed

---

## Agent Connection

```powershell
# Source runtime library
. "$PSScriptRoot\..\..\scripts\agent-runtime.ps1"

# Connect to watchdog
Connect-ToWatchdog -AgentName "developer" -SessionDir ".\.claude\session"

# Enter message loop
Enter-AgentLoop -MessageHandler {
    param($Message)
    # Process $Message (already acknowledged by pipe read)
}
```

---

## V2 Message Types

| V2 Type | From | To | Purpose |
|---------|------|-----|---------|
| `WorkAssign` | pm | workers | Assign task |
| `WorkComplete` | workers | pm | Task done |
| `WorkBlocked` | workers | pm | Blocked on dependency |
| `ProblemReport` | workers | pm | Bug/blocker found |
| `Query` | any | any | Ask question |
| `Response` | any | any | Answer question |
| `ValidationRequest` | pm | qa | Run validation |
| `ValidationResult` | qa | pm | Validation results |
| `System` | watchdog | all | Shutdown/errors |

---

## Sending Messages (V2)

Use `Send-*` helper functions from `agent-runtime.ps1`:

```powershell
# Work complete
Send-WorkComplete -TaskId "feat-001" -Result "success"

# Query
Send-Message -To "pm" -Type "Query" -Payload @{
    question = "How should I handle this edge case?"
    context = @{ taskId = "feat-001" }
}

# Problem report
Send-ProblemReport -TaskId "feat-001" -ProblemType "bug"
```

---

## Critical ACK Pairs

| Sender → Receiver | Message Type | ACK Required | ACK Type |
|-------------------|--------------|--------------|----------|
| Game Designer → PM | `ResearchUpdate` | Yes | `Response` |
| Game Designer → PM | `DesignUpdate` | Yes | `Response` |
| Worker → PM | `Query` | Yes | `Response` |
| PM → Worker | `Response` (priority) | Optional | `Response` |

---

## V1 → V2 Migration

| V1 Feature | V2 Equivalent |
|------------|---------------|
| `.claude/session/messages/{agent}/` | Named pipe `ralph-{agent}-main` |
| `message-queue.ps1` | `agent-runtime.ps1` |
| `Send-AgentMessage` with `message_ack` | Automatic (pipe connection) |
| Manual acknowledgment | Not needed |

---

## Anti-Patterns

❌ **DON'T**:
- Use file-based message queues
- Send `message_ack` messages (not needed in V2)
- Manually create/delete message files
- Use `message-queue.ps1` functions

✅ **DO**:
- Use `agent-runtime.ps1` for connection
- Use `Enter-AgentLoop` for message processing
- Use `Send-*` functions to send messages
- Let pipe connection handle acknowledgment

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| No messages received | Verify watchdog V2 running, check logs |
| Connection timeout | Check `.claude/session/` exists, verify pipe name |

---

## Related Skills

| Skill | Purpose |
|-------|---------|
| `shared-message-handling` | V2 message delivery |
| `shared-ralph-event-protocol` | Complete V2 protocol |
| `shared-ralph-core` | Session structure |
