# PowerShell Orchestration Architecture

This document provides a comprehensive overview of the PowerShell scripts that form the core orchestration infrastructure of Ralph Orchestra.

## Overview

Ralph Orchestra's PowerShell scripts implement a multi-agent orchestration system with two modes:

| Mode | Parallelism | Token Usage | Speed | Best For |
|------|-------------|-------------|-------|----------|
| **Event-Driven** | Full (5 agents) | Medium | Fastest (<10ms) | Production, speed priority |
| **Sequential** | None (1 at a time) | Low (~70% savings) | Medium (5-10s) | Token efficiency, smaller projects |

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    POWERSCRIPT ORCHESTRATION ARCHITECTURE               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                         ENTRY POINTS                            │   │
│  │  ┌──────────────────┐  ┌──────────────────┐                    │   │
│  │  │ ralph-event-v2-  │  │ ralph-single-    │                    │   │
│  │  │ session.ps1      │  │ session.ps1      │                    │   │
│  │  │ (Event-Driven)   │  │ (Sequential)     │                    │   │
│  │  └────────┬─────────┘  └────────┬─────────┘                    │   │
│  └───────────┼────────────────────┼──────────────────────────────────┘   │
│              │                    │                                     │
│              ▼                    ▼                                     │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                      WATCHDOG ORCHESTRATORS                     │   │
│  │  ┌──────────────────┐  ┌──────────────────┐                    │   │
│  │  │ watchdog-event-  │  │ watchdog-single. │                    │   │
│  │  │ v2.ps1           │  │ ps1              │                    │   │
│  │  │ ActorSupervisor  │  │ Handoff Protocol │                    │   │
│  │  │ + Event Sourcing │  │                  │                    │   │
│  │  └────────┬─────────┘  └────────┬─────────┘                    │   │
│  └───────────┼────────────────────┼──────────────────────────────────┘   │
│              │                    │                                     │
│              ▼                    ▼                                     │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                       CORE INFRASTRUCTURE                        │   │
│  │  ┌───────────────┐  ┌───────────────┐  ┌─────────────────────┐  │   │
│  │  │ event-bus     │  │ eventlog      │  │ supervisor          │  │   │
│  │  │ .ps1          │  │ .ps1          │  │ .ps1                │  │   │
│  │  │ Bidirectional │  │ Event         │  │ Actor Lifecycle      │  │   │
│  │  │ Pipes <10ms   │  │ Sourcing      │  │ Auto-restart        │  │   │
│  │  └───────────────┘  └───────────────┘  └─────────────────────┘  │   │
│  │                                                                  │   │
│  │  ┌───────────────┐  ┌───────────────┐  ┌─────────────────────┐  │   │
│  │  │ agent-runtime │  │ message-      │  │ ralph-config        │  │   │
│  │  │ .ps1          │  │ protocol.ps1  │  │ .ps1                │  │   │
│  │  │ Connection    │  │ 12 Msg Types  │  │ Environment Config  │  │   │
│  │  │ Library       │  │              │  │                      │  │   │
│  │  └───────────────┘  └───────────────┘  └─────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Script Categorization

### Session Launchers (Entry Points)

| Script | Purpose | Parameters |
|--------|---------|------------|
| [`ralph-event-v2-session.ps1`](../.claude/scripts/ralph-event-v2-session.ps1) | Launch event-driven mode | `-Debug`, `-MaxIterations` |
| [`ralph-single-session.ps1`](../.claude/scripts/ralph-single-session.ps1) | Launch sequential mode | `-InitialAgent`, `-NoDashboard`, `-Debug`, `-MaxIterations` |

### Watchdog Orchestrators

| Script | Purpose | Key Features |
|--------|---------|--------------|
| [`watchdog-event-v2.ps1`](../.claude/scripts/watchdog-event-v2.ps1) | Event-driven orchestrator | ActorSupervisor, Event Sourcing, auto-restart |
| [`watchdog-single.ps1`](../.claude/scripts/watchdog-single.ps1) | Sequential orchestrator | Handoff protocol, context passing |

### Core Infrastructure

| Script | Purpose | Key Functions |
|--------|---------|---------------|
| [`eventlog.ps1`](../.claude/scripts/eventlog.ps1) | Event sourcing foundation | `Write-Event`, `Get-EventsSince`, `Rebuild-AgentStatus` |
| [`event-bus.ps1`](../.claude/scripts/event-bus.ps1) | Bidirectional pipe transport | `New-BidirectionalPipe`, `Send-MessageToAgent`, `Receive-MessageFromAgent` |
| [`supervisor.ps1`](../.claude/scripts/supervisor.ps1) | Actor supervision | `ActorSupervisor` class, `StartActor`, `Supervise` |
| [`message-protocol.ps1`](../.claude/scripts/message-protocol.ps1) | 12 core message types | Message type definitions, validation |
| [`agent-runtime.ps1`](../.claude/scripts/agent-runtime.ps1) | Agent connection library | `Connect-ToWatchdog`, `Enter-AgentLoop`, `Send-*` functions |

### Configuration & Utilities

| Script | Purpose |
|--------|---------|
| [`ralph-config.ps1`](../.claude/scripts/ralph-config.ps1) | Centralized configuration, agent definitions, security |
| [`safe-file-io.ps1`](../.claude/scripts/safe-file-io.ps1) | Timeout-protected file I/O operations |
| [`context-manager.ps1`](../.claude/scripts/context-manager.ps1) | Context reset management |
| [`agent-loop.ps1`](../.claude/scripts/agent-loop.ps1) | Agent execution loop wrapper |
| [`file-lock.ps1`](../.claude/scripts/file-lock.ps1) | File locking mechanisms |
| [`Dashboard-Common.ps1`](../.claude/scripts/Dashboard-Common.ps1) | Dashboard display utilities |
| [`Watchdog-Common.ps1`](../.claude/scripts/Watchdog-Common.ps1) | Shared watchdog functions |

### Test Scripts

| Pattern | Purpose |
|---------|---------|
| `test-*.ps1` | Integration, recovery, handoff testing |
| `run-all-tests.ps1` | Test runner |

## State Management

```
.claude/session/
├── eventlog.jsonl             # Append-only event log (source of truth)
├── agent-status.json          # Materialized view from event log
├── undelivered.jsonl          # Failed delivery queue
├── coordinator-state.json     # Main coordination state
├── handoff-signal.json        # Agent switch signal (sequential)
├── pending-handoff.json       # Context for next agent (sequential)
├── handoff-log.json           # History of handoffs
├── progress.txt               # Human-readable progress log
└── logs/
    ├── pm.log
    ├── developer.log
    ├── techartist.log
    ├── qa.log
    ├── gamedesigner.log
    └── watchdog.log
```

## Execution Flow by Mode

### Event-Driven Mode

1. **Session Setup**: `ralph-event-v2-session.ps1` initializes event log
2. **Watchdog Start**: `watchdog-event-v2.ps1` creates ActorSupervisor
3. **Agent Launch**: PM starts first, other agents spawned on demand
4. **Message Loop**:
   - PM assigns task → Developer starts working
   - PM requests validation → QA starts working
   - Messages delivered via bidirectional named pipes (<10ms)
5. **Supervision**: ActorSupervisor monitors health, auto-restarts crashes
6. **Event Log**: All events persisted to `eventlog.jsonl`
7. **Completion**: When all tasks complete, graceful shutdown

### Sequential Mode

1. **Session Setup**: `ralph-single-session.ps1` initializes session
2. **Initial Agent**: PM agent starts first
3. **Work Loop**:
   - Agent works until task complete or needs handoff
   - Agent writes `handoff-signal.json`
   - Watchdog detects signal, stops current agent
   - Watchdog starts next agent with context from `pending-handoff.json`
4. **Repeat**: Handoff continues until `RALPH_COMPLETE`

## Key Design Principles

### 1. Actor Model with Supervision

- **ActorSupervisor** spawns and monitors all agents
- **Let-it-crash** philosophy - agents that crash are restarted
- **Exponential backoff** for restart attempts: 5s, 10s, 20s, 40s, 60s (max)
- **Max restarts** (3) before giving up on an agent

### 2. Event Sourcing

- **Single source of truth**: `eventlog.jsonl` is append-only
- **State derivation**: Current state rebuilt by replaying events
- **Materialized views**: `agent-status.json` auto-generated from event log
- **At-least-once delivery**: Events persisted before acknowledgment

### 3. Bidirectional Named Pipes

- **<10ms delivery** for rapid communication
- **No file-based queues** - pipes are the only transport
- **Bidirectional** - one pipe per agent for both send/receive
- **Automatic fallback**: Undelivered queue for pipe failures

### 4. Simplified Message Protocol

- **12 core types** covering all communication needs
- **Unified format**: All messages share same structure
- **Type consolidation**: `WorkAssign` covers all assignments, `WorkComplete` covers all completions

### 5. Graceful Shutdown

- **Shutdown messages** sent via pipes
- **Grace period** (default: 30 seconds)
- **State preservation** via event log
- **Clean exit codes**: 0 or 42 for graceful, other codes trigger restart

## Performance Characteristics

| Metric | Event-Driven | Sequential |
|--------|--------------|------------|
| Message Delivery | <10ms | N/A (handoffs) |
| Token Usage | Medium | Low (~70% savings) |
| Parallel Execution | Yes (5 agents) | No |
| Agent Restart Time | <500ms | N/A |
| Crash Recovery | Automatic | Manual |
| Message Types | 12 | 12 |
| State Files | 1 event log | Multiple files |

## Message Type Summary

The system uses 12 core message types:

| Type | Purpose |
|------|---------|
| `WorkAssign` | All work assignments |
| `WorkComplete` | All completions |
| `ValidationRequest` | Validation requests |
| `ValidationResult` | Validation results |
| `ProblemReport` | Bug reports, issues |
| `Query` | Questions |
| `Response` | Answers |
| `Retrospective` | Retrospective events |
| `Playtest` | Playtesting |
| `DesignUpdate` | Design docs |
| `ResearchUpdate` | Research findings |
| `System` | Shutdown, errors |

## See Also

- [Event-Driven Mode](./powershell-event-mode.md) - Complete event-driven guide
- [Sequential Mode](./powershell-sequential-mode.md) - Token-efficient alternative
- [Message System](./powershell-messaging.md) - Message protocol
- [Configuration Reference](./powershell-configuration.md) - Environment variables
- [Testing and Debugging](./powershell-testing.md) - Test scripts and troubleshooting
