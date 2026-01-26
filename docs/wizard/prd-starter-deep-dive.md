# PRD Starter Wizard - Deep Dive

> **Technical Reference** - Internal architecture and implementation details of the PRD Starter Wizard
>
> **Audience**: Developers, contributors, and anyone extending the wizard system
>
> **For user guides**, see [PRD Starter Walkthrough](../quick-start/prd-starter.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Wizard Modes](#2-wizard-modes)
3. [Phase-by-Phase Deep Dive](#3-phase-by-phase-deep-dive)
4. [Python Generator Scripts](#4-python-generator-scripts)
5. [State Management](#5-state-management)
6. [Template System](#6-template-system)
7. [Preset System](#7-preset-system)
8. [Sub-Agent Orchestration](#8-sub-agent-orchestration)
9. [Generated Files](#9-generated-files)
10. [Troubleshooting & Debugging](#10-troubleshooting--debugging)

---

## 1. Overview

### 1.1 What is the PRD Starter Wizard?

The **PRD Starter Wizard** is an automated project initialization system for Ralph Orchestra. It guides users through configuring multi-agent development environments with custom agents, skills, workflows, and orchestration modes.

**Key Capabilities:**

- **Three Configuration Modes**: Quick Start (presets), Standard (guided), Expert (fully custom)
- **Dynamic Agent Creation**: Generates custom agent definitions with role-specific instructions
- **Skill Management**: Automatically creates and attaches relevant skills
- **Workflow Generation**: Builds custom workflow skills for agent coordination
- **File Generation**: Creates all necessary config files, agents, and documentation
- **State Persistence**: Saves progress and supports resume capability

### 1.2 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         USER SESSION                                    │
│                     (Claude Code CLI)                                   │
└─────────────────────────────────────┬───────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    PRD-STARTER AGENT                                    │
│              (.claude/agents/prd-starter.agent.md)                      │
│                                                                         │
│  • Orchestrates 11+ phases                                              │
│  • Manages state transitions                                            │
│  • Invokes sub-agents for specialized tasks                             │
│  • Coordinates with Python generator                                    │
└─────────────────────────────────────┬───────────────────────────────────┘
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        ▼                             ▼                             ▼
┌──────────────────┐        ┌──────────────────┐        ┌──────────────────┐
│   State File     │        │   Sub-Agents     │        │   Questions      │
│ (.claude/session/)│        │   (7+ agents)    │        │   (User Input)   │
│                  │        │                  │        │                  │
│ • Progress       │        │ • pm-research    │        │ • Mode selection │
│ • Config         │        │ • pm-prd-creator │        │ • Agent config   │
│ • Tech stack     │        │ • pm-agent-*     │        │ • Settings       │
└──────────────────┘        └──────────────────┘        └──────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    PYTHON GENERATOR                                     │
│           (.claude/scripts/prd-starter/*.py)                            │
│                                                                         │
│  cli.py → generator.py → [agent_generator, docs_generator,              │
│                          script_manager, readme_generator, etc.]        │
└─────────────────────────────────────┬───────────────────────────────────┘
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        ▼                             ▼                             ▼
┌──────────────────┐        ┌──────────────────┐        ┌──────────────────┐
│  Jinja2          │        │  Ralph Files     │        │  Generated       │
│  Templates       │        │  (copy/select)   │        │  Output          │
│  (.claude/       │        │                  │        │                  │
│   templates/)    │        │ • Agent files    │        │ • Agent .md      │
│                  │        │ • Skills         │        │ • Settings .json  │
│ • agent.md       │        │ • Scripts        │        │ • README.md      │
│ • skill.md       │        │ • Schemas        │        │ • CLAUDE.md      │
│ • prd.json       │        │ • Presets        │        │ • prd.json       │
└──────────────────┘        └──────────────────┘        └──────────────────┘
```

### 1.3 Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| **Wizard Agent** | [`.claude/agents/prd-starter.agent.md`](../../.claude/agents/prd-starter.agent.md) | Main orchestrator, phase management |
| **Skill Entry** | [`.claude/skills/ralph-prd-starter/`](../../.claude/skills/ralph-prd-starter/) | User-facing `/ralph-prd-starter` command |
| **PowerShell Wrapper** | [`.claude/scripts/prd-starter-generator.ps1`](../../.claude/scripts/prd-starter-generator.ps1) | Python detection, dependency installation |
| **Python CLI** | [`.claude/scripts/prd-starter/cli.py`](../../.claude/scripts/prd-starter/cli.py) | Argument parsing, main entry point |
| **Main Generator** | [`.claude/scripts/prd-starter/generator.py`](../../.claude/scripts/prd-starter/generator.py) | Orchestrates all file generation |
| **State Schema** | [`.claude/schemas/prd-starter-state.schema.json`](../../.claude/schemas/prd-starter-state.schema.json) | JSON Schema v4.0 validation |
| **Templates** | [`.claude/templates/`](../../.claude/templates/) | Jinja2 templates for all generated files |
| **Presets** | [`.claude/presets/`](../../.claude/presets/) | 14+ quick-start configurations |

---

## 2. Wizard Modes

The wizard offers three configuration modes with increasing depth and customization.

### 2.1 Quick Start Mode (5 minutes)

**When to use**: Rapid prototyping, getting started quickly, standard project types

**Flow**:
1. Select project type preset
2. Review generated configuration
3. Generate

**What happens**:
- Loads preset configuration from [`.claude/presets/*.json`](../../.claude/presets/)
- Skips manual agent configuration (uses preset agents)
- Skips manual feature collection (uses preset features)
- Optionally runs research if `runResearch: true` in preset

**Available Presets**:
- `full-stack-web` - React + Node.js + PostgreSQL
- `threejs-game` - React Three Fiber + Rapier
- `phaser-game` - Phaser 3
- `nextjs-app` - Next.js App Router
- `python-backend` - FastAPI + SQLAlchemy
- And 9 more (see [Wizard Presets](./wizard-presets.md))

### 2.2 Standard Mode (15 minutes)

**When to use**: Custom projects needing some configuration

**Flow**:
1. Select project type (or skip)
2. Configure project details
3. Select agents from catalog
4. Configure orchestration
5. Review and generate

**What happens**:
- Guided questions for project identity
- Agent selection from 100+ skill catalog
- Basic orchestration configuration
- Skips deep research (unless manually requested)

### 2.3 Expert Mode (30+ minutes)

**When to use**: Complex projects requiring full customization

**Flow**:
1. Full project deep dive
2. Custom agent creation (not just selection)
3. Sub-agent orchestration for dynamic generation:
   - `pm-agent-creator` - Creates custom agent definitions
   - `pm-skill-creator` - Creates custom skills
   - `pm-workflow-creator` - Creates workflow skills
   - `pm-agent-file-generator` - Generates AGENT.md files
4. Deep research phase (`pm-research-specialist`)
5. Optional GDD creation (`gamedesigner-thermite-facilitator`)
6. PRD creation (`pm-prd-creator`)
7. Full quality standards configuration
8. Feature dependency mapping

**What happens**:
- Everything from Standard mode PLUS
- Dynamic agent creation with custom instructions
- Tech stack command discovery via research
- Custom skill generation
- Workflow skill generation for agent coordination
- Decision logs (DEC-NNN) and open questions (OQ-NNN)
- Complete PRD with dependencies

---

## 3. Phase-by-Phase Deep Dive

The wizard progresses through multiple phases, each updating the state file and collecting specific information.

### 3.1 Phase 1: Entry Point Selection

**Purpose**: Determine wizard mode and entry path

**What Happens**:
1. User invokes `/ralph-prd-starter`
2. [prd-starter.agent.md](../../.claude/agents/prd-starter.agent.md) loads
3. State file is checked at `.claude/session/prd-starter-state.json`
4. If state exists, user is asked to resume or start over
5. User selects mode: Quick Start, Standard, or Expert

**State Changes**:
```json
{
  "version": "4.0.0",
  "wizardMode": "quick-start" | "standard" | "expert",
  "currentPhase": "entry",
  "startedAt": "2025-01-26T10:00:00Z"
}
```

**User Interactions**:
- Choose wizard mode
- Choose to resume previous session or start fresh

**Expected Output**:
- State file created or loaded
- Wizard mode determined

### 3.2 Phase 2: Preset Selection (Quick Start Only)

**Purpose**: Load pre-configured project template

**Preset System**:

Presets are JSON files in [`.claude/presets/`](../../.claude/presets/) containing complete project configurations:

```json
{
  "name": "full-stack-web",
  "displayName": "Full Stack Web Application",
  "description": "React + Node.js + PostgreSQL web app",
  "projectType": "web",
  "techStack": {
    "frontend": "react",
    "backend": "node.js",
    "database": "postgresql"
  },
  "agents": ["pm", "developer", "qa"],
  "features": [
    {
      "id": "feat-001",
      "title": "Setup React application",
      "priority": "high"
    }
  ],
  "orchestration": {
    "mode": "event-driven",
    "workflow": "collaborative"
  },
  "runResearch": true
}
```

**Preset Loading** (see [loader.py](../../.claude/scripts/prd-starter/loader.py)):

1. Read preset file from `.claude/presets/{preset-name}.json`
2. Validate against preset schema
3. Merge preset config into state
4. Enable agents specified in preset

**State Updates**:
```json
{
  "selectedPreset": "full-stack-web",
  "project": {
    "name": "my-web-app",
    "description": "Full stack web application",
    "type": "web"
  },
  "agents": {
    "pm": { "enabled": true },
    "developer": { "enabled": true },
    "qa": { "enabled": true }
  }
}
```

**Expected Output**:
- Preset configuration loaded into state
- Wizard skips to Phase 8b (if `runResearch: true`) or Phase 9

### 3.3 Phase 3: Project Deep Dive

**Purpose**: Collect project identity and scope information

**Questions Asked**:
1. What is the project name?
2. Provide a brief description (1-2 sentences)
3. What type of project is this? (web, game, mobile, backend, data, devops, other)
4. What is the primary technology stack? (open-ended)
5. Any specific frameworks or libraries? (optional)

**Data Collected**:
```json
{
  "project": {
    "name": "my-awesome-project",
    "description": "A brief description of the project",
    "type": "web",
    "customType": "",
    "techStack": {
      "primary": "react",
      "frameworks": ["next.js", "tailwind"],
      "libraries": []
    }
  }
}
```

**State Updates**:
- `project.name` - Project identifier
- `project.description` - Human-readable description
- `project.type` - Category from enum
- `project.customType` - Custom description if type is "other"
- `currentPhase` set to "project-deep-dive"

**Expected Output**:
- Complete project identity in state
- Basis for agent configuration and skill selection

### 3.4 Phase 4: Agent Configuration

**Purpose**: Define which agents will work on the project

**Dynamic Agent Creation Loop** (Expert Mode only):

In Expert mode, agents aren't just selected—they're dynamically created through sub-agent orchestration:

```
┌─────────────────────────────────────────────────────────────────┐
│              pm-agent-creator (Coordinator)                      │
│                                                                 │
│  1. Defines agent role and responsibilities                     │
│  2. Specifies required skills                                   │
│  3. Determines MCP servers                                      │
│  4. Delegates to pm-skill-creator for custom skills             │
│  5. Delegates to pm-workflow-creator for workflows              │
│  6. Delegates to pm-agent-file-generator for AGENT.md           │
└─────────────────────────────────────────────────────────────────┘
                                │
                ┌───────────────┼───────────────┐
                ▼               ▼               ▼
        ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
        │ pm-skill-    │ │ pm-workflow- │ │ pm-agent-    │
        │ creator      │ │ creator      │ │ file-        │
        │              │ │              │ │ generator    │
        └──────────────┘ └──────────────┘ └──────────────┘
```

**Standard/Quick Start Mode**:
- User selects from predefined agent catalog
- Agent definitions loaded from templates
- No dynamic creation

**Sub-Agent Orchestration**:

| Sub-Agent | Purpose | Input | Output |
|-----------|---------|-------|--------|
| `pm-agent-creator` | Define agent configuration | Role, responsibilities | Agent config dict |
| `pm-skill-creator` | Create custom skills | Skill requirements | SKILL.md files |
| `pm-workflow-creator` | Create workflow skills | Agent interactions | Workflow skill |
| `pm-agent-file-generator` | Generate AGENT.md | Agent config | Agent file |

**State Updates**:
```json
{
  "agents": {
    "my-custom-agent": {
      "enabled": true,
      "displayName": "My Custom Agent",
      "role": "developer",
      "customType": "",
      "icon": "...",
      "primaryResponsibility": "...",
      "cannotDo": ["..."],
      "works_with": ["pm", "qa"],
      "mcpServers": ["filesystem", "github"],
      "skills": ["dev-r3f-r3f-fundamentals", "custom-skill"],
      "subAgents": [],
      "quantity": 1,
      "mainActivities": ["..."],
      "interactionPattern": "collaborate",
      "workflow": {},
      "model": "inherit"
    }
  },
  "customAgents": ["my-custom-agent"]
}
```

**Expected Output**:
- All agents defined in state
- Custom skills created (Expert mode)
- Workflow skills created (Expert mode)
- Agent configuration complete

### 3.5 Phase 5: Orchestration Configuration

**Purpose**: Define how agents coordinate their work

**Options**:

| Mode | Description | Best For |
|------|-------------|----------|
| `event-driven` | Parallel agents with named pipes (V2) | Maximum speed, complex projects |
| `sequential` | One agent at a time, handoff protocol | Token efficiency, simple projects |
| `hitl` | Human-in-the-loop, single iterations | Learning, debugging |

**Workflow Patterns**:
- `waterfall` - Sequential handoffs only
- `collaborative` - Agents work together freely
- `autonomous` - Agents self-coordinate
- `custom` - User-defined workflow

**State Updates**:
```json
{
  "orchestration": {
    "mode": "event-driven",
    "workflow": "collaborative",
    "maxIterations": 200,
    "heartbeatInterval": 30
  }
}
```

**Expected Output**:
- Orchestration mode configured
- Session scripts selected based on mode

### 3.6 Phase 6: MCP Server Configuration

**Purpose**: Define which MCP servers each agent can access

**Available MCP Servers**:
- `filesystem` - File system access
- `github` - GitHub API integration
- `web-search` - Web search capability
- `brave-search` - Brave search API
- `playwright` - Browser automation
- `vision` - Image analysis
- `blender` - 3D modeling integration
- `shadertoy` - Shader development
- `image-process` - Image processing

**Agent-Specific Defaults**:

| Agent | Default MCP Servers |
|-------|---------------------|
| pm | filesystem, github, web-search, brave-search |
| developer | filesystem, github, web-search, brave-search |
| techartist | filesystem, github, playwright, vision, blender, shadertoy |
| qa | filesystem, github, playwright, vision |
| gamedesigner | filesystem, github, web-search, playwright, vision |

**State Updates**:
```json
{
  "agents": {
    "developer": {
      "mcpServers": ["filesystem", "github", "web-search"]
    }
  }
}
```

**Expected Output**:
- MCP server assignments per agent
- Settings files will be generated with correct server configs

### 3.7 Phase 7: Quality Standards

**Purpose**: Define quality gates and validation requirements

**Configuration Options**:

```json
{
  "qualityStandards": {
    "testing": {
      "required": true,
      "coverageThreshold": 80,
      "framework": "vitest"
    },
    "typeChecking": {
      "enabled": true,
      "strict": true
    },
    "linting": {
      "enabled": true,
      "rules": "recommended"
    },
    "documentation": {
      "required": true,
      "formats": ["md", "jsdoc"]
    },
    "codeReview": {
      "required": true,
      "reviewers": 1
    }
  }
}
```

**State Updates**:
- Quality standards defined in state
- Used by CLAUDE.md generation

**Expected Output**:
- Quality standards configuration
- Will be enforced during development

### 3.8 Phase 8: Initial Features Collection

**Purpose**: Define starting feature list for PRD

**Process**:
1. User provides feature ideas
2. Wizard organizes into PRD format
3. Categories assigned (architectural, feature, bugfix, refactor)
4. Priorities set (high, medium, low)
5. Agent assignments made

**Feature Format**:
```json
{
  "features": [
    {
      "id": "feat-001",
      "category": "architectural",
      "priority": "high",
      "title": "Setup project structure",
      "description": "Initialize React app with routing",
      "acceptanceCriteria": [
        "App runs on localhost:3000",
        "Routing works between pages"
      ],
      "agent": "developer",
      "dependencies": [],
      "passes": false
    }
  ]
}
```

**Expected Output**:
- Initial feature list in state
- Basis for PRD generation

### 3.9 Phase 8b: Deep Research

**Purpose**: Discover tech stack commands and generate clarifying questions

**pm-research-specialist Invocation**:

The wizard invokes `pm-research-specialist` sub-agent with:
- Project type and tech stack from state
- Project description and context
- Request for command discovery

**Research Process**:

1. **Domain Analysis**: Research project domain terminology
2. **Command Discovery**: Find runtime-specific commands for the tech stack
3. **Dependency Analysis**: Identify key dependencies and their versions
4. **Best Practices**: Research standard patterns for the tech stack
5. **Question Generation**: Create clarifying questions for user

**Expected Output from Research**:

```json
{
  "researchData": {
    "completedAt": "2025-01-26T10:30:00Z",
    "domainTerminology": {
      "components": ["Component", "Hook", "Props"],
      "patterns": ["Server Components", "Client Components"]
    },
    "discoveredCommands": {
      "install": "npm install",
      "dev": "npm run dev",
      "build": "npm run build",
      "test": "npm run test",
      "lint": "npm run lint"
    },
    "dependencies": {
      "react": "^18.3.0",
      "next": "^14.0.0"
    },
    "bestPractices": [
      "Use Server Components by default",
      "Client Components need 'use client' directive"
    ],
    "clarifyingQuestions": [
      {
        "id": "cq-001",
        "question": "Will you use Server Actions or API routes?",
        "options": ["Server Actions", "API Routes", "Both"],
        "impact": "Determines data fetching pattern"
      }
    ]
  }
}
```

**Generated Files**:
- `.claude/session/research-summary.md` - Research findings document
- `docs/research/tech-stack-research.md` - Persistent research summary

**State Updates**:
- `researchData` populated with findings
- Used by init script and PRD generation

### 3.10 Phase 8c: GDD Creation (Games Only)

**Purpose**: Create comprehensive Game Design Document for game projects

**When Triggered**: `project.type === "game"`

**gamedesigner-thermite-facilitator Invocation**:

The wizard invokes `gamedesigner-thermite-facilitator` which:
1. Runs a Thermite design session (8-persona simulation)
2. Generates design decisions with DEC-NNN format
3. Creates open questions with OQ-NNN format
4. Produces comprehensive GDD structure

**Thermite Design Session**:

Thermite is a multi-persona design simulation with 8 expert personas:
- **The Architect** - Systems and structure
- **The Veteran** - Industry experience
- **The Dreamer** - Creative vision
- **The Analyst** - Data and metrics
- **The Craftsman** - Implementation details
- **The Historian** - Genre knowledge
- **The Challenger** - Critical thinking
- **The synthesizer** - Integration and cohesion

**Design Decision Format (DEC-NNN)**:

```markdown
## DEC-001: First-Person vs Third-Person Camera

**Context**: Player needs to interact with objects while seeing avatar

**Decision**: Third-person over-the-shoulder camera

**Rationale**:
- Better spatial awareness for platforming
- Player can see their avatar's reactions
- Industry standard for this genre

**Alternatives Considered**:
- First-person: More immersive but less avatar visibility
- Isometric: Better tactical view but less immersion

**Impact**: Affects character model detail, animation requirements
```

**Open Questions Format (OQ-NNN)**:

```markdown
## OQ-001: Multiplayer Architecture

**Question**: Should we use server-authoritative or client-authoritative networking?

**Options**:
- Server-authoritative: More secure, more complex
- Client-authoritative: Simpler, more vulnerable to cheats
- Hybrid: Balance based on gameplay criticality

**Stakeholders**: Developer, QA

**Due**: Before sprint 2
```

**Expected Output Files**:
- `docs/gdd/README.md` - Main GDD entry point
- `docs/gdd/decisions.md` - All design decisions (DEC-NNN)
- `docs/gdd/questions.md` - Open questions (OQ-NNN)
- `docs/gdd/summary.md` - Session summary

**State Updates**:
```json
{
  "gddData": {
    "completedAt": "2025-01-26T11:00:00Z",
    "sessionType": "thermite-boardroom-retreat",
    "decisions": ["DEC-001", "DEC-002"],
    "openQuestions": ["OQ-001"],
    "summaryPath": "docs/gdd/summary.md"
  }
}
```

### 3.11 Phase 8d: PRD Creation

**Purpose**: Generate initial PRD with refined features and dependencies

**pm-prd-creator Invocation**:

The wizard invokes `pm-prd-creator` to:
1. Refine collected features into PRD format
2. Establish dependencies between features
3. Assign agents and priorities
4. Generate initial `prd.json`

**PRD Generation Process**:

1. **Feature Refinement**: Convert user input to structured PRD items
2. **Dependency Mapping**: Identify which features must come first
3. **Agent Assignment**: Match features to appropriate agents
4. **Priority Calculation**: Order by dependencies and priority

**PRD Structure**:

```json
{
  "metadata": {
    "version": "1.0.0",
    "createdAt": "2025-01-26T11:30:00Z",
    "projectName": "my-project"
  },
  "items": [
    {
      "id": "feat-001",
      "category": "architectural",
      "priority": "high",
      "title": "Setup React application",
      "description": "Initialize Next.js app with App Router",
      "acceptanceCriteria": [
        "App runs on localhost:3000",
        "App Router configured",
        "Base layout created"
      ],
      "agent": "developer",
      "dependencies": [],
      "passes": false
    },
    {
      "id": "feat-002",
      "category": "feature",
      "priority": "high",
      "title": "Create home page",
      "description": "Design and implement home page",
      "acceptanceCriteria": [
        "Hero section displays",
        "Navigation works",
        "Responsive design"
      ],
      "agent": "developer",
      "dependencies": ["feat-001"],
      "passes": false
    }
  ]
}
```

**Expected Output**:
- `prd.json` - Complete PRD file
- State updated with `prdSpecification`

### 3.12 Phase 8e: Project Location Selection

**Purpose**: Determine where files will be generated

**Options**:
1. **Current directory** - Generate in the directory where wizard was invoked
2. **New subdirectory** - Create new directory within current location
3. **Custom path** - Specify absolute or relative path

**State Updates**:
```json
{
  "projectLocation": {
    "type": "subdirectory",
    "path": "./my-project",
    "absolutePath": "/Users/user/projects/my-project"
  }
}
```

**Directory Resolution** (see [utils.py](../../.claude/scripts/prd-starter/utils.py:resolve_project_location)):

1. Parse location type from user input
2. Resolve absolute path
3. Check for existing directory
4. Validate write permissions
5. Create directory if needed

**Expected Output**:
- Project location determined and validated
- Directory created if it doesn't exist

### 3.13 Phase 9: Review and Generate

**Purpose**: Final review and file generation

**Review Process**:
1. Display complete configuration summary
2. Show all agents that will be created
3. Show feature/PRD items
4. Show project location
5. Request final confirmation

**Generation Process** (see [generator.py:generate_all](../../.claude/scripts/prd-starter/generator.py:L276-L354)):

If user confirms:

1. **Validate configuration** - Run [ConfigValidator](../../.claude/scripts/prd-starter/validator.py)
2. **Generate agents** - Create [`.claude/agents/{name}/AGENT.md`](../../.claude/agents/) files
3. **Generate settings** - Create [`.claude/settings.{agent}.json`](../../.claude/settings.) files
4. **Update scripts** - Modify watchdog and session scripts
5. **Generate init script** - Create project initialization script
6. **Generate README.md** - Create project documentation
7. **Generate CLAUDE.md** - Create Claude instructions
8. **Setup workflow docs** - Create workflow documentation directory
9. **Mark complete** - Set `completedAt` in state

**Expected Output**:
All files generated in target project location

---

## 4. Python Generator Scripts

The Python generator is a modular system that handles all file generation after the wizard completes.

### 4.1 Script Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│              prd-starter-generator.ps1                          │
│              (PowerShell Wrapper)                               │
│                                                                 │
│  • Detects Python installation                                  │
│  • Creates virtual environment if needed                        │
│  • Installs dependencies (jinja2, jsonschema)                  │
│  • Invokes Python CLI                                          │
└─────────────────────────────────────┬───────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────┐
│              cli.py (Main Entry Point)                          │
│                                                                 │
│  • Parses command-line arguments                               │
│  • Loads state file                                            │
│  • Resolves project location                                   │
│  • Creates generator instance                                  │
│  • Calls generate_all()                                        │
└─────────────────────────────────────┬───────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────┐
│              generator.py (Orchestrator)                        │
│                                                                 │
│  • PRDStarterGenerator class                                   │
│  • Coordinates all generation                                  │
│  • Delegates to specialized generators                         │
└─────────────────────────────────────┬───────────────────────────┘
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        ▼                             ▼                             ▼
┌──────────────────┐        ┌──────────────────┐        ┌──────────────────┐
│  AgentGenerator  │        │  DocsGenerator   │        │ ScriptManager    │
│  (agent_         │        │  (docs_          │        │  (script_        │
│   generator.py)  │        │   generator.py)  │        │   manager.py)    │
└──────────────────┘        └──────────────────┘        └──────────────────┘
        │                             │                             │
        ▼                             ▼                             ▼
┌──────────────────┐        ┌──────────────────┐        ┌──────────────────┐
│  AGENT.md files  │        │  README.md       │        │  Updated         │
│  settings/*.json │        │  CLAUDE.md       │        │  watchdog.ps1    │
│  workflows/      │        │  init scripts    │        │  session scripts │
└──────────────────┘        └──────────────────┘        └──────────────────┘
```

### 4.2 Main Generator (generator.py)

**File**: [`.claude/scripts/prd-starter/generator.py`](../../.claude/scripts/prd-starter/generator.py)

**PRDStarterGenerator Class**:

```python
class PRDStarterGenerator:
    def __init__(self, project_root: str | Path = "."):
        self.project_root = Path(project_root).resolve()
        self.templates_dir = self.project_root / ".claude" / "templates"
        self.scripts_dir = self.project_root / ".claude" / "scripts"
        self.schemas_dir = self.project_root / ".claude" / "schemas"
        self.session_dir = self.project_root / ".claude" / "session"

        # Initialize components
        self.renderer = TemplateRenderer(self.templates_dir)
        self.validator = ConfigValidator(self.schemas_dir)

        # Initialize specialized generators
        self.agent_gen = AgentGenerator(self.project_root, self.renderer)
        self.script_mgr = ScriptManager(self.scripts_dir, self.script_updater)
        self.docs_gen = DocsGenerator(self.project_root, self.renderer)
        self.file_copier = RalphFileCopier(self.project_root)
        self.readme_gen = ReadmeGenerator(self.project_root)
```

**generate_all() Method** (lines 276-354):

This is the main orchestration method:

```python
def generate_all(self, project_config: ProjectConfig, tech_stack: dict = None) -> ValidationResult:
    errors = []
    warnings = []

    # 1. Validate configuration
    validation = self.validate_config(project_config)
    if not validation.valid:
        return ValidationResult(valid=False, errors=validation.errors)

    # 2. Generate agents
    agent_names = []
    for agent in project_config.agents:
        if self.generate_agent(agent, project_config):
            agent_names.append(agent.name)
            self.generate_agent_settings(agent.name, agent.mcp_servers)

    # 3. Update scripts
    if agent_names:
        self.update_watchdog_scripts(agent_names)
        self.update_message_queue(agent_names)
        self.update_session_scripts(agent_names)

    # 4. Generate initialization script
    if tech_stack:
        self.generate_init_script(project_config, tech_stack)

    # 5. Setup workflow documentation
    self.setup_workflow_docs_directory(project_config)

    # 6. Generate README.md
    self.generate_readme(project_config, tech_stack, agents_config)

    # 7. Generate CLAUDE.md
    self.generate_claude_md(project_config, tech_stack, agents_config,
                           project_config.quality_standards)

    return ValidationResult(valid=len(errors) == 0, errors=errors, warnings=warnings)
```

### 4.3 Specialized Generators

#### AgentGenerator (agent_generator.py)

**Purpose**: Generate agent directory structure and files

**Key Methods**:
- `generate_agent()` - Main agent generation
- `generate_agent_settings()` - Settings file for each agent
- `generate_agent_directory()` - Creates directory structure

**Generated Structure**:
```
.claude/agents/{agent-name}/
├── AGENT.md          # Main agent instructions
├── SUB_AGENTS.md     # Sub-agent catalog (if any)
└── workflows/        # Custom workflow skills (if any)
    └── {agent}-workflow.md
```

#### ScriptManager (script_manager.py)

**Purpose**: Update watchdog and session scripts with new agents

**Key Methods**:
- `update_watchdog_scripts()` - Add agents to watchdog.ps1
- `update_message_queue()` - Update message-queue.ps1
- `update_session_scripts()` - Update session launcher scripts

**Process**:
1. Read existing script
2. Find agent list sections
3. Add new agents
4. Write updated script

#### DocsGenerator (docs_generator.py)

**Purpose**: Generate documentation files

**Key Methods**:
- `generate_init_script()` - Create project initialization script
- `generate_research_summary()` - Create research findings doc
- `generate_gdd_summary()` - Create GDD summary doc
- `generate_prd()` - Generate initial prd.json
- `setup_workflow_docs_directory()` - Setup workflow documentation

#### RalphFileCopier (file_copier.py)

**Purpose**: Copy Ralph Orchestra files to target project

**Key Methods**:
- `copy_ralph_orchestra_files()` - Selective file copy based on enabled agents

**Process**:
1. Define file manifest with agent associations
2. Filter by enabled agents
3. Copy to target project
4. Return results (copied, skipped, errors)

#### ReadmeGenerator (readme_generator.py)

**Purpose**: Generate README.md and CLAUDE.md

**Key Methods**:
- `generate_readme()` - Create project README
- `generate_claude_md()` - Create Claude instructions

### 4.4 Supporting Modules

#### Loader (loader.py)

**Purpose**: Load and parse state files, configs, and presets

**Key Functions**:
- `load_state_file()` - Load prd-starter-state.json
- `load_config_file()` - Load agent config JSON
- `load_preset()` - Load preset configuration
- `state_to_project_config()` - Convert state to ProjectConfig

#### Renderer (renderer.py)

**Purpose**: Jinja2 template rendering

**TemplateRenderer Class**:
```python
class TemplateRenderer:
    def __init__(self, templates_dir: Path):
        self.env = Environment(
            loader=FileSystemLoader(templates_dir),
            trim_blocks=True,
            lstrip_blocks=True
        )

    def render_agent_md(self, config: AgentConfig) -> str:
        template = self.env.get_template("agent-template.md")
        return template.render(**config.__dict__)

    def render_settings_json(self, agent_name: str, mcp_servers: list[str]) -> str:
        template = self.env.get_template("settings-template.json")
        return template.render(agent_name=agent_name, mcp_servers=mcp_servers)
```

#### Validator (validator.py)

**Purpose**: Validate configurations against JSON schemas

**ConfigValidator Class**:
```python
class ConfigValidator:
    def __init__(self, schemas_dir: Path):
        # Load JSON schemas
        self.state_schema = self._load_schema("prd-starter-state.schema.json")

    def validate_state(self, state: dict) -> ValidationResult:
        # Validate against schema
        # Return ValidationResult
```

#### Utils (utils.py)

**Purpose**: Utility functions

**Key Functions**:
- `resolve_project_location()` - Determine target project directory
- `create_project_directory()` - Create directory if needed
- `sanitize_agent_name()` - Convert display name to agent identifier

#### Model Types (model_types.py)

**Purpose**: Type definitions for all data structures

**Key Classes**:
- `AgentConfig` - Single agent configuration
- `ProjectConfig` - Complete project configuration
- `ValidationResult` - Validation operation result
- `WorkflowPattern` - Enum of workflow patterns
- `OrchestrationMode` - Enum of orchestration modes
- `ProjectType` - Enum of project types

---

## 5. State Management

The wizard maintains state throughout its operation, enabling resume capability and tracking progress.

### 5.1 State File Structure

**Location**: `.claude/session/prd-starter-state.json`

**Complete Structure**:

```json
{
  "version": "4.0.0",
  "startedAt": "2025-01-26T10:00:00Z",
  "completedAt": null,
  "wizardMode": "expert",
  "currentPhase": "agent-configuration",
  "selectedPreset": null,

  "project": {
    "name": "my-project",
    "description": "Project description",
    "type": "web",
    "customType": "",
    "techStack": {
      "primary": "react",
      "frameworks": [],
      "libraries": []
    }
  },

  "agents": {
    "pm": {
      "enabled": true,
      "displayName": "Project Manager",
      "role": "pm",
      "mcpServers": ["filesystem", "github"],
      "skills": ["pm-workflow"],
      "subAgents": []
    },
    "developer": {
      "enabled": true,
      "displayName": "Developer",
      "role": "developer",
      "mcpServers": ["filesystem", "github", "web-search"],
      "skills": ["dev-r3f-r3f-fundamentals"],
      "subAgents": []
    }
  },
  "customAgents": [],

  "orchestration": {
    "mode": "event-driven",
    "workflow": "collaborative",
    "maxIterations": 200,
    "heartbeatInterval": 30
  },

  "qualityStandards": {
    "testing": {
      "required": true,
      "coverageThreshold": 80
    },
    "typeChecking": {
      "enabled": true,
      "strict": true
    }
  },

  "features": [
    {
      "id": "feat-001",
      "category": "architectural",
      "priority": "high",
      "title": "Setup project",
      "description": "Initialize project structure",
      "acceptanceCriteria": [],
      "agent": "developer",
      "dependencies": [],
      "passes": false
    }
  ],

  "researchData": {
    "completedAt": "2025-01-26T10:30:00Z",
    "domainTerminology": {},
    "discoveredCommands": {},
    "dependencies": {},
    "bestPractices": [],
    "clarifyingQuestions": []
  },

  "gddData": {
    "completedAt": null,
    "sessionType": null,
    "decisions": [],
    "openQuestions": []
  },

  "prdSpecification": {
    "completedAt": null,
    "items": []
  },

  "projectLocation": {
    "type": "subdirectory",
    "path": "./my-project",
    "absolutePath": "/full/path/to/my-project"
  }
}
```

### 5.2 State Schema (prd-starter-state.schema.json)

**File**: [`.claude/schemas/prd-starter-state.schema.json`](../../.claude/schemas/prd-starter-state.schema.json)

**Purpose**: JSON Schema v4.0 validation for state file

**Key Validation Rules**:
- Version must be "4.0.0" or higher
- `wizardMode` must be one of: "quick-start", "standard", "expert"
- `project.type` must be valid ProjectType enum
- All agent configs require: name, displayName, role
- `orchestration.mode` must be valid OrchestrationMode enum

### 5.3 State Persistence Protocol

**When State is Saved**:

1. After each phase completes
2. After each user response
3. Before invoking sub-agents
4. After sub-agent returns
5. Before generation phase

**Saving Process**:

The [prd-starter.agent.md](../../.claude/agents/prd-starter.agent.md) handles persistence:

```
1. Collect current state values
2. Update currentPhase
3. Add timestamp for phase completion
4. Write to .claude/session/prd-starter-state.json
5. Continue to next phase
```

### 5.4 Resume Capability

**How Resume Works**:

1. Wizard checks for existing state file on startup
2. If found, offers user option to resume or restart
3. Resume reads `currentPhase` and continues from there
4. Sub-agent results (research, GDD) are preserved

**Resume Limitations**:
- Cannot undo previous phases
- Sub-agent invocations are not rerun
- User can modify state values if needed

---

## 6. Template System

The wizard uses Jinja2 templates for generating all dynamic files.

### 6.1 Agent Template (agent-template.md)

**Location**: [`.claude/templates/agent-template.md`](../../.claude/templates/agent-template.md)

**Purpose**: Template for generating `.claude/agents/{name}/AGENT.md` files

**Template Variables**:
- `name` - Agent identifier
- `display_name` - Human-readable name
- `role` - Agent role type
- `icon` - ASCII art icon
- `primary_responsibility` - Main purpose
- `cannot_do` - Restrictions
- `works_with` - Collaborating agents
- `skills` - List of skill names
- `sub_agents` - Sub-agent list
- `mcp_servers` - MCP server list

**Example Usage**:
```jinja2
---
name: {{ name }}
description: {{ display_name }} - {{ primary_responsibility }}
skills: [{% for s in skills %}{{ s }}{{ "," if not loop.last else "" }}{% endfor %}]
---

# {{ display_name }}

{{ icon }}

## Primary Responsibility

{{ primary_responsibility }}

## What This Agent Cannot Do

{% for item in cannot_do %}
- {{ item }}
{% endfor %}
```

### 6.2 Settings Template (settings-template.json)

**Location**: [`.claude/templates/settings-template.json`](../../.claude/templates/settings-template.json)

**Purpose**: Template for generating `.claude/settings.{agent}.json` files

**Template Variables**:
- `agent_name` - Name of the agent
- `mcp_servers` - List of MCP server names

**Output Structure**:
```json
{
  "mcpServers": {
    {% for server in mcp_servers %}
    "{{ server }}": {
      "enabled": true
    }{{ "," if not loop.last else "" }}
    {% endfor %}
  }
}
```

### 6.3 PRD Template (prd-template.json)

**Location**: [`.claude/templates/prd-template.json`](../../.claude/templates/prd-template.json)

**Purpose**: Template for generating initial `prd.json`

**Template Variables**:
- `project_name` - Project identifier
- `items` - Feature list with dependencies

### 6.4 Workflow Skill Template (workflow-skill-template.md)

**Location**: [`.claude/templates/workflow-skill-template.md`](../../.claude/templates/workflow-skill-template.md)

**Purpose**: Template for generating custom workflow skills

**Template Variables**:
- `agent_name` - Agent this workflow is for
- `states` - State machine states
- `transitions` - State transitions
- `interactions` - Agent interaction patterns

**Generated Output**:
```markdown
---
name: {{ agent_name }}-workflow
description: Custom workflow for {{ agent_name }}
category: orchestration
---

# {{ agent_name }} Workflow

## States

{% for state in states %}
### {{ state.name }}
{{ state.description }}
{% endfor %}

## Transitions

{% for transition in transitions %}
- {{ transition.from }} → {{ transition.to }}: {{ transition.trigger }}
{% endfor %}
```

### 6.5 Documentation Templates

**README Template** ([`README-project-template.md`](../../.claude/templates/README-project-template.md)):
- Project name and description
- Tech stack badges
- Quick start commands
- Documentation links
- Contributing guidelines

**CLAUDE Template** ([`CLAUDE-project-template.md`](../../.claude/templates/CLAUDE-project-template.md)):
- Project-specific instructions
- Quality standards
- Tech stack conventions
- Agent expectations

### 6.6 Rendering Process

**TemplateRenderer Class** ([renderer.py](../../.claude/scripts/prd-starter/renderer.py)):

```python
class TemplateRenderer:
    def __init__(self, templates_dir: Path):
        self.env = Environment(
            loader=FileSystemLoader(templates_dir),
            trim_blocks=True,      # Remove first newline after tag
            lstrip_blocks=True,    # Strip leading whitespace
            autoescape=False       # No auto-escaping for code templates
        )

    def render(self, template_name: str, **context) -> str:
        template = self.env.get_template(template_name)
        return template.render(**context)
```

**Usage Example**:
```python
renderer = TemplateRenderer(templates_dir)
agent_md = renderer.render_agent_md(agent_config)
with open(output_path, "w") as f:
    f.write(agent_md)
```

---

## 7. Preset System

Presets provide quick-start configurations for common project types.

### 7.1 Preset File Structure

**Location**: [`.claude/presets/{preset-name}.json`](../../.claude/presets/)

**Structure**:
```json
{
  "name": "full-stack-web",
  "displayName": "Full Stack Web Application",
  "description": "React + Node.js + PostgreSQL",
  "projectType": "web",
  "techStack": {
    "frontend": "react",
    "backend": "node.js",
    "database": "postgresql",
    "styling": "tailwind",
    "testing": "jest"
  },
  "agents": [
    {
      "name": "pm",
      "enabled": true
    },
    {
      "name": "developer",
      "enabled": true
    },
    {
      "name": "qa",
      "enabled": true
    }
  ],
  "features": [
    {
      "id": "feat-001",
      "category": "architectural",
      "priority": "high",
      "title": "Setup React application",
      "description": "Initialize React with Vite",
      "agent": "developer"
    }
  ],
  "orchestration": {
    "mode": "event-driven",
    "workflow": "collaborative"
  },
  "qualityStandards": {
    "testing": {
      "required": true,
      "coverageThreshold": 80
    }
  },
  "runResearch": true,
  "runGDD": false
}
```

### 7.2 Available Presets

See [Wizard Presets](./wizard-presets.md) for complete list of 14+ presets:

| Preset | Project Type | Tech Stack |
|--------|--------------|------------|
| `full-stack-web` | Web | React + Node.js + PostgreSQL |
| `threejs-game` | Game | React Three Fiber + Rapier |
| `phaser-game` | Game | Phaser 3 |
| `nextjs-app` | Web | Next.js App Router |
| `python-backend` | Backend | FastAPI + SQLAlchemy |
| `mobile-app` | Mobile | React Native |
| And 8 more... | | |

### 7.3 Preset Loading Process

**Loader Function** ([loader.py:load_preset](../../.claude/scripts/prd-starter/loader.py)):

```python
def load_preset(preset_name: str, project_root: Path) -> dict | None:
    """Load a preset configuration by name.

    Args:
        preset_name: Name of the preset (without .json extension)
        project_root: Project root directory

    Returns:
        Preset configuration dict or None if not found
    """
    preset_path = project_root / ".claude" / "presets" / f"{preset_name}.json"

    if not preset_path.exists():
        return None

    with open(preset_path, "r") as f:
        return json.load(f)
```

**Preset Application**:
1. Load preset JSON file
2. Validate structure
3. Merge into state file
4. Enable specified agents
5. Apply tech stack configuration
6. Add features to PRD
7. Set orchestration mode

---

## 8. Sub-Agent Orchestration

The wizard delegates specialized tasks to sub-agents for dynamic content generation.

### 8.1 pm-research-specialist

**Agent**: [`.claude/agents/pm-research-specialist.agent.md`](../../.claude/agents/pm-research-specialist.agent.md)

**Purpose**: Deep research on project domain and tech stack

**Invocation**: Phase 8b (Deep Research)

**Input**:
- Project type and description
- Tech stack from state
- Request for command discovery

**Process**:
1. Web search for runtime-specific commands
2. Research domain terminology
3. Identify key dependencies and versions
4. Document best practices
5. Generate clarifying questions

**Output**:
- `researchData` in state
- `.claude/session/research-summary.md`
- `docs/research/tech-stack-research.md`

### 8.2 pm-prd-creator

**Agent**: [`.claude/agents/pm-prd-creator.agent.md`](../../.claude/agents/pm-prd-creator.agent.md)

**Purpose**: Create structured PRD from features

**Invocation**: Phase 8d (PRD Creation)

**Input**:
- Collected features from Phase 8
- Research data from Phase 8b
- Agent assignments

**Process**:
1. Refine features into PRD format
2. Map dependencies between features
3. Assign categories and priorities
4. Generate prd.json structure

**Output**:
- `prdSpecification` in state
- `prd.json` in project root

### 8.3 pm-agent-creator

**Agent**: [`.claude/agents/pm-agent-creator.agent.md`](../../.claude/agents/pm-agent-creator.agent.md)

**Purpose**: Define custom agent configurations

**Invocation**: Phase 4 (Agent Configuration) - Expert mode only

**Input**:
- Agent role requested by user
- Project context

**Process**:
1. Define agent role and responsibilities
2. Specify required skills
3. Determine MCP servers
4. Create icon (ASCII art)
5. Define interaction patterns

**Output**:
- Agent configuration dict
- Delegates to pm-skill-creator for custom skills
- Delegates to pm-workflow-creator for workflows
- Delegates to pm-agent-file-generator for AGENT.md

### 8.4 pm-skill-creator

**Agent**: [`.claude/agents/pm-skill-creator.agent.md`](../../.claude/agents/pm-skill-creator.agent.md)

**Purpose**: Create custom skill files

**Invocation**: By pm-agent-creator

**Input**:
- Agent configuration
- Required capabilities

**Process**:
1. Define skill structure
2. Write skill instructions
3. Specify YAML frontmatter
4. Generate SKILL.md content

**Output**:
- `.claude/skills/{skill-name}/SKILL.md` files

### 8.5 pm-workflow-creator

**Agent**: [`.claude/agents/pm-workflow-creator.agent.md`](../../.claude/agents/pm-workflow-creator.agent.md)

**Purpose**: Create workflow skills for agent coordination

**Invocation**: By pm-agent-creator

**Input**:
- Agent interactions
- State machine requirements

**Process**:
1. Define workflow states
2. Specify transitions
3. Document interaction patterns
4. Generate workflow skill

**Output**:
- Workflow skill file

### 8.6 pm-agent-file-generator

**Agent**: [`.claude/agents/pm-agent-file-generator.agent.md`](../../.claude/agents/pm-agent-file-generator.agent.md)

**Purpose**: Generate AGENT.md files from configuration

**Invocation**: By pm-agent-creator

**Input**:
- Complete agent configuration

**Process**:
1. Render agent template
2. Inject configuration values
3. Write AGENT.md file
4. Create subdirectory structure

**Output**:
- `.claude/agents/{name}/AGENT.md` file

### 8.7 gamedesigner-thermite-facilitator

**Agent**: [`.claude/agents/gamedesigner-thermite-facilitator.agent.md`](../../.claude/agents/gamedesigner-thermite-facilitator.agent.md)

**Purpose**: Run Thermite design sessions for game projects

**Invocation**: Phase 8c (GDD Creation) - Games only

**Input**:
- Game project description
- Research findings

**Process**:
1. Run 8-persona Thermite simulation
2. Generate design decisions (DEC-NNN)
3. Create open questions (OQ-NNN)
4. Produce GDD structure

**Output**:
- `gddData` in state
- `docs/gdd/` directory with:
  - `README.md` - Main GDD
  - `decisions.md` - All design decisions
  - `questions.md` - Open questions
  - `summary.md` - Session summary

---

## 9. Generated Files

After the wizard completes, the following files are generated in the target project.

### 9.1 Agent Files

**Location**: `.claude/agents/{agent-name}/`

**Files**:
```
.claude/agents/{agent-name}/
├── AGENT.md              # Main agent instructions
├── SUB_AGENTS.md         # Sub-agent catalog (if applicable)
└── workflows/            # Custom workflow skills (if any)
    └── {agent}-workflow.md
```

**AGENT.md Structure**:
```markdown
---
name: my-agent
description: Custom agent for specific tasks
skills: [custom-skill-1, custom-skill-2]
---

# My Agent

[ASCII Icon]

## Primary Responsibility

What this agent does...

## What This Agent Cannot Do

- Task X
- Task Y

## Collaboration

Works with: pm, developer, qa

## Skills

- custom-skill-1: Description
- custom-skill-2: Description
```

### 9.2 Settings Files

**Location**: `.claude/settings.{agent-name}.json`

**Structure**:
```json
{
  "mcpServers": {
    "filesystem": {
      "enabled": true
    },
    "github": {
      "enabled": true
    }
  }
}
```

### 9.3 Documentation Files

**README.md**:
```markdown
# My Project

Project description...

## Quick Start

\`\`\`bash
npm install
npm run dev
\`\`\`

## Tech Stack

- React 18
- Next.js 14
- Tailwind CSS

## Ralph Orchestra

This project uses Ralph Orchestra for autonomous development.

See [CLAUDE.md](CLAUDE.md) for project-specific instructions.
```

**CLAUDE.md**:
```markdown
# My Project - Claude Documentation

## Tech Stack

- Runtime: Node.js
- Framework: React

## Quality Standards

- Test coverage: 80%
- Type checking: Strict mode
- Linting: ESLint recommended

## Project Conventions

- Use functional components
- Prefer Server Components
- Follow React best practices
```

### 9.4 PRD Files

**prd.json** (Project root):
```json
{
  "metadata": {
    "version": "1.0.0",
    "createdAt": "2025-01-26T11:30:00Z",
    "projectName": "my-project"
  },
  "items": [
    {
      "id": "feat-001",
      "category": "architectural",
      "priority": "high",
      "title": "Setup project",
      "description": "Initialize project structure",
      "acceptanceCriteria": [
        "Project builds successfully",
        "Tests pass"
      ],
      "agent": "developer",
      "dependencies": [],
      "passes": false
    }
  ]
}
```

### 9.5 Updated Scripts

**watchdog.ps1** - Updated with new agents:
```powershell
$agents = @("pm", "developer", "qa", "my-custom-agent")
```

**message-queue.ps1** - Updated with new agents:
```powershell
$queues = @{
    "pm" = @("developer", "qa", "my-custom-agent")
    "developer" = @("pm", "qa")
    "qa" = @("pm", "developer")
    "my-custom-agent" = @("pm", "developer", "qa")
}
```

**Session scripts** - Updated for orchestration mode:
- `ralph-event-session.ps1` (event-driven)
- `ralph-single-session.ps1` (sequential)
- `ralph-multi-session.ps1` (polling)

---

## 10. Troubleshooting & Debugging

### 10.1 Common Issues

#### State File Not Found

**Symptom**: Wizard says "No existing state found" when expecting resume

**Causes**:
- State file deleted
- Wrong working directory
- State file corrupted

**Solutions**:
```bash
# Check for state file
ls .claude/session/prd-starter-state.json

# View current state
cat .claude/session/prd-starter-state.json

# Restart wizard (will create new state)
/ralph-prd-starter
```

#### Generation Fails

**Symptom**: Files not generated after Phase 9

**Causes**:
- Python not installed
- Dependencies missing
- Invalid state data
- Permission errors

**Solutions**:
```bash
# Check Python
python --version

# Check dependencies
pip list | grep jinja2

# Reinstall dependencies
pip install jinja2 jsonschema

# Check permissions
ls -la .claude/
```

#### Agent File Invalid

**Symptom**: Agent not loading after generation

**Causes**:
- Invalid YAML frontmatter
- Missing required fields
- Skill doesn't exist

**Solutions**:
```bash
# Check agent file
cat .claude/agents/my-agent/AGENT.md

# Validate YAML frontmatter
# Ensure: name, description, skills are present

# Check skills exist
ls .claude/skills/
```

#### Template Render Error

**Symptom**: "Template not found" or "Undefined variable"

**Causes**:
- Template file missing
- Variable name mismatch
- Invalid Jinja2 syntax

**Solutions**:
```bash
# Check templates exist
ls .claude/templates/

# Verify template syntax
# Ensure {{ variable }} matches config keys

# Test rendering
python -c "from jinja2 import Environment; ..."
```

### 10.2 Debug Mode

**Enable Verbose Output**:

```bash
# Run generator with verbose flag
python .claude/scripts/prd-starter/prd-starter-generator.py \
    --action generate \
    --state .claude/session/prd-starter-state.json \
    --verbose
```

**What Verbose Shows**:
- Every file being copied
- Every template being rendered
- Detailed error messages
- Stack traces

### 10.3 State File Inspection

**View Current State**:

```bash
# Pretty print state
cat .claude/session/prd-starter-state.json | jq

# Check current phase
jq .currentPhase .claude/session/prd-starter-state.json

# Check enabled agents
jq .agents .claude/session/prd-starter-state.json

# Check research data
jq .researchData .claude/session/prd-starter-state.json
```

**Manually Edit State** (advanced):

```bash
# Open in editor
code .claude/session/prd-starter-state.json

# Common manual edits:
# - Change currentPhase to resume from different point
# - Enable/disable agents
# - Add features to list
# - Modify tech stack
```

### 10.4 Validation

**Validate State Against Schema**:

```python
from jsonschema import validate, Draft7Validator
import json

# Load schema
with open(".claude/schemas/prd-starter-state.schema.json") as f:
    schema = json.load(f)

# Load state
with open(".claude/session/prd-starter-state.json") as f:
    state = json.load(f)

# Validate
try:
    validate(instance=state, schema=schema)
    print("State is valid")
except Exception as e:
    print(f"Validation error: {e}")
```

---

## See Also

- **[PRD Starter Walkthrough](../quick-start/prd-starter.md)** - User guide for the wizard
- **[Wizard Presets](./wizard-presets.md)** - All available presets
- **[Skill Catalog](./wizard-skill-catalog.md)** - Available skills
- **[Sub-Agent Catalog](./wizard-subagent-catalog.md)** - Available sub-agents
- **[Main Documentation Index](../README.md)** - All documentation
