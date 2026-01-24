# Message System Documentation

The message system is the core communication infrastructure for Ralph Orchestra's event-driven orchestration mode. It provides reliable, idempotent message passing between agents.

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MESSAGE SYSTEM ARCHITECTURE                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌──────────────┐    ┌──────────────────────────────────────┐            │
│   │   Agent A    │───►│          Message Queue               │            │
│   │              │    │  (.claude/session/messages/{agent}/)   │            │
│   └──────────────┘    └──────────────┬───────────────────────┘            │
│                                     │                                    │
│                                     │                                    │
│                                     ▼                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                      WATCHDOG MESSAGE ROUTER                       │  │
│   │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐    │  │
│   │  │ Message Pool │  │   Idempotency│  │    Pipe Transport     │    │  │
│   │  │  (Optional)  │  │    Tracking  │  │    (<10ms delivery)  │    │  │
│   │  └──────────────┘  └──────────────┘  └──────────────────────┘    │  │
│   └───────────────────────────────┬───────────────────────────────────┘  │
│                                   │                                      │
│                                   ▼                                      │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                        Agent B Inbox                               │  │
│   │           (.claude/session/messages/{agent}/inbox/)               │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Components

### Core Scripts

| Script | Purpose | Location |
|--------|---------|----------|
| [`message-queue.ps1`](../.claude/scripts/message-queue.ps1) | Core message queue functions | 40KB |
| [`message-state-manager.ps1`](../.claude/scripts/message-state-manager.ps1) | Idempotency tracking | 23KB |
| [`pipe-transport.ps1`](../.claude/scripts/pipe-transport.ps1) | Named pipe transport | 16KB |
| [`message-pool.ps1`](../.claude/scripts/message-pool.ps1) | Object pooling (optional) | 9KB |

## Message Queue Structure

### Directory Layout

```
.claude/session/messages/
├── pm/
│   ├── inbox/
│   │   ├── msg-20250115-103000-a1b2c3d4.json
│   │   └── msg-20250115-103005-e5f6g7h8.json
│   └── processed/
│       └── msg-20250115-102950-xyz123.json
├── developer/
│   ├── inbox/
│   └── processed/
├── qa/
│   ├── inbox/
│   └── processed/
├── techartist/
│   ├── inbox/
│   └── processed/
├── gamedesigner/
│   ├── inbox/
│   └── processed/
└── watchdog/
    ├── inbox/
    └── processed/
```

### Message Format

```json
{
  "id": "msg-20250115-103000-a1b2c3d4",
  "from": "pm",
  "to": "developer",
  "type": "task_assign",
  "priority": "high",
  "payload": {
    "taskId": "feat-001",
    "title": "Implement user authentication",
    "description": "Add login functionality"
  },
  "timestamp": "2025-01-15T10:30:00.000Z",
  "replyTo": null
}
```

## Message Types

### Standard Message Types

| Type | From → To | Purpose |
|------|-----------|---------|
| `task_assign` | PM → Worker | Assign work task |
| `validation_request` | Worker → QA | Request validation |
| `bug_report` | QA → PM | Report bugs found |
| `task_complete` | QA → PM | Confirm task passed |
| `question` | Any → Any | Ask for clarification |
| `answer` | Any → Any | Respond to question |
| `research_update` | PM → All | Share research findings |
| `regression_request` | PM → QA | Request regression testing |
| `prd_update` | PM → All | PRD/spec changes |
| `status_update` | Worker → PM | Report current status |
| `priority_review` | Any → PM | Request prioritization |
| `agent_ready` | Agent → Watchdog | Signal agent started |
| `shutdown` | Watchdog → Agent | Request graceful shutdown |

### Extended Message Types

| Type | Purpose |
|------|---------|
| `asset_assign` | PM → Tech Artist (asset work) |
| `asset_question` | Agent → Tech Artist |
| `asset_ready` | Tech Artist → PM |
| `design_guidance` | Game Designer → Worker |
| `design_guidance_request` | Worker → Game Designer |
| `design_question` | Worker → Game Designer |
| `design_answer` | Game Designer → Worker |
| `gdd_ready` | Game Designer → PM |
| `gdd_update` | Game Designer → PM |
| `implementation_complete` | Worker → PM |
| `mechanic_proposal` | Game Designer → PM |
| `playtest_request` | PM → Game Designer |
| `playtest_report` | Game Designer → PM |
| `priority_response` | PM → Agent |
| `quality_concern` | QA → PM |
| `reference_request` | Worker → Game Designer |
| `research_request` | PM → Game Designer |
| `research_response` | Game Designer → PM |
| `retrospective_contribution` | Worker → PM |
| `retrospective_initiate` | PM → All |
| `shader_request` | Worker → Tech Artist |
| `skill_improvements` | PM → PM |
| `skill_request` | Worker → PM |
| `work_blocked` | Worker → PM |
| `work_complete` | Worker → PM |

## Priority Levels

Messages are sorted by priority before delivery:

| Priority | Weight | Use Case |
|----------|--------|----------|
| `urgent` | 4 | Shutdown signals, critical bugs |
| `high` | 3 | Time-sensitive tasks |
| `normal` | 2 | Regular communication |
| `low` | 1 | Background notifications |

## Message Queue API

### Initialization

```powershell
# Source the message queue module
. "$PSScriptRoot\message-queue.ps1"

# Initialize for a session
Initialize-MessageQueue -SessionDir ".claude/session"

# Creates inbox folders for all agents
```

### Sending Messages

**Location:** [message-queue.ps1:99-200](../.claude/scripts/message-queue.ps1:99)

```powershell
Send-AgentMessage `
    -From "pm" `
    -To "developer" `
    -Type "task_assign" `
    -Payload @{
        taskId = "feat-001"
        title = "Add user authentication"
    } `
    -Priority "high"
```

**Process:**

1. Generate unique message ID: `msg-{timestamp}-{guid}`
2. Create message JSON file in recipient's inbox
3. Write to `.tmp` file first (atomic pattern)
4. Rename to final filename
5. Track in sent messages cache (idempotency)

### Getting Pending Messages

```powershell
$messages = Get-PendingMessages -Agent "developer"

# Returns array of message objects:
# @{
#     id = "msg-20250115-103000-a1b2c3d4"
#     from = "pm"
#     type = "task_assign"
#     priority = "high"
#     payload = @{ ... }
#     timestamp = "2025-01-15T10:30:00.000Z"
# }
```

**Features:**
- Timeout protection (prevents hanging)
- Priority sorting (urgent first)
- Returns all messages in inbox

### Acknowledging Messages

```powershell
Invoke-AcknowledgeMessage -MessageId "msg-20250115-103000-a1b2c3d4" -Agent "developer"
```

**Process:**

1. Move message from `inbox/` to `processed/`
2. Update state manager (mark as processed)
3. Delete message file

### Convenience Functions

```powershell
# Task assignment
Send-TaskAssignment -To "developer" -TaskId "feat-001" -Title "Add auth"

# Validation request
Send-ValidationRequest -From "developer" -TaskId "feat-001"

# Bug report
Send-BugReport -From "qa" -TaskId "feat-001" -Bugs $bugList

# Task complete
Send-TaskComplete -From "qa" -TaskId "feat-001"
```

## Named Pipe Transport

### Overview

**Location:** [`.claude/scripts/pipe-transport.ps1`](../.claude/scripts/pipe-transport.ps1:1)

Named pipes provide **ultra-fast message delivery** (<10ms) compared to file queue + restart (2-5 seconds).

### Pipe Creation

```powershell
# Source pipe transport
. "$PSScriptRoot\pipe-transport.ps1"

# Initialize pipe server
$success = Initialize-PipeServer -SessionDir ".claude/session"

# Creates pipes:
# - ralph-pm-inbox
# - ralph-developer-inbox
# - ralph-qa-inbox
# - ralph-gamedesigner-inbox
# - ralph-techartist-inbox
```

### Sending via Pipe

```powershell
$success = Send-PipeMessage `
    -ToAgent "developer" `
    -Message $messageObject `
    -WaitForConnection $false
```

**Parameters:**

| Parameter | Description |
|-----------|-------------|
| `ToAgent` | Target agent name |
| `Message` | Message object (hashtable) |
| `WaitForConnection` | Wait for agent to connect (default: false) |

### Performance Comparison

| Method | Delivery Time | Process Restart | True Event-Driven |
|--------|---------------|-----------------|-------------------|
| **Named Pipe** | <10ms | No | Yes |
| File Queue + Restart | 2-5 seconds | Yes | No |

## Idempotency Tracking

### Message State Manager

**Location:** [`.claude/scripts/message-state-manager.ps1`](../.claude/scripts/message-state-manager.ps1:1)

Tracks all processed messages to prevent duplicates:

```powershell
# Initialize
Initialize-MessageStateManager -SessionDir ".claude/session"

# Check if message was processed
if (Test-MessageProcessed -MessageId "msg-xxx") {
    Write-Host "Message already processed, skipping"
}

# Mark as processed
Set-MessageProcessed -MessageId "msg-xxx" -Agent "developer"
```

### State File

**Location:** `.claude/session/message-state.json`

```json
{
  "processedMessages": {
    "msg-20250115-103000-a1b2c3d4": {
      "agent": "developer",
      "processedAt": "2025-01-15T10:30:05.000Z"
    }
  },
  "completedTasks": {
    "feat-001": {
      "completedAt": "2025-01-15T11:45:00.000Z",
      "validatedBy": "qa"
    }
  },
  "sentMessages": {
    "pm:developer:feat-001": {
      "sentAt": "2025-01-15T10:30:00.000Z",
      "type": "task_assign"
    }
  },
  "lastCleanup": "2025-01-15T12:00:00.000Z",
  "version": "2.0"
}
```

### Automatic Cleanup

- **Runs every 15 minutes** during state writes
- **Removes entries older than 6 hours**
- **Prevents memory leaks** from long-running sessions

## Object Pooling

### Message Pool

**Location:** [`.claude/scripts/message-pool.ps1`](../.claude/scripts/message-pool.ps1:1)

Optional performance optimization:

```powershell
# Enable pooling
. "$PSScriptRoot\message-pool.ps1"
Initialize-MessagePool

# Get pooled message (avoids allocation)
$message = Get-PooledMessage

# Return to pool when done
Return-PooledMessage -Message $message
```

**Benefits:**
- Reduces memory allocations
- Improves GC performance
- For high-message-throughput scenarios

## Message Flow Examples

### Example 1: Task Assignment

```
┌──────────┐                              ┌──────────┐
│    PM    │                              │ Developer│
└─────┬────┘                              └─────┬────┘
      │                                        │
      │ Send-AgentMessage                     │
      │   -From: pm                           │
      │   -To: developer                      │
      │   -Type: task_assign                  │
      │   -Payload: {taskId: "feat-001"}      │
      │                                        │
      ▼                                        │
┌──────────────────────────────────────────────┐
│  Message written to:                        │
│  .claude/session/messages/developer/inbox/  │
│    msg-20250115-103000-a1b2c3d4.json        │
└──────────────────────────────────────────────┘
      │                                        │
      │                                        │ Get-PendingMessages
      │                                        │
      │◄───────────────────────────────────────┤
      │                                        │
      │                                        ▼
┌──────────────────────────────────────────────┐
│  Developer receives message object           │
│  Processes task...                           │
└──────────────────────────────────────────────┘
      │                                        │
      │                                        │ Invoke-AcknowledgeMessage
      │                                        │
      │◄───────────────────────────────────────┤
      │                                        │
      ▼                                        ▼
┌──────────────────────────────────────────────┐
│  Message moved to processed/                 │
│  State updated in message-state.json         │
└──────────────────────────────────────────────┘
```

### Example 2: Validation Request

```
Developer ──► validation_request ──► QA
     │                    │
     │                    └──► Type: validation_request
     │                         Payload: {taskId, changes}
     │
     └──► Send-AgentMessage
          -From: developer
          -To: qa
          -Type: validation_request
```

### Example 3: Bug Report

```
QA ──► bug_report ──► PM
  │                  │
  └──► Send-AgentMessage
       -From: qa
       -To: pm
       -Type: bug_report
       -Payload: {taskId, bugs: [...]}

PM processes bug report:
  1. Reviews bugs
  2. Determines priority
  3. May send task_assign back to Developer
```

## Error Handling

### Atomic Writes

All message operations use atomic write pattern:

```powershell
# 1. Write to temp file
$message | ConvertTo-Json | Out-File -FilePath "$path.tmp"

# 2. Atomic rename (prevents partial reads)
Move-Item -Path "$path.tmp" -Destination $path -Force
```

### Timeout Protection

File I/O operations have timeout protection:

```powershell
# Prevents hanging on file locks
Invoke-WithTimeout -TimeoutMs 5000 -ScriptBlock {
    Get-Content $path -Raw
}
```

### Corruption Handling

Corrupt message files are quarantined:

```powershell
try {
    $message = Get-Content $path -Raw | ConvertFrom-Json
} catch {
    # Move to quarantine for analysis
    Move-Item -Path $path -Destination "$path.corrupt"
}
```

## Troubleshooting

### Messages Not Delivered

**Symptoms:** Messages in inbox but agent doesn't process

**Solutions:**

1. **Check message format** - valid JSON required
2. **Verify agent status** - agent must be running
3. **Check pipe connection** (event mode)
4. **Review watchdog logs**

### Duplicate Messages

**Symptoms:** Same message processed multiple times

**Solutions:**

1. **Check state manager** - `message-state.json` should track processed
2. **Verify acknowledgment** - `Invoke-AcknowledgeMessage` called
3. **Check for race conditions** - concurrent deliveries

### State File Corruption

**Symptoms:** State manager fails to load

**Solutions:**

1. **Backup current state**
2. **Delete corrupted file** - will recreate with empty state
3. **Review corrupt file** for patterns

## See Also

- [Architecture Overview](./powershell-architecture.md)
- [Event-Driven Mode](./powershell-event-mode.md)
- [Configuration Reference](./powershell-configuration.md)
