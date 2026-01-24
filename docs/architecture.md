# Architecture

Ralph Orchestra is a multi-agent autonomous development framework that coordinates specialized AI agents to work together on software development tasks.

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         RALPH ORCHESTRA                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────┐     │
│  │    PM      │───▶│  DEVELOPER  │───▶│           QA             │     │
│  │(Coordinator)│    │(Logic Worker)│    │        (Worker)          │     │
│  └─────────────┘    └─────────────┘    └─────────────────────────┘     │
│         │                  ▲                                              │
│         │                  │                                              │
│         └──────────────────┴──────────────────────────────────────┐     │
│                           (cycle repeats)                           │     │
│                                                                 │     │
│  ┌─────────────┐    ┌─────────────────────────────────────────┐  │     │
│  │TECH ARTIST  │    │            GAME DESIGNER                │  │     │
│  │(Asset Worker)│   │         (Design Worker)                │  │     │
│  │             │    │  GDD • Design Q&A • Playtesting         │  │     │
│  │Materials    │    │  Thermite Design Integration           │  │     │
│  │Shaders      │    │                                     │  │     │
│  │VFX          │    │                                     │  │     │
│  └─────────────┘    └─────────────────────────────────────────┘  │     │
└─────────────────────────────────────────────────────────────────────────┘
```

## Agent Roles

### PM Agent (Coordinator)

The PM agent orchestrates the entire development process:

- **Task Selection** - Uses priority algorithm to select next task from PRD
- **Scale-Adaptive Planning** - Adjusts approach based on PRD task count (0-4)
- **Assignment** - Assigns tasks to appropriate agents via messages
- **Progress Tracking** - Updates PRD status and maintains coordinator state
- **Retrospective** - Runs end-of-cycle review and proposes skill improvements

**Key characteristic:** Never writes code directly. Coordinates other agents.

### Developer Agent (Worker)

The Developer agent implements features:

- Reads task specs from assigned messages
- Implements features using domain-specific skills (R3F, TypeScript, etc.)
- Uses git worktrees for parallel development with Tech Artist
- Runs feedback loops (type-check, lint, test, build)
- Commits work with conventional commits
- Sends validation request to QA

**Focus Areas:**
- Game mechanics and systems
- State management (Zustand stores)
- Physics integration (Rapier)
- Network/multiplayer code (client & server)
- Data structures and APIs

### QA Agent (Worker)

The QA agent validates implementations:

- Runs automated tests
- Performs browser testing with Playwright
- Validates against acceptance criteria
- Reports bugs with structured format or confirms pass
- Sends results back to PM

### Tech Artist Agent (Worker)

The Tech Artist agent creates visual assets and effects:

- Creates 3D/2D assets and materials
- Implements GLSL shaders and visual effects
- Adds UI polish and post-processing
- Optimizes assets for performance (60 FPS target)
- Uses git worktrees for parallel development with Developer
- Sends asset-ready notifications to QA

**Focus Areas:**
- 3D model integration and materials
- Shader development (GLSL)
- Visual effects (particles, VFX)
- UI styling and polish
- Post-processing effects
- Asset optimization (LOD, compression)

### Game Designer Agent (Worker)

The Game Designer agent handles design-specific tasks:

- Creates Game Design Documents (GDDs) when none exist
- Uses thermite-design skill for structured design sessions
- Answers design questions from Developer/QA/Tech Artist
- Designs game mechanics, levels, characters, weapons
- Performs playtesting via Playwright MCP automation
- Reports playtest results to PM

## PRD Starter - Quick Setup

Use `/ralph-prd-starter` for automated project setup:

- **8-phase interactive wizard** - Guides through project ID, agent config, workflow, orchestration, tech stack, quality standards, and features
- **Generates custom configuration** - Creates agents, skills, settings files tailored to your project
- **Cross-platform support** - Works on Windows, macOS, and Linux
- **State persistence** - Resume from any phase if interrupted
- **Research-backed** - Researches best practices between phases

See [PRD Starter Guide](./prd-starter.md) for complete documentation.

## Sub-agent Architecture

Each main agent can delegate work to specialized sub-agents for cost optimization and focused expertise. Sub-agents keep the main agent's context clean and reduce token usage by ~77% for search tasks.

### How Sub-agents Work

```
┌─────────────────────────────────────────────────────────────────────┐
│                    MAIN AGENT (e.g., Developer)                      │
│                                                                      │
│  "Use the code-research subagent to find components using           │
│   useFrame hook"                                                     │
│                                 │                                    │
│                                 ▼                                    │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │           SUB-AGENT (code-research)                          │   │
│  │           Model: Haiku (faster, cheaper)                     │   │
│  │           Tools: Read, Glob, Grep (read-only)                │   │
│  │                                                                │   │
│  │   Result: Returns concise file list with line numbers        │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                 │                                    │
│                                 ▼                                    │
│  Main agent receives result and continues with main task             │
└─────────────────────────────────────────────────────────────────────┘
```

### Sub-agent Definitions

Sub-agents are defined in `.claude/agents/*.agent.md` with YAML frontmatter:

```yaml
---
name: implementation
description: Implement features using R3F/TypeScript patterns
model: sonnet
skills:
  - dev-r3f-r3f-fundamentals
  - dev-r3f-r3f-physics
tools: Read, Write, Edit, Bash
---

You are an implementation specialist...
```

### All Sub-agents

| Agent | Sub-agents | Purpose |
|-------|------------|---------|
| **Developer** | code-research, implementation, code-quality, validation, commit, task-researcher | Research, code, validate, commit workflow |
| **PM** | task-researcher, retrospective-facilitator, skill-researcher, prd-organizer, test-planner, architecture-validator | Task selection, retrospectives, skill improvement |
| **QA** | browser-validator, multiplayer-validator, visual-regression-tester, gameplay-tester, code-review, visual-tester | Specialized validation types |
| **Tech Artist** | asset-researcher, asset-creator, shader-compiler, particle-system-designer, visual-validator, visual-tester, performance-profiler, code-quality | Asset creation pipeline |
| **Game Designer** | asset-analyst, visual-reference-researcher, reference-game-researcher, thermite-facilitator, gdd-documenter, playtest-evidence-collector | Design and research |

### Cost Optimization

- **Haiku models** for search, research, parsing tasks (~77% cost reduction)
- **Sonnet models** for implementation, design, validation (higher quality)

### Delegation Pattern

```
"Use the {subagent-name} subagent to {brief task description}"
```

Examples:
- "Use the code-research subagent to find components using useFrame hook"
- "Use the implementation subagent to implement player jump mechanics"
- "Use the asset-researcher subagent to find all texture files for the vehicle"

## Task Lifecycle

```
┌──────────────────────────────────────────────────────────────────────┐
│                         TASK LIFECYCLE                                │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────┐  │
│  │ 1. SELECT   │───▶│ 2. ASSIGN   │───▶│ 3. IMPLEMENT            │  │
│  │   (PM)      │    │  (PM→Dev)   │    │   (Developer/TechArtist) │  │
│  │             │    │             │    │                         │  │
│  │ Read PRD    │    │ Update      │    │   - Domain skills       │  │
│  │ Scale 0-4   │    │ state.json  │    │   - Feedback loops      │  │
│  │ Find next   │    │ Send msg    │    │   - Git worktree        │  │
│  └─────────────┘    └─────────────┘    └───────────┬─────────────┘  │
│                                                     │                │
│  ┌─────────────┐    ┌─────────────────────────────┐│                │
│  │ 5. RETRO    │◀───│ 4. VALIDATE                 ││                │
│  │   (PM)      │    │   (QA)                      │◀┘                │
│  │             │    │                             │                  │
│  │ Mark passed │    │   - npm run build           │                  │
│  │ Update PRD  │    │   - npm run test            │                  │
│  │ Skill check │    │   - Browser validation      │                  │
│  │ Next task   │    │   - Bug report or pass      │                  │
│  └─────────────┘    └─────────────────────────────┘                  │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │ 6. RETROSPECTIVE (End of Task)                                 │  │
│  │   - Developer: Implementation review                           │  │
│  │   - QA: Validation findings                                    │  │
│  │   - Tech Artist: Visual quality assessment                      │  │
│  │   - Game Designer: Playtest results (via Thermite)             │  │
│  │   - PM: Synthesis and PRD reorganization                       │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

## Scale-Adaptive Planning

The PM agent uses scale levels (0-4) based on PRD task count to optimize planning overhead:

| Scale | Task Count | Parallelism | Overhead | Planning Style |
|-------|------------|-------------|----------|----------------|
| 0     | 1-3        | None        | Minimal  | Direct execution |
| 1     | 4-8        | Low         | Light    | Simple grouping |
| 2     | 9-15       | Medium      | Moderate | Dependency analysis |
| 3     | 16-30      | High        | Significant | Critical path focus |
| 4     | 31+        | Very High   | Heavy    | Phased rollout |

This prevents over-planning for small projects while ensuring proper coordination for large ones.

## Named Pipe Messaging (Phase 2)

Ralph Orchestra Phase 2 introduces named pipe messaging for ultra-fast communication:

- **< 10ms** message delivery (vs 2-5 seconds with file queue)
- Watchdog creates named pipes for each agent on startup
- Workers (Developer, QA, Tech Artist, Game Designer) connect to pipes
- PM (coordinator) continues with file queue for simplicity
- Automatic fallback to file queue if pipes unavailable

### Split State Files

Phase 2 splits the monolithic `coordinator-state.json`:

```
.claude/session/
├── state/
│   ├── agents.json      # Agent statuses (watchdog primary writer)
│   ├── prd.json         # PRD state (PM primary writer)
│   ├── current-task.json # Active task (shared)
│   └── metrics.json     # Performance metrics (watchdog)
```

This eliminates write contention and improves reliability.

### Git Worktrees for Parallel Development

Developer and Tech Artist can work simultaneously using git worktrees:

```
project/
├── .git/
├── src/                    # Main working tree (Developer)
└── worktrees/
    ├── dev-feature-001/    # Developer worktree
    └── ta-visuals-002/     # Tech Artist worktree
```

Each agent has their own working tree, eliminating merge conflicts.

## Project Structure

```
ralph-orchestra/
├── .claude/
│   ├── commands/           # Slash commands for agents
│   │   ├── ralph-coordinator-event.md  # PM event-driven mode
│   │   ├── ralph-coordinator-single.md # PM sequential mode
│   │   ├── ralph-worker-event.md       # Worker event-driven mode
│   │   ├── ralph-worker-single.md      # Worker sequential mode
│   │   ├── ralph-hitl.md               # Human-in-the-loop mode
│   │   ├── ralph-prd-starter.md        # Project setup wizard
│   │   └── cancel-ralph.md             # Graceful shutdown
│   │
│   ├── scripts/            # Orchestration scripts
│   │   ├── watchdog-event.ps1        # Event-driven orchestrator
│   │   ├── watchdog-single.ps1       # Sequential mode orchestrator
│   │   ├── ralph-event-session.ps1   # Event-driven launcher
│   │   ├── ralph-single-session.ps1  # Sequential launcher
│   │   ├── prd-starter-generator.ps1 # Project setup generator
│   │   └── ralph-config.ps1          # Shared configuration
│   │
│   ├── agents/              # SUB-AGENT DEFINITIONS (FLAT)
│   │   │                    # 26+ .agent.md files, NOT organized by agent
│   │   ├── implementation.agent.md     # Code implementation specialist
│   │   ├── code-quality.agent.md       # Code quality specialist
│   │   ├── code-research.agent.md      # Code research specialist (Haiku)
│   │   ├── commit.agent.md             # Git commit specialist
│   │   ├── validation.agent.md         # Validation specialist
│   │   ├── browser-validator.agent.md  # Browser testing specialist
│   │   ├── multiplayer-validator.agent.md # Multiplayer validation
│   │   ├── visual-tester.agent.md      # Visual regression testing
│   │   ├── gdd-documenter.agent.md     # GDD documentation specialist
│   │   ├── prd-organizer.agent.md      # PRD organization specialist
│   │   ├── task-researcher.agent.md    # PM task research specialist
│   │   └── ... (16+ more sub-agents)
│   │
│   ├── protocols/           # NEW: Communication protocols
│   │   ├── event-driven.md           # Event-driven orchestration protocol
│   │   ├── sequential.md             # Sequential agent coordination
│   │   └── worktree-setup.md         # Git worktree setup protocol
│   │
│   ├── schemas/             # NEW: Configuration validation
│   │   ├── agent-config.schema.json  # Agent configuration schema
│   │   └── prd-starter-state.schema.json # PRD Starter state schema
│   │
│   ├── templates/           # NEW: Agent/skill templates
│   │   ├── agent-template.md        # Agent definition template
│   │   ├── SKILL_TEMPLATE.md        # Skill template
│   │   ├── SUBAGENT_TEMPLATE.md     # Sub-agent template
│   │   └── settings-template.json   # Settings configuration template
│   │
│   ├── skills/             # Folder-based skills (70+)
│   │   ├── dev-r3f-r3f-fundamentals/SKILL.md
│   │   ├── dev-multiplayer-colyseus-server/SKILL.md
│   │   ├── ta-shader-development/SKILL.md
│   │   ├── qa-browser-testing/SKILL.md
│   │   ├── pm-workflow/SKILL.md
│   │   ├── shared-ralph-core/SKILL.md
│   │   └── ... (70+ skill folders)
│   │
│   ├── session/            # Runtime state (gitignored)
│   │   ├── state/                   # Split state files
│   │   ├── pipes/                   # Named pipe endpoints
│   │   ├── coordinator-state.json   # Main coordination state
│   │   ├── handoff-signal.json      # Agent switching signals
│   │   ├── messages/                # Event-driven message queues
│   │   └── logs/                    # Agent output logs
│   │
│   └── settings.*.json     # Per-agent Claude settings
│
├── agents/                 # Main agent definitions
│   ├── pm/AGENT.md         # PM behavior instructions
│   ├── developer/AGENT.md  # Developer behavior instructions
│   ├── techartist/AGENT.md # Tech Artist behavior instructions
│   ├── qa/AGENT.md         # QA behavior instructions
│   └── gamedesigner/AGENT.md # Game Designer behavior instructions
│
├── prd.json                # Product Requirements Document (tasks)
├── CLAUDE.md               # Project context for Claude
└── README.md               # Main documentation
```

## Session Files

| File | Purpose |
|------|---------|
| `prd.json` | Project requirements with `passes` field |
| `.claude/session/state/agents.json` | Agent statuses (Phase 2 split) |
| `.claude/session/state/prd.json` | PRD state (Phase 2 split) |
| `.claude/session/state/current-task.json` | Active task details (Phase 2 split) |
| `.claude/session/coordinator-state.json` | Shared coordination state |
| `.claude/session/handoff-signal.json` | Agent switching signals (sequential) |
| `.claude/session/messages/` | Message queues (event-driven) |
| `.claude/session/pipes/` | Named pipe endpoints (Phase 2) |
| `.claude/session/logs/` | Agent output logs |

## Message Flow (Event-Driven)

```
PM assigns task → Worker (Developer/TechArtist) picks up from inbox
    ↓
Worker acknowledges message → sends message_ack to PM
    ↓
Worker implements → sends validation request to QA
    ↓
QA validates → sends result (bug report OR pass) to PM
    ↓
PM updates PRD, marks task passed or assigns back to worker
```

**Message Acknowledgment Protocol**: All workers MUST acknowledge received messages immediately via `message_ack`. This prevents duplicate messages, enables delivery tracking, and allows deadlock recovery.

For design questions, any agent can message the Game Designer, who responds with design answers. Tech Artist can request artistic references from Game Designer.

### Message Types

| Type | From → To | Purpose |
|------|-----------|---------|
| `task_assign` | PM → Developer/TechArtist | Assign task for implementation |
| `validation_request` | Developer/TechArtist → QA | Request validation |
| `asset_ready` | Tech Artist → QA | Assets ready for validation |
| `bug_report` | QA → PM | Report bugs with priority |
| `task_complete` | QA → PM | Confirm task passed |
| `question` / `answer` | Any ↔ Any | Q&A between agents |
| `gdd_ready` | Game Designer → PM | GDD is ready |
| `gdd_update` | Game Designer → PM | GDD has been updated |
| `design_question` | Any → Game Designer | Ask design question |
| `design_answer` | Game Designer → Any | Answer design question |
| `playtest_request` | PM → Game Designer | Request playtest |
| `playtest_report` | Game Designer → PM | Playtest results |
| `asset_assign` | PM → Tech Artist | Assign visual task |
| `asset_question` | Tech Artist → PM/Game Designer | Clarification request |
| `shader_request` | Tech Artist → PM | Propose shader work |
| `reference_request` | Tech Artist → Game Designer | Request artistic references |
| `message_ack` | Worker → PM | Acknowledge message receipt |
| `retrospective_initiate` | PM → All Workers | Start retrospective |
| `test_plan_request` | PM → QA/GameDesigner | Request test plan input |

## Thermite Design Integration

The Game Designer agent uses the [thermite-design](.claude/skills/thermite-design.md) skill for structured game design sessions. This provides:

**Design Pillars:**
- Meaningful Risk - Every action matters
- Readable Chaos - Chaotic but parseable
- Compressed Tension - 5-8 minute matches
- Earned Mastery - Skill beats gear
- Sustainable Economy - Patchable, not exploitable

**Design Session Types:**
- Mechanic design - Define gameplay systems
- Level design - Map and environment creation
- Character design - Classes and abilities
- Weapon design - Items and equipment
- Playtesting - Validation via Playwright MCP

## Further Reading

- [Orchestration Modes](./orchestration-modes.md) - Deep dive into each mode
- [Configuration](./configuration.md) - PRD format and settings
- [Extending](./extending.md) - Adding custom agents and skills
- [PRD Starter Guide](./prd-starter.md) - Interactive setup wizard
- [Protocol Reference](./protocols.md) - Communication protocols
