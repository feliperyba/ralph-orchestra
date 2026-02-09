# Getting Started with Ralph Orchestra

This guide will help you install and run Ralph Orchestra for the first time.

## Prerequisites

- **[Claude CLI](https://docs.anthropic.com/en/docs/claude-cli)** installed and authenticated
- **PowerShell 5.1+** (Windows) or Bash (Linux/macOS)
- **Node.js 18+** (if using with a Node.js project)

## Installation

```bash
git clone https://github.com/feliperyba/ralph-orchestra
cd ralph-orchestra
npm install
```

## Understanding the Interfaces

Ralph Orchestra can be invoked through **three different interfaces**, each with different trade-offs:

| Interface | How to Invoke | Session Setup | Token Efficiency | Best For |
|-----------|---------------|---------------|------------------|----------|
| **PowerShell Scripts** | `.\.claude\scripts\ralph-event-session.ps1` | Automatic | Medium | Production, autonomous runs |
| **PowerShell Scripts** | `.\.claude\scripts\ralph-single-session.ps1` | Automatic | High | Token-efficient runs |
| **Claude CLI** | `/ralph-coordinator-event` in terminal | Manual | Standard | Learning, debugging |
| **Claude Code IDE** | `/ralph-hitl` in chat | Semi-auto | Standard | Learning, integrated workflow |

### PowerShell Scripts (Recommended for Production)

Full orchestration with automatic session management, health monitoring, and graceful shutdown:

```powershell
# Event-driven (PM-first, message queues) - Recommended
.\.claude\scripts\ralph-event-session.ps1

# Sequential (token-efficient, one agent at a time)
.\.claude\scripts\ralph-single-session.ps1

```

**What happens:**
1. Watchdog process starts and creates `./.claude/session/`
2. PM launches first, workers start on demand
3. Watchdog monitors health and delivers messages
4. Real-time dashboard shows agent status

### Claude CLI (Terminal)

Direct slash commands in separate terminals:

```bash
# Event-driven mode (PM-first, on-demand workers)
# Terminal 1: PM Coordinator
/ralph-coordinator-event

# Terminal 2: Developer Worker
/ralph-worker-event --agent developer

# Terminal 3: QA Worker
/ralph-worker-event --agent qa

# Terminal 4: Game Designer Worker
/ralph-worker-event --agent gamedesigner

# OR Sequential mode (token-efficient)
/ralph-coordinator-single
/ralph-worker-single --agent developer
/ralph-worker-single --agent qa
/ralph-worker-single --agent gamedesigner
```

### Claude Code IDE (VSCode Extension)

Slash commands directly in the chat interface:

```
/ralph-hitl
```

The IDE automatically loads agent settings and skills based on task category.

## First Run with HITL Mode

Before running autonomous sessions, use HITL (Human-in-the-Loop) mode to understand the flow:

```
/ralph-hitl
```

This runs a **single iteration** with full visibility so you can see exactly how each agent operates.

## Running in Production Modes

### Event-Driven Mode (Recommended)

PM starts first. The watchdog launches workers on demand when they have pending messages:

```powershell
.\.claude\scripts\ralph-event-session.ps1
```

**Benefits:** Adaptive parallelism, no polling overhead, idempotent delivery

### Sequential Mode (Token-Efficient)

Only one agent runs at a time. A watchdog process orchestrates handoffs:

```powershell
.\.claude\scripts\ralph-single-session.ps1
```

**Benefits:** ~70% lower token usage, simpler debugging, clear execution flow

## Stopping Agents

- **Ctrl+C** in the watchdog terminal
- Run `/cancel-ralph` in any agent terminal
- All tasks complete → agents output `<promise>RALPH_COMPLETE</promise>`
- Max iterations reached → watchdog stops all agents gracefully

## Setting Max Iterations

Always set a safety limit before running autonomous sessions:

```powershell
# Set for current session
$env:RALPH_MAX_ITERATIONS = 100
.\.claude\scripts\ralph-event-session.ps1

# Or use script parameter
.\.claude\scripts\ralph-event-session.ps1 -MaxIterations 50
```

See [Configuration](./configuration.md#max-iterations) for more options.

## Next Steps

- [Architecture](./architecture.md) - Understand the system architecture
- [Orchestration Modes](./orchestration-modes.md) - Deep dive into each mode
- [Configuration](./configuration.md) - PRD format, settings, and tuning
