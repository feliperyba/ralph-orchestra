# Ralph Orchestra

> A multi-agent autonomous development framework that coordinates multiple AI CLI agents to work together on software development tasks.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude CLI](https://img.shields.io/badge/Claude-CLI-blue.svg)](https://docs.anthropic.com/en/docs/claude-cli)
[![OpenCode CLI](https://img.shields.io/badge/OpenCode-CLI-green.svg)](https://opencode.ai)

## What is Ralph Orchestra?

Ralph Orchestra enables **autonomous software development** by coordinating specialized AI agents, subagents, and skills together with a Watchdog process for Agent state, context window, and messaging coordination. The agents communicate through shared state files and can run indefinitely until all tasks are complete.

## Key Features
- **Multi-CLI Support** - Works with Claude CLI, OpenCode CLI, and easily extensible to more
- **PRD Starter Wizard** - AI guided project initialization and configuration
- **Multi-Agent Coordination** - PM, Developer, Tech Artist, QA, and Game Designer agents with modular skills
- **Three Orchestration Modes** - Event-driven, Sequential, or HITL
- **Watchdog Process** - Never-exit orchestrator that manages agent lifecycle
- **Message-Based Communication** - File-based messages for agent coordination
- **Scale-Adaptive Planning** - PM adjusts approach based on PRD task count
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

### OpenCode Setup

When using OpenCode, create the configuration file:

```powershell
copy opencode.example.json opencode.json
```

Then configure your [AI provider](https://opencode.ai/docs/providers/) in `opencode.json`.

### Running Agents

#### Event-Driven Mode (Recommended)

```powershell
# With Claude (default)
.\.claude\scripts\ralph-event-session.ps1

# With OpenCode
.\.claude\scripts\ralph-event-session.ps1 -Provider opencode
```

#### Sequential Mode (Token-Efficient)

```powershell
.\.claude\scripts\ralph-single-session.ps1
```

#### HITL Mode (Learning)

```
/ralph-hitl
```

## CLI Provider Architecture

Ralph uses a class-based provider system with PowerShell modules:

```
.claude/providers/
├── CliProvider.psm1            # Module with base class + helpers
├── ClaudeProvider.ps1          # Claude implementation
├── OpenCodeProvider.ps1        # OpenCode implementation
└── ProviderFactory.ps1         # Factory + registration
```

### Provider Module System

Providers use PowerShell modules (`.psm1`) for proper class inheritance:
- `using module .\CliProvider.psm1` loads the base class at parse time
- This eliminates TypeNotFound warnings from sourced scripts

### Provider Differences

| Feature | Claude | OpenCode |
|---------|--------|----------|
| **Agent Selection** | `--agent` in slash command | `--agent ralph-{name}` flag |
| **Message Delivery** | CLI `--message` argument | CLI `-m`/`--command` (primary), file-based fallback |
| **MCP Config** | `--mcp-config` CLI arg | Auto-loaded |

### Adding New Providers

1. Create `NewProvider.ps1` inheriting from `CliProvider`
2. Add `using module .\CliProvider.psm1` at the top
3. Implement required methods (`BuildAgentCommand`, `GetCapabilities`, etc.)
4. Register in `ProviderFactory.ps1`

See [Extending](./docs/extending.md) for details.

## Documentation

| Document | Description |
|----------|-------------|
| [Getting Started](./docs/getting-started.md) | Installation, prerequisites, first run |
| [Orchestration Modes](./docs/orchestration-modes.md) | All modes explained in detail |
| [Architecture](./docs/architecture.md) | System architecture, agent roles, message flow |
| [Configuration](./docs/configuration.md) | PRD format, agent settings, CLI providers |
| [Extending](./docs/extending.md) | Adding custom agents, skills, CLI providers |
| [Monitoring](./docs/monitoring.md) | Dashboard, logs, troubleshooting |
