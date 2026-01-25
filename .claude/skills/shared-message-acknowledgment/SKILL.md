---
name: message-acknowledgment
description: Message acknowledgment protocol for worker agents - confirm message receipt to PM
category: coordination
keywords: [ack, acknowledgment, message, confirmation, delivery, protocol]
---

# Message Acknowledgment Protocol Skill

> "Always acknowledge received messages - PM needs confirmation you got them."

**IMPORTANT FOR EVENT-DRIVEN MODE:**
The message queue is PRE-LOADED by the agent runner script. All examples below that show sourcing `message-queue.ps1` can be skipped - the functions are already available.

## When to Use This Skill

Use this EVERY TIME you receive a message from PM. **Acknowledgment is MANDATORY for all message types.**

## Why Acknowledgment Matters

Without acknowledgment:

- PM doesn't know if you received the message
- PM may resend the same message (duplication)
- System can't detect message delivery failures
- Deadlock recovery is impossible

## Quick Start

**CRITICAL**: Send acknowledgment IMMEDIATELY after reading the message, BEFORE processing it.

**NOTE: In EVENT-DRIVEN mode, the message queue is PRE-LOADED. Skip sourcing the script.**

**Recommended: Use Glob/Read tools (simplest):**
```
1. Glob: .claude/session/messages/{agent}/msg-*.json
2. For EACH message file:
   a. Read the file
   b. Send acknowledgment using pq-send
   c. Process the message
   d. Delete the file: rm .claude/session/messages/{agent}/msg-{id}.json
```

**Using pq-* helpers:**
```bash
source ./.claude/scripts/pwsh-helper.sh

# Get messages
pq-get {agent}

# Send acknowledgment
pq-send {agent} pm message_ack '{"originalMessageId":"msg-id","originalMessageType":"task_assign","acknowledgedAt":"2026-01-25T00:00:00Z","status":"received"}'

# Remove after processing
pq-remove {agent} msg-id
```

## Acknowledgment Message Format

| Field                         | Value              | Description                                 |
| ----------------------------- | ------------------ | ------------------------------------------- |
| `from`                        | Your agent name    | `developer`, `qa`, or `gamedesigner`        |
| `to`                          | `pm`               | Always send to PM                           |
| `type`                        | `message_ack`      | Fixed message type                          |
| `priority`                    | `normal`           | Standard priority                           |
| `payload.originalMessageId`   | `$msg.id`          | The ID of the message you're acknowledging  |
| `payload.originalMessageType` | `$msg.type`        | The type of message you received            |
| `payload.acknowledgedAt`      | ISO 8601 timestamp | When you received it                        |
| `payload.status`              | `received`         | Confirms receipt (processing happens after) |

## Complete Example

### Developer Agent

```powershell
# From Bash: powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ". '.\.claude\scripts\message-queue.ps1'"
# From PowerShell: . .\.claude\scripts\message-queue.ps1

# Messages are in: .claude/session/messages/developer/
# Format: msg-developer-{yyyyMMdd-HHmmss}-{seq}.json
$messageDir = ".claude/session/messages/developer"
if (Test-Path $messageDir) {
    $messageFiles = Get-ChildItem $messageDir -Filter "msg-developer-*.json" | Sort-Object Name

    foreach ($file in $messageFiles) {
        $msg = Get-Content $file.FullName -Raw | ConvertFrom-Json

        # ACKNOWLEDGE FIRST
        Send-AgentMessage -From "developer" -To "pm" -Type "message_ack" -Payload @{
            originalMessageId = $msg.id
            originalMessageType = $msg.type
            acknowledgedAt = (Get-Date).ToUniversalTime().ToString("o")
            status = "received"
        } -Priority "normal"

        # THEN PROCESS
        switch ($msg.type) {
            "task_assign" {
                # Read task details
                $taskId = $msg.payload.taskId
                Write-Host "[DEV] Received task assignment: $taskId"

                # Update status to working
                $prd = Get-Content "prd.json" -Raw | ConvertFrom-Json
                $prd.agents.developer.status = "working"
                $prd.agents.developer.lastSeen = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
                $prd.agents.developer.currentTask = $taskId
                $prd | ConvertTo-Json -Depth 10 | Set-Content "prd.json"

                # Implementation happens here...
            }

            "priority_response" {
                # PM answered your question
                Write-Host "[DEV] Received PM response: $($msg.payload.decision)"
            }

            "design_answer" {
                # Game Designer answered design question
                Write-Host "[DEV] Received design answer from GD"
            }
        }

        # Remove processed message
        Remove-AgentMessage -Agent "developer" -MessageId $msg.id
    }
}
```

### QA Agent

```powershell
# From Bash: powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ". '.\.claude\scripts\message-queue.ps1'"
# From PowerShell: . .\.claude\scripts\message-queue.ps1

# Messages are in: .claude/session/messages/qa/
# Format: msg-qa-{yyyyMMdd-HHmmss}-{seq}.json
$messageDir = ".claude/session/messages/qa"
if (Test-Path $messageDir) {
    $messageFiles = Get-ChildItem $messageDir -Filter "msg-qa-*.json" | Sort-Object Name

    foreach ($file in $messageFiles) {
        $msg = Get-Content $file.FullName -Raw | ConvertFrom-Json

        # ACKNOWLEDGE FIRST
        Send-AgentMessage -From "qa" -To "pm" -Type "message_ack" -Payload @{
            originalMessageId = $msg.id
            originalMessageType = $msg.type
            acknowledgedAt = (Get-Date).ToUniversalTime().ToString("o")
            status = "received"
        } -Priority "normal"

        # THEN PROCESS
        switch ($msg.type) {
            "validation_request" {
                $taskId = $msg.payload.taskId
                Write-Host "[QA] Starting validation for: $taskId"

                # Validation happens here...
            }

            "test_plan_request" {
                # PM wants test plan input
                $testPlan = @{
                    taskId = $msg.payload.taskId
                    testCases = @()
                    edgeCases = @()
                    validationApproach = @{
                        unit = @()
                        integration = @()
                        e2e = @()
                        manual = @()
                    }
                }

                Send-AgentMessage -From "qa" -To "pm" -Type "test_plan_contribution" -Payload $testPlan
            }
        }

        Remove-AgentMessage -Agent "qa" -MessageId $msg.id
    }
}
```

### Game Designer Agent

```powershell
# From Bash: powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ". '.\.claude\scripts\message-queue.ps1'"
# From PowerShell: . .\.claude\scripts\message-queue.ps1

# Messages are in: .claude/session/messages/gamedesigner/
# Format: msg-gamedesigner-{yyyyMMdd-HHmmss}-{seq}.json
$messageDir = ".claude/session/messages/gamedesigner"
if (Test-Path $messageDir) {
    $messageFiles = Get-ChildItem $messageDir -Filter "msg-gamedesigner-*.json" | Sort-Object Name

    foreach ($file in $messageFiles) {
        $msg = Get-Content $file.FullName -Raw | ConvertFrom-Json

        # ACKNOWLEDGE FIRST
        Send-AgentMessage -From "gamedesigner" -To "pm" -Type "message_ack" -Payload @{
            originalMessageId = $msg.id
            originalMessageType = $msg.type
            acknowledgedAt = (Get-Date).ToUniversalTime().ToString("o")
            status = "received"
        } -Priority "normal"

        # THEN PROCESS
        switch ($msg.type) {
            "playtest_request" {
                $taskId = $msg.payload.taskId
                Write-Host "[GD] Starting playtest for: $taskId"

                # Playtest happens here...
                Send-AgentMessage -From "gamedesigner" -To "pm" -Type "playtest_report" -Payload @{
                    taskId = $taskId
                    # ... report content
                }
            }

            "test_plan_request" {
                # PM wants design input for test planning
                $designInput = @{
                    taskId = $msg.payload.taskId
                    designValidation = @()
                    playtestScenarios = @()
                    uxConsiderations = @()
                }

                Send-AgentMessage -From "gamedesigner" -To "pm" -Type "test_plan_contribution" -Payload $designInput
            }
        }

        Remove-AgentMessage -Agent "gamedesigner" -MessageId $msg.id
    }
}
```

## What Happens on PM Side

When PM receives your acknowledgment:

```powershell
# PM processes message_ack
Set-SentMessageAcknowledged -MessageId $msg.payload.originalMessageId -To $msg.from

# Now PM knows:
# - The message was delivered
# - The agent is alive and processing
# - No need to resend
```

This allows PM to:

- Track which messages were actually delivered
- Detect failed message delivery
- Avoid duplicate sends after restart
- Recover from deadlock situations

## Anti-Patterns

| Don't                                          | Do Instead                                          |
| ---------------------------------------------- | --------------------------------------------------- |
| Process the message first, then acknowledge    | Acknowledge FIRST, then process                     |
| Skip acknowledgment for "unimportant" messages | Acknowledge ALL messages                            |
| Send acknowledgment after completing work      | Send acknowledgment immediately on receipt          |
| Forget to remove message after processing      | Always call `Remove-AgentMessage` after ack+process |

## Idempotency Note

If you accidentally acknowledge the same message twice, PM will handle it gracefully. The `Set-SentMessageAcknowledged` function is idempotent - calling it multiple times with the same message ID has no additional effect.

## See Also

- [`.claude/skills/idle-signaling.md`](idle-signaling.md) - Proactive availability signaling
- [`.claude/skills/deadlock-detection.md`](deadlock-detection.md) - PM's detection logic
- [`.claude/skills/ralph-event-protocol.md`](ralph-event-protocol.md) - Complete message protocol
