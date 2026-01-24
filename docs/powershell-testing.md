# Testing and Debugging Guide

This document covers the test scripts, debug utilities, and troubleshooting procedures for Ralph Orchestra's PowerShell infrastructure.

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TESTING & DEBUGGING TOOLKIT                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌────────────────────┐    ┌────────────────────┐    ┌───────────────────┐ │
│   │   TEST SCRIPTS     │    │   DEBUG SCRIPTS    │    │  BENCHMARK SCRIPTS │ │
│   │                    │    │                    │    │                   │ │
│   │  test-integration  │    │  debug-queue       │    │  benchmark-       │ │
│   │  test-recovery     │    │  debug-queue2-10   │    │  performance      │ │
│   │  test-concurrency  │    │  debug-roundtrip   │    │                   │ │
│   │  test-handoff      │    │  debug-failures    │    │                   │ │
│   │  test-message-pool │    │                    │    │                   │ │
│   │  run-all-tests     │    │                    │    │                   │ │
│   └────────────────────┘    └────────────────────┘    └───────────────────┘ │
│                                                                             │
│   ┌───────────────────────────────────────────────────────────────────────┐ │
│   │                        TROUBLESHOOTING GUIDE                           │ │
│   │  Common Issues • Diagnosis Steps • Solutions • Log Analysis         │ │
│   └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Test Scripts

### Running All Tests

**Location:** [`.claude/scripts/run-all-tests.ps1`](../.claude/scripts/run-all-tests.ps1:1)

```powershell
.\.claude\scripts\run-all-tests.ps1
```

**Output:**
```
=== Running All Tests ===

1. Running Integration Tests...
Integration Tests: PASS

2. Running Recovery Tests...
Recovery Tests: PASS

3. Running Concurrency Tests...
Concurrency Tests: PASS

=== Test Complete ===
Overall: ALL TESTS PASSED
```

### Test Script Reference

| Script | Purpose | Location |
|--------|---------|----------|
| [`test-integration.ps1`](../.claude/scripts/test-integration.ps1) | End-to-end integration tests | 200+ lines |
| [`test-recovery.ps1`](../.claude/scripts/test-recovery.ps1) | Crash recovery and state persistence | 150+ lines |
| [`test-concurrency.ps1`](../.claude/scripts/test-concurrency.ps1) | Concurrent message handling | 100+ lines |
| [`test-handoff-detection.ps1`](../.claude/scripts/test-handoff-detection.ps1) | Sequential mode handoff detection | 80+ lines |
| [`test-message-pool.ps1`](../.claude/scripts/test-message-pool.ps1) | Object pooling performance | 60+ lines |
| [`test-message-queue-pool.ps1`](../.claude/scripts/test-message-queue-pool.ps1) | Queue + pool integration | 70+ lines |
| [`test-priority-only.ps1`](../.claude/scripts/test-priority-only.ps1) | Priority message routing | 50+ lines |
| [`test-dashboard-cache.ps1`](../.claude/scripts/test-dashboard-cache.ps1) | Dashboard performance | 40+ lines |
| [`test-helpers.ps1`](../.claude/scripts/test-helpers.ps1) | Shared test utilities | 100+ lines |

### Integration Tests

**Location:** [`.claude/scripts/test-integration.ps1`](../.claude/scripts/test-integration.ps1:1)

**Tests:**
- Message queue initialization
- Message sending and receiving
- Message acknowledgment
- State manager persistence
- Pipe transport (if available)

**Running:**
```powershell
.\.claude\scripts\test-integration.ps1

# Returns 0 on success, non-zero on failure
echo $LASTEXITCODE
```

### Recovery Tests

**Location:** [`.claude/scripts/test-recovery.ps1`](../.claude/scripts/test-recovery.ps1:1)

**Tests:**
- Watchdog crash recovery
- Agent crash detection
- State file restoration
- Message queue preservation after restart

**Running:**
```powershell
.\.claude\scripts\test-recovery.ps1
```

### Concurrency Tests

**Location:** [`.claude/scripts/test-concurrency.ps1`](../.claude/scripts/test-concurrency.ps1:1)

**Tests:**
- Simultaneous message sending
- Race condition handling
- Idempotency under concurrent load
- File locking correctness

**Running:**
```powershell
.\.claude\scripts\test-concurrency.ps1
```

### Handoff Detection Tests

**Location:** [`.claude/scripts/test-handoff-detection.ps1`](../.claude/scripts/test-handoff-detection.ps1:1)

**Tests:**
- Signal file detection
- Log pattern fallback detection
- Completion signal detection
- Context file reading

**Running:**
```powershell
.\.claude\scripts\test-handoff-detection.ps1

# Create a test signal file
.\.claude\scripts\test-handoff-detection.ps1 -CreateTestSignal
```

## Debug Scripts

### Debug Queue Scripts

**Scripts:**
- [`debug-queue.ps1`](../.claude/scripts/debug-queue.ps1:1) - Main queue debug tool
- [`debug-queue2.ps1`](../.claude/scripts/debug-queue2.ps1) through [`debug-queue10.ps1`](../.claude/scripts/debug-queue10.ps1) - Numbered queue variations

**Purpose:** Inspect and manipulate message queues

**Usage:**
```powershell
# Show current queue state
.\.claude\scripts\debug-queue.ps1

# Output includes:
# - Message counts per agent
# - Pending messages
# - Processed messages
# - Queue age statistics
```

### Debug Roundtrip Scripts

**Scripts:**
- [`debug-roundtrip.ps1`](../.claude/scripts/debug-roundtrip.ps1:1)
- [`debug-roundtrip2.ps1`](../.claude/scripts/debug-roundtrip2.ps1:1)

**Purpose:** Test message delivery roundtrip

**Usage:**
```powershell
# Send test message and track delivery
.\.claude\scripts\debug-roundtrip.ps1

# Output includes:
# - Send timestamp
# - Delivery timestamp
# - Roundtrip time
# - Message acknowledgment status
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

## Benchmark Scripts

### Performance Benchmark

**Location:** [`.claude/scripts/benchmark-performance.ps1`](../.claude/scripts/benchmark-performance.ps1:1)

**Metrics:**
- Message queue throughput (messages/second)
- Average message delivery time
- File I/O performance
- Pipe transport vs file queue comparison

**Usage:**
```powershell
.\.claude\scripts\benchmark-performance.ps1

# Sample Output:
# Message Queue Throughput: 1250 msg/sec
# Avg Delivery Time: 8ms (pipe), 3200ms (file queue)
# File Read Time: 45ms avg
# Pipe Write Time: 3ms avg
```

## Troubleshooting Guide

### Common Issues

#### 1. Watchdog Won't Start

**Symptoms:**
- Watchdog script exits immediately
- No watchdog window appears
- Error about missing modules

**Diagnosis:**
```powershell
# Check PowerShell execution policy
Get-ExecutionPolicy -List

# Check if modules exist
Test-Path .\.claude\scripts\ralph-config.ps1
Test-Path .\.claude\scripts\message-queue.ps1

# Try running with debug output
.\.claude\scripts\watchdog-event.ps1 -Debug
```

**Solutions:**
1. Set execution policy:
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```
2. Verify all script files exist
3. Check for syntax errors in config files

#### 2. Agents Not Starting

**Symptoms:**
- Watchdog starts but agents don't appear
- "Failed to start agent" messages in log
- No agent windows

**Diagnosis:**
```powershell
# Check agent commands in config
# Verify slash commands exist
Test-Path .\.claude\commands\ralph-coordinator-event.md
Test-Path .\.claude\commands\ralph-worker-event.md

# Check session directory
ls .claude\session\logs\
```

**Solutions:**
1. Verify Claude CLI is installed:
   ```powershell
   claude --version
   ```
2. Check command definitions exist
3. Check for sufficient system resources

#### 3. Messages Not Delivered

**Symptoms:**
- Messages pile up in inbox
- Agents don't process messages
- "No messages delivered" in logs

**Diagnosis:**
```powershell
# Check message queue
.\.claude\scripts\debug-queue.ps1

# Check agent status
Get-Content .claude\session\state\agents.json

# Check message state
Get-Content .claude\session\message-state.json
```

**Solutions:**
1. **Event mode:** Check pipe status
2. **Sequential mode:** Check handoff signal format
3. Verify agent is running and healthy
4. Check for grace period blocking

#### 4. Agent Crashes Repeatedly

**Symptoms:**
- Agent restarts repeatedly
- "Crashed with pending messages" in logs
- Increasing restart count

**Diagnosis:**
```powershell
# Check agent logs for errors
Get-Content .claude\session\logs\developer.log -Tail 50

# Check for memory issues
Get-Process powershell | Where-Object MainWindowTitle -like "*Ralph*"

# Check for script errors
$Error[0] | Select-Object *
```

**Solutions:**
1. Check for infinite loops in agent behavior
2. Verify skill files are valid (YAML syntax)
3. Increase timeout values if operations are slow
4. Check for resource exhaustion

#### 5. Handoff Not Detected (Sequential Mode)

**Symptoms:**
- Agent finishes but handoff doesn't trigger
- Watchdog doesn't detect signal
- "No handoff found" in logs

**Diagnosis:**
```powershell
# Check signal file format
Get-Content .claude\session\handoff-signal.json

# Check agent log for HANDOFF pattern
Select-String -Path .claude\session\logs\*.log -Pattern "HANDOFF:"

# Run handoff detection test
.\.claude\scripts\test-handoff-detection.ps1
```

**Solutions:**
1. Verify signal file has valid JSON
2. Check agent is writing to correct location
3. Verify fallback log pattern if file method fails

### Log Analysis

### Log File Locations

```
.claude/session/logs/
├── watchdog.log              # Watchdog output
├── pm.log                    # PM agent output
├── developer.log             # Developer agent output
├── qa.log                    # QA agent output
├── techartist.log            # Tech Artist output
├── gamedesigner.log          # Game Designer output
└── watchdog-summary.log      # Session summary
```

### Reading Logs

```powershell
# Tail last 50 lines
Get-Content .claude\session\logs\watchdog.log -Tail 50

# Follow log (like tail -f)
Get-Content .claude\session\logs\watchdog.log -Wait

# Search for errors
Select-String -Path .claude\session\logs\*.log -Pattern "ERROR" -Context 2,2

# Search for specific message
Select-String -Path .claude\session\logs\*.log -Pattern "task_assign"
```

### Common Log Patterns

| Pattern | Meaning |
|---------|---------|
| `Started` | Agent started successfully |
| `Stopped` | Agent stopped (graceful or forced) |
| `Crashed` | Agent exited unexpectedly |
| `Stale` | Agent not responding |
| `Delivery via pipe` | Message sent via named pipe |
| `Delivery via file queue` | Fallback delivery method |
| `Handoff detected` | Sequential mode handoff found |

## Debug Mode

### Enabling Debug Output

**Watchdog:**
```powershell
.\.claude\scripts\watchdog-event.ps1 -Debug
```

**Session Launcher:**
```powershell
.\.claude\scripts\ralph-event-session.ps1 -Debug
```

### Debug Output Includes:

- Detailed message processing steps
- Pipe connection status
- Agent state transitions
- File I/O operations
- Error stack traces

## State Inspection

### Coordinator State

```powershell
Get-Content .claude\session\coordinator-state.json | ConvertFrom-Json
```

**Shows:**
- Current active agent
- Last update time
- Orchestration mode
- Pending handoff information

### Agent States

```powershell
Get-Content .claude\session\state\agents.json | ConvertFrom-Json
```

**Shows:**
- Process states (running/stopped)
- Work statuses (idle/working/waiting/etc.)
- Current tasks
- Last activity times

### Message State

```powershell
Get-Content .claude\session\message-state.json | ConvertFrom-Json
```

**Shows:**
- Processed messages
- Completed tasks
- Sent messages
- Last cleanup time

## Performance Profiling

### Measuring Message Throughput

```powershell
# Run before and after to compare
$before = (Get-ChildItem .claude\session\messages\*\inbox\).Count

# ... send some messages ...

$after = (Get-ChildItem .claude\session\messages\*\inbox\).Count
$throughput = $after - $before
```

### Measuring Delivery Time

```powershell
# Use debug-roundtrip script
.\.claude\scripts\debug-roundtrip.ps1 | Select-String "Roundtrip"
```

### Memory Profiling

```powershell
# Check PowerShell process memory
Get-Process powershell |
    Where-Object MainWindowTitle -like "*Ralph*" |
    Select-Object Name, Id, WorkingSet, CPU
```

## Recovery Procedures

### Recovering from Crash

1. **Check session state:**
   ```powershell
   Get-Content .claude\session\coordinator-state.json
   ```

2. **Check for incomplete tasks:**
   ```powershell
   Get-Content .claude\session\current-task.json
   ```

3. **Restart session:**
   ```powershell
   # Event mode
   .\.claude\scripts\ralph-event-session.ps1

   # Sequential mode
   .\.claude\scripts\ralph-single-session.ps1
   ```

### Clearing Stuck State

**Warning:** Only do this if no agents are running.

```powershell
# Remove stuck consolidation mode
Remove-Item .claude\session\consolidation-mode.json -Force

# Remove stale state files
Remove-Item .claude\session\state\*.json -Force

# Clear message queues
Remove-Item .claude\session\messages\*\* -Recurse -Force
```

### Resetting Session

**Complete reset:**

```powershell
# Stop all agents first (Ctrl+C in each window)

# Remove session directory
Remove-Item .claude\session -Recurse -Force

# Start fresh session
.\.claude\scripts\ralph-event-session.ps1
```

## See Also

- [Architecture Overview](./powershell-architecture.md)
- [Event-Driven Mode](./powershell-event-mode.md)
- [Sequential Mode](./powershell-sequential-mode.md)
- [Message System](./powershell-messaging.md)
- [Configuration Reference](./powershell-configuration.md)
