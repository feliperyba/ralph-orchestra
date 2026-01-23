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

## Sub-agent Architecture

Each main agent can delegate work to specialized sub-agents for cost optimization and focused expertise. Sub-agents keep the main agent's context clean and reduce token usage by ~77% for search tasks.

### How Sub-agents Work

```
┌─────────────────────────────────────────────────────────────────────┐
│                    MAIN AGENT (e.g., Developer)                      │
│                                                                      │
│  "Use the codebase-explorer subagent to find components using       │
│   useFrame hook"                                                     │
│                                 │                                    │
│                                 ▼                                    │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │           SUB-AGENT (codebase-explorer)                      │   │
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

Sub-agents are defined in `.claude/agents/{agent}/` with YAML frontmatter:

```yaml
---
name: codebase-explorer
description: Fast codebase search for Developer agent
model: haiku
tools: Read, Glob, Grep
disallowedTools: Write, Edit, Bash
---

You are a codebase exploration specialist...
```

### All Sub-agents

| Agent | Sub-agent | Model | Purpose |
|-------|-----------|-------|---------|
| **Developer** | codebase-explorer | Haiku | Fast file/pattern search |
| | gameplay-implementer | Sonnet | Implement game mechanics |
| | network-implementer | Sonnet | Multiplayer/server code |
| | state-architect | Sonnet | Zustand stores, data flow |
| **PM** | task-selector | Sonnet | Analyze PRD, select next task |
| | prd-analyst | Sonnet | Break down features into tasks |
| | retro-facilitator | Sonnet | Run retrospective meetings |
| | skill-researcher | Sonnet | Research skill improvements |
| | gdd-reviewer | Sonnet | Review GDD from Game Designer |
| **QA** | test-output-analyzer | Haiku | Parse verbose test results |
| | code-inspector | Sonnet | Review code quality |
| | browser-validator | Sonnet | Playwright testing |
| | multiplayer-validator | Sonnet | Server-authoritative checks |
| **Tech Artist** | asset-locator | Haiku | Find visual asset files |
| | shader-creator | Sonnet | Create GLSL shaders |
| | material-designer | Sonnet | Create PBR materials |
| | fx-implementer | Sonnet | Particle effects, VFX |
| | ui-polisher | Sonnet | UI styling, animations |
| **Game Designer** | gdd-researcher | Haiku | Research game design patterns |
| | gdd-writer | Sonnet | Create game design docs |
| | playtest-specialist | Sonnet | Playtest via Playwright |
| | mechanic-designer | Sonnet | Design game mechanics |

### Cost Optimization

- **Haiku models** for search, research, parsing tasks (~77% cost reduction)
- **Sonnet models** for implementation, design, validation (higher quality)

Example cost savings:
- Main model (Sonnet): ~$0.15 per search
- Haiku subagent: ~$0.05 per search

### Delegation Pattern

```
"Use the {subagent-name} subagent to {brief task description}"
```

Examples:
- "Use the codebase-explorer subagent to find components using useFrame hook"
- "Use the gameplay-implementer subagent to implement player jump mechanics"
- "Use the asset-locator subagent to find all texture files for the vehicle"

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
│   │   └── cancel-ralph.md             # Graceful shutdown
│   │
│   ├── scripts/            # Orchestration scripts
│   │   ├── watchdog-event.ps1        # Event-driven orchestrator
│   │   ├── watchdog-single.ps1       # Sequential mode orchestrator
│   │   ├── ralph-event-session.ps1   # Event-driven launcher
│   │   ├── ralph-single-session.ps1  # Sequential launcher
│   │   ├── ralph-multi-session.ps1   # Polling mode launcher
│   │   ├── pipe-transport.ps1        # Named pipe messaging
│   │   ├── message-queue.ps1         # Message queue functions
│   ├── message-state-manager.ps1 # Message state tracking
│   │   └── ralph-config.ps1          # Shared configuration
│   │
│   ├── skills/             # Centralized skills (56+ skill directories)
│   │   ├── ralph-core.md             # Core orchestration concepts
│   │   ├── ralph-router.md           # Routes to agent skills
│   │   ├── ralph-handoff.md          # Handoff protocol
│   │   ├── ralph-event-protocol.md   # Event-driven messaging
│   │   ├── file-permissions.md       # File write permissions
│   │   ├── heartbeat-protocol.md     # Agent heartbeat updates
│   │   ├── message-handling.md       # Pending message processing
│   │   ├── worker-protocol.md        # Worker pool model
│   │   ├── context-management.md     # Context window auto-reset
│   │   ├── dev-backend-multiplayer  # Developer: Server-authoritative
│   │   ├── dev-client-prediction    # Developer: Client prediction
│   │   ├── qa-validation-workflow   # QA: Validation pipeline
│   │   ├── qa-browser-testing       # QA: Playwright testing
│   │   ├── thermite-design          # Game Designer: Design sessions
│   │   └── ... (56+ total skills)
│   │
│   ├── session/            # Runtime state (gitignored)
│   │   ├── state/                   # Split state files (Phase 2)
│   │   │   ├── agents.json          # Agent statuses
│   │   │   ├── prd.json             # PRD state
│   │   │   ├── current-task.json    # Active task
│   │   │   └── metrics.json         # Performance metrics
│   │   ├── pipes/                   # Named pipe endpoints
│   │   ├── coordinator-state.json    # Main coordination state
│   │   ├── current-task.json         # Active task details
│   │   ├── handoff-signal.json       # Agent switching signals
│   │   ├── messages/                 # Event-driven message queues
│   │   │   ├── pm/                   # PM inbox
│   │   │   ├── developer/            # Developer inbox
│   │   │   ├── techartist/           # Tech Artist inbox
│   │   │   ├── qa/                   # QA inbox
│   │   │   ├── gamedesigner/         # Game Designer inbox
│   │   │   └── watchdog/             # Watchdog inbox
│   │   └── logs/                     # Agent output logs
│   │
│   └── settings.*.json     # Per-agent Claude settings
│
├── agents/                 # Agent definitions
│   ├── pm/
│   │   ├── AGENT.md        # PM behavior instructions
│   │   ├── SKILLS.md       # Skills documentation
│   │   ├── checklists/      # PM checklists
│   │   └── references/      # PM reference materials
│   ├── developer/
│   │   ├── AGENT.md        # Developer behavior instructions
│   │   ├── SKILLS.md       # Skills documentation
│   │   ├── checklists/      # Developer checklists
│   │   └── references/      # Developer reference materials
│   ├── techartist/
│   │   ├── AGENT.md        # Tech Artist behavior instructions
│   │   ├── SKILLS.md       # Skills documentation
│   │   ├── checklists/      # Tech Artist checklists
│   │   └── references/      # Tech Artist reference materials
│   ├── qa/
│   │   ├── AGENT.md        # QA behavior instructions
│   │   ├── SKILLS.md       # Skills documentation
│   │   ├── checklists/      # QA checklists
│   │   └── references/      # QA reference materials
│   └── gamedesigner/
│       ├── AGENT.md        # Game Designer behavior instructions
│       ├── checklists/      # Game Designer checklists
│       └── references/      # Game Designer reference materials
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
