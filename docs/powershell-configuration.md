# Configuration Reference

Ralph Orchestra's configuration is centralized in [`ralph-config.ps1`](../.claude/scripts/ralph-config.ps1), providing standardized settings, environment variable parsing, and utility functions.

## Overview

**Location:** [`.claude/scripts/ralph-config.ps1`](../.claude/scripts/ralph-config.ps1:1)

**Purpose:**
- Centralized configuration for all Ralph scripts
- Environment variable parsing with type validation
- Agent definitions and settings
- Security features (credential redaction)
- Path management

## Loading Configuration

All scripts source the configuration at startup:

```powershell
# Source the configuration
. "$PSScriptRoot\ralph-config.ps1"

# Get configuration hashtable
$config = Get-RalphConfig

# Get path structure
$paths = Get-RalphPaths -ProjectRoot "C:\path\to\project"
```

## Environment Variables

All configuration can be overridden via environment variables:

| Variable | Default | Range | Description |
|----------|---------|-------|-------------|
| `RALPH_MAX_ITERATIONS` | 200 | 1-10000 | Maximum iterations before stop |
| `RALPH_COMPLETION_PROMISE` | `RALPH_COMPLETE` | - | Promise string for completion |
| `RALPH_CONTEXT_RESET_PROMISE` | `CONTEXT_RESET` | - | Promise string for context reset |
| `RALPH_IDLE_TIMEOUT` | 60 | 10-3600 | Seconds before agent considered idle |
| `RALPH_HEARTBEAT_INTERVAL` | 30 | 5-300 | Seconds between heartbeat updates |
| `RALPH_STALE_THRESHOLD` | 90 | 30-600 | Seconds before agent marked stale |
| `RALPH_CONTEXT_THRESHOLD` | 70 | 50-95 | Context reset percentage threshold |
| `RALPH_POLL_INTERVAL_MS` | 500 | 100-10000 | Message check interval (ms) |
| `RALPH_RESTART_DELAY` | 2 | 1-30 | Seconds to wait before restart |
| `RALPH_MAX_RESTART_ATTEMPTS` | 3 | 1-10 | Max restart attempts before long wait |
| `RALPH_LOCK_TIMEOUT_MS` | 5000 | 1000-30000 | File lock timeout (ms) |
| `RALPH_LOCK_RETRY_MS` | 100 | 10-1000 | File lock retry delay (ms) |
| `RALPH_MAX_LOG_SIZE_MB` | 50 | 10-500 | Max log file size before rotation |
| `RALPH_MAX_ARCHIVE_AGE_HOURS` | 24 | 1-168 | Max age of archived logs (hours) |
| `RALPH_MAX_MESSAGE_QUEUE_SIZE` | 1000 | 100-10000 | Max messages in queue |
| `RALPH_WINDOW_CLOSE_DELAY` | 30 | 5-120 | Seconds before window closes on exit |
| `RALPH_PROCESS_START_GRACE` | 5 | 1-30 | Grace period for process start (seconds) |
| `RALPH_AGENT_STAGGER_DELAY` | 3 | 1-10 | Delay between agent starts (seconds) |
| `RALPH_DELIVERY_GRACE` | 10 | 5-60 | Grace period between message deliveries |
| `RALPH_CONSOLIDATION_TIMEOUT` | 300 | 60-900 | PM consolidation timeout (seconds) |
| `RALPH_FILE_READ_TIMEOUT` | 500 | 100-5000 | File read timeout (ms) |
| `RALPH_FILE_ENUM_TIMEOUT` | 300 | 100-5000 | File enumeration timeout (ms) |
| `RALPH_CIRCUIT_BREAKER_ENABLED` | `true` | - | Enable circuit breaker |
| `RALPH_CIRCUIT_BREAKER_MAX_FAILURES` | 3 | 1-10 | Failures before cooldown |
| `RALPH_CIRCUIT_BREAKER_COOLDOWN` | 60 | 10-600 | Cooldown period (seconds) |
| `RALPH_MESSAGE_PROCESSING_TIMEOUT` | 300 | 100-5000 | Message processing timeout (ms) |
| `RALPH_TEMP_SCRIPT_MAX_AGE_HOURS` | 1 | 1-24 | Max age for temp scripts (hours) |

### Setting Environment Variables

**PowerShell:**
```powershell
$env:RALPH_MAX_ITERATIONS = 500
$env:RALPH_IDLE_TIMEOUT = 120
.\.claude\scripts\ralph-event-session.ps1
```

**Command Prompt:**
```cmd
set RALPH_MAX_ITERATIONS=500
set RALPH_IDLE_TIMEOUT=120
\.claude\scripts\ralph-event-session.ps1
```

**Linux/macOS Bash:**
```bash
export RALPH_MAX_ITERATIONS=500
export RALPH_IDLE_TIMEOUT=120
./.claude/scripts/ralph-event-session.sh
```

## Agent Configuration

### Agent Definitions

**Location:** [ralph-config.ps1:300-350](../.claude/scripts/ralph-config.ps1:300)

```powershell
$Script:AgentConfig = @{
    "pm" = @{
        Type        = "coordinator"
        Command     = "/ralph-coordinator-event"
        DisplayName = "PM (Coordinator)"
        Color       = "Magenta"
    }
    "developer" = @{
        Type        = "worker"
        Command     = "/ralph-worker-event --agent developer"
        DisplayName = "Developer"
        Color       = "Cyan"
    }
    "qa" = @{
        Type        = "worker"
        Command     = "/ralph-worker-event --agent qa"
        DisplayName = "QA"
        Color       = "Yellow"
    }
    "gamedesigner" = @{
        Type        = "worker"
        Command     = "/ralph-worker-event --agent gamedesigner"
        DisplayName = "Game Designer"
        Color       = "Blue"
    }
    "techartist" = @{
        Type        = "worker"
        Command     = "/ralph-worker-event --agent techartist"
        DisplayName = "Tech Artist"
        Color       = "Green"
    }
}
```

### Agent Status Values

**Valid Process States:**
- `stopped` - Process not running
- `running` - Process is running

**Valid Work Statuses:**
- `stopped` - Process not running
- `starting` - Process booting up, not ready for interruption
- `idle` - Running but not actively working
- `working` - Actively processing a task
- `waiting` - Waiting for input/response
- `ready` - Ready to accept new work
- `completed` - Finished all work
- `terminated` - Intentionally stopped
- `error` - Error state

### Status Validation

```powershell
# Validate agent status
if (Test-ValidAgentStatus -Status "working") {
    Write-Host "Valid status"
}

# Get all valid statuses
$statuses = Get-ValidAgentStatuses
```

## Path Configuration

### Get-RalphPaths Function

**Location:** [ralph-config.ps1:270-310](../.claude/scripts/ralph-config.ps1:270)

```powershell
$paths = Get-RalphPaths -ProjectRoot "C:\path\to\project"
```

**Returns:**
```powershell
@{
    # Directories
    SessionDir    = ".claude/session"
    ScriptsDir    = ".claude/scripts"
    HooksDir      = ".claude/hooks"
    SkillsDir     = ".claude/skills"

    # State files
    CoordinatorState = ".claude/session/coordinator-state.json"
    CurrentTask      = ".claude/session/current-task.json"
    HandoffLog       = ".claude/session/handoff-log.json"
    ContinueFlag     = ".claude/session/continue-loop.flag"

    # Per-agent state files
    AgentStatePM        = ".claude/session/agent-pm.json"
    AgentStateDeveloper = ".claude/session/agent-developer.json"
    AgentStateQA        = ".claude/session/agent-qa.json"

    # Progress files
    ProgressLog = ".claude/session/progress.txt"
    EventsLog   = ".claude/session/events.jsonl"
    MetricsFile = ".claude/session/metrics.json"

    # Work-in-progress
    WorkInProgress = ".claude/session/work-in-progress.json"
}
```

## Security Features

### Credential Redaction

**Location:** [ralph-config.ps1:69-128](../.claude/scripts/ralph-config.ps1:69)

**Function:** `Remove-SensitiveData`

Redacts potentially sensitive data from strings before logging:

```powershell
$safeOutput = Remove-SensitiveData -Text $commandOutput
Write-Host $safeOutput
```

**Patterns Redacted:**

| Pattern | Example |
|---------|---------|
| Bearer tokens | `Bearer [REDACTED]` |
| API keys | `api_key=[REDACTED]` |
| Access tokens | `access_token=[REDACTED]` |
| Passwords | `password=[REDACTED]` |
| Secrets | `secret=[REDACTED]` |
| GitHub tokens | `[GITHUB_TOKEN_REDACTED]` |
| AWS keys | `[AWS_KEY_REDACTED]` |
| Azure keys | `[AZURE_KEY_REDACTED]` |

### Safe String Handling

**Location:** [ralph-config.ps1:450-480](../.claude/scripts/ralph-config.ps1:450)

Prevents command injection when generating scripts:

```powershell
$safeString = Get-SafeScriptString -Input "user_provided_value"
# Returns sanitized string safe for script generation
```

**Sanitization:**
- Removes backticks
- Removes variable substitution characters
- Removes special characters
- Escapes quotes

## Auxiliary Script Management

### Script Classification

**Location:** [ralph-config.ps1:192-228](../.claude/scripts/ralph-config.ps1:192)

Scripts created during sessions are classified as:

| Type | Patterns | Behavior |
|------|----------|----------|
| **Temporary** | `*-runner.ps1`, `pending-messages-*.json`, `*.exit`, `*.tmp` | Auto-deleted after age threshold |
| **Reusable** | (Custom patterns) | Persisted, should be documented |
| **Unknown** | (Other patterns) | Not auto-deleted |

### Temp Script Cleanup

**Location:** [ralph-config.ps1:230-264](../.claude/scripts/ralph-config.ps1:230)

```powershell
# Remove temporary scripts older than 1 hour
Invoke-TempScriptCleanup -SessionDir ".claude/session" -MaxAgeHours 1
```

**Default:** 1 hour max age (configurable via `RALPH_TEMP_SCRIPT_MAX_AGE_HOURS`)

## Circuit Breaker

### Purpose

Prevents infinite loops when operations repeatedly fail.

### Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `RALPH_CIRCUIT_BREAKER_ENABLED` | `true` | Enable/disable circuit breaker |
| `RALPH_CIRCUIT_BREAKER_MAX_FAILURES` | 3 | Failures before triggering cooldown |
| `RALPH_CIRCUIT_BREAKER_COOLDOWN` | 60 | Cooldown period in seconds |

### Behavior

```
┌──────────────┐
│   Operation  │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Success?   │────Yes───► Continue
└──────┬───────┘
       │ No
       ▼
┌──────────────┐
│  Increment   │
│  Fail Count  │
└──────┬───────┘
       │
       ▼
┌─────────────────────────────┐
│  Fail Count >= Max Failures? │
└───────┬─────────────────────┘
        │
   ┌────┴────┐
   ▼         ▼
 Yes        No
   │         │
   ▼         ▼
┌─────────┐  │
│ Enter   │  │
│Cooldown │  │
│(Wait 60s)│ │
└────┬────┘  │
    │       │
    └───┬───┘
        ▼
   Continue
```

## Logging Configuration

### Log Rotation

**Location:** [watchdog-event.ps1:100-132](../.claude/scripts/watchdog-event.ps1:100)

Logs rotate when size exceeds threshold:

```powershell
# .log → .log.1 → .log.2 → .log.3 → delete
```

**Settings:**
- `RALPH_MAX_LOG_SIZE_MB`: Max size before rotation (default: 50)
- `RALPH_MAX_ARCHIVE_AGE_HOURS`: Max age of archives (default: 24)

### Log Levels

```powershell
Write-RalphLog -Message "Info message" -Level "INFO" -Color Green
Write-RalphLog -Message "Warning" -Level "WARN" -Color Yellow
Write-RalphLog -Message "Error" -Level "ERROR" -Color Red
Write-RalphLog -Message "Debug" -Level "DEBUG" -Color Gray
```

## Timeout Configuration

### File I/O Timeouts

Prevents watchdog freeze on slow I/O:

| Setting | Default | Purpose |
|---------|---------|---------|
| `RALPH_FILE_READ_TIMEOUT` | 500ms | File read operations |
| `RALPH_FILE_ENUM_TIMEOUT` | 300ms | Directory enumeration |
| `RALPH_LOCK_TIMEOUT_MS` | 5000ms | File lock acquisition |
| `RALPH_MESSAGE_PROCESSING_TIMEOUT` | 300ms | Message queue processing |

### Agent Timeouts

| Setting | Default | Purpose |
|---------|---------|---------|
| `RALPH_IDLE_TIMEOUT` | 60s | Agent idle before stale |
| `RALPH_STALE_THRESHOLD` | 90s | Agent stale before restart |
| `RALPH_HEARTBEAT_INTERVAL` | 30s | Heartbeat update frequency |

## Troubleshooting

### Configuration Not Loading

**Symptoms:** Scripts use default values instead of environment variables

**Solutions:**

1. **Verify environment variable syntax:**
   ```powershell
   Get-ChildItem Env: | Where-Object Name -like "RALPH_*"
   ```

2. **Check variable scope:**
   - Process variables only affect current session
   - Use User/Machine scope for persistence

3. **Validate type conversion:**
   ```powershell
   $value = Get-EnvInt -Name "RALPH_MAX_ITERATIONS" -Default 200
   ```

### Path Issues

**Symptoms:** Scripts can't find files or directories

**Solutions:**

1. **Verify project root:**
   ```powershell
   $paths = Get-RalphPaths -ProjectRoot "C:\absolute\path"
   ```

2. **Check session directory exists:**
   ```powershell
   Test-Path ".claude/session"
   ```

3. **Verify relative paths:**
   - Scripts assume running from project root
   - Use `Set-Location` to change directory if needed

## See Also

- [Architecture Overview](./powershell-architecture.md)
- [Event-Driven Mode](./powershell-event-mode.md)
- [Sequential Mode](./powershell-sequential-mode.md)
- [Message System](./powershell-messaging.md)
