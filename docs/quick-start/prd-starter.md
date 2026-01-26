# PRD Starter - Project Setup Wizard

The PRD Starter is an interactive setup wizard that generates custom agents, skills, and configuration for any project type.

## Overview

PRD Starter guides you through an 8-phase workflow to create a complete Ralph Orchestra setup tailored to your specific needs:

- **Project-Agnostic** - Works with web apps, games, mobile, backend, data, DevOps, or custom projects
- **Custom Agents** - Define N agents with any roles, skills, and permissions
- **Cross-Platform** - Works on Windows, macOS, and Linux
- **Research-Backed** - Researches best practices between phases
- **State Persistence** - Resume from any phase if interrupted

## Quick Start

```
/ralph-prd-starter
```

Or use the skill directly:

```
/skill ralph-prd-starter
```

## 8-Phase Workflow

### Phase 1: Project Identification

Define your project's basic information:

| Field | Description | Example |
|-------|-------------|---------|
| Project Type | Application category | Web Application, Game Development, Backend API |
| Project Name | Human-readable name | "My E-Commerce Site" |
| Project ID | Machine-readable identifier | `my-ecommerce-site` |
| Description | Brief project summary | "A modern e-commerce platform with real-time inventory" |

### Phase 2: Agent Configuration

Define your custom agents:

| Field | Description | Example |
|-------|-------------|---------|
| Agent Name | Human-readable name | "Frontend Developer" |
| Agent ID | Machine-readable identifier | `frontend-dev` |
| Role | Primary responsibility | "Implements React components and state management" |
| Skills | List of skill IDs | `react-hooks`, `typescript-patterns`, `vitest-testing` |
| MCP Servers | Available MCP servers | `github`, `filesystem`, `web-search` |

You can define any number of agents with custom roles and permissions.

### Phase 3: Workflow Pattern

Choose how agents collaborate:

| Pattern | Description | Best For |
|---------|-------------|----------|
| **Waterfall** | Sequential handoffs | Clear dependencies, smaller teams |
| **Collaborative** | Parallel with messaging | Independent workstreams, faster delivery |
| **Autonomous** | Self-coordinating | Mature teams, well-defined boundaries |

### Phase 4: Orchestration Mode

Select the coordination mechanism:

| Mode | Description | Token Efficiency | Parallelism |
|------|-------------|------------------|-------------|
| **Event-Driven** | Named pipes + message queues | Medium | Full |
| **Sequential** | Handoff-based | High | None |
| **HITL** | Human-in-the-loop | Standard | Single |

### Phase 5: Technology Stack

Define your project's technologies:

| Category | Options |
|----------|---------|
| Frontend | React, Vue, Svelte, Angular, None |
| Backend | Node.js, Python, Go, Rust, None |
| Database | PostgreSQL, MongoDB, MySQL, Redis, None |
| Build Tools | Vite, Webpack, esbuild, None |
| Testing | Vitest, Jest, Playwright, Cypress, None |

### Phase 6: Quality Standards

Set quality gates:

| Standard | Options |
|----------|---------|
| TypeScript Mode | Strict, Moderate, Loose, None |
| Test Coverage Target | 80%, 60%, 40%, None |
| Linting | ESLint, Prettier, Both, None |
| CI/CD | GitHub Actions, GitLab CI, None |

### Phase 7: Initial Features

Define your starting feature set:

For each feature:
- **Title** - Human-readable name
- **Description** - What the feature does
- **Acceptance Criteria** - Pass/fail conditions
- **Priority** - high, medium, low
- **Target Agent** - Which agent implements it

### Phase 8b: Deep Research (All Modes)

The wizard launches the `pm-research-specialist` sub-agent to:

1. **Research similar projects** - Find and analyze similar projects on GitHub
2. **Identify best practices** - Tech stack specific recommendations
3. **Generate clarifying questions** - 5-10 targeted questions based on research gaps
4. **Present findings** - User reviews research and answers questions

**User Review Gate:** User can request more research or modify questions before continuing.

### Phase 8c: GDD Creation (Game Projects Only)

For game development projects, the wizard launches the `gamedesigner-thermite-facilitator` to:

1. **Run Thermite Design Session** - Boardroom Retreat with expert personas
2. **Create design decisions** - DEC-NNN format with rationale
3. **Document open questions** - OQ-NNN format with priority
4. **Establish design pillars** - Core design principles

**Output files:**
- `docs/design/decision_log.md` - All design decisions
- `docs/design/open_questions.md` - Unresolved questions
- `docs/design/gdd.md` - GDD summary

**User Review Gate:** User can request additional Thermite sessions or modify GDD.

### Phase 8d: PRD Creation (All Modes)

The wizard launches the `pm-prd-creator` agent to:

1. **Load all inputs** - Research data, GDD (if game), user answers, initial features
2. **Apply PM expertise** - Use task selection and organization skills
3. **Generate prd.json** - Properly structured with dependencies, priorities, agent assignments
4. **Present for review** - User reviews complete PRD before approval

**Critical:** The PRD is created by a PM agent with full PM expertise, not by the generator script.

**User Review Gate:** User can approve, request modifications, or request new research.

### Phase 9: Review and Confirm

Review all selections and confirm generation. The wizard will display:

- Project summary
- Agent list with roles
- Feature breakdown by agent
- Technology stack summary

Confirm to generate all files, or go back to adjust.

## Generated Files

After confirmation, the following files are created:

### For Each Agent

```
agents/{agent-id}/
└── AGENT.md              # Agent behavior definition
```

```markdown
# YOU ARE THE {AGENT NAME} AGENT

## Your Role
{role description}

## When You're Used
- {trigger condition 1}
- {trigger condition 2}

## Your Workflow
1. {step 1}
2. {step 2}
3. {step 3}

## Quality Standards
{quality requirements}
```

### Per-Agent Settings

```
.claude/settings.{agent-id}.json
```

```json
{
  "mcpServers": {
    "filesystem": { ... },
    "github": { ... },
    ...
  }
}
```

### Project Files

```
prd.json                 # Initial PRD with features (created by PM agent in Phase 8d)
docs/research-summary.md # Research findings from pm-research-specialist
docs/design/             # GDD files (game projects only)
├── decision_log.md      # Design decisions from Thermite session
├── open_questions.md    # Unresolved design questions
└── gdd.md              # GDD summary
```

### Updated Scripts

The following scripts are updated to include your custom agents:

- `.claude/scripts/watchdog-event.ps1` - Adds agents to ValidateSet
- `.claude/scripts/watchdog-single.ps1` - Adds agents to handoff pattern
- `.claude/scripts/message-queue.ps1` - Adds agents to message routing
- `.claude/scripts/ralph-event-session.ps1` - Adds agent directories
- `.claude/scripts/ralph-single-session.ps1` - Adds agent validation

## State Persistence

Progress is saved in `.claude/session/prd-starter-state.json`:

```json
{
  "version": "4.0.0",
  "startedAt": "2026-01-26T10:00:00Z",
  "completedAt": null,
  "currentPhase": "deep_research",
  "phases": {
    "project_identification": {
      "completed": true,
      "data": {
        "projectType": "Web Application",
        "projectName": "My App",
        "projectId": "my-app",
        "description": "A web application"
      }
    },
    "agent_configuration": {
      "completed": false,
      "data": null
    }
  },
  "researchData": {
    "similarProjects": [...],
    "bestPractices": [...],
    "questionsAsked": [...],
    "questionsAnswered": [...]
  },
  "gddData": {
    "designDecisions": [...],
    "openQuestions": [...],
    "designPillars": [...]
  },
  "prdSpecification": {
    "refinedFeatures": [...],
    "dependencies": [...]
  }
}
```

### Resuming

To resume from where you left off, simply invoke the command again:

```
/ralph-prd-starter
```

The wizard will detect the state file and continue from the last incomplete phase.

### Reset State

To start over:

```powershell
# Windows
.\.claude\scripts\prd-starter-generator.ps1 -Action reset

# Mac/Linux
python3 .claude/scripts/prd-starter-generator.py --action reset
```

## Manual Generator Invocation

After the state file is complete, you can manually invoke the generator:

### Windows (PowerShell)

```powershell
.\.claude\scripts\prd-starter-generator.ps1 `
    -Action generate `
    -StateFile .claude\session\prd-starter-state.json `
    -Verbose
```

### Mac/Linux (Bash)

```bash
python3 .claude/scripts/prd-starter-generator.py \
    --action generate \
    --state .claude/session/prd-starter-state.json \
    --verbose
```

## Requirements

- Python 3.8+
- Jinja2: `pip install jinja2`
- PyYAML: `pip install pyyaml`
- JSONSchema: `pip install jsonschema`

Or install all dependencies:

```bash
pip install -r .claude/scripts/prd-starter-requirements.txt
```

## Examples

### Web Application Setup

```
Phase 1: Web Application → React, TypeScript
Phase 2: Frontend Developer (React + TS), QA (Playwright)
Phase 3: Collaborative workflow
Phase 4: Event-driven orchestration
Phase 5: Vite, Vitest, ESLint
Phase 6: TypeScript strict, 80% coverage
Phase 7: Auth feature, Dashboard feature
Phase 8: Generate
```

**Generated:**
- `agents/frontend-dev/AGENT.md` - React/TypeScript specialist
- `agents/qa/AGENT.md` - Playwright testing specialist
- `.claude/settings.frontend-dev.json` - MCP config with GitHub, filesystem
- `.claude/settings.qa.json` - MCP config with Playwright, filesystem
- `prd.json` - Initial feature backlog

### Game Development Setup

```
Phase 1: Game Development → Three.js, React Three Fiber
Phase 2: Game Developer (R3F), Tech Artist (shaders), QA (E2E)
Phase 3: Collaborative workflow
Phase 4: Event-driven orchestration
Phase 5: Vite, Playwright
Phase 6: TypeScript strict, 80% coverage
Phase 7: Player controller, Physics, UI overlay
Phase 8: Generate
```

**Generated:**
- `agents/game-dev/AGENT.md` - R3F game mechanics
- `agents/tech-artist/AGENT.md` - Shader and VFX creation
- `agents/qa/AGENT.md` - E2E gameplay testing
- `prd.json` - Game feature backlog

### Backend API Setup

```
Phase 1: Backend API → Node.js, Express
Phase 2: Backend Developer (Node.js), QA (integration tests)
Phase 3: Waterfall workflow
Phase 4: Sequential orchestration
Phase 5: Jest, Supertest
Phase 6: TypeScript strict, 80% coverage
Phase 7: Auth endpoints, User CRUD, WebSocket support
Phase 8: Generate
```

**Generated:**
- `agents/backend-dev/AGENT.md` - Node.js/Express API development
- `agents/qa/AGENT.md` - Integration testing
- `prd.json` - API endpoint backlog

## Troubleshooting

### Wizard Won't Start

**Symptom:** Command not found or nothing happens

**Solutions:**
1. Verify Claude CLI is installed: `claude --version`
2. Check the skill file exists: `.claude/skills/ralph-prd-starter/SKILL.md`
3. Try direct skill invocation: `/skill ralph-prd-starter`

### Generator Fails

**Symptom:** Python script errors

**Solutions:**
1. Verify Python 3.8+ is installed: `python3 --version`
2. Install dependencies: `pip install -r .claude/scripts/prd-starter-requirements.txt`
3. Check state file format: `cat .claude/session/prd-starter-state.json`

### Generated Files Incorrect

**Symptom:** Generated files don't match your selections

**Solutions:**
1. Review state file for accuracy
2. Run generator with `--verbose` flag
3. Check template files in `.claude/templates/`

### Resume Doesn't Work

**Symptom:** Wizard starts from beginning instead of resuming

**Solutions:**
1. Verify state file exists: `.claude/session/prd-starter-state.json`
2. Check `currentPhase` field in state file
3. Ensure state file has valid JSON format

## Want to Learn More?

For a comprehensive technical deep dive into how the wizard works internally, see:
- **[PRD Starter Deep Dive](../wizard/prd-starter-deep-dive.md)** - Architecture, scripts, templates, state management

## See Also

- [Architecture](../core/architecture.md) - System architecture overview
- [Configuration](../core/configuration.md) - Agent settings and PRD format
- [Extending](../advanced/extending.md) - Adding custom agents and skills
- [Getting Started](./getting-started.md) - Installation and first run
