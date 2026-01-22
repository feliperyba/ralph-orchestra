# Ralph Orchestra

> A multi-agent autonomous development framework that coordinates multiple Claude CLI agents to work together on software development tasks.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude CLI](https://img.shields.io/badge/Claude-CLI-blue.svg)](https://docs.anthropic.com/en/docs/claude-cli)

## What is Ralph Orchestra?

Ralph Orchestra enables **autonomous software development** by coordinating specialized AI agents:

- **PM Agent** (Coordinator) - Selects tasks, assigns work, runs retrospectives
- **Developer Agent** (Worker) - Implements game logic, networking, and core systems
- **Tech Artist Agent** (Worker) - Creates 3D/2D assets, shaders, and visual effects
- **QA Agent** (Worker) - Validates implementations, runs tests, reports bugs
- **Game Designer Agent** (Worker) - Creates GDDs, validates design, playtests

The agents communicate through shared state files and can run indefinitely until all tasks are complete.

## Quick Start

### Prerequisites

- [Claude CLI](https://docs.anthropic.com/en/docs/claude-cli) installed and authenticated
- PowerShell 5.1+ (Windows) or Bash (Linux/macOS)

### Installation

```bash
git clone https://github.com/feliperyba/ralph-orchestra
cd ralph-orchestra
npm install
```

### Running Agents

#### Event-Driven Mode (Recommended)

All agents run in parallel with message-based communication:

```powershell
.\.claude\scripts\ralph-event-session.ps1
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

#### Stopping Agents

Press `Ctrl+C` in the watchdog terminal, or run `/cancel-ralph` in any agent terminal.

#### Manual Agent Startup

For individual agent sessions:

```powershell
/ralph-coordinator-event           # Start PM (coordinator)
/ralph-worker-event --agent developer   # Start Developer
/ralph-worker-event --agent techartist  # Start Tech Artist
/ralph-worker-event --agent qa          # Start QA
```

## Key Features

- **Multi-Agent Coordination** - PM, Developer, Tech Artist, QA, and Game Designer agents with modular skills
- **Four Orchestration Modes** - Event-driven, Sequential, Polling, or HITL
- **Watchdog Process** - Never-exit orchestrator that manages agent lifecycle
- **Message-Based Communication** - File-based messages for agent coordination
- **Scale-Adaptive Planning** - PM adjusts approach based on PRD task count (0-4)
- **Skill Improvement** - Agents research and propose skill updates during retrospectives

## Architecture

```
PM selects task → assigns to developer
     ↓
Developer implements feature
     ↓
QA validates implementation (reports bugs OR passes)
     ↓
PM receives QA's result
     ↓
Iteration completes → next task begins
```

## Documentation

| Document | Description |
|----------|-------------|
| [Getting Started](./docs/getting-started.md) | Installation, prerequisites, first run |
| [Orchestration Modes](./docs/orchestration-modes.md) | All 4 modes explained in detail |
| [Architecture](./docs/architecture.md) | System architecture, agent roles, message flow |
| [Configuration](./docs/configuration.md) | PRD format, agent settings, watchdog config |
| [Extending](./docs/extending.md) | Adding custom agents, skills, routing |
| [Monitoring](./docs/monitoring.md) | Dashboard, logs, troubleshooting |

### Additional Resources

- [.claude/scripts/README.md](./.claude/scripts/README.md) - Script reference
- [agents/\*/AGENT.md](./agents/) - Per-agent behavior instructions
- [agents/\*/skills/](./agents/) - Modular skills (YAML frontmatter)
- [.claude/skills/](./.claude/skills/) - Orchestration skills & routers

## Example PRD Item

```json
{
  "id": "feat-001",
  "title": "User Authentication",
  "priority": "high",
  "status": "pending",
  "passes": false,
  "agent": "developer",
  "acceptanceCriteria": [
    "Users can register with email/password",
    "Users can log in and receive JWT token",
    "Protected routes require valid token"
  ]
}
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run the agents to validate
5. Submit a pull request

## License

MIT License - See [LICENSE](LICENSE) for details.

## References and Inspiration

This project was conceived and developed based on the following resources:

### Core Multi-Agent Frameworks

- [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD) - Breakthrough Make And Deliver method
- [Agents.md](https://agents.md/) - Comprehensive guide on AI agent architectures
- [Agent Skills.md](https://agent-skills.md/) - Best practices for agent skills

### Ralph Wiggum Autonomous Development

- [Ralph Wiggum - Claude Code](https://github.com/anthropics/claude-code/blob/main/plugins/ralph-wiggum/README.md) - Official plugin documentation
- [Tips for AI Coding with Ralph Wiggum](https://www.aihero.dev/tips-for-ai-coding-with-ralph-wiggum) - Practical usage guide
- [Ralph Multi-Session Architecture](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum) - Multi-agent patterns

### Claude AI & MCP

- [Claude CLI Documentation](https://docs.anthropic.com/en/docs/claude-cli) - Official CLI reference
- [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) - Standard for AI-tool connections
- [MCP Servers](https://github.com/modelcontextprotocol) - Official server implementations
