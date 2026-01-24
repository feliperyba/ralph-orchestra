# Ralph Orchestra Documentation

Welcome to the Ralph Orchestra documentation. Start with the **Quick Start** guide below.

## Quick Start (New Users)

| Document | Description | Time |
|----------|-------------|------|
| **[Getting Started](./getting-started.md)** | Install and run in 5 minutes | 5 min |
| **[Framework Guide](./framework.md)** | Understand framework vs templates | 5 min |
| **[PRD Starter Wizard](./prd-starter.md)** | Complete wizard walkthrough | 10 min |

## Core Documentation

| Document | Description |
|----------|-------------|
| **[Framework Architecture](./architecture.md)** | System design, components, internals |
| **[Orchestration Modes](./orchestration-modes.md)** | Event-driven, Sequential, Polling, HITL |
| **[Configuration](./configuration.md)** | PRD format, settings, tuning |

## Wizard Reference

| Document | Description |
|----------|-------------|
| **[Wizard Presets](./wizard-presets.md)** | All 14+ quick-start presets |
| **[Skill Catalog](./wizard-skill-catalog.md)** | Browse 100+ available skills |
| **[Sub-agent Catalog](./wizard-subagent-catalog.md)** | All 28+ sub-agents explained |

## Advanced Topics

| Document | Description |
|----------|-------------|
| **[Extending](./extending.md)** | Creating custom agents and skills |
| **[Protocols](./protocols.md)** | Communication protocols |
| **[Monitoring](./monitoring.md)** | Dashboard, logs, troubleshooting |

## PowerShell Orchestration (Technical)

> **Note:** This section covers the PowerShell scripts that implement Ralph's orchestration infrastructure.

| Document | Description |
|----------|-------------|
| **[PowerShell Architecture](./powershell-architecture.md)** | Core orchestration architecture overview |
| **[Event-Driven Mode](./powershell-event-mode.md)** | Event-driven parallel mode deep dive |
| **[Sequential Mode](./powershell-sequential-mode.md)** | Sequential handoff mode deep dive |
| **[Message System](./powershell-messaging.md)** | Message queue and pipe transport |
| **[Configuration Reference](./powershell-configuration.md)** | Environment variables and settings |
| **[Testing Guide](./powershell-testing.md)** | Test scripts and troubleshooting |
| **[Scripts README](../.claude/scripts/README.md)** | Quick script reference |

## Best Practices

| Document | Description |
|----------|-------------|
| **[Sub-agent Best Practices](./subagent-best-practices.md)** | Using sub-agents effectively |
| **[Skills Best Practices](./skills-best-practices.md)** | Creating quality skills |

## Reference

| Document | Description |
|----------|-------------|
| **[Skill Mapping](./skill-mapping.md)** | Skill-to-task mapping |
| **[Architecture Flow Guide](./architecture-flow-guide.md)** | Flow diagrams |
| **[Research Sources](./research-sources.md)** | Research references |

## Workflow Documentation

| Document | Description |
|----------|-------------|
| **[Workflows README](./workflows/README.md)** | Workflow template standards |
| **[Workflow Template](./workflows/_template.md)** | Template structure |

---

## Documentation Structure

```
docs/
├── README.md                    # This file - documentation index
│
├── Quick Start/
│   ├── getting-started.md       # Install and run in 5 minutes
│   ├── framework.md             # Understand framework vs templates
│   └── prd-starter.md           # Complete wizard walkthrough
│
├── Core/
│   ├── architecture.md          # System design and components
│   ├── orchestration-modes.md   # All orchestration modes
│   └── configuration.md         # PRD format and settings
│
├── Wizard Reference/
│   ├── wizard-presets.md        # All 14+ presets
│   ├── wizard-skill-catalog.md  # 100+ skills
│   └── wizard-subagent-catalog.md # 28+ sub-agents
│
├── Advanced/
│   ├── extending.md             # Custom agents and skills
│   ├── protocols.md             # Communication protocols
│   └── monitoring.md            # Dashboard and troubleshooting
│
├── PowerShell/                  # PowerShell orchestration (technical)
│   ├── powershell-architecture.md   # Orchestration architecture overview
│   ├── powershell-event-mode.md      # Event-driven mode deep dive
│   ├── powershell-sequential-mode.md  # Sequential mode deep dive
│   ├── powershell-messaging.md        # Message system documentation
│   ├── powershell-configuration.md    # Configuration reference
│   └── powershell-testing.md          # Testing and debugging
│
├── Best Practices/
│   ├── subagent-best-practices.md
│   └── skills-best-practices.md
│
├── Reference/
│   ├── skill-mapping.md
│   ├── architecture-flow-guide.md
│   └── research-sources.md
│
└── workflows/
    ├── README.md                # Workflow standards
    └── _template.md             # Template structure
```

---

## Key Concepts

### Framework vs Templates

**Ralph Orchestra** is a framework - an orchestration infrastructure that works with any technology stack.

The included `agents/` and `.claude/presets/` are **templates** for learning. Always use the wizard (`/ralph-prd-starter`) to generate custom configurations.

See [Framework Guide](./framework.md) for details.

### Orchestration Modes

| Mode | Parallelism | Token Usage | Best For |
|------|-------------|-------------|----------|
| **Event-Driven** | Full (5 agents) | Medium | Production, speed |
| **Sequential** | None (1 at a time) | Low (~70% savings) | Token efficiency |
| **HITL** | Single iteration | Standard | Learning, debugging |

See [Orchestration Modes](./orchestration-modes.md) for details.

### Agent Roles

The framework supports configurable agent roles:

| Role | Purpose | Configured Via |
|------|---------|---------------|
| **Coordinator** (PM) | Task assignment, retrospectives | Wizard |
| **Worker** (Developer) | Feature implementation | Wizard |
| **Specialist** | Domain-specific work | Wizard (optional) |
| **Validator** (QA) | Testing, validation | Wizard |
| **Designer** | Specifications, research | Wizard (optional) |

Agent names, skills, and MCP servers are all configured during wizard setup.

---

## Getting Help

1. **New to Ralph Orchestra?** Start with [Getting Started](./getting-started.md)
2. **Setting up a project?** Run `/ralph-prd-starter` and see [PRD Starter Guide](./prd-starter.md)
3. **Understanding how it works?** Read [Framework Guide](./framework.md) and [Architecture](./architecture.md)
4. **Customizing?** See [Extending](./extending.md)

---

## External Resources

- [Claude CLI Documentation](https://docs.anthropic.com/en/docs/claude-cli)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [Ralph Wiggum Plugin](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum)
