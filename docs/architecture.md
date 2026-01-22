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
│  │ (Coordinator)│    │(Logic Worker)│    │        (Worker)          │     │
│  └─────────────┘    └─────────────┘    └─────────────────────────┘     │
│         │                  ▲                                              │
│         │                  │                                              │
│         └──────────────────┴──────────────────────────────────────┐     │
│                           (cycle repeats)                           │     │
│                                                                 │     │
│  ┌─────────────┐    ┌─────────────────────────────────────────┐  │     │
│  │TECH ARTIST  │    │            GAME DESIGNER                │  │     │
│  │(Asset Worker)│   │         (On Demand Worker)             │  │     │
│  │             │    │  GDD • Design Q&A • Playtesting         │  │     │
│  │Materials    │    │                                     │  │     │
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
- Runs feedback loops (type-check, lint, test, build)
- Commits work with conventional commits
- Sends validation request to QA

### QA Agent (Worker)

The QA agent validates implementations:

- Runs automated tests
- Performs browser testing with Playwright
- Validates against acceptance criteria
- Reports bugs with structured format or confirms pass
- Sends results back to PM

### Game Designer Agent (On-Demand Worker)

The Game Designer agent handles design-specific tasks:

- Creates Game Design Documents (GDDs) when none exist
- Answers design questions from Developer/QA/Tech Artist
- Designs game mechanics, levels, characters, weapons
- Performs playtesting via Playwright MCP automation
- Reports playtest results to PM

### Tech Artist Agent (Asset Worker)

The Tech Artist agent handles visual asset tasks:

- Creates 3D/2D assets and materials
- Implements GLSL shaders and visual effects
- Adds UI polish and post-processing
- Optimizes assets for performance (60 FPS target)
- Commits work with `[ralph] [techartist]` prefix
- Sends asset-ready notifications to QA

## Task Lifecycle

```
┌──────────────────────────────────────────────────────────────────────┐
│                         TASK LIFECYCLE                                │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────┐  │
│  │ 1. SELECT   │───▶│ 2. ASSIGN   │───▶│ 3. IMPLEMENT            │  │
│  │   (PM)      │    │  (PM→Dev)   │    │   (Developer)           │  │
│  │             │    │             │    │                         │  │
│  │ Read PRD    │    │ Update      │    │   - Domain skills       │  │
│  │ Scale 0-4   │    │ state.json  │    │   - Feedback loops      │  │
│  │ Find next   │    │ Send msg    │    │   - Commit changes      │  │
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
│  │ 6. RETROSPECTIVE (End of PRD)                                  │  │
│  │   - Review all tasks completed                                 │  │
│  │   - Research skill improvements via MCP                        │  │
│  │   - Propose updates to agent skills                            │  │
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

## Project Structure

```
ralph-orchestra/
├── .claude/
│   ├── commands/           # Slash commands for agents
│   │   ├── ralph-coordinator-event.md  # PM event-driven mode
│   │   ├── ralph-coordinator-single.md # PM sequential mode
│   │   ├── ralph-worker-event.md       # Dev/QA event-driven mode
│   │   ├── ralph-worker-single.md      # Dev/QA sequential mode
│   │   ├── ralph-hitl.md               # Human-in-the-loop mode
│   │   └── cancel-ralph.md             # Graceful shutdown
│   │
│   ├── scripts/            # Orchestration scripts
│   │   ├── watchdog-event.ps1        # Event-driven orchestrator
│   │   ├── watchdog-single.ps1       # Sequential mode orchestrator
│   │   ├── ralph-event-session.ps1   # Event-driven launcher
│   │   ├── ralph-single-session.ps1  # Sequential mode launcher
│   │   ├── ralph-multi-session.ps1   # Polling mode launcher
│   │   ├── message-queue.ps1         # Message queue functions
│   │   └── ralph-config.ps1          # Shared configuration
│   │
│   ├── skills/             # Orchestration skills (YAML frontmatter)
│   │   ├── ralph-core.md             # Core orchestration concepts
│   │   ├── ralph-router.md           # Routes to agent skills
│   │   ├── ralph-handoff.md          # Handoff protocol
│   │   ├── ralph-event-protocol.md   # Event-driven messaging
│   │   └── ...
│   │
│   ├── session/            # Runtime state (gitignored)
│   │   ├── coordinator-state.json    # Main coordination state
│   │   ├── current-task.json         # Active task details
│   │   ├── handoff-signal.json       # Agent switching signals
│   │   ├── messages/                 # Event-driven message queues
│   │   └── logs/                     # Agent output logs
│   │
│   └── settings.*.json     # Per-agent Claude settings
│
├── agents/                 # Modular agent definitions
│   ├── pm/
│   │   ├── AGENT.md        # PM behavior instructions
│   │   ├── SKILLS.md       # Skills index
│   │   └── skills/         # Modular skills
│   │       ├── task-selection.md     # Priority algorithm
│   │       ├── retrospective.md      # Retrospective facilitation
│   │       ├── skill-improvement.md  # MCP-based skill updates
│   │       └── scale-adaptive.md     # Scale 0-4 planning
│   │
│   ├── developer/
│   │   ├── AGENT.md        # Developer behavior instructions
│   │   ├── SKILLS.md       # Skills index
│   │   └── skills/         # Modular skills
│   │       ├── r3f-fundamentals.md   # R3F scene composition
│   │       ├── r3f-materials.md      # Materials & shaders
│   │       ├── r3f-physics.md        # Rapier physics
│   │       ├── r3f-performance.md    # Performance optimization
│   │       ├── feedback-loops.md     # Type/lint/test/build
│   │       └── typescript-patterns.md # TS best practices
│   │
│   ├── techartist/
│   │   ├── AGENT.md        # Tech Artist behavior instructions
│   │   ├── SKILLS.md       # Skills index
│   │   ├── skills/         # Modular skills
│   │   │   ├── r3f-fundamentals.md   # R3F scene composition
│   │   │   ├── r3f-materials.md      # PBR materials & custom shaders
│   │   │   ├── shader-sdf.md         # SDF primitives for shaders
│   │   │   ├── postfx-effects.md     # Post-processing effects
│   │   │   ├── particles-gpu.md      # GPU particle systems
│   │   │   ├── asset-workflow.md     # Asset pipeline workflow
│   │   │   ├── shader-development.md  # Shader creation process
│   │   │   └── visual-polish.md       # UI/visual polish checklist
│   │   ├── checklists/      # Quality checklists
│   │   │   ├── asset-quality.md      # Asset quality checks
│   │   │   ├── shader-review.md      # Shader performance checks
│   │   │   └── visual-consistency.md # Style consistency
│   │   └── references/      # Reference material
│   │       ├── material-presets.md   # Common material setups
│   │       └── shader-patterns.md    # Reusable shader patterns
│   │
│   ├── qa/
│   │   ├── AGENT.md        # QA behavior instructions
│   │   ├── SKILLS.md       # Skills index
│   │   └── skills/         # Modular skills
│   │       ├── validation-workflow.md # Full validation pipeline
│   │       ├── browser-testing.md    # Playwright MCP testing
│   │       └── bug-reporting.md      # Bug report format
│   │
│   └── gamedesigner/
│       ├── AGENT.md        # Game Designer behavior instructions
│       └── skills/         # Modular skills
│           ├── gdd-creation.md        # Game Design Document creation
│           ├── mechanic-design.md      # Game mechanics documentation
│           ├── level-design.md         # Map and level design
│           ├── character-design.md     # Character and class design
│           └── playtest-validation.md  # Playwright-based playtesting
│
├── prd.json                # Product Requirements Document (tasks)
├── CLAUDE.md               # Project context for Claude
└── README.md               # Main documentation
```

## Session Files

| File | Purpose |
|------|---------|
| `prd.json` | Project requirements with `passes` field |
| `.claude/session/coordinator-state.json` | Shared coordination state |
| `.claude/session/current-task.json` | Active task details |
| `.claude/session/handoff-signal.json` | Agent switching signals (sequential) |
| `.claude/session/messages/` | Message queues (event-driven) |
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

**Message Acknowledgment Protocol**: All workers MUST acknowledge received messages immediately via `message_ack`. This prevents duplicate messages, enables delivery tracking, and allows deadlock recovery. See [orchestration-modes.md](./orchestration-modes.md#message-acknowledgment-protocol) for details.

For design questions, any agent can message the Game Designer, who responds with design answers. Tech Artist can request artistic references from Game Designer.

## Further Reading

- [Orchestration Modes](./orchestration-modes.md) - Deep dive into each mode
- [Configuration](./configuration.md) - PRD format and settings
- [Extending](./extending.md) - Adding custom agents and skills
