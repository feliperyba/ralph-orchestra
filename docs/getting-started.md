# Getting Started with Ralph Orchestra

This guide will help you get started with Ralph Orchestra - an agnostic framework for multi-agent AI development.

## Quick Start (5 minutes)

**Step 1: Install Ralph Orchestra**

```bash
git clone https://github.com/feliperyba/ralph-orchestra
cd ralph-orchestra
npm install
```

**Step 2: Run the PRD Starter Wizard**

```
/ralph-prd-starter
```

**Step 3: Choose Your Mode**

| Mode | Time | Best For |
|------|------|----------|
| **Quick Start** | 5 min | New projects, use a preset |
| **Standard** | 15 min | Custom configuration with guidance |
| **Expert** | 30+ min | Full control over every setting |

**Step 4: Start Your Agents**

After the wizard completes, start your configured agents:

```powershell
# Event-driven mode (parallel, recommended)
.\.claude\scripts\ralph-event-session.ps1

# OR Sequential mode (token-efficient)
.\.claude\scripts\ralph-single-session.ps1
```

That's it! Your agents will work autonomously until all PRD tasks are complete.

---

## Prerequisites

- **[Claude CLI](https://docs.anthropic.com/en/docs/claude-cli)** installed and authenticated
- **PowerShell 5.1+** (Windows) or Bash (Linux/macOS)
- Your project's runtime (Node.js, Python, Rust, etc.)

---

## The PRD Starter Workflow

The PRD Starter wizard is the recommended way to configure Ralph Orchestra for any project.

### What the Wizard Does

1. **Project Identification** - Project type, name, description
2. **Agent Selection** - Choose which agents to enable (PM, Developer, Specialist, QA, Designer)
3. **Skill Configuration** - Assign skills to each agent based on your tech stack
4. **Orchestration Mode** - Event-driven, Sequential, or HITL
5. **Technology Stack** - Runtime, package manager, framework
6. **Quality Standards** - Type checking, linting, testing, build commands
7. **Initial PRD** - Define features with acceptance criteria
8. **File Generation** - Creates all configuration files

### What Gets Generated

| File | Purpose |
|------|---------|
| `agents/{name}/AGENT.md` | Agent definitions with skills |
| `.claude/settings.{name}.json` | MCP server configuration |
| `prd.json` | Your product requirements document |
| `.claude/scripts/init-project.{sh,ps1}` | Project initialization script |

### Preset Options

Quick Start mode includes presets for:

- **Game Development** - Indie Game Dev, Game Studio, Mobile Game, Multiplayer Arena
- **Web Applications** - Modern Web App, Full Stack SaaS, Dashboard Analytics
- **Business** - E-Commerce Store, SaaS Product, Enterprise Suite
- **Technical** - API Server, Data/ML Pipeline, DevOps/Infrastructure

See [Wizard Presets](./wizard-presets.md) for details.

---

## Understanding Orchestration Modes

After wizard configuration, choose how your agents run:

### Event-Driven Mode (Recommended)

All agents run in parallel with message-based communication:

```powershell
.\.claude\scripts\ralph-event-session.ps1
```

**Benefits:** Parallel execution, named pipe speed (< 10ms message delivery)

### Sequential Mode (Token-Efficient)

One agent at a time with orchestrated handoffs:

```powershell
.\.claude\scripts\ralph-single-session.ps1
```

**Benefits:** ~70% lower token usage, simpler debugging

### HITL Mode (Learning)

Single iteration for understanding the flow:

```
/ralph-hitl
```

**Benefits:** Full visibility, learn before going autonomous

See [Orchestration Modes](./orchestration-modes.md) for detailed comparison.

---

## Framework vs Templates

**Important:** Ralph Orchestra is a framework, not a template. The wizard generates custom configurations.

### What is the Framework?

The framework provides:
- Communication protocols (named pipes, message queues)
- Agent lifecycle management (watchdog, health monitoring)
- Quality enforcement (feedback loops, code gates)
- Modular skill system (compose capabilities)
- PRD Starter wizard (generate configurations)

### What are Templates?

Templates are learning examples:
- Agent definitions in `agents/` - Show structure, don't use directly
- Presets in `.claude/presets/` - Starting points for common projects
- Skills in `.claude/skills/` - Reusable building blocks

**Always run the wizard** - don't copy templates directly.

---

## Interface Options

### PowerShell Scripts (Recommended)

Full orchestration with automatic session management:

```powershell
# Event-driven (parallel)
.\.claude\scripts\ralph-event-session.ps1

# Sequential (token-efficient)
.\.claude\scripts\ralph-single-session.ps1
```

### Claude CLI Commands

Manual terminal setup for fine-grained control:

```bash
# Terminal 1: PM Coordinator
/ralph-coordinator-event

# Terminal 2-N: Workers (names from your wizard config)
/ralph-worker-event --agent developer
/ralph-worker-event --agent specialist
/ralph-worker-event --agent qa
```

**Note:** Agent names depend on your wizard configuration. The default templates include: `pm`, `developer`, `techartist`, `qa`, `gamedesigner` - but you configure these during setup.

---

## Controlling Sessions

### Starting

```powershell
.\.claude\scripts\ralph-event-session.ps1
```

### Stopping

- Press `Ctrl+C` in the watchdog terminal
- Run `/cancel-ralph` in any agent terminal
- Agents auto-stop when all tasks complete

### Max Iterations

Set a safety limit:

```powershell
$env:RALPH_MAX_ITERATIONS = 100
.\.claude\scripts\ralph-event-session.ps1
```

---

## Git Worktrees (Parallel Development)

Agents can work simultaneously in isolated worktrees:

- Each agent gets their own working tree
- No merge conflicts between parallel workers
- System creates worktrees automatically when needed

---

## Next Steps

- **[PRD Starter Guide](./prd-starter.md)** - Complete wizard walkthrough
- **[Orchestration Modes](./orchestration-modes.md)** - Deep dive into each mode
- **[Framework Architecture](./architecture.md)** - System design and internals
- **[Configuration](./configuration.md)** - PRD format and advanced settings
- **[Wizard Presets](./wizard-presets.md)** - All available presets
- **[Skill Catalog](./wizard-skill-catalog.md)** - Browse available skills
