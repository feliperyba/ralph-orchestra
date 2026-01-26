# Sequential Mode - Deep Dive

Sequential mode is a **token-efficient orchestration mode** where only one agent runs at a time. Agents coordinate via handoff signals, sharing context between switches.

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       SEQUENTIAL MODE ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌──────────┐    handoff-signal.json    ┌──────────┐                     │
│   │    PM    │ ────────────────────────►│ Developer│                     │
│   │  Agent   │◄──────────────────────── │  Agent   │                     │
│   └──────────┘    pending-handoff.json    └──────────┘                     │
│         │                  ▲                       │                       │
│         │                  │                       │                       │
│         ▼                  │                       ▼                       │
│   ┌──────────┐             │                ┌──────────┐                   │
│   │ Watchdog │─────────────┘                │    QA    │                   │
│   │  Single  │     Detects & Routes        │  Agent   │                   │
│   └──────────┘                              └──────────┘                   │
│                                                                             │
│   Only ONE agent active at any time - saves ~70% on token usage           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Key Characteristics

| Feature | Description |
|---------|-------------|
| **Parallelism** | None (one agent at a time) |
| **Token Usage** | Low (~70% savings vs event mode) |
| **Handoff Mechanism** | `handoff-signal.json` file |
| **Context Passing** | `pending-handoff.json` file |
| **Best For** | Token efficiency, smaller projects, debugging |

## Session Startup

### ralph-single-session.ps1

**Location:** [`.claude/scripts/ralph-single-session.ps1`](../.claude/scripts/ralph-single-session.ps1:1)

**Parameters:**
```powershell
-InitialAgent <name>    # Which agent starts first (default: "pm")
-GracefulShutdownSeconds 30    # Wait time for graceful shutdown
-MaxRestarts 3           # Retries before longer wait
-Debug                   # Enable debug output
-MaxIterations <n>       # Override maximum iterations
```

**Startup Sequence:**

1. **Validate initial agent** name
2. **Create session directories**
3. **Initialize `coordinator-state.json`** with session info
4. **Initialize `handoff-log.json`** to track handoffs
5. **Launch watchdog** with parameters

## Watchdog Single Orchestrator

### watchdog-single.ps1

**Location:** [`.claude/scripts/watchdog-single.ps1`](../.claude/scripts/watchdog-single.ps1:1)

**Parameters:**
```powershell
-GracefulShutdownSeconds 30    # Wait for agent to save state
-HandoffCheckIntervalMs 1000   # Check for handoff signals
-MaxRestarts 3                 # Retries before longer wait
-Debug                         # Enable verbose output
```

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        WATCHDOG SINGLE LOOP                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌────────────────┐                                                    │
│  │   START PM     │                                                    │
│  │   AGENT FIRST  │                                                    │
│  └────────┬───────┘                                                    │
│           │                                                            │
│           ▼                                                            │
│  ┌────────────────┐    ┌────────────────┐    ┌────────────────┐        │
│  │ CHECK FOR      │───►│ HANDOFF FOUND? │───►│ STOP CURRENT   │        │
│  │ HANDOFF SIGNAL │    │                │    │ AGENT          │        │
│  └────────────────┘    └───────┬────────┘    └───────┬────────┘        │
│          │                    No                      │ Yes               │
│          │                    │                       │                 │
│          │                    ▼                       ▼                 │
│          │           ┌────────────────┐    ┌────────────────┐          │
│          │           │ CHECK FOR      │    │ READ CONTEXT   │          │
│          │           │ COMPLETION     │    │ FROM           │          │
│          │           │ (RALPH_COMPLETE)│  │ pending-handoff│          │
│          │           └───────┬────────┘    └───────┬────────┘          │
│          │                   │                     │                   │
│          └───────────────────┴─────────────────────┴───────────────────┤
│                                  │                                       │
│                                  ▼                                       │
│                    ┌─────────────────────────────────┐                 │
│                    │   START NEXT AGENT             │                 │
│                    │   WITH CONTEXT                  │                 │
│                    └─────────────────────────────────┘                 │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Main Loop

```powershell
# Start initial agent
Start-SingleAgent -AgentName $InitialAgent

while (-not $Script:SessionComplete) {
    # 1. Check for handoff signal
    $handoff = Test-HandoffRequest -AgentName $Script:ActiveAgent

    if ($handoff) {
        if ($handoff.Type -eq "complete") {
            # Session complete!
            $Script:SessionComplete = $true
            break
        }

        # 2. Stop current agent
        Stop-Agent

        # 3. Read handoff context
        $context = Get-HandoffContext

        # 4. Start next agent with context
        Start-SingleAgent -AgentName $handoff.TargetAgent -HandoffContext $context
    }

    # Sleep before next check
    Start-Sleep -Milliseconds $HandoffCheckIntervalMs
}
```

## Handoff Protocol

### Handoff Signal Detection

**Location:** [watchdog-single.ps1:78-183](../.claude/scripts/watchdog-single.ps1:78)

The watchdog uses **two methods** to detect handoff requests:

#### 1. Primary: Signal File (Recommended)

```json
{
  "type": "handoff",
  "targetAgent": "developer",
  "context": "Implement feat-001 - Add user authentication"
}
```

**File:** `.claude/session/handoff-signal.json`

**Benefits:**
- Most reliable method
- No parsing ambiguity
- Supports structured context

#### 2. Fallback: Log Pattern

Watches agent log files for the pattern:

```
HANDOFF:agent_name:context_message
```

**Example:**
```
HANDOFF:developer:Implement feat-001 - Add user authentication
```

**Less reliable** but serves as backup if signal file fails.

### Handoff Flow

```
┌──────────────┐                         ┌──────────────┐
│   Agent A    │                         │   Watchdog   │
│              │                         │              │
│  Work until  │                         │  Poll every  │
│  complete    │                         │  1 second    │
│  or need     │                         │              │
│  handoff     │                         │              │
│       │      │                         │      │       │
│       │ Write│                         │      │ Check │
│       │      │─────────────────────────►│      │       │
│       │ handoff-signal.json             │      │       │
│       │      │                         │      ▼       │
│       │      │                         │ Detect!     │
│       │      │                         │      │       │
│       │      │                         │      │ Stop  │
│       │      │◜────────────────────────┤      │       │
│       │      │    Shutdown signal       │      │       │
│       │      │                         │      │       │
│       │      │                         │      │ Read  │
│       │      │                         │      │       │
│       │      │                         │      ▼       │
│       │      │                         │ pending-    │
│       │      │                         │ handoff.json │
│       │      │                         │      │       │
│       │      │                         │      │ Start │
│       │      │                         │      │ Agent │
│       │      │─────────────────────────►│      │ B     │
│       │      │    Context to B          │              │
│       │      │                         │              │
│       ▼      │                         │              │
│   Exit       │                         │              │
└──────────────┘                         └──────────────┘

                                            ┌──────────────┐
                                            │   Agent B    │
                                            │              │
                                            │  Read context│
                                            │  from file   │
                                            │       │      │
                                            │       ▼      │
                                            │  Continue    │
                                            │  work        │
                                            │              │
                                            └──────────────┘
```

### Handoff Context

**File:** `.claude/session/pending-handoff.json`

**Structure:**
```json
{
  "targetAgent": "developer",
  "context": "Implement feat-001 - Add user authentication",
  "timestamp": "2025-01-15T10:30:00.000Z"
}
```

**Context is passed to next agent** via command-line file reading.

## Agent Lifecycle

### Start-SingleAgent Function

**Location:** [watchdog-single.ps1:276-400](../.claude/scripts/watchdog-single.ps1:276)

```powershell
Start-SingleAgent -AgentName "developer" -HandoffContext "Implement feature X"
```

**Process:**

1. **Create runner script** at `{session}/logs/{agent}-runner.ps1`
2. **Write handoff context** to `pending-handoff.json`
3. **Start PowerShell process** with window title "Ralph Single-Agent: {agent}"
4. **Update coordinator state** with current agent
5. **Track process** in `$Script:ActiveAgent`

**Slash Commands:**
- PM: `/ralph-coordinator-single`
- Developer: `/ralph-worker-single --agent developer`
- QA: `/ralph-worker-single --agent qa`

### Stop-Agent Function

```powershell
Stop-Agent -AgentName "developer" -Graceful
```

**Process:**

1. Send shutdown message (if graceful)
2. Wait for graceful exit (up to 30 seconds)
3. Kill child processes if needed
4. Kill parent process if still running
5. Clear active agent tracking

## Handoff Log

All handoffs are logged to `handoff-log.json`:

```json
{
  "sessionId": "ralph-single-20250115-103000",
  "handoffs": [
    {
      "timestamp": "2025-01-15T10:30:15.000Z",
      "from": "pm",
      "to": "developer",
      "reason": "task_assigned",
      "context": "Implement feat-001"
    },
    {
      "timestamp": "2025-01-15T11:45:30.000Z",
      "from": "developer",
      "to": "qa",
      "reason": "validation_request",
      "context": "Validate feat-001"
    }
  ]
}
```

## Coordinator State

**File:** `.claude/session/coordinator-state.json`

Updated on each handoff:

```json
{
  "currentAgent": "developer",
  "lastUpdate": "2025-01-15T10:30:15.000Z",
  "orchestrationMode": "single-agent",
  "pendingHandoff": {
    "targetAgent": "qa",
    "context": "Validate implementation",
    "requestedAt": "2025-01-15T11:45:00.000Z"
  }
}
```

## Completion Detection

### RALPH_COMPLETE Promise

Agents signal completion by:

1. **Writing completion signal:**
   ```json
   {
     "type": "complete"
   }
   ```

2. **OR outputting the promise:**
   ```
   <promise>RALPH_COMPLETE</promise>
   ```

### Watchdog Response

```powershell
if ($handoff.Type -eq "complete") {
    Write-Host "[WATCHDOG] Session complete!" -ForegroundColor Green
    $Script:SessionComplete = $true
    break
}
```

## Dashboard

The watchdog displays a live dashboard:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                   RALPH SINGLE-AGENT MODE                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Active Agent: ● Developer                                              │
│  PID: 12345     Started: 00:05:32 ago                                  │
│                                                                         │
│  Recent Handoffs:                                                       │
│    10:30:15  pm ─────► developer  (task_assigned)                       │
│    11:45:30  developer ─► qa  (validation_request)                      │
│    12:15:00  qa ─────► developer  (bug_report)                          │
│                                                                         │
│  Total Handoffs: 3    Iterations: 42/200                               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RALPH_MAX_ITERATIONS` | 200 | Maximum total iterations across all agents |
| `RALPH_IDLE_TIMEOUT` | 60 | Idle timeout |
| `RALPH_RESTART_DELAY` | 2 | Seconds to wait before restart |
| `RALPH_MAX_RESTART_ATTEMPTS` | 3 | Retries before longer wait |

## Token Efficiency

Sequential mode saves approximately **70% of tokens** compared to event-driven mode:

| Factor | Event-Driven | Sequential |
|--------|--------------|------------|
| Running Agents | 5 simultaneously | 1 at a time |
| Context Rebuild | Each agent maintains | Passed via file |
| Message Processing | Continuous | Only on handoff |
| Duplicate Processing | Possible | Eliminated |

## Troubleshooting

### Handoff Not Detected

**Symptoms:** Watchdog doesn't detect agent's handoff request

**Solutions:**

1. **Check signal file format:**
   ```powershell
   Get-Content .claude/session/handoff-signal.json
   ```

2. **Verify log pattern** (fallback method):
   ```powershell
   Select-String -Path .claude/session/logs/*.log -Pattern "HANDOFF:"
   ```

3. **Check agent log** for errors:
   ```powershell
   Get-Content .claude/session/logs/developer.log -Tail 50
   ```

### Agent Won't Start

**Symptoms:** Watchdog fails to start agent after handoff

**Solutions:**

1. **Verify slash command** exists in `.claude/commands/`
2. **Check PowerShell execution policy**
3. **Look for errors in watchdog.log**
4. **Try running agent manually** to isolate issue

### Context Not Passed

**Symptoms:** Next agent doesn't receive handoff context

**Solutions:**

1. **Check pending-handoff.json exists** and has valid JSON
2. **Verify agent reads file** on startup (check agent log)
3. **Check file permissions** - should be readable

## Comparison with Event-Driven Mode

| Aspect | Sequential | Event-Driven |
|--------|-----------|--------------|
| **Token Usage** | ~70% savings | Baseline |
| **Speed** | Handoffs take 5-10s | Messages <10ms |
| **Debugging** | Easier (one agent at a time) | Harder (parallel) |
| **Best For** | Token efficiency, small projects | Production, speed |
| **Message History** | In handoff log | In message queue |
| **State Transfer** | Via file | Via message |

## See Also

- [Architecture Overview](./powershell-architecture.md)
- [Event-Driven Mode](./powershell-event-mode.md)
- [Message System](./powershell-messaging.md)
- [Configuration Reference](./powershell-configuration.md)
