# Ralph Orchestra

> An **agnostic orchestration framework** for multi-agent AI development using Claude Code. Configure once, then let specialized agents build your project autonomously.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude CLI](https://img.shields.io/badge/Claude-CLI-blue.svg)](https://docs.anthropic.com/en/docs/claude-cli)

---

## What is Ralph Orchestra?

Ralph Orchestra is a **framework for orchestrating AI agents**. It provides:

- **PRD Starter Wizard** - Generate custom agent configurations for YOUR project
- **Orchestration Modes** - Event-driven (parallel), Sequential (token-efficient), or HITL (learning)
- **Multi-Agent Coordination** - PM, Developer, Specialist, QA agents working together
- **Technology Agnostic** - Works with any stack (Node.js, Python, Rust, Go, Java, .NET, etc.)
- **Sub-agent Delegation** - 28+ specialized sub-agents for focused tasks
- **Modular Skills** - 100+ reusable skills for common development tasks
- **Quality Enforcement** - Automated feedback loops and code quality gates
- **Git Worktrees** - Parallel workers without merge conflicts
- **Watchdog Process** - Never-exit orchestrator for long-running sessions

The included agents and skills are **templates** - starting points that demonstrate how to configure the framework for your needs. The wizard generates customized configurations based on your project type.

---

## Quick Start

**Start here** - Run the PRD Starter wizard to configure agents for your project:

```
/ralph-prd-starter
```

The wizard guides you through:

1. **Quick Start** (5 min) - Choose from 14+ presets (web, game, mobile, backend, etc.)
2. **Standard** (15 min) - Guided configuration with AI recommendations
3. **Expert** (30+ min) - Full control over every setting

After setup, agents work autonomously until your PRD is complete.

---

## Supported Project Types

The PRD Starter includes presets for:

| Category             | Presets                                                            |
| -------------------- | ------------------------------------------------------------------ |
| **Game Development** | Indie Game Dev, Game Studio, Mobile Game, Multiplayer Arena        |
| **Web Applications** | Modern Web App, Full Stack SaaS, Dashboard Analytics               |
| **Business**         | E-Commerce Store, SaaS Product, Enterprise Suite, Content Platform |
| **Technical**        | API Server, Data/ML Pipeline, DevOps/Infrastructure                |

...or create a **custom configuration** for any project type.

---

### Agent Roles (Configurable)

The framework supports configurable agent roles. The default templates include:

- **PM** (Coordinator) - Task selection, assignment, retrospectives
- **Developer** (Worker) - Feature implementation, code quality
- **Specialist** (Worker) - Domain-specific work (configurable - Tech Artist, Data Scientist, etc.)
- **QA** (Worker) - Testing, validation, bug reporting
- **Designer** (Worker) - Specifications, research, playtesting

You customize which agents are enabled and what skills they have during wizard setup.

---

## Framework vs Agents Templates

**Ralph Orchestra** is the orchestration infrastructure:

- **Event-Driven Architecture** - Event Sourcing, Actor Model, CQRS (PowerShell 5.1 compatible)
- Communication protocols (named pipes, message queues)
- Agent lifecycle management (supervision trees, health monitoring)
- Quality enforcement (feedback loops, code gates)
- Modular skill system (compose capabilities)
- PRD Starter wizard (generate configurations)

**Included templates** are examples:

- Agent definitions in `agents/` - Show structure, customize for your needs
- Presets in `.claude/presets/` - Starting points for common project types
- Skills in `.claude/skills/` - Reusable building blocks

---

## Architecture

The architecture provides a comprehensive orchestration infrastructure:

- **Event Sourcing** - Append-only event log with crash recovery
- **Actor Model** - Erlang/OTP-style supervision trees
- **CQRS** - Separate read/write models for optimal performance
- **Named Pipes** - Sub-10ms message delivery
- **PowerShell 5.1 Compatible** - Runs on default Windows PowerShell

See [Architecture Documentation](docs/powershell/v2-architecture.md) for details.

---

## Claude CLI Commands Reference

| Command                               | Purpose                                     |
| ------------------------------------- | ------------------------------------------- |
| `/ralph-prd-starter`                  | **Setup wizard** - First-time configuration |
| `/ralph-hitl`                         | Single iteration - Learn the flow           |
| `/ralph-coordinator-event`            | Start PM (parallel mode)                    |
| `/ralph-coordinator-single`           | Start PM (sequential mode)                  |
| `/ralph-worker-event --agent <name>`  | Start worker (parallel)                     |
| `/ralph-worker-single --agent <name>` | Start worker (sequential)                   |
| `/cancel-ralph`                       | Cancel active session                       |

---

## Documentation

**Complete documentation:** [docs/README.md](docs/README.md)

| Quick Start | Wizard Reference | Core | Architecture |
| ----------- | ---------------- | ---- | ------------ |
| [Getting Started](docs/quick-start/getting-started.md) | [Wizard Presets](docs/wizard/wizard-presets.md) | [Framework Architecture](docs/core/architecture.md) | [Event-Driven Architecture](docs/powershell/v2-architecture.md) |
| [Framework Guide](docs/quick-start/framework.md) | [Skill Catalog](docs/wizard/wizard-skill-catalog.md) | [Orchestration Modes](docs/core/orchestration-modes.md) | [Event Sourcing & Actor Model](docs/powershell/v2-architecture.md) |
| [PRD Starter Walkthrough](docs/quick-start/prd-starter.md) | [PRD Starter Deep Dive](docs/wizard/prd-starter-deep-dive.md) | [PowerShell Scripts Guide](.claude/scripts/README.md) | |

---

## References

Inspired by and built upon:

- [Ralph Wiggum Plugin](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum) - Official Anthropic multi-agent framework
- [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD) - Breakthrough Make And Deliver
- [Claude CLI](https://docs.anthropic.com/en/docs/claude-cli) - Command-line interface
- [MCP Protocol](https://modelcontextprotocol.io/) - Model Context Protocol

---

## License

MIT License - See [LICENSE](LICENSE) for details.
