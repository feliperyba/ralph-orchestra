# Getting Started with Ralph Orchestra

This guide will help you install and run Ralph Orchestra for the first time.

## Prerequisites

Choose your CLI:
- **[Claude CLI](https://docs.anthropic.com/en/docs/claude-cli)** - Install and authenticate
- **[OpenCode CLI](https://opencode.ai/docs)** - Install and configure a provider

System requirements:
- **PowerShell 5.1+** (Windows) or Bash (Linux/macOS)
- **Node.js 18+** (if using with a Node.js project)

## Installation

```bash
git clone https://github.com/feliperyba/ralph-orchestra
cd ralph-orchestra
npm install
```

## CLI Provider Setup

### Using Claude (Default)

No additional setup needed if Claude CLI is installed and authenticated.

### Using OpenCode

1. Copy the example configuration:
   ```powershell
   copy opencode.example.json opencode.json
   ```

2. Configure your AI provider in `opencode.json` (see [OpenCode providers](https://opencode.ai/docs/providers/))

3. Set the provider:
   ```powershell
   $env:RALPH_CLI_PROVIDER = "opencode"
   ```

## Understanding the Interfaces

Ralph Orchestra can be invoked through **multiple interfaces**:

| Interface | How to Invoke | Best For |
|-----------|---------------|----------|
| **PowerShell Scripts** | `.\.claude\scripts\ralph-event-session.ps1` | Production, autonomous runs |
| **PowerShell Scripts** | `.\.claude\scripts\ralph-single-session.ps1` | Token-efficient runs |
| **Claude CLI** | `/ralph-coordinator-event` | Learning, debugging |
| **Claude Code IDE** | `/ralph-hitl` | Learning, integrated workflow |

### PowerShell Scripts (Recommended)

```powershell
# Event-driven (PM-first, message queues) - Recommended
.\.claude\scripts\ralph-event-session.ps1

# With OpenCode
.\.claude\scripts\ralph-event-session.ps1 -Provider opencode

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
/ralph-coordinator-event                    # PM Coordinator
/ralph-worker-event --agent developer       # Developer Worker
/ralph-worker-event --agent qa              # QA Worker
/ralph-worker-event --agent gamedesigner    # Game Designer
```

### Claude Code IDE (VSCode Extension)

```
/ralph-hitl
```

## First Run with HITL Mode

Before running autonomous sessions, use HITL mode to understand the flow:

```
/ralph-hitl
```

This runs a **single iteration** with full visibility.

## Running in Production Modes

### Event-Driven Mode (Recommended)

```powershell
# Claude (default)
.\.claude\scripts\ralph-event-session.ps1

# OpenCode
$env:RALPH_CLI_PROVIDER = "opencode"
.\.claude\scripts\ralph-event-session.ps1
```

**Benefits:** Adaptive parallelism, no polling overhead, idempotent delivery

### Sequential Mode (Token-Efficient)

```powershell
.\.claude\scripts\ralph-single-session.ps1
```

**Benefits:** ~70% lower token usage, simpler debugging

## Stopping Agents

- **Ctrl+C** in the watchdog terminal
- Run `/cancel-ralph` in any agent terminal
- All tasks complete → agents output `<promise>RALPH_COMPLETE</promise>`
- Max iterations reached → watchdog stops all agents gracefully

## Setting Max Iterations

Always set a safety limit before running autonomous sessions:

```powershell
# Environment variable
$env:RALPH_MAX_ITERATIONS = 100

# Or script parameter
.\.claude\scripts\ralph-event-session.ps1 -MaxIterations 50
```

## Next Steps

- [Architecture](./architecture.md) - Understand the system architecture
- [Orchestration Modes](./orchestration-modes.md) - Deep dive into each mode
- [Configuration](./configuration.md) - PRD format, CLI providers, settings
- [Extending](./extending.md) - Add custom agents and CLI providers
