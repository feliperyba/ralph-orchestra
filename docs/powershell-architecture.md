# PowerShell Orchestration Architecture

This document provides a comprehensive overview of the PowerShell scripts that form the core orchestration infrastructure of Ralph Orchestra.

## Overview

Ralph Orchestra's PowerShell scripts implement a multi-agent orchestration system with three distinct modes:

| Mode | Parallelism | Token Usage | Speed | Best For |
|------|-------------|-------------|-------|----------|
| **Event-Driven** | Full (5 agents) | Medium | Fastest | Production, speed priority |
| **Sequential** | None (1 at a time) | Low (~70% savings) | Medium | Token efficiency, smaller projects |
| **Polling** | Full (5 agents) | High | Slowest | Legacy, debugging |

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    POWERSCRIPT ORCHESTRATION ARCHITECTURE               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     ENTRY POINTS                                │   │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────┐  │   │
│  │  │ ralph-event-     │  │ ralph-single-    │  │ ralph-multi-  │  │   │
│  │  │ session.ps1      │  │ session.ps1      │  │ session.ps1   │  │   │
│  │  │ (Event Mode)     │  │ (Sequential)     │  │ (Polling)     │  │   │
│  │  └────────┬─────────┘  └────────┬─────────┘  └───────┬───────┘  │   │
│  └───────────┼────────────────────┼──────────────────────┼───────────┘   │
│              │                    │                      │                │
│              ▼                    ▼                      ▼                │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     WATCHDOG ORCHESTRATORS                      │   │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────┐  │   │
│  │  │ watchdog-event.  │  │ watchdog-single. │  │ watchdog.ps1  │  │   │
│  │  │ ps1              │  │ ps1              │  │ (Legacy)      │  │   │
│  │  │ Named Pipes      │  │ Handoff Protocol │  │ Polling 30s   │  │   │
│  │  └────────┬─────────┘  └────────┬─────────┘  └───────────────┘  │   │
│  └───────────┼────────────────────┼──────────────────────────────────┘   │
│              │                    │                                     │
│              ▼                    ▼                                     │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                  SHARED INFRASTRUCTURE                           │   │
│  │  ┌───────────────┐  ┌───────────────┐  ┌─────────────────────┐  │   │
│  │  │ message-queue │  │ pipe-transport │  │ ralph-config        │  │   │
│  │  │ .ps1          │  │ .ps1           │  │ .ps1                │  │   │
│  │  │ Idempotency   │  │ <10ms Delivery │  │ Environment Config  │  │   │
│  │  └───────────────┘  └───────────────┘  └─────────────────────┘  │   │
│  │                                                                  │   │
│  │  ┌───────────────┐  ┌───────────────┐  ┌─────────────────────┐  │   │
│  │  │ safe-file-io  │  │ split-state-  │  │ message-state-      │  │   │
│  │  │ .ps1          │  │ manager.ps1   │  │ manager.ps1         │  │   │
│  │  │ Timeout I/O   │  │ State Files   │  │ Duplicate Detect     │  │   │
│  │  └───────────────┘  └───────────────┘  └─────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Script Categorization

### Session Launchers (Entry Points)

| Script | Purpose | Parameters |
|--------|---------|------------|
| [`ralph-event-session.ps1`](../.claude/scripts/ralph-event-session.ps1) | Launch event-driven parallel mode | `-NoDashboard`, `-Debug`, `-ProjectRoot`, `-MaxIterations` |
| [`ralph-single-session.ps1`](../.claude/scripts/ralph-single-session.ps1) | Launch sequential orchestration | `-InitialAgent`, `-NoDashboard`, `-Debug`, `-MaxIterations` |
| [`ralph-multi-session.ps1`](../.claude/scripts/ralph-multi-session.ps1) | Launch polling parallel mode (legacy) | `-NoDashboard`, `-Debug`, `-Wait` |

### Watchdog Orchestrators

| Script | Purpose | Key Features |
|--------|---------|--------------|
| [`watchdog-event.ps1`](../.claude/scripts/watchdog-event.ps1) | Message broker for event mode | Named pipes, message routing, health monitoring |
| [`watchdog-single.ps1`](../.claude/scripts/watchdog-single.ps1) | Handoff-based orchestration | Single agent at a time, context preservation |
| [`watchdog.ps1`](../.claude/scripts/watchdog.ps1) | Legacy polling monitor | 30-second polling intervals |

### Message Infrastructure

| Script | Purpose | Key Functions |
|--------|---------|---------------|
| [`message-queue.ps1`](../.claude/scripts/message-queue.ps1) | Core message queue system | `Send-AgentMessage`, `Get-PendingMessages`, `Invoke-AcknowledgeMessage` |
| [`pipe-transport.ps1`](../.claude/scripts/pipe-transport.ps1) | Named pipe messaging layer | `Initialize-PipeServer`, `Send-PipeMessage`, `Wait-PipeConnection` |
| [`message-state-manager.ps1`](../.claude/scripts/message-state-manager.ps1) | Message idempotency tracking | Duplicate detection, state persistence |
| [`message-pool.ps1`](../.claude/scripts/message-pool.ps1) | Object pooling for messages | Performance optimization |

### Configuration & Utilities

| Script | Purpose |
|--------|---------|
| [`ralph-config.ps1`](../.claude/scripts/ralph-config.ps1) | Centralized configuration, agent definitions, security |
| [`safe-file-io.ps1`](../.claude/scripts/safe-file-io.ps1) | Timeout-protected file I/O operations |
| [`split-state-manager.ps1`](../.claude/scripts/split-state-manager.ps1) | Split state file management |
| [`context-manager.ps1`](../.claude/scripts/context-manager.ps1) | Context reset management |
| [`agent-loop.ps1`](../.claude/scripts/agent-loop.ps1) | Agent execution loop wrapper |
| [`file-lock.ps1`](../.claude/scripts/file-lock.ps1) | File locking mechanisms |
| [`Consolidation-Mode.ps1`](../.claude/scripts/Consolidation-Mode.ps1) | PM consolidation behavior |
| [`Dashboard-Common.ps1`](../.claude/scripts/Dashboard-Common.ps1) | Dashboard display utilities |
| [`Watchdog-Common.ps1`](../.claude/scripts/Watchdog-Common.ps1) | Shared watchdog functions |

### Test & Debug Scripts

| Pattern | Purpose |
|---------|---------|
| `test-*.ps1` | Concurrency, integration, recovery, handoff testing |
| `debug-*.ps1` | Debug utilities for various scenarios |
| `run-all-tests.ps1` | Test runner |
| `benchmark-performance.ps1` | Performance benchmarking |

## Component Relationships

### Message Flow

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│    Agent A   │───►│   Message    │───►│   Watchdog   │───►│   Agent B    │
│              │    │   Queue      │    │   Router     │    │   Inbox      │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
                           │                                      │
                           │    ┌─────────────────────────────────┤
                           │    │ Named Pipe Delivery (<10ms)     │
                           │    │ OR File Queue Fallback          │
                           │    └─────────────────────────────────┤
                           ▼                                      ▼
                    ┌──────────────────────────────────────────────────┐
                    │         Message Acknowledgment & Cleanup          │
                    └──────────────────────────────────────────────────┘
```

### State Management

```
.claude/session/
├── state/
│   ├── agents.json          # Agent statuses (watchdog writes)
│   ├── prd.json             # PRD state (PM writes)
│   ├── current-task.json    # Active task (shared)
│   └── metrics.json         # Performance metrics
├── pipes/                   # Named pipe endpoints (event mode)
├── messages/                # Message queues
│   ├── pm/inbox/
│   ├── developer/inbox/
│   ├── qa/inbox/
│   ├── techartist/inbox/
│   ├── gamedesigner/inbox/
│   └── watchdog/inbox/
├── coordinator-state.json   # Main coordination state
├── handoff-signal.json      # Agent switch signal (sequential)
├── pending-handoff.json     # Context for next agent (sequential)
├── handoff-log.json         # History of handoffs
├── progress.txt             # Human-readable progress log
└── logs/
    ├── pm.log               # PM agent output
    ├── developer.log        # Developer agent output
    ├── techartist.log       # Tech Artist output
    ├── qa.log               # QA output
    ├── gamedesigner.log     # Game Designer output
    └── watchdog.log         # Watchdog output
```

## Execution Flow by Mode

### Event-Driven Mode

1. **Session Setup**: `ralph-event-session.ps1` creates message queue directories
2. **Watchdog Start**: `watchdog-event.ps1` initializes named pipes
3. **Agent Launch**: All agents start in parallel, connect to their pipes
4. **Message Loop**:
   - PM assigns task → Developer starts working
   - PM requests validation → QA starts working
   - Agents communicate via message queue
   - Watchdog routes messages via named pipes (<10ms delivery)
5. **Health Monitoring**: Watchdog checks agent health, restarts if needed
6. **Completion**: When all tasks complete, agents exit

### Sequential Mode

1. **Session Setup**: `ralph-single-session.ps1` initializes session
2. **Initial Agent**: PM agent starts first
3. **Work Loop**:
   - Agent works until task complete or needs handoff
   - Agent writes `handoff-signal.json`
   - Watchdog detects signal, stops current agent
   - Watchdog starts next agent with context from `pending-handoff.json`
4. **Repeat**: Handoff continues until `RALPH_COMPLETE`

### Polling Mode (Legacy)

1. **Session Setup**: `ralph-multi-session.ps1` launches all agent windows
2. **Independent Loops**: Each agent polls coordinator state every 30 seconds
3. **State-Based Coordination**: Agents check `prd.json` for their next task
4. **Completion**: Agents exit when all tasks pass

## Key Design Principles

### 1. Never-Exit Orchestrator

Watchdogs use a "never-exit" design - they run continuously until:
- User presses `Ctrl+C`
- `RALPH_COMPLETE` promise is detected
- `/cancel-ralph` command sets terminated status

### 2. Idempotent Messaging

All message operations are idempotent:
- Messages use unique IDs (`msg-{timestamp}-{guid}`)
- State tracking prevents duplicate processing
- Atomic writes via temp file + rename pattern

### 3. Graceful Shutdown

Agents receive graceful shutdown signals:
- Configurable grace period (default: 30 seconds)
- State files are preserved
- In-progress messages are completed

### 4. Health Monitoring

Watchdogs monitor agent health:
- Heartbeat detection (default: 90-second stale threshold)
- Automatic restart of crashed agents
- Status tracking in `agents.json`

### 5. Security

Credential redaction in logs:
- `Remove-SensitiveData` function redacts API keys, tokens, passwords
- Patterns for Bearer tokens, GitHub tokens, AWS keys, Azure keys
- All console output passes through redaction

## Performance Characteristics

| Metric | Event-Driven | Sequential | Polling |
|--------|--------------|------------|---------|
| Message Delivery | <10ms | N/A | 30s poll |
| Token Usage | Medium | Low (~70% savings) | High |
| Parallel Execution | Yes (5 agents) | No | Yes |
| Memory Footprint | Medium | Low | High |
| Debuggability | Good | Best | Fair |

## See Also

- [Event-Driven Mode Deep Dive](./powershell-event-mode.md)
- [Sequential Mode Deep Dive](./powershell-sequential-mode.md)
- [Message System Documentation](./powershell-messaging.md)
- [Configuration Reference](./powershell-configuration.md)
- [Testing and Debugging](./powershell-testing.md)
- [Scripts README](../.claude/scripts/README.md)
