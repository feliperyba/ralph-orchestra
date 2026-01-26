# PRD Starter - Project Setup Wizard

The PRD Starter is an interactive setup wizard that generates custom agents, skills, and configuration for any project type.

## Overview

PRD Starter guides you through a 13-phase workflow to create a complete Ralph Orchestra setup tailored to your specific needs:

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

## 13-Phase Workflow

### Phase 1: Entry Point Selection

Choose your configuration mode:

| Option | Description | Best For |
|--------|-------------|----------|
| ⚡ **Quick Start** | Choose a named preset and customize project name | First-time users, common scenarios |
| 🎯 **Standard Mode** | Guided questions with AI recommendations | Most users, balanced approach |
| 🔧 **Expert Mode** | Full control over every configuration | Advanced users, custom needs |

**Based on selection:**
- **Quick Start** → Skip to Phase 2 (Named Presets)
- **Standard/Expert** → Skip to Phase 3 (Project Deep Dive)

### Phase 2: Named Presets (Quick Start Only)

Choose from 14 preset configurations organized by category:

**🎮 Game Development Presets:**
- **Indie Game Dev** - Solo/small team 3D games with R3F
- **Game Studio** - Professional game studio with multiplayer
- **Mobile Game** - iOS/Android games with performance focus
- **Multiplayer Arena** - Server-authoritative multiplayer games

**🌐 Web Application Presets:**
- **Modern Web App** - React/Vue/Svelte single-page apps
- **Full Stack SaaS** - Complete web applications with backend
- **Dashboard/Analytics** - Data-heavy applications with charts
- **Content Platform** - Blogs, docs, content sites

**🏢 Business & Commerce Presets:**
- **E-Commerce Store** - Online stores with checkout flow
- **SaaS Product** - Subscription-based products
- **Enterprise Suite** - Large-scale business applications

**🔧 Technical Presets:**
- **API Server** - Node.js/Python/Go API services
- **Data/ML Pipeline** - ML models and data processing
- **DevOps/Infrastructure** - CI/CD, deployment, automation
- **Custom** - Build your own from scratch

After preset selection, the wizard asks for project name, then skips to Phase 8 (Initial Features).

### Phase 3: Project Deep Dive (Standard/Expert)

Answer questions about your project:

| Question | Description | Example |
|----------|-------------|---------|
| Project Name | Human-readable name | "My E-Commerce Site" |
| One-Line Summary | Brief project description | "A modern e-commerce platform with real-time inventory" |
| Project Category | Application category | Web Application, Game Development, Backend API |
| Technology Stack | Primary technologies | React, TypeScript, Node.js |
| Team Size | Team composition | Solo, Small Team (2-5), Medium (6-20), Enterprise (20+) |
| Project Scale | Project scope | Prototype/MVP, Startup Product, Production System |
| Success Factors | Multi-select priorities | Speed to market, Code quality, Visual excellence, etc. |

### Phase 4: Agent Configuration (Standard/Expert)

Configure custom agents using a dynamic creation loop. The wizard launches the `pm-agent-creator` sub-agent to guide you through:

1. **Agent Definition** - Name, type, primary responsibility
2. **Skills Configuration** - Select existing skills or create new ones
3. **Sub-Agents Configuration** - Choose sub-agents for delegation
4. **Workflow Configuration** - Define states, transitions, and message handling
5. **File Generation** - Generate AGENT.md with `pm-agent-file-generator`

**Options:**
- **Use Standard Preset** - Quick configure all 5 standard agents (PM, Developer, Tech Artist, QA, Game Designer)
- **Custom Configuration** - Create agents individually with full control
- **Skip for Now** - Use default agents, configure later

### Phase 5: Orchestration Configuration (Standard/Expert)

Configure how agents coordinate:

| Setting | Options |
|---------|---------|
| Orchestration Mode | Event-Driven, Sequential, Polling, HITL |
| Max Iterations | Default: 200 |
| Context Reset Behavior | Auto-reset at 70%, 80%, or Manual only |

### Phase 6: MCP Server Configuration (Expert Only)

For each enabled agent, confirm which MCP servers to enable:

| Agent | Available MCP Servers |
|-------|----------------------|
| **PM** | github, filesystem, web-search, brave-search |
| **Developer** | github, filesystem, web-search, brave-search |
| **Tech Artist** | playwright, vision, blender, shadertoy, image-process, filesystem, github |
| **QA** | playwright, vision, filesystem, github |
| **Game Designer** | playwright, vision, filesystem, github, web-search |

### Phase 7: Quality Standards (Standard/Expert)

Set quality gates for generated code:

| Standard | Options |
|----------|---------|
| TypeScript Strictness | Strict, Standard, Loose, None |
| Test Coverage Target | 95%, 80%, 60%, None |
| Lint Rules | ESLint Recommended, Custom, None |
| Commit Convention | [ralph] format, Conventional, Custom |
| CI/CD Integration | GitHub Actions, GitLab CI, None |
| Additional Quality Gates | Multi-select from available options |

### Phase 8: Initial Features (All Modes)

Describe your starting features in natural language. The wizard parses your input into structured PRD items with:
- **Title** - Human-readable name
- **Description** - What the feature does
- **Acceptance Criteria** - Pass/fail conditions
- **Priority** - high, medium, low
- **Target Agent** - Which agent implements it

### Phase 8b: Deep Research (All Modes)

The wizard launches the `pm-research-specialist` sub-agent to perform deep domain research:

1. **Research similar projects** - Find and analyze similar projects on GitHub
2. **Identify best practices** - Tech stack specific recommendations
3. **Discover common pitfalls** - Known challenges and how to avoid them
4. **Generate clarifying questions** - 5-10 targeted questions based on research gaps
5. **Present findings** - User reviews research and answers questions

**User Review Gate:** User can request more research, modify questions, or continue.

**Output:** Research data saved to state file, questions and answers collected.

### Phase 8c: GDD Creation (Game Projects Only)

For game development projects, the wizard launches the `gamedesigner-thermite-facilitator` to run a Thermite Design Session:

1. **Run Thermite Design Session** - Boardroom Retreat with expert personas
2. **Create design decisions** - DEC-NNN format with rationale
3. **Document open questions** - OQ-NNN format with priority
4. **Establish design pillars** - Core design principles
5. **Define core mechanics** - Key gameplay systems

**Output files:**
- `docs/design/decision_log.md` - All design decisions
- `docs/design/open_questions.md` - Unresolved questions
- `docs/design/gdd.md` - GDD summary

**User Review Gate:** User can request additional Thermite sessions, modify GDD, or continue.

### Phase 8d: PRD Creation (All Modes)

The wizard launches the `pm-prd-creator` agent to create the final prd.json:

1. **Load all inputs** - Research data, GDD (if game), user answers, initial features
2. **Apply PM expertise** - Use task selection and organization skills
3. **Generate prd.json** - Properly structured with dependencies, priorities, agent assignments
4. **Present for review** - User reviews complete PRD before approval

**Critical:** The PRD is created by a PM agent with full PM expertise, not by the generator script.

**User Review Gate:** User can approve, request modifications, or request new research.

**Output:** `prd.json` file created with properly structured PRD items.

### Phase 8e: Project Location Selection (All Modes)

Before generating files, specify where to create the project:

| Option | Description |
|--------|-------------|
| 📁 **Subdirectory (Recommended)** | Create a folder with project name in ralph-orchestra |
| 📍 **Custom Path** | Specify a custom location for the project |
| 🔄 **Current Directory** | Generate in the current directory (not recommended) |

**Default:** Subdirectory mode creates the project at `{ralph-orchestra-root}/{project-name}/`.

**Output:** Project location saved to state file.

### Phase 9: Review and Generate

Review the complete configuration summary:

```
══════════════════════════════════════════════════════════════
                    RALPH ORCHESTRA SETUP
══════════════════════════════════════════════════════════════

📁 PROJECT: {projectName}
📋 TYPE: {projectCategory} ({techStack})
👥 TEAM: {teamSize}
🎯 MODE: {orchestrationMode}

───────────────────────────────────────────────────────────────
AGENTS ({count})
───────────────────────────────────────────────────────────────
  {agent summaries}

───────────────────────────────────────────────────────────────
FEATURES ({count})
───────────────────────────────────────────────────────────────
  {feature summaries}
```

**Confirm to generate** all files, or go back to adjust.

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

### Web Application Setup (Quick Start Mode)

```
Phase 1: Quick Start mode selected
Phase 2: Modern Web App preset chosen
Phase 8: Auth feature, Dashboard feature
Phase 8b: Deep Research (web app best practices)
Phase 8d: PRD Creation
Phase 8e: Subdirectory location
Phase 9: Review and Generate
```

**Generated:**
- `agents/pm/AGENT.md` - Coordinator agent
- `agents/developer/AGENT.md` - React/TypeScript specialist
- `agents/qa/AGENT.md` - Playwright testing specialist
- `.claude/settings.{agent}.json` - MCP configs for each agent
- `prd.json` - Initial feature backlog

### Game Development Setup (Standard Mode)

```
Phase 1: Standard mode selected
Phase 3: Game Development category, R3F tech stack
Phase 4: Developer, Tech Artist, QA agents configured
Phase 5: Event-driven orchestration
Phase 7: TypeScript strict, 80% coverage
Phase 8: Player controller, Physics, UI overlay
Phase 8b: Deep Research (game dev patterns)
Phase 8c: GDD Creation (Thermite session)
Phase 8d: PRD Creation
Phase 8e: Subdirectory location
Phase 9: Review and Generate
```

**Generated:**
- `agents/pm/AGENT.md` - Coordinator agent
- `agents/developer/AGENT.md` - R3F game mechanics
- `agents/techartist/AGENT.md` - Shader and VFX creation
- `agents/qa/AGENT.md` - E2E gameplay testing
- `agents/gamedesigner/AGENT.md` - Design and GDD
- `prd.json` - Game feature backlog
- `docs/design/decision_log.md` - Design decisions
- `docs/design/open_questions.md` - Open questions
- `docs/design/gdd.md` - GDD summary

### Backend API Setup (Expert Mode)

```
Phase 1: Expert mode selected
Phase 3: Backend API category, Node.js/Express stack
Phase 4: Backend Developer, QA agents configured
Phase 5: Sequential orchestration
Phase 6: MCP servers confirmed
Phase 7: TypeScript strict, 80% coverage, custom lint rules
Phase 8: Auth endpoints, User CRUD, WebSocket support
Phase 8b: Deep Research (backend best practices)
Phase 8d: PRD Creation
Phase 8e: Custom path location
Phase 9: Review and Generate
```

**Generated:**
- `agents/pm/AGENT.md` - Coordinator agent
- `agents/developer/AGENT.md` - Node.js/Express API development
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
