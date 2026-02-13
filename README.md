# Ralph Orchestra

> A multi-agent autonomous development framework that coordinates multiple AI CLI agents to work together on software development tasks.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude CLI](https://img.shields.io/badge/Claude-CLI-blue.svg)](https://docs.anthropic.com/en/docs/claude-cli)
[![OpenCode CLI](https://img.shields.io/badge/OpenCode-CLI-green.svg)](https://opencode.ai)

## What is Ralph Orchestra?

Ralph Orchestra enables **autonomous software development** by coordinating specialized AI agents, subagents, and skills together with a Watchdog process for Agent state, context window, and messaging coordination. The agents communicate through shared state files and can run indefinitely until all tasks are complete.

## Key Features
- **Multi-CLI Support** - Works with Claude CLI, OpenCode CLI, and extensible to more
- **PRD Starter Wizard** - AI guided project initialization and configuration.
- **Multi-Agent Coordination** - PM, Developer, Tech Artist, QA, and Game Designer agents with modular skills
- **Three Orchestration Modes** - Event-driven, Sequential, or HITL
- **Watchdog Process** - Never-exit orchestrator that manages agent lifecycle. The context window is kept individual for each agent and cleaned per task.
- **Message-Based Communication** - File-based messages for agent coordination
- **Scale-Adaptive Planning** - PM adjusts approach based on PRD task count (0-4)
- **Skill Improvement** - Agents research and propose skill updates during retrospectives

## Quick Start

### Prerequisites

Choose your CLI:
- **Claude CLI**: [Install Claude CLI](https://docs.anthropic.com/en/docs/claude-cli) and authenticate
- **OpenCode CLI**: [Install OpenCode](https://opencode.ai/docs) and configure a provider

System requirements:
- PowerShell 5.1+ (Windows) or Bash (Linux/macOS)
- Python 3.8+

### CLI Provider Selection

Ralph Orchestra supports multiple AI CLIs. Select your provider via:

**Option 1: Environment Variable**
```powershell
$env:RALPH_CLI_PROVIDER = "opencode"  # or "claude"
```

**Option 2: Configuration File**

Create `cli-provider.json` in your project root:
```json
{
  "provider": "opencode"
}
```

**Option 3: Command Line**
```powershell
.\.claude\scripts\ralph-event-session.ps1 -Provider opencode
```

### PRD Starter Wizard

The PRD Starter Wizard automates Ralph Orchestra project initialization by:
- Collecting project requirements through conversational prompts
- Researching similar projects and best practices
- Creating game design documents (for game projects)
- Generating PM-quality PRDs
- Scaffolding complete project structure with agents, scripts, and documentation

### Running Agents

#### Event-Driven Mode (Recommended)

PM starts first. The watchdog launches workers on demand when they have pending messages:

```powershell
.\.claude\scripts\ralph-event-session.ps1
```

With OpenCode:
```powershell
.\.claude\scripts\ralph-event-session.ps1 -Provider opencode
```

#### Sequential Mode (Token-Efficient)

One agent at a time with ~70% lower token usage:

```powershell
.\.claude\scripts\ralph-single-session.ps1
```

#### HITL Mode (Learning)

Single iteration for learning the flow:

```
/ralph-hitl
```

#### Manual Agent Startup

For individual agent sessions:

```bash
/ralph-coordinator-event           # Start PM (coordinator)
/ralph-worker-event --agent developer   # Start Developer
/ralph-worker-event --agent techartist  # Start Tech Artist
/ralph-worker-event --agent qa          # Start QA
```

## Documentation

| Document | Description |
|----------|-------------|
| [Getting Started](./docs/getting-started.md) | Installation, prerequisites, first run |
| [PRD Starter Wizard](./docs/prd-starter.md) | Phases and configuration steps explained |
| [Orchestration Modes](./docs/orchestration-modes.md) | All modes explained in detail |
| [Architecture](./docs/architecture.md) | System architecture, agent roles, message flow |
| [Configuration](./docs/configuration.md) | PRD format, agent settings, watchdog config |
| [Extending](./docs/extending.md) | Adding custom agents, skills, routing |
| [Monitoring](./docs/monitoring.md) | Dashboard, logs, troubleshooting |

## Extending CLI Providers

Ralph Orchestra uses a provider abstraction that makes it easy to add new CLI support:

1. Create a new provider in `.claude/providers/` implementing the `CliProvider` interface
2. Register it in `ProviderFactory.ps1`
3. Add configuration to `cli-provider.json`

See `.claude/providers/` for examples (ClaudeProvider, OpenCodeProvider).


