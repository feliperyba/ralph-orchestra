# V2 Architecture - Event-Driven Multi-Agent System

The V2 architecture represents a complete redesign of Ralph Orchestra's orchestration infrastructure, implementing industry-standard patterns for distributed systems: **Event Sourcing**, **Actor Model**, and **CQRS**.

## Overview

The V2 architecture provides:

- **Event Sourcing** - All state changes stored as append-only events
- **Actor Model** - Erlang/OTP-style supervision trees with restart strategies
- **CQRS** - Separate read and write models for optimal performance
- **Named Pipes** - Sub-10ms message delivery between agents
- **PowerShell 5.1 Compatible** - Runs on default Windows PowerShell

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    V2 EVENT-DRIVEN ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌─────────────┐    ┌──────────────┐    ┌─────────────────────┐  │
│   │   Concurrency│    │ Serialization│    │      Metrics        │  │
│   │   Primitives │    │   Module     │    │      Tracking      │  │
│   └──────┬──────┘    └──────┬───────┘    └──────────┬──────────┘  │
│          │                  │                        │              │
│          └──────────────────┼────────────────────────┘              │
│                             │                                       │
│                    ┌────────▼─────────┐                            │
│                    │  Event Log (JSONL)│                           │
│                    │  - Sequence Numbers │                          │
│                    │  - Mutex Protection │                          │
│                    │  - Crash Recovery    │                          │
│                    └────────┬─────────┘                            │
│                             │                                       │
│          ┌──────────────────┼──────────────────┐                    │
│          │                  │                  │                    │
│    ┌─────▼─────┐     ┌──────▼──────┐   ┌─────▼──────┐             │
│    │ Event Bus │     │ Supervisor  │   │Event Store │             │
│    │ (Pipes)   │     │ (Actor Mgmt)│   │(Snapshots) │             │
│    └─────┬─────┘     └──────┬──────┘   └───────────┘             │
│          │                  │                                       │
│          └──────────────────┼──────────────────┐                    │
│                             │                  │                    │
│                    ┌────────▼─────────┐  ┌───▼──────┐             │
│                    │   Named Pipes    │  │Projections│             │
│                    │   PM/Dev/QA/etc  │  │(CQRS)    │             │
│                    └──────────────────┘  └──────────┘             │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Modules

### Core Infrastructure

| Module | Description | Classes/Functions |
|--------|-------------|-------------------|
| [`concurrency.ps1`](../../.claude/scripts/v2-architecture/concurrency.ps1) | Thread-safe synchronization primitives | `GlobalMutex`, `AsyncEvent`, `AtomicCounter`, `ReadWriteLock` |
| [`serialization.ps1`](../../.claude/scripts/v2-architecture/serialization.ps1) | Fast JSON message serialization | `MessageSerializer`, `MessagePool`, `BinaryProtocol` |
| [`metrics.ps1`](../../.claude/scripts/v2-architecture/metrics.ps1) | Performance tracking and latency metrics | `LatencyTracker`, `ThroughputCounter`, `ErrorCounter`, `MetricsCollector` |

### Event Sourcing

| Module | Description | Key Functions |
|--------|-------------|---------------|
| [`eventlog.ps1`](../../.claude/scripts/v2-architecture/eventlog.ps1) | Append-only event log with mutex protection | `Initialize-EventLog`, `Write-Event`, `Get-EventsSince`, `Rebuild-AgentStatus` |
| [`event-store.ps1`](../../.claude/scripts/v2-architecture/event-store.ps1) | Production event store with snapshots | `StoredEvent`, `Snapshot`, `EventStore` |
| [`event-versioning.ps1`](../../.claude/scripts/v2-architecture/event-versioning.ps1) | Event versioning and migration (PS 7+ only) | `EventVersion`, `EventMigration` |
| [`projections.ps1`](../../.claude/scripts/v2-architecture/projections.ps1) | CQRS read models (PS 7+ only) | `Projection`, `AgentStatusProjection`, `ProjectionManager` |

### Actor Model

| Module | Description | Classes |
|--------|-------------|---------|
| [`actor.ps1`](../../.claude/scripts/v2-architecture/actor.ps1) | Actor Model with mailboxes and selective receive | `ActorMessage`, `ActorMailbox`, `RalphActor` |
| [`supervision-tree.ps1`](../../.claude/scripts/v2-architecture/supervision-tree.ps1) | Hierarchical supervision with restart strategies | `SupervisorSpec`, `ActorSupervisorV2`, `RestartStrategy` |
| [`supervisor.ps1`](../../.claude/scripts/v2-architecture/supervisor.ps1) | Actor lifecycle management (Erlang/OTP-style) | `ActorSupervisor` |

### Messaging

| Module | Description | Key Functions |
|--------|-------------|---------------|
| [`event-bus.ps1`](../../.claude/scripts/v2-architecture/event-bus.ps1) | Bidirectional named pipe transport | `Initialize-EventBus`, `Open-AgentPipe`, `Send-Message`, `Receive-Messages` |
| [`async-pipes.ps1`](../../.claude/scripts/v2-architecture/async-pipes.ps1) | Event-driven pipe I/O for sub-10ms latency | `AsyncPipeReader`, `MessageBatcher`, `MessageForwarder` |
| [`message-protocol.ps1`](../../.claude/scripts/v2-architecture/message-protocol.ps1) | Message format and routing | Message format definitions |

### Utilities

| Module | Description | Purpose |
|--------|-------------|---------|
| [`agent-runtime.ps1`](../../.claude/scripts/v2-architecture/agent-runtime.ps1) | Agent process lifecycle management | Process spawning, health checks |
| [`cleanup-stale-ps.ps1`](../../.claude/scripts/v2-architecture/cleanup-stale-ps.ps1) | Cleanup stale PowerShell processes | Session cleanup |

## Design Patterns

### Event Sourcing

All state changes are stored as events in an append-only log:

```powershell
# Write an event
$seq = Write-Event -Type "TaskAssigned" -Data @{
    taskId = "task-123"
    agent = "developer"
    title = "Implement feature X"
}

# Read events since a sequence number
$events = Get-EventsSince -FromSeq 100

# Rebuild state from events
$status = Rebuild-AgentStatus
```

**Benefits:**
- Complete audit trail
- Crash recovery via log replay
- Temporal queries (state at any point in time)
- Debugging via event inspection

### Actor Model

Agents are actors with mailboxes and supervision:

```powershell
# Create supervisor
$supervisor = [ActorSupervisor]::new($sessionDir, "main")

# Start actor (agent)
$supervisor.StartActor("developer", "permanent", 3, "one-for-one")

# Supervisor handles crashes and restarts
```

**Restart Strategies:**
- `one-for-one`: Only restart crashed child
- `one-for-all`: Restart all children if one crashes
- `rest-for-one`: Restart crashed child and those started after it

### CQRS

Separate read and write models:

```powershell
# Write model: Event Log (append-only)
Write-Event -Type "AgentStarted" -Data @{ agent = "developer"; pid = 1234 }

# Read model: Materialized View (fast queries)
$status = Get-AgentStatus -Agent "developer"
```

**Benefits:**
- Optimal read performance
- Scalable queries
- Separate optimization for reads/writes

## Performance Targets

The V2 architecture is designed for:

| Metric | Target | Notes |
|--------|--------|-------|
| Message Delivery (p50) | < 10ms | Via named pipes |
| Message Delivery (p95) | < 20ms | 95th percentile |
| Message Delivery (p99) | < 50ms | 99th percentile |
| Throughput | > 10,000 msgs/sec | Sustained rate |
| Memory | Stable (no leaks) | Over 24 hours |
| Disk | Stable (with rotation) | With log compaction |

## PowerShell 5.1 Compatibility

All core modules are compatible with PowerShell 5.1 (default on Windows 10/11):

| PS 7+ Feature | PS 5.1 Equivalent |
|---------------|-------------------|
| `lock($obj) { }` | `[System.Threading.Monitor]::Enter/Exit` |
| `$obj?.Method()` | `if ($null -ne $obj) { $obj.Method() }` |
| `??` operator | `if ($null -eq $x) { }` |
| `[List[T]]` | `[System.Collections.Generic.List[T]]` |
| `System.Text.Json` | `ConvertTo-Json / ConvertFrom-Json` |

**Note:** Some experimental modules (`event-versioning.ps1`, `projections.ps1`) use PS 7+ features and are marked accordingly.

## Testing

The V2 architecture includes comprehensive tests:

| Test File | Purpose | Pass Rate |
|-----------|---------|-----------|
| [`Test-Concurrency.ps1`](../../.claude/tests/Test-Concurrency.ps1) | Concurrency primitives and thread safety | 15/15 (100%) |
| [`Test-Performance.ps1`](../../.claude/tests/Test-Performance.ps1) | Performance benchmarks and targets | 14/14 (100%) |
| [`Test-Reliability.ps1`](../../.claude/tests/Test-Reliability.ps1) | Integration and reliability tests | Requires PS 7+ |

Run tests:
```powershell
cd .claude\tests
Invoke-Pester Test-Concurrency.ps1
Invoke-Pester Test-Performance.ps1
```

## Session Directory Structure

```
.claude/session/
├── eventlog.jsonl              # Append-only event log (source of truth)
├── agent-status.json           # Materialized view from events (CQRS read model)
├── current-task.json           # Active task details
├── pipes/                      # Named pipe endpoints
│   ├── pm                      # PM pipe
│   ├── developer               # Developer pipe
│   ├── techartist              # Tech Artist pipe
│   ├── qa                      # QA pipe
│   └── gamedesigner            # Game Designer pipe
├── messages/                   # Fallback message queue
│   ├── pm/
│   ├── developer/
│   └── ...
└── undelivered.jsonl           # Failed message delivery attempts
```

## Event Flow

1. **PM Agent** assigns task to Developer
2. **Event Written** to `eventlog.jsonl` with sequence number
3. **Message Sent** via named pipe (sub-10ms delivery)
4. **Developer Receives** message and processes task
5. **Events Written** for each state change
6. **Agent Status Updated** in `agent-status.json` (materialized view)
7. **Watchdog Monitors** agent health via events

## Crash Recovery

On crash/restart:

1. **Watchdog starts** and reads `eventlog.jsonl`
2. **Replays all events** to rebuild state
3. **Restores agent statuses** from events
4. **Resumes work** from last sequence number
5. **No data loss** due to append-only log

## Troubleshooting

### "All pipe instances are busy"

Run session cleanup:
```powershell
.\.claude\scripts\v2-architecture\cleanup-stale-ps.ps1
```

### Sequence number duplicates

Check mutex initialization:
```powershell
# Verify mutex is created
Get-EventLogMutexInternal
```

### Events not appearing in log

Check file permissions and mutex:
```powershell
# Test event writing
.\.claude\tests\Test-DebugEventLog.ps1
```

## References

- [Event Sourcing (Martin Fowler)](https://martinfowler.com/eaaDev/EventSourcing.html)
- [Actor Model (Erlang)](https://www.erlang.org/doc/reference_manual/processes.html)
- [CQRS Pattern (Microsoft)](https://docs.microsoft.com/en-us/azure/architecture/patterns/cqrs)
- [Erlang/OTP Design Principles](https://www.erlang.org/doc/design_principles/sup_princ)
