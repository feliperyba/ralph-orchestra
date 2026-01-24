# Event-Driven Mode - Deep Dive

Event-driven mode is the **recommended orchestration mode** for Ralph Orchestra. All agents run in parallel with ultra-fast message delivery via named pipes.

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       EVENT-DRIVEN MODE ARCHITECTURE                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌──────────────┐         ┌─────────────────────────────────────┐        │
│   │   WATCHDOG   │◄────────┤        Named Pipe Transport          │        │
│   │  (Message    │         └─────────────────────────────────────┘        │
│   │   Broker)    │                                                     │
│   └──────┬───────┘                                                      │
│          │                                                              │
│          │  < 10ms message delivery                                     │
│          │                                                              │
│    ┌─────┴─────┬───────┬───────┬───────┐                                │
│    ▼           ▼       ▼       ▼       ▼                                │
│ ┌────────┐ ┌────────┐ ┌──────┐ ┌──────┐ ┌──────────┐                    │
│ │   PM   │ │  Dev   │ │  QA  │ │  GD  │ │   TA     │                    │
│ │ Agent  │ │ Agent  │ │Agent │ │Agent │ │  Agent   │                    │
│ └────────┘ └────────┘ └──────┘ └──────┘ └──────────┘                    │
│                                                                             │
│   All agents run continuously, blocking on pipe reads for instant delivery  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Key Characteristics

| Feature | Description |
|---------|-------------|
| **Parallelism** | All 5 agents run simultaneously |
| **Message Delivery** | <10ms via named pipes (vs 2-5 seconds file queue) |
| **Token Usage** | Medium (baseline efficiency) |
| **Performance** | ~1000x faster than file+restart delivery |
| **Best For** | Production use, speed-critical projects |

## Session Startup

### ralph-event-session.ps1

**Location:** [`.claude/scripts/ralph-event-session.ps1`](../.claude/scripts/ralph-event-session.ps1:1)

**Parameters:**
```powershell
-Debug                # Enable verbose debug output
-NoDashboard          # Disable live dashboard display
-ProjectRoot <path>   # Override project root detection
-MaxIterations <n>    # Override maximum iterations (default: 200)
```

**Startup Sequence:**

1. **Create session directories:**
   ```
   .claude/session/
   ├── messages/{pm,developer,qa,techartist,gamedesigner,watchdog}/
   ├── logs/
   ├── state/
   └── pipes/
   ```

2. **Clear old session data** (with user confirmation)

3. **Initialize coordinator state** in `coordinator-state.json`

4. **Verify PRD exists** (`prd.json`)

5. **Launch watchdog** with parameters

## Watchdog Event Orchestrator

### watchdog-event.ps1

**Location:** [`.claude/scripts/watchdog-event.ps1`](../.claude/scripts/watchdog-event.ps1:1)

**Parameters:**
```powershell
-MessageCheckIntervalMs 500    # How often to check message queue
-HealthCheckIntervalMs 10000   # How often to check agent health
-GracefulShutdownSeconds 30    # Wait time for graceful shutdown
-Debug                        # Enable debug output
```

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        WATCHDOG EVENT LOOP                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌────────────────┐    ┌────────────────┐    ┌────────────────┐       │
│  │ PROCESS        │───►│ DELIVER        │───►│ HEALTH CHECK   │       │
│  │ MESSAGES       │    │ PENDING        │    │ & RESTART      │       │
│  └────────────────┘    └────────────────┘    └────────────────┘       │
│         │                      │                      │                  │
│         └──────────────────────┴──────────────────────┴──────────────┐  │
│                                                                     │  │
│  ┌────────────────────────────────────────────────────────────────┐ │  │
│  │                    RETROSPECTIVE MONITORING                     │ │ │  │
│  │              (wakes PM when all workers contribute)             │ │ │  │
│  └────────────────────────────────────────────────────────────────┘ │  │
│                                                                     │  │
└─────────────────────────────────────────────────────────────────────────┘
```

### Main Loop

The watchdog runs continuously, performing four main operations:

```powershell
while (-not $Script:SessionComplete) {
    # 1. Process messages from agents
    Invoke-ProcessMessages

    # 2. Deliver pending messages to agents
    Invoke-DeliverPendingMessages

    # 3. Check agent health and restart if needed
    Invoke-HealthCheck

    # 4. Monitor retrospective contributions
    Invoke-RetrospectiveWatcher

    # Sleep briefly before next iteration
    Start-Sleep -Milliseconds $MessageCheckIntervalMs
}
```

## Named Pipe System

### Pipe Creation

**Location:** [`.claude/scripts/pipe-transport.ps1`](../.claude/scripts/pipe-transport.ps1:1)

Pipes are created during watchdog initialization:

```powershell
Initialize-PipeServer -SessionDir $paths.SessionDir
```

**Pipe Names:**
- `ralph-pm-inbox`
- `ralph-developer-inbox`
- `ralph-qa-inbox`
- `ralph-gamedesigner-inbox`
- `ralph-techartist-inbox`

### Pipe Connection Flow

```
┌──────────────┐                    ┌──────────────┐
│   WATCHDOG   │                    │    AGENT     │
│              │                    │              │
│  Create Pipe │                    │              │
│  (Server)    │                    │              │
│       │      │                    │              │
│       │ Wait │◄───────────────────┤ Connect      │
│       │      │                    │ (Client)     │
│       ▼      │                    │              │
│  Connected   │                    │ Block Read   │
│       │      │                    │              │
│  Write Msg   │────────────────────►│             │
│       │      │   (<10ms delivery)  │             │
│       │      │                    │ Process      │
│       │      │                    │      │       │
│       │      │                    │      ▼       │
│       │      │                    │  Send ACK    │
│       │      │◜─────────────────────┤             │
│       │      │                    │ Continue     │
└──────────────┘                    └──────────────┘
```

### Pipe Transport Functions

| Function | Purpose |
|----------|---------|
| `Initialize-PipeServer` | Creates named pipes for all agents |
| `Send-PipeMessage` | Writes message to agent pipe asynchronously |
| `Wait-PipeConnection` | Waits for agent to connect to its pipe |

**Performance:** ~1000x faster than file+restart method (10ms vs 2000-5000ms)

## Message Routing

### Message Delivery Flow

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Agent A    │───►│  Message     │───►│  Watchdog    │
│              │    │  Queue      │    │  Router      │
└──────────────┘    └──────────────┘    └──────┬───────┘
                                            │
                         ┌──────────────────┴──────────────────┐
                         │                                     │
                    ┌────▼─────┐                         ┌─────▼────┐
                    │   PIPE   │                         │  FILE    │
                    │  TRY #1  │                         │ FALLBACK │
                    │          │                         │          │
                    │ Success? │                         │  Stop +   │
                    │   Yes    │                         │  Restart  │
                    └────┬─────┘                         └────┬─────┘
                         │                                  │
                         │ <10ms                             │ 2-5s
                         ▼                                  ▼
                    ┌─────────────────────────────────────────┐
                    │            Agent B Receives             │
                    └─────────────────────────────────────────┘
```

### Delivery Methods

**1. Named Pipe Delivery (Primary)**

Located in [watchdog-event.ps1:630-671](../.claude/scripts/watchdog-event.ps1:630)

```powershell
# Try pipe delivery first
foreach ($msg in $pendingMessages) {
    if (-not (Send-MessageViaPipe -ToAgent $agentName -Message $msg)) {
        $pipeSuccess = $false
        break
    }
    # Acknowledge immediately for pipe delivery
    Invoke-AcknowledgeMessageSafe -MessageId $msg.id
}
```

**Benefits:**
- <10ms delivery time
- No process restarts
- True event-driven behavior
- Agent blocks on pipe read

**2. File Queue + Restart (Fallback)**

Located in [watchdog-event.ps1:674-740](../.claude/scripts/watchdog-event.ps1:674)

```powershell
# Grace period check - don't re-deliver too frequently
$timeSinceLastDelivery = ([DateTime]::UtcNow - $agent.LastDeliveryTime).TotalSeconds
if ($timeSinceLastDelivery -lt $DeliveryGraceSeconds) {
    continue  # Skip - within grace period
}

# Stop agent, restart with pending messages
Stop-Agent -AgentName $agentName -Reason "message_delivery"
Start-Agent -AgentName $agentName -PendingMessages $messageData
```

**Grace Period:** 10 seconds default - prevents restart loops

## Agent Lifecycle

### Agent States

Each agent has two tracked states:

| State Type | Values | Description |
|------------|--------|-------------|
| **ProcessState** | stopped, running | Actual OS process status |
| **WorkStatus** | starting, idle, working, waiting, ready, error | Agent's reported activity |

### Start-Agent Function

**Location:** [watchdog-event.ps1:267-395](../.claude/scripts/watchdog-event.ps1:267)

```powershell
Start-Agent -AgentName "developer" -PendingMessages @($msg1, $msg2)
```

**Process:**

1. **Create runner script** at `{session}/logs/{agent}-runner.ps1`
2. **Write pending messages** to `pending-messages-{agent}.json`
3. **Start PowerShell process** with window title "Ralph Event: {agent}"
4. **Track process** in `$Script:Agents[$agentName]`
5. **Send agent_ready message** to watchdog

### Stop-Agent Function

**Location:** [watchdog-event.ps1:397-449](../.claude/scripts/watchdog-event.ps1:397)

```powershell
Stop-Agent -AgentName "developer" -Graceful -Reason "task_complete"
```

**Process:**

1. **Send shutdown message** via queue (if graceful)
2. **Wait for graceful exit** (up to `GracefulShutdownSeconds`)
3. **Kill child processes** (claude.exe subprocesses)
4. **Kill parent process** if still running
5. **Dispose process object** to release handles

## Health Monitoring

### Test-AgentHealth Function

**Location:** [watchdog-event.ps1:500-600](../.claude/scripts/watchdog-event.ps1:500)

**Health Categories:**

| Category | Criteria | Action |
|----------|----------|--------|
| **dead** | Process exited unexpectedly | Restart if pending messages |
| **stale** | No activity for >90 seconds | Log warning |
| **healthy** | Process running and active | None |

**Stale Threshold:** Configurable via `RALPH_STALE_THRESHOLD` env var (default: 90 seconds)

### Invoke-HealthCheck Function

**Location:** [watchdog-event.ps1:742-771](../.claude/scripts/watchdog-event.ps1:742)

Runs every 10 seconds (configurable):

```powershell
foreach ($agentName in @("pm", "developer", "qa", "gamedesigner", "techartist")) {
    $health = Test-AgentHealth -AgentName $agentName

    switch ($health) {
        "dead" {
            # Restart if has pending messages
            if (Get-MessageCount)[$agentName] -gt 0) {
                Restart-Agent -AgentName $agentName -Reason "crashed_with_pending"
            }
        }
        "stale" {
            Write-WatchdogLog "$agentName appears stale"
        }
    }
}
```

## Retrospective Monitoring

### Retrospective File Watcher

**Location:** [watchdog-event.ps1:777-850](../.claude/scripts/watchdog-event.ps1:777)

Watches `retrospective.txt` for worker contributions:

```powershell
$Script:RetrospectiveContributions = @{
    developer = $false
    techartist = $false
    qa = $false
    gamedesigner = $false
}
```

**Trigger:** When all workers have contributed, sends `research_update` to PM to continue.

## Dashboard

### Live Dashboard Display

The watchdog displays a live dashboard (unless `-NoDashboard` is specified):

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    RALPH EVENT-DRIVEN MODE                             │
├─────────────────────────────────────────────────────────────────────────┤
│  PM:        ● working  [msg: task_assign]  Messages: 2                 │
│  Developer: ● idle     [msg: (none)]     Messages: 0                 │
│  QA:        ○ stopped  [msg: (none)]     Messages: 0                 │
│  Game Des.: ○ stopped  [msg: (none)]     Messages: 0                 │
│  Tech Art.: ○ stopped  [msg: (none)]     Messages: 0                 │
├─────────────────────────────────────────────────────────────────────────┤
│  Messages Routed: 15    |    Iterations: 42/200                      │
│  Uptime: 00:15:32       │    Last Message: 2s ago                    │
└─────────────────────────────────────────────────────────────────────────┘
```

**Status Indicators:**
- ● = Active/Running
- ○ = Stopped
- ◉ = Error

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RALPH_MAX_ITERATIONS` | 200 | Maximum agent iterations |
| `RALPH_IDLE_TIMEOUT` | 60 | Idle timeout before agent considered stale |
| `RALPH_STALE_THRESHOLD` | 90 | Seconds before agent marked stale |
| `RALPH_POLL_INTERVAL_MS` | 500 | Message check interval |

## Troubleshooting

### Agents Not Receiving Messages

**Symptoms:** Messages pile up in queue but agent doesn't process

**Solutions:**

1. **Check pipe status:**
   ```powershell
   # Pipes should exist in .claude/session/pipes/
   Get-ChildItem .claude/session/pipes/
   ```

2. **Verify agent is running:**
   ```powershell
   Get-Process powershell | Where-Object { $_.MainWindowTitle -like "*Ralph Event*" }
   ```

3. **Check for grace period blocking:**
   - Default: 10 seconds between deliveries
   - Adjust if needed via `$DeliveryGraceSeconds`

### Watchdog Exits Unexpectedly

**Symptoms:** Watchdog process terminates

**Solutions:**

1. **Check watchdog.log** for error messages
2. **Verify PowerShell execution policy:** `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`
3. **Run with `-Debug` flag** for verbose output

### Pipe Delivery Fails

**Symptoms:** Falls back to file queue frequently

**Solutions:**

1. **Verify pipe-transport.ps1 exists** and loads successfully
2. **Check for pipe name conflicts** with other applications
3. **Windows named pipes** require Windows 8.1 or later

## See Also

- [Architecture Overview](./powershell-architecture.md)
- [Sequential Mode](./powershell-sequential-mode.md)
- [Message System](./powershell-messaging.md)
- [Configuration Reference](./powershell-configuration.md)
