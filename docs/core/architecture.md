# Framework Architecture

Ralph Orchestra is an agnostic multi-agent orchestration framework that coordinates specialized AI agents to work together on software development tasks.

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         RALPH ORCHESTRA                                 │
│                   (Agnostic Orchestration Framework)                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────┐      ┌──────────────┐      ┌─────────────────────┐    │
│  │ COORDINATOR  │─────▶│   WORKER 1   │─────▶│      VALIDATOR       │    │
│  │  (PM Agent)   │      │ (Developer)  │      │     (QA Agent)      │    │
│  └──────┬───────┘      └──────┬───────┘      └─────────────────────┘    │
│         │                     │                                             │
│         │                     ▲                                             │
│         └─────────────────────┴─────────────────────────────────────┐   │
│                           (cycle repeats)                          │   │
│                                                                 │   │
│  ┌──────────────┐      ┌─────────────────────────────────────────┐  │   │
│  │ SPECIALIST   │      │              DESIGNER                      │  │   │
│  │  (Optional)  │      │           (Optional)                       │  │   │
│  │              │      │  Specifications • Research • Validation  │  │   │
│  │ Domain-      │      │                                             │  │   │
│  │ Specific     │      │  Configured during wizard setup           │  │   │
│  │ Skills       │      │                                             │  │   │
│  └──────────────┘      └─────────────────────────────────────────┘  │   │
│                                                                 │   │
│  Note: Agent roles, names, and skills are configurable via          │  │
│  the PRD Starter wizard. The above shows a typical configuration   │  │
│  after running /ralph-prd-starter                                  │  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Framework Components

| Component | Description | Configurable? |
|-----------|-------------|---------------|
| **PRD Starter Wizard** | Generates custom agent configurations | Yes - per project |
| **Orchestration Modes** | Event-Driven V2, Sequential, HITL | Yes - per session |
| **Agent System** | PM, Workers, Specialists, Validators | Yes - via wizard |
| **Skill Library** | 100+ modular capabilities | Yes - per agent |
| **Communication** | Named pipes, event log (V2), state files | Yes - per mode |
| **Quality Gates** | Feedback loops, code standards, validation | Yes - per project |

> **V2 Note:** Polling mode is deprecated. Event-Driven V2 uses Actor Model with Event Sourcing.

## Agent Roles (Configurable)

The framework supports **configurable agent roles**. The default templates include:

### Coordinator Agent (PM)

Orchestrates the development process:

- **Task Selection** - Priority algorithm from PRD
- **Scale-Adaptive Planning** - Adjusts approach based on task count
- **Assignment** - Routes tasks to appropriate workers
- **Progress Tracking** - Updates PRD and coordinator state
- **Retrospective** - Runs reviews and proposes improvements

**Never writes code directly** - coordinates other agents.

### Worker Agents

Implement specific work:

| Worker Template | Purpose | Example Skills |
|----------------|---------|----------------|
| **Developer** | Feature implementation | Language/framework patterns, testing, validation |
| **Specialist** | Domain-specific work | Graphics, data science, DevOps, etc. |
| **Validator** | Testing and validation | Automated tests, browser testing, code review |

**All workers:**
- Read task specs from assigned messages
- Use domain-specific skills from their configuration
- Run feedback loops (type-check, lint, test, build)
- Commit work with conventional commits
- Send validation request when complete

### Optional Agents

Enabled via wizard based on project needs:

| Agent Template | When to Enable | Example Use |
|----------------|----------------|-------------|
| **Designer** | Projects requiring specifications | Game design docs, UX research, technical specs |
| **Specialist** | Domain-specific work | Data pipelines, ML models, graphics/shaders |

## PRD Starter - Custom Configuration

**Always use the wizard** to generate project-specific configurations:

```
/ralph-prd-starter
```

The wizard configures:
1. **Agent Selection** - Which agents to enable (PM, Developer, Specialist, QA, Designer)
2. **Skill Assignment** - What skills each agent has
3. **Technology Stack** - Runtime, framework, language
4. **Orchestration Mode** - Event-driven, Sequential, or HITL
5. **Quality Standards** - Feedback loops and code gates

See [PRD Starter Guide](../quick-start/prd-starter.md) for complete documentation.

## Sub-agent Architecture

Each main agent can delegate to specialized sub-agents for cost optimization:

### How Sub-agents Work

```
┌─────────────────────────────────────────────────────────────────────┐
│                    MAIN AGENT (e.g., Developer)                      │
│                                                                      │
│  "Use the code-research subagent to find components"                 │
│                                 │                                    │
│                                 ▼                                    │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │           SUB-AGENT (code-research)                          │   │
│  │           Model: Haiku (faster, cheaper)                     │   │
│  │           Tools: Read, Glob, Grep (read-only)                │   │
│  │                                                                │   │
│  │   Result: Returns concise findings to main agent             │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                 │                                    │
│                                 ▼                                    │
│  Main agent receives result and continues                             │
└─────────────────────────────────────────────────────────────────────┘
```

### Cost Optimization

| Task Type | Model | Cost Reduction |
|-----------|-------|----------------|
| Search, Research, Parsing | Haiku | ~77% |
| Implementation, Validation | Sonnet | Full cost (higher quality) |

### Sub-agent Examples

The framework includes 28+ sub-agents. Examples:

| Agent | Sub-agents | Purpose |
|-------|------------|---------|
| **Developer** | code-research, implementation, code-quality, validation, commit | Code workflow |
| **Coordinator** | task-researcher, retrospective-facilitator, prd-organizer | Management |
| **Validator** | browser-validator, code-review, visual-tester | Testing types |
| **Specialist** | asset-creator, shader-compiler, performance-profiler | Domain work |

**Note:** Sub-agents are configured per agent during wizard setup.

## Task Lifecycle

```
┌──────────────────────────────────────────────────────────────────────┐
│                         TASK LIFECYCLE                                │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐      ┌──────────────┐      ┌─────────────────────┐ │
│  │  1. SELECT   │─────▶│  2. ASSIGN   │─────▶│  3. IMPLEMENT       │ │
│  │ (Coordinator)│      │  (→Worker)   │      │  (Worker Agent)     │ │
│  │              │      │              │      │                     │ │
│  │  Read PRD    │      │  Update      │      │  - Domain skills    │ │
│  │  Find next   │      │  state       │      │  - Feedback loops   │ │
│  └──────────────┘      └──────────────┘      └──────────┬──────────┘ │
│                                                       │              │
│  ┌──────────────┐      ┌─────────────────────────────┐              ││
│  │  5. RETRO    │◀─────│  4. VALIDATE                 │◀─────────────┘│
│  │ (Coordinator)│      │  (Validator)                 │               │
│  │              │      │                              │               │
│  │  Mark passed │      │  - Type check                │               │
│  │  Update PRD  │      │  - Lint                      │               │
│  │  Next task   │      │  - Tests                     │               │
│  └──────────────┘      │  - Build                     │               │
│                        │  - Bug report OR pass         │               │
│                        └───────────────────────────────┘               │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

## Scale-Adaptive Planning

The coordinator uses scale levels (0-4) based on PRD task count:

| Scale | Task Count | Planning Style |
|-------|------------|----------------|
| 0     | 1-3        | Direct execution |
| 1     | 4-8        | Simple grouping |
| 2     | 9-15       | Dependency analysis |
| 3     | 16-30      | Critical path focus |
| 4     | 31+        | Phased rollout |

## Communication Architecture

### Named Pipe Messaging (Event-Driven Mode)

- **< 10ms** message delivery
- Watchdog creates named pipes for each agent
- Automatic fallback to file queue if unavailable

### Message Flow

```
Coordinator assigns task → Worker acknowledges
    ↓
Worker implements → Sends to Validator
    ↓
Validator validates → Reports result (bug OR pass)
    ↓
Coordinator updates PRD → Marks task passed OR reassigns
```

### Message Types (V2)

| V2 Type | From → To | Purpose |
|---------|-----------|---------|
| `WorkAssign` | Coordinator → Worker | Assign work |
| `ValidationRequest` | Worker → Validator | Request validation |
| `ProblemReport` | Validator → Coordinator | Report bugs |
| `WorkComplete` | Validator → Coordinator | Confirm pass |
| `Query` / `Response` | Any ↔ Any | Q&A between agents |
| `AgentStatus` | Worker → Coordinator | Acknowledge receipt |

## Project Structure

```
ralph-orchestra/
├── .claude/
│   ├── commands/           # Slash commands
│   │   ├── ralph-prd-starter.md    # Setup wizard
│   │   ├── ralph-coordinator-*.md # Coordinator modes
│   │   ├── ralph-worker-*.md       # Worker modes
│   │   └── cancel-ralph.md         # Graceful shutdown
│   │
│   ├── scripts/            # Orchestration scripts
│   │   ├── watchdog-*.ps1          # Orchestrators
│   │   └── ralph-*-session.ps1     # Session launchers
│   │
│   ├── agents/             # Sub-agent definitions (26+)
│   │   ├── implementation.agent.md
│   │   ├── code-quality.agent.md
│   │   ├── browser-validator.agent.md
│   │   └── ...
│   │
│   ├── skills/             # Modular skills (100+)
│   │   ├── dev-*/SKILL.md          # Developer skills
│   │   ├── qa-*/SKILL.md           # Validator skills
│   │   ├── pm-*/SKILL.md           # Coordinator skills
│   │   └── shared-*/SKILL.md       # Shared skills
│   │
│   ├── protocols/           # Communication protocols
│   ├── schemas/             # Configuration schemas
│   ├── templates/           # Agent/skill templates
│   ├── presets/             # Quick-start configurations
│   │
│   ├── session/            # Runtime state (gitignored)
│   │   ├── eventlog.jsonl          # V2: Append-only event log
│   │   ├── agent-status.json       # V2: Materialized view
│   │   ├── undelivered.jsonl       # V2: Failed delivery queue
│   │   └── logs/                   # Agent logs
│   │
│   └── settings.*.json     # Per-agent Claude settings
│
├── agents/                 # TEMPLATE agent definitions
│   ├── pm/AGENT.md         # Coordinator template
│   ├── developer/AGENT.md  # Worker template
│   └── ...                 # Other templates
│
├── docs/                   # Documentation
├── prd.json                # Generated: Your PRD
└── README.md               # Main documentation
```

**Important:** The `agents/` directory contains **templates**. Run the wizard to generate custom configurations.

## Session Files (V2)

| File | Purpose |
|------|---------|
| `prd.json` | Project requirements with `passes` field |
| `.claude/session/eventlog.jsonl` | Append-only event log (source of truth) |
| `.claude/session/agent-status.json` | Materialized view from event log |
| `.claude/session/pipes/` | Named pipe endpoints |
| `.claude/session/logs/` | Agent output logs |
| `.claude/session/coordinator-state.json` | PM coordination state |
| `.claude/session/handoff-signal.json` | Agent switch signal (sequential mode) |

## Framework vs Templates

**Framework:** The orchestration infrastructure (protocols, skills, wizard)

**Templates:** Example configurations in `agents/`, `.claude/presets/` - use the wizard instead of copying

See [Framework Guide](../quick-start/framework.md) for complete explanation.

## Further Reading

- **[Framework Guide](../quick-start/framework.md)** - Understanding framework vs templates
- **[PRD Starter Guide](../quick-start/prd-starter.md)** - Complete wizard walkthrough
- **[Orchestration Modes](./orchestration-modes.md)** - Event-driven, Sequential, Polling, HITL
- **[Configuration](./configuration.md)** - PRD format and settings
- **[Wizard Presets](../wizard/wizard-presets.md)** - Available quick-start configurations
- **[Skill Catalog](../wizard/wizard-skill-catalog.md)** - Browse available skills
