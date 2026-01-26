# Ralph Orchestra Documentation

Welcome to the Ralph Orchestra documentation. Start with the **Quick Start** guide below.

## Quick Start (New Users)

| Document | Description | Time |
|----------|-------------|------|
| **[Getting Started](./quick-start/getting-started.md)** | Install and run in 5 minutes | 5 min |
| **[Framework Guide](./quick-start/framework.md)** | Understand framework vs templates | 5 min |
| **[PRD Starter Wizard](./quick-start/prd-starter.md)** | Complete wizard walkthrough | 10 min |

## Core Documentation

| Document | Description |
|----------|-------------|
| **[Framework Architecture](./core/architecture.md)** | System design, components, internals |
| **[Orchestration Modes](./core/orchestration-modes.md)** | Event-Driven V2, Sequential, HITL |
| **[Configuration](./core/configuration.md)** | PRD format, settings, tuning |

## Wizard Reference

| Document | Description | Audience |
|----------|-------------|----------|
| **[Wizard Presets](./wizard/wizard-presets.md)** | All 14+ quick-start presets | All users |
| **[Skill Catalog](./wizard/wizard-skill-catalog.md)** | Browse 100+ available skills | All users |
| **[Sub-agent Catalog](./wizard/wizard-subagent-catalog.md)** | All 28+ sub-agents explained | All users |
| **[PRD Starter Deep Dive](./wizard/prd-starter-deep-dive.md)** | Technical deep dive on wizard internals | Developers, contributors |

## Advanced Topics

| Document | Description |
|----------|-------------|
| **[Extending](./advanced/extending.md)** | Creating custom agents and skills |
| **[Protocols](./advanced/protocols.md)** | Communication protocols |
| **[Monitoring](./advanced/monitoring.md)** | Dashboard, logs, troubleshooting |

## PowerShell Orchestration (Technical)

> **Note:** This section covers the PowerShell scripts that implement Ralph's orchestration infrastructure.

| Document | Description |
|----------|-------------|
| **[PowerShell Guide](./powershell/README.md)** | PowerShell documentation index |
| **[V2 Architecture](./powershell/v2-architecture.md)** | ⭐ NEW: Event Sourcing, Actor Model, CQRS |
| **[PowerShell Architecture](./powershell/powershell-architecture.md)** | Core orchestration architecture overview |
| **[Event-Driven Mode](./powershell/powershell-event-mode.md)** | Event-driven parallel mode deep dive |
| **[Sequential Mode](./powershell/powershell-sequential-mode.md)** | Sequential handoff mode deep dive |
| **[Message System](./powershell/powershell-messaging.md)** | V2 messaging: event sourcing, named pipes |
| **[Configuration Reference](./powershell/powershell-configuration.md)** | Environment variables and settings |
| **[Testing Guide](./powershell/powershell-testing.md)** | Test scripts and troubleshooting |
| **[Scripts README](../.claude/scripts/README.md)** | Quick script reference with V2 modules |

## Best Practices

| Document | Description |
|----------|-------------|
| **[Sub-agent Best Practices](./best-practices/subagent-best-practices.md)** | Using sub-agents effectively |
| **[Skills Best Practices](./best-practices/skills-best-practices.md)** | Creating quality skills |

## Reference

| Document | Description |
|----------|-------------|
| **[Skill Mapping](./reference/skill-mapping.md)** | Skill-to-task mapping |
| **[Architecture Flow Guide](./reference/architecture-flow-guide.md)** | Flow diagrams |
| **[Research Sources](./reference/research-sources.md)** | Research references |
| **[Claude Code Reference](./reference/claude-code-reference.md)** | Claude Code CLI guide |
| **[Prompt Engineering Reference](./reference/prompt-engineering-reference.md)** | Prompt engineering guide |

## Workflow Documentation

| Document | Description |
|----------|-------------|
| **[Workflows README](./workflows/README.md)** | Workflow template standards |
| **[Workflow Template](./workflows/_template.md)** | Template structure |

---

## Documentation Structure

```
docs/
├── README.md                           # This file - documentation index
│
├── quick-start/                        # New user onboarding
│   ├── README.md                       # Section index
│   ├── getting-started.md              # Install and run in 5 minutes
│   ├── framework.md                    # Framework vs templates
│   └── prd-starter.md                  # Complete wizard walkthrough
│
├── core/                               # Essential framework documentation
│   ├── README.md                       # Section index
│   ├── architecture.md                 # System design and components
│   ├── orchestration-modes.md          # All orchestration modes
│   └── configuration.md                # PRD format and settings
│
├── wizard/                             # PRD Starter wizard reference
│   ├── README.md                       # Section index
│   ├── prd-starter-deep-dive.md        # Technical deep dive on wizard internals
│   ├── wizard-presets.md               # All 14+ presets
│   ├── wizard-skill-catalog.md         # 100+ skills
│   └── wizard-subagent-catalog.md      # 28+ sub-agents
│
├── advanced/                           # Extension and customization
│   ├── README.md                       # Section index
│   ├── extending.md                    # Custom agents and skills
│   ├── protocols.md                    # Communication protocols
│   └── monitoring.md                   # Dashboard and troubleshooting
│
├── powershell/                         # PowerShell orchestration (technical)
│   ├── README.md                       # Section index
│   ├── powershell-architecture.md      # Orchestration architecture overview
│   ├── powershell-event-mode.md        # Event-driven mode deep dive
│   ├── powershell-sequential-mode.md   # Sequential mode deep dive
│   ├── powershell-messaging.md         # Message system documentation
│   ├── powershell-configuration.md     # Configuration reference
│   └── powershell-testing.md           # Testing and debugging
│
├── best-practices/                     # Development best practices
│   ├── README.md                       # Section index
│   ├── subagent-best-practices.md      # Using sub-agents effectively
│   └── skills-best-practices.md        # Creating quality skills
│
├── reference/                          # Reference materials
│   ├── README.md                       # Section index
│   ├── skill-mapping.md                # Skill-to-task mapping
│   ├── architecture-flow-guide.md      # Flow diagrams
│   ├── research-sources.md             # Research references
│   ├── claude-code-reference.md        # Claude Code CLI guide
│   └── prompt-engineering-reference.md # Prompt engineering guide
│
└── workflows/                          # Agent workflow documentation
    ├── README.md                       # Workflow standards
    └── _template.md                    # Template structure
```

---

## Key Concepts

### Framework vs Templates

**Ralph Orchestra** is a framework - an orchestration infrastructure that works with any technology stack.

The included `agents/` and `.claude/presets/` are **templates** for learning. Always use the wizard (`/ralph-prd-starter`) to generate custom configurations.

See [Framework Guide](./quick-start/framework.md) for details.

### Orchestration Modes

| Mode | Parallelism | Token Usage | Best For |
|------|-------------|-------------|----------|
| **Event-Driven V2** | Full (5 agents) | Medium | Production, speed |
| **Sequential** | None (1 at a time) | Low (~70% savings) | Token efficiency |
| **HITL** | Single iteration | Standard | Learning, debugging |

See [Orchestration Modes](./core/orchestration-modes.md) for details.

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

1. **New to Ralph Orchestra?** Start with [Getting Started](./quick-start/getting-started.md)
2. **Setting up a project?** Run `/ralph-prd-starter` and see [PRD Starter Guide](./quick-start/prd-starter.md)
3. **Understanding how it works?** Read [Framework Guide](./quick-start/framework.md) and [Architecture](./core/architecture.md)
4. **Customizing?** See [Extending](./advanced/extending.md)

---

## External Resources

- [Claude CLI Documentation](https://docs.anthropic.com/en/docs/claude-cli)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [Ralph Wiggum Plugin](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum)
