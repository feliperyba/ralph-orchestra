# Testing and Debugging Guide V2

This document covers the test scripts, debug utilities, and troubleshooting procedures for Ralph Orchestra's PowerShell infrastructure.

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TESTING & DEBUGGING V2 TOOLKIT                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌────────────────────┐    ┌────────────────────┐                        │
│   │   V2 TEST SCRIPTS  │    │   TROUBLESHOOTING  │                        │
│   │                    │    │   GUIDE           │                        │
│   │  test-v2-eventlog  │    │  Common Issues     │                        │
│   │  test-v2-message   │    │  Log Analysis      │                        │
│   │  test-v2-eventbus  │    │  V2 Debug Tools    │                        │
│   │  test-v2-supervisor│    │                    │                        │
│   │  test-v2-integration│    │                    │                        │
│   │  benchmark-v2      │    │                    │                        │
│   └────────────────────┘    └────────────────────┘                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## V2 Architecture

The V2 test suite is organized by component:

```
V2 Tests (71 total tests)
├── test-v2-eventlog.ps1 (13 tests)
│   ├── Event log initialization
│   ├── Sequence numbering
│   ├── Event filtering
│   ├── State rebuild
│   ├── Materialized views
│   └── Corruption handling
├── test-v2-messageprotocol.ps1 (18 tests)
│   ├── Message creation
│   ├── Message validation
│   ├── Legacy type mapping
│   └── Creation helpers
├── test-v2-eventbus.ps1 (15 tests)
│   ├── Pipe creation
│   ├── Undelivered queue
│   ├── Message send/receive
│   └── Status functions
├── test-v2-supervisor.ps1 (13 tests)
│   ├── Supervisor initialization
│   ├── State rebuild
│   ├── Health checking
│   └── Actor management
└── test-v2-integration.ps1 (12 tests)
    ├── Full system initialization
    ├── Component integration
    ├── State persistence
    └── End-to-end workflows
```

### Running Individual Test Suites

**Event log tests:**
```powershell
.\.claude\scripts\test-v2-eventlog.ps1
```

**Message protocol tests:**
```powershell
.\.claude\scripts\test-v2-messageprotocol.ps1
```

**Event bus tests:**
```powershell
.\.claude\scripts\test-v2-eventbus.ps1
```

**Supervisor tests:**
```powershell
.\.claude\scripts\test-v2-supervisor.ps1
```

**Integration tests:**
```powershell
.\.claude\scripts\test-v2-integration.ps1
```

### Performance Benchmarks

**Location:** [`benchmark-v2-messaging.ps1`](../.claude/scripts/benchmark-v2-messaging.ps1)

**Running:**
```powershell
.\.claude\scripts\benchmark-v2-messaging.ps1
```

**Benchmark Results (1000 events baseline):**
| Metric | Result | Target | Status |
|--------|--------|--------|--------|
| Event write throughput | 17 events/sec | > 1000 events/sec | ⚠️ File I/O bound |
| Event replay speed | 9754 events/sec | > 5000 events/sec | ✅ Exceeds target |
| Message serialization | 24203 msg/sec | > 10000 msg/sec | ✅ Exceeds target |
| Message deserialization | 17962 msg/sec | > 10000 msg/sec | ✅ Exceeds target |
| Memory per 1000 events | 28 MB | < 100 MB | ✅ Efficient |

**Note:** Event write throughput is intentionally file-bound. For Ralph's use case, events are generated as agents perform actions (not in tight loops), so 17 events/sec is acceptable.

## Test Scripts

### Running All Tests

**Location:** [`.claude/scripts/run-all-tests.ps1`](../.claude/scripts/run-all-tests.ps1:1)

```powershell
.\.claude\scripts\run-all-tests.ps1
```

### Test Script Reference

| Script | Purpose | Tests | Status |
|--------|---------|-------|--------|
| **V2 Unit Tests** | | | |
| [`test-v2-eventlog.ps1`](../.claude/scripts/test-v2-eventlog.ps1) | Event sourcing foundation | 13 | ✅ Active |
| [`test-v2-messageprotocol.ps1`](../.claude/scripts/test-v2-messageprotocol.ps1) | Message validation & protocol | 18 | ✅ Active |
| [`test-v2-eventbus.ps1`](../.claude/scripts/test-v2-eventbus.ps1) | Named pipe messaging | 15 | ✅ Active |
| [`test-v2-supervisor.ps1`](../.claude/scripts/test-v2-supervisor.ps1) | Actor supervision | 13 | ✅ Active |
| **V2 Integration Tests** | | | |
| [`test-v2-integration.ps1`](../.claude/scripts/test-v2-integration.ps1) | End-to-end V2 integration | 12 | ✅ Active |
| **Performance** | | | |
| [`benchmark-v2-messaging.ps1`](../.claude/scripts/benchmark-v2-messaging.ps1) | V2 performance benchmarks | N/A | ✅ Active |
| **Optional Tests** | | | |
| [`test-dashboard-cache.ps1`](../.claude/scripts/test-dashboard-cache.ps1) | Dashboard cell caching | N/A | ✅ Active |
| [`test-handoff-detection.ps1`](../.claude/scripts/test-handoff-detection.ps1) | Sequential mode handoff | N/A | ✅ Active |
| **Shared Utilities** | | | |
| [`test-helpers.ps1`](../.claude/scripts/test-helpers.ps1) | Shared test utilities | N/A | ✅ Required |
| [`run-all-tests.ps1`](../.claude/scripts/run-all-tests.ps1) | Master test runner | 7 suites | ✅ Active |

## Debug Tools V2

### Event Log Inspector

**New for V2** - Inspect the event log:

```powershell
# View recent events
Get-Content .\.claude\session\eventlog.jsonl -Tail 50 | ConvertFrom-Json

# View agent status
Get-Content .\.claude\session\agent-status.json | ConvertFrom-Json

# View undelivered messages
Get-Content .\.claude\session\undelivered.jsonl
```

### Debug Failures Script

**Location:** [`.claude/scripts/debug-failures.ps1`](../.claude/scripts/debug-failures.ps1:1)

**Purpose:** Analyze failure patterns and error logs

**Usage:**
```powershell
.\.claude\scripts\debug-failures.ps1

# Output includes:
# - Recent errors from all agent logs
# - Failure counts by agent
# - Common error patterns
# - Suggested fixes
```

### Agent Log Analysis

```powershell
# View agent log in real-time
Get-Content .\.claude\session\logs\developer.log -Wait -Tail 50

# Search for errors
Select-String -Path .\.claude\session\logs\*.log -Pattern "ERROR" -Context 2,2

# Search for specific message
Select-String -Path .\.claude\session\logs\*.log -Pattern "WorkAssign"
```

## Troubleshooting V2

### Watchdog Won't Start

**Symptoms:** Watchdog script exits immediately

**Solutions:**
1. **Check PowerShell execution policy:**
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```

2. **Verify V2 scripts exist:**
   ```powershell
   Test-Path .\.claude\scripts\watchdog-event-v2.ps1
   Test-Path .\.claude\scripts\eventlog.ps1
   Test-Path .\.claude\scripts\event-bus.ps1
   Test-Path .\.claude\scripts\supervisor.ps1
   ```

3. **Check for syntax errors** in config files

### Agents Not Starting

**Symptoms:** Watchdog starts but agents don't appear

**Solutions:**
1. **Verify slash commands** exist in `.claude/commands/`
2. **Check session directory** exists
3. **Look for errors** in watchdog.log
4. **Try running agent manually**

### Messages Not Delivered (V2)

**Symptoms:** Agent doesn't receive messages

**Solutions:**
1. **Check undelivered queue:**
   ```powershell
   Get-Content .\.claude\session\undelivered.jsonl
   ```

2. **Verify agent status:**
   ```powershell
   Get-Content .\.claude\session\agent-status.json | ConvertFrom-Json
   ```

3. **Check event log** for delivery events

### Agent Won't Connect

**Symptoms:** `Connect-ToWatchdog` fails

**Solutions:**
1. Verify watchdog V2 is running
2. Check `.claude/session/` exists
3. Verify pipe name format: `ralph-{agent}-main`

### Event Log Issues

**Symptoms:** State not syncing

**Solutions:**
1. Check event log exists: `Test-Path .\.claude\session\eventlog.jsonl`
2. Verify append-only (no deletions)
3. Rebuild status: `Export-AgentStatus`

## Debug Mode

### Enabling Debug Output

**Watchdog V2:**
```powershell
.\.claude\scripts\ralph-event-v2-session.ps1 -Debug
```

**Session launcher:**
```powershell
.\.claude\scripts\ralph-single-session.ps1 -NoDashboard
```

### V2 Debug Output Includes:
- Event log writes
- Pipe connection status
- Agent state transitions
- Supervisor actions (spawn, restart, stop)

## State Inspection V2

### Event Log

```powershell
# View recent events
Get-Content .\.claude\session\eventlog.jsonl -Tail 20 | ForEach-Object {
    $_ | ConvertFrom-Json | Format-Table Type, Timestamp
}
```

### Agent Status

```powershell
Get-Content .\.claude\session\agent-status.json | ConvertFrom-Json
```

### Coordinator State

```powershell
Get-Content .\.claude\session\coordinator-state.json | ConvertFrom-Json
```

## Recovery Procedures V2

### Recovering from Crash

1. **Check event log** for crash details:
   ```powershell
   Get-Content .\.claude\session\eventlog.jsonl | Select-String "AgentCrashed"
   ```

2. **Check agent status:**
   ```powershell
   Get-Content .\.claude\session\agent-status.json
   ```

3. **Restart session:**
   ```powershell
   .\.claude\scripts\ralph-event-v2-session.ps1
   ```

### Resetting Session

**Complete reset:**

```powershell
# Stop all agents first (Ctrl+C in each window)

# Remove session directory
Remove-Item .claude\session -Recurse -Force

# Start fresh session
.\.claude\scripts\ralph-event-v2-session.ps1
```

## Log File Locations V2

```
.claude/session/logs/
├── watchdog.log               # Watchdog V2 output
├── pm.log                     # PM agent output
├── developer.log              # Developer agent output
├── techartist.log             # Tech Artist output
├── qa.log                     # QA output
├── gamedesigner.log           # Game Designer output
└── watchdog-summary.log       # Session summary on exit
```

## See Also

- [Architecture Overview](./powershell-architecture.md)
- [Event-Driven Mode V2](./powershell-event-mode.md)
- [Message System V2](./powershell-messaging.md)
- [Configuration Reference](./powershell-configuration.md)
