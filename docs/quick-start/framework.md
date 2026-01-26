# Ralph Orchestra Framework

Understanding what Ralph Orchestra is and how to use it effectively.

## What is Ralph Orchestra?

Ralph Orchestra is an **agnostic orchestration framework** for multi-agent AI development. It is NOT a hard-coded template for any specific technology stack or project type.

### The Framework Core

The framework provides the infrastructure for coordinating AI agents:

| Component | Purpose |
|-----------|---------|
| **Communication Protocols** | Named pipes, event sourcing, ActorSupervisor |
| **Agent Lifecycle** | ActorSupervisor with auto-restart, health monitoring, graceful shutdown |
| **Quality Enforcement** | Feedback loops, code gates, mandatory validation |
| **Modular Skill System** | Compose capabilities from 100+ reusable skills |
| **PRD Starter Wizard** | Generate custom configurations for your project |
| **Orchestration Modes** | Event-Driven V2, Sequential, HITL |

These components work with ANY technology stack - Node.js, Python, Rust, Go, Java, .NET, or anything else.

### What Makes It Different

| Aspect | Ralph Orchestra | Hard-Coded Frameworks |
|--------|-----------------|----------------------|
| **Technology** | Agnostic - works with any stack | Tied to specific tech (e.g., R3F, Django) |
| **Configuration** | Wizard generates custom setup | Fixed template, copy-paste |
| **Agents** | You define roles and skills | Pre-defined agent types |
| **Skills** | Modular, composable | Built-in, hard-coded |
| **Extensibility** | Add custom agents/skills easily | Requires framework changes |

---

## The Included Templates

Ralph Orchestra includes **templates** that serve as learning examples and starting points. These are NOT the main product.

### Agent Templates

Located in `agents/`:

```
agents/
├── pm/AGENT.md          # Project Manager template
├── developer/AGENT.md   # Developer template
├── techartist/AGENT.md  # Technical Artist template (games)
├── qa/AGENT.md          # QA template
└── gamedesigner/AGENT.md # Game Designer template (games)
```

**Purpose:** Show how to structure an agent definition. Use as reference when creating custom agents.

**DO NOT:** Copy these directly to your project. They're examples.

**DO:** Run `/ralph-prd-starter` to generate customized agents.

### Preset Configurations

Located in `.claude/presets/`:

| Category | Presets |
|----------|---------|
| **Games** | `indie-game-dev.json`, `game-studio.json`, `mobile-game.json`, `multiplayer-arena.json` |
| **Web** | `modern-web-app.json`, `full-stack-saas.json`, `dashboard-analytics.json` |
| **Business** | `ecommerce-store.json`, `saas-product.json`, `enterprise-suite.json` |
| **Technical** | `api-server.json`, `data-ml-pipeline.json`, `devops-infrastructure.json` |

**Purpose:** Quick-start configurations for common project types.

**DO NOT:** Edit preset files directly. Your changes will be lost on updates.

**DO:** Use the wizard's Quick Start mode to select a preset, then customize.

### Skill Library

Located in `.claude/skills/`:

- 100+ modular skills covering development workflows
- Organized by category: `dev-*`, `qa-*`, `pm-*`, `shared-*`, etc.
- Each skill is self-contained with YAML frontmatter

**Purpose:** Reusable building blocks for agent capabilities.

**DO:** Reference these when understanding available capabilities.
**DO:** Use them via the wizard's skill selection interface.
**DO NOT:** Manually copy skill files unless creating custom skills.

---

## How to Use Ralph Orchestra

### Correct Workflow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CORRECT RALPH ORCHESTRA WORKFLOW                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   1. Run /ralph-prd-starter                                        │
│                                                                     │
│   2. Answer questions about your project                           │
│                                                                     │
│   3. Review and confirm configuration                              │
│                                                                     │
│   4. Wizard generates custom files                                 │
│                                                                     │
│   5. Start agents and let them work                                │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Incorrect Workflow

```
┌─────────────────────────────────────────────────────────────────────┐
│                      ❌ INCORRECT WORKFLOW                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   1. Copy agents/techartist/AGENT.md to your project               │
│                                                                     │
│  2. Edit .claude/settings.techartist.json manually                 │
│                                                                     │
│   3. Run agents with copied template                               │
│                                                                     │
│   Result: Configuration doesn't match YOUR project needs!          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## What Gets Generated

When you run the wizard, it creates files **customized for your project**:

### Generated Agent Definitions

```markdown
<!-- agents/your-custom-developer/AGENT.md -->

---
name: your-custom-developer
role: developer
orchestration: event-driven
version: 1.0.0
---

# Developer Agent

This agent is configured for:
- Runtime: Python 3.11
- Framework: FastAPI
- Database: PostgreSQL
- Testing: pytest + coverage

## Skills
- dev-typescript-typescript-basics (if TS was selected)
- dev-python-best-practices (if Python was selected)
- dev-validation-feedback-loops
- (custom skills based on your project)
```

### Generated Settings

```json
{
  "mcpServers": {
    "github": { /* your repo config */ },
    "filesystem": { /* your project paths */ }
  },
  "skills": [
    "dev-python-best-practices",
    "dev-validation-feedback-loops"
    // only skills relevant to YOUR project
  ]
}
```

### Generated PRD

```json
{
  "projectName": "Your Project",
  "techStack": {
    "runtime": "python",
    "framework": "fastapi"
  },
  "agents": {
    "developer": {
      "enabled": true,
      "skills": [ /* your selected skills */ ]
    }
  },
  "items": [ /* your features */ ]
}
```

---

## Understanding Agent Roles

The framework supports **configurable agent roles**. The default templates include:

| Role | Template Name | Purpose | Can Be Renamed? |
|------|---------------|---------|----------------|
| Coordinator | `pm` | Task assignment, retrospectives | Yes |
| Implementer | `developer` | Feature implementation | Yes |
| Specialist | `techartist` | Domain-specific work | Yes |
| Validator | `qa` | Testing, validation | Yes |
| Designer | `gamedesigner` | Specifications, research | Yes |

**Important:** These are template names. During wizard setup, you can:
- Enable/disable agents based on your needs
- Rename agents to match your domain
- Assign different skills to each agent
- Create custom agent types

### Example: Non-Game Project

For a data science project, you might configure:

| Agent Name | Role | Skills |
|------------|------|--------|
| `coordinator` | PM | pm-workflow, task-research |
| `implementation` | Developer | dev-python-best-practices, dev-r3f-r3f-fundamentals |
| `data-specialist` | Custom | pandas-manipulation, scikit-learn-training |
| `validation` | QA | qa-code-review, qa-validation-workflow |

---

## Customization Guide

### Creating Custom Agents

1. Run `/ralph-prd-starter`
2. Choose **Standard** or **Expert** mode
3. When prompted for agents, select **Custom**
4. Define your agent's:
   - Name and role
   - Primary responsibility
   - Skills to include
   - MCP servers needed

### Creating Custom Skills

1. Browse `.claude/skills/` to understand skill structure
2. Use `.claude/templates/skill-template.md` as a starting point
3. Create your skill in a local directory
4. Reference it during wizard configuration (Expert mode)

### Creating Custom Presets

1. Copy an existing preset from `.claude/presets/`
2. Modify tech stack, agents, and skills
3. Save as `my-preset.json`
4. Select during wizard Quick Start mode

---

## See Also

- [PRD Starter Guide](./prd-starter.md) - Complete wizard walkthrough
- [Wizard Presets](../wizard/wizard-presets.md) - All available presets
- [Skill Catalog](../wizard/wizard-skill-catalog.md) - Browse available skills
- [Extending](../advanced/extending.md) - Creating custom agents and skills
