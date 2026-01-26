# Ralph Orchestra - Complete Architecture & Flow

> **Visual guide to the multi-agent autonomous development system**

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Startup Flow](#2-startup-flow)
3. [Message Flow](#3-message-flow)
4. [Agent Execution Flow](#4-agent-execution-flow)
5. [Sub-Agent Routing](#5-sub-agent-routing)
6. [File Organization](#6-file-organization)
7. [Data Flow Examples](#7-data-flow-examples)

---

## 1. System Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Ralph Orchestra                                │
│                       Multi-Agent Development System                      │
└─────────────────────────────────────────────────────────────────────────┘
                                      │
                ┌─────────────────────┼─────────────────────┐
                ▼                     ▼                     ▼
    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
    │  Event-Driven   │    │   Sequential    │    │      HITL       │
    │     Mode        │    │     Mode        │    │     Mode        │
    │ (Parallel)      │    │ (One-at-a-time) │    │  (Learning)      │
    └────────┬────────┘    └────────┬────────┘    └────────┬────────┘
             │                      │                      │
             │                      │                      │
    ┌────────▼─────────────────────────────────────────────────────────┐
    │                    WATCHDOG (Orchestrator)                        │
    │  • Spawns agents                                                 │
    │  • Routes messages                                              │
    │  • Monitors health                                               │
    │  • Restarts on failure                                           │
    └────────┬─────────────────────────────────────────────────────────┘
             │
    ┌────────┴────────────────┬───────────────┬───────────────┐
    ▼                         ▼               ▼               ▼
┌─────────┐           ┌─────────┐      ┌─────────┐   ┌─────────┐
│   PM    │           │Developer│      │    QA   │   │Game     │
│Coordinator│         │Worker   │      │Validator│   │Designer │
└────┬────┘           └────┬────┘      └────┬────┘   └────┬────┘
     │                     │               │             │
     ▼                     ▼               ▼             ▼
┌─────────┐           ┌─────────┐      ┌─────────┐   ┌─────────┐
│prd.json │           │Source   │      │Tests    │   │GDD      │
│         │           │Code     │      │Browser  │   │Design   │
└─────────┘           └─────────┘      └─────────┘   └─────────┘
```

### Component Responsibilities

| Component | Role | Key Files |
|-----------|------|-----------|
| **Watchdog** | Orchestrator, spawns agents, routes messages | PowerShell scripts |
| **PM Coordinator** | Task selection, progress tracking, retrospectives | `agents/pm/AGENT.md` |
| **Developer Worker** | Feature implementation, bug fixes | `agents/developer/AGENT.md` |
| **QA Validator** | Testing, validation, bug reporting | `agents/qa/AGENT.md` |
| **prd.json** | Single source of truth for all state | `prd.json` |

---

## 2. Startup Flow

### Event-Driven Mode Startup Sequence

```
USER ACTION
    │
    ▼
./.claude/scripts/ralph-event-v2-session.ps1
    │
    ├─► Start WATCHDOG process (background)
    │       │
    │       ├─► Creates .claude/session/ with eventlog.jsonl
    │       ├─► Creates named pipes for each agent
    │       ├─► Starts PM Coordinator
    │       └─► Begins monitoring loop
    │
    └─► Start PM Coordinator (terminal 1)
            │
            ├─► Load agents/pm/AGENT.md
            │
            ├─► Activate /pm-workflow skill
            │       │
            │       ├─► Read prd.json
            │       ├─► Select next task
            │       └─► Begin coordination
            │
            ├─► Send WorkAssign message to worker via named pipe
            │       │
            │       └─► Message delivered via Send-Message function
            │
            └─► Exit (WATCHDOG will restart with new context)


WORKER SPAWN (triggered by task_assign message)
    │
    ▼
./.claude/scripts/ralph-worker-event.ps1 --agent developer
    │
    ├─► Load agents/developer/AGENT.md
    │
    ├─► Activate /developer-workflow skill
    │       │
    │       ├─► Read prd.json for task details
    │       ├─► Load relevant skills
    │       └─► Begin work
    │
    ├─► Perform work (research → implement → validate)
    │
    ├─► Send status_update to watchdog
    │
    ├─► Send task_complete or bug_report to PM
    │
    └─► Exit (WATCHDOG will restart with new context)
```

### Sequential Mode Startup Sequence

```
USER ACTION
    │
    ▼
./.claude/scripts/ralph-single-session.ps1
    │
    └─► Start PM Coordinator (terminal 1)
            │
            ├─► Complete task selection
            │
            ├─► Write handoff signal to .claude/session/handoff-signal.json
            │       │
            │       ├─► { "targetAgent": "developer", "context": "...", "timestamp": "..." }
            │
            └─► Exit

    ▼ (User starts next agent)
./.claude/scripts/ralph-worker-single.ps1 --agent developer
    │
    ├─► Read handoff signal
    │
    ├─► Load agents/developer/AGENT.md
    │
    ├─► Perform work
    │
    ├─► Write next handoff signal (to QA)
    │
    └─► Exit
```

---

## 3. Message Flow

### Session Directory Structure

```
.claude/session/
├── eventlog.jsonl         # Append-only event log (source of truth)
├── agent-status.json      # Materialized view from event log
├── undelivered.jsonl      # Failed delivery fallback queue
└── logs/                  # Agent log files
```

### Message Format

```json
{
  "id": "msg-{recipient}-{yyyyMMdd-HHmmss}-{seq}",
  "from": "{sender-agent}",
  "to": "{recipient-agent}",
  "type": "{message-type}",
  "priority": "urgent|high|normal|low",
  "payload": {
    "taskId": "feat-001",
    "summary": "Task description",
    "details": {}
  },
  "timestamp": "2026-01-23T12:00:00.000Z",
  "status": "pending"
}
```

### Message Types

| From → To | Type | Purpose |
|-----------|------|---------|
| **PM → Developer** | `task_assign` | Assign new task |
| **PM → QA** | `task_assign` | Assign validation |
| **Developer → PM** | `question` | Ask for clarification |
| **Developer → QA** | `validation_request` | Request validation |
| **Developer → Watchdog** | `status_update` | Heartbeat |
| **QA → PM** | `task_complete` | Validation passed |
| **QA → PM** | `bug_report` | Validation failed |
| **QA → Developer** | `bug_report` | Return bugs |
| **PM → All** | `retrospective_initiate` | Start retrospective |

### Message Lifecycle

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│     PM      │────▶│   Message   │────▶│  Developer  │
│  Coordinator│     │    Queue    │     │    Worker    │
└─────────────┘     └─────────────┘     └─────────────┘
      │                   │                   │
      │                   │ ▼                  │
      │                   │ Created            │
      │                   │ status=pending     │
      │                   │                   │
      │                   │                   ▼
      │                   │              ┌───────────┐
      │                   │              │ Processing│
      │                   │              │   Work    │
      │                   │              └───────────┘
      │                   │                   │
      │                   │                   ▼
      │                   │              Delete message
      │                   │              Send response
      │                   │                   │
      ▼                   ▼                   ▼
┌───────────────────────────────────────────────────────┐
│                     prd.json                           │
│  - agents.{agent}.status = current state               │
│  - agents.{agent}.currentTaskId = active task          │
│  - items[{taskId}].status = task status                 │
│  - items[{taskId}].passes = validation result         │
└───────────────────────────────────────────────────────┘
```

---

## 4. Agent Execution Flow

### Developer Agent Complete Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                      1. INITIALIZATION                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Command: ./ralph-worker-event.ps1 --agent developer              │
│       │                                                            │
│       ▼                                                            │
│  Load AGENT.md                                                     │
│       │                                                            │
│       ├─► YAML frontmatter (role, name, icon, version)           │
│       ├─► Role Card (Primary, Cannot, Works With, Startup)      │
│       ├─► Core Responsibilities                                   │
│       ├─► Startup Sequence                                        │
│       ├─► Decision Framework                                      │
│       ├─► Task Type to Skill Mapping                             │
│       └─► Skills & Sub-Agents tables                              │
│                                                                     │
│  Activate /developer-workflow skill                                │
│       │                                                            │
│       ├─► Read prd.json                                           │
│       ├─► Check for pending messages                             │
│       ├─► Identify current task                                  │
│       └─► Determine workflow phase                               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      2. TASK RESEARCH                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Check inbox: Read messages from named pipe via Enter-AgentLoop  │
│       │                                                            │
│       ├─► Found WorkAssign message?                              │
│       │       │                                                   │
│       │       ├─► Yes: Extract task details                      │
│       │       │                                                   │
│       │       └─► No: Check prd.json for awaiting work           │
│       │                                                            │
│  Load relevant skills                                             │
│       │                                                            │
│       ├─► dev-r3f-r3f-fundamentals (if R3F task)                     │
│       ├─► dev-multiplayer-server-authoritative (if multiplayer)      │
│       └─► dev-typescript-typescript-basics (if TS task)             │
│                                                                     │
│  Research existing patterns                                        │
│       │                                                            │
│       ├─► Read GDD sections                                      │
│       ├─► Search codebase (Grep/Glob)                             │
│       ├─► Find similar implementations                           │
│       └─► Document findings                                      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      3. IMPLEMENTATION                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Apply skill knowledge to implement feature                         │
│       │                                                            │
│       ├─► Write code following patterns                          │
│       ├─► Use proper TypeScript (no any, no @ts-ignore)          │
│       ├─│ Follow R3F best practices                              │
│       └─► Adhere to server-authoritative architecture (multi)    │
│                                                                     │
│  Send periodic heartbeats to watchdog                              │
│       │                                                            │
│       └─► status_update: "working on feat-001"                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      4. VALIDATION                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Run feedback loops (MANDATORY before commit)                     │
│       │                                                            │
│       ├─► npm run type-check (must pass)                         │
│       ├─► npm run lint (must pass)                                │
│       ├─► npm run test (must pass)                                │
│       └─► npm run build (must succeed)                            │
│                                                                     │
│  If all pass:                                                     │
│       │                                                            │
│       ├─► Update prd.json.items[taskId].status                   │
│       ├─► Send validation_request to QA                          │
│       └─► Exit (watchdog restarts)                                │
│                                                                     │
│  If any fail:                                                    │
│       │                                                            │
│       ├─► Fix issues                                             │
│       ├─► Re-run feedback loops                                   │
│       └─► Loop until all pass                                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      5. COMPLETION                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Receive validation passed from QA                                │
│       │                                                            │
│       ├─► Commit changes with Ralph format:                       │
│       │   [ralph] [developer] feat-001: Brief description         │
│       │                                                            │
│       ├─► Update prd.json:                                        │
│       │   items[feat-001].status = "complete"                     │
│       │   items[feat-001].passes = true                          │
│       │   agents.developer.status = "idle"                        │
│       │                                                            │
│       └─► Send task_complete to PM                                │
│                                                                     │
│  Exit (watchdog detects idle, prepares next task)                 │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 5. Sub-Agent Routing

### Sub-Agent Invocation Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    MAIN AGENT (developer)                           │
│                                                                     │
│  "I need to research existing patterns before implementing"       │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ Uses Task tool
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     SUB-AGENT: code-research                        │
│                                                                     │
│  YAML Frontmatter:                                                 │
│  ---                                                                │
│  name: code-research                                                │
│  description: Research existing codebase patterns before impl      │
│  model: haiku                                                       │
│  skills: [developer/pattern-finding, developer/codebase-exploration,│
│            developer/gdd-reading]                                   │
│  tools: [Read, Grep, Glob]                                        │
│  ---                                                                │
│                                                                     │
│  • Searches codebase for similar implementations                    │
│  • Reads GDD for design context                                   │
│  • Returns findings to orchestrator                                │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ Returns findings
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                 SUB-AGENT: implementation                           │
│                                                                     │
│  • Writes code based on research findings                          │
│  • Uses appropriate R3F/TypeScript skills                           │
│  • Returns to orchestrator when complete                           │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ Code complete
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      SUB-AGENT: validation                          │
│                                                                     │
│  YAML Frontmatter:                                                 │
│  ---                                                                │
│  name: validation                                                   │
│  description: Run feedback loops before commit                     │
│  model: haiku                                                       │
│  skills: [developer/feedback-loops, developer/browser-testing,     │
│            developer/quality-gates]                                 │
│  ---                                                                │
│                                                                     │
│  • Runs type-check, lint, test, build                             │
│  • Returns validation result to orchestrator                       │
└─────────────────────────────────────────────────────────────────────┘
```

### Sub-Agent Registry (Developer)

```json
{
  "subagents": {
    "code-research": {
      "file": "code-research.agent.md",
      "description": "Research existing patterns. MANDATORY before coding.",
      "phase": "research",
      "model": "haiku",
      "triggers": ["task_assigned"]
    },
    "implementation": {
      "file": "implementation.agent.md",
      "description": "Write code following researched patterns.",
      "phase": "implementation",
      "model": "sonnet",
      "triggers": ["research_complete"]
    },
    "validation": {
      "file": "validation.agent.md",
      "description": "Run feedback loops. MANDATORY before commit.",
      "phase": "validation",
      "model": "haiku",
      "triggers": ["implementation_complete"]
    },
    "commit": {
      "file": "commit.agent.md",
      "description": "Handle commits, PRD updates, messaging.",
      "phase": "commit",
      "model": "haiku",
      "triggers": ["validation_passed"]
    }
  },
  "workflow": ["code-research", "implementation", "validation", "commit"]
}
```

---

## 6. File Organization

### Complete Directory Structure with Purposes

```
agentic-threejs/
│
├── agents/                              # MAIN AGENT DEFINITIONS
│   │                                   # Each agent has a single AGENT.md file
│   │
│   ├── developer/AGENT.md               # Developer Agent - main entry point
│   ├── pm/AGENT.md                      # PM Coordinator Agent
│   ├── qa/AGENT.md                      # QA Validator Agent
│   ├── gamedesigner/AGENT.md            # Game Designer Agent
│   └── techartist/                      # Tech Artist Agent
│       ├── AGENT.md
│       ├── checklists/                  # (Empty - planned for future use)
│       ├── references/                  # (Empty - planned for future use)
│       └── skills/                      # (Empty - planned for future use)
│
├── .claude/                             # CLAUDE CLI CONFIGURATION
│   │
│   ├── agents/                          # SUB-AGENT DEFINITIONS (FLAT)
│   │   │                               # 32 .agent.md files, not per-agent subdirs
│   │   │
│   │   ├── implementation.agent.md     # Code implementation specialist
│   │   ├── code-quality.agent.md       # Code quality specialist
│   │   ├── code-research.agent.md      # Code research specialist
│   │   ├── commit.agent.md             # Git commit specialist
│   │   ├── validation.agent.md         # Validation specialist
│   │   ├── gdd-documenter.agent.md     # GDD documentation specialist
│   │   ├── prd-organizer.agent.md      # PRD organization specialist
│   │   └── ... (24 more sub-agents)
│   │
│   ├── commands/                        # SLASH COMMANDS (6 files)
│   │   │
│   │   ├── ralph-coordinator-event.md   # Start PM (event mode)
│   │   ├── ralph-coordinator-single.md  # Start PM (sequential)
│   │   ├── ralph-worker-event.md        # Start worker (event mode)
│   │   ├── ralph-worker-single.md       # Start worker (sequential)
│   │   ├── ralph-hitl.md                # Learning mode
│   │   └── cancel-ralph.md              # Cancel active loop
│   │
│   ├── hooks/                           # Process management hooks
│   │   ├── hooks.json
│   │   └── stop-hook.ps1
│   │
│   ├── orchestration/                   # Agent coordination docs
│   │   ├── agent-handoff.md
│   │   └── multi-session-coordinator.md
│   │
│   ├── protocols/                       # SYSTEM-LEVEL PROTOCOLS
│   │   ├── event-driven.md              # Message-based communication
│   │   ├── sequential.md                # Handoff-based flow
│   │   └── worktree-setup.md            # Git worktree procedures
│   │
│   ├── scripts/                         # PowerShell orchestration scripts (20+ files)
│   │   ├── ralph-event-session.ps1     # Event-driven launcher
│   │   ├── ralph-single-session.ps1    # Sequential launcher
│   │   ├── watchdog-event.ps1          # Event-driven orchestrator
│   │   ├── watchdog-single.ps1         # Sequential orchestrator
│   │   └── ... (16 more utility scripts)
│   │
│   ├── skills/                          # MODULAR SKILLS (FLAT with prefixes)
│   │   │                               # Not organized by agent subdirectories
│   │   │
│   │   ├── dev-r3f-r3f-fundamentals/   # Developer skills (33 total)
│   │   ├── dev-r3f-r3f-materials/
│   │   ├── dev-r3f-r3f-physics/
│   │   ├── dev-typescript-typescript-basics/
│   │   ├── dev-multiplayer-server-authoritative/
│   │   ├── dev-validation-feedback-loops/
│   │   ├── pm-organization-scale-adaptive/  # PM skills (11 total)
│   │   ├── pm-retrospective-facilitation/
│   │   ├── qa-validation-workflow/      # QA skills (8 total)
│   │   ├── qa-browser-testing/
│   │   ├── gd-design-character/         # Game Designer skills (9 total)
│   │   ├── gd-gdd-creation/
│   │   ├── ta-vfx-particles/            # Tech Artist skills (17 total)
│   │   ├── ta-r3f-fundamentals/
│   │   ├── ta-shader-development/
│   │   ├── shared-ralph-core/           # Shared/orchestration skills
│   │   ├── shared-ralph-router/
│   │   ├── shared-ralph-event-protocol/
│   │   └── shared-worker-worktree/
│   │
│   ├── templates/                       # Template files
│   │   ├── SKILL_TEMPLATE.md
│   │   ├── SUBAGENT_TEMPLATE.md
│   │   ├── prd-template.json
│   │   └── progress-template.txt
│   │
│   ├── screenshots/                     # Screenshots from testing
│   │
│   ├── settings.*.json                  # MCP SERVER CONFIGURATIONS
│   │   ├── settings.developer.json
│   │   ├── settings.qa.json
│   │   ├── settings.pm.json
│   │   ├── settings.gamedesigner.json
│   │   ├── settings.techartist.json
│   │   └── settings.local.json
│   │
│   └── session/                        # RUNTIME STATE
│       ├── messages/                   # Message queues
│       │   ├── pm/                      # PM's inbox
│       │   ├── developer/               # Developer's inbox
│       │   ├── qa/                      # QA's inbox
│       │   ├── gamedesigner/            # Game Designer's inbox
│       │   ├── techartist/              # Tech Artist's inbox
│       │   └── watchdog/                # Status updates
│       │
│       ├── logs/                       # Agent output logs
│       │   ├── pm.log & pm.log.exit
│       │   ├── developer.log & developer.log.exit
│       │   ├── qa.log & qa.log.exit
│       │   └── watchdog.log
│       │
│       ├── heartbeat.ps1               # Session heartbeat monitoring
│       ├── progress.txt                # Session progress log
│       ├── handoff-log.json            # Handoff signal history
│       ├── message-state.json          # Current message state
│       ├── messages.log                # Message history log
│       ├── retrospective.txt           # Latest retrospective summary
│       ├── pending-messages-pm.json    # PM message queue
│       ├── pending-messages-developer.json
│       ├── pending-messages-qa.json
│       └── developer-progress.txt     # Developer progress tracking
│
├── docs/                               # DOCUMENTATION
│   ├── agent-template-guide.md        # Agent creation guide
│   ├── architecture-flow-guide.md     # This guide
│   ├── architecture.md                # System architecture overview
│   ├── configuration.md               # PRD format and settings
│   ├── extending.md                   # Adding agents/skills
│   ├── getting-started.md             # Installation guide
│   ├── monitoring.md                  # Dashboard and troubleshooting
│   ├── orchestration-modes.md         # All 4 modes explained
│   ├── skill-mapping.md               # Skills to task mapping
│   ├── skills-best-practices.md       # Skill creation guide
│   ├── subagent-best-practices.md     # Sub-agent guide
│   └── design/gdd/                    # Game Design Document (16 files)
│
├── prd.json                            # SINGLE SOURCE OF TRUTH
│   │                                   # All agent states
│   │                                   # All task statuses
│   │                                   # Session tracking
│
└── progress.txt                        # Session progress log
```

---

## 7. Data Flow Examples

### Example 1: Complete Task Flow (Event-Driven)

```
TIMELINE: Task "feat-001: Implement player movement"

┌─────────────────────────────────────────────────────────────────────┐
│  T0: PM Coordinator assigns task                                  │
├─────────────────────────────────────────────────────────────────────┤
│  PM reads prd.json, selects feat-001                             │
│  PM sends message via Send-Message:                              │
│  {                                                                  │
│    "type": "WorkAssign",                                           │
│    "payload": { "taskId": "feat-001", "title": "Player movement" }  │
│  }                                                                  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  T1: Developer Worker receives task                                │
├─────────────────────────────────────────────────────────────────────┤
│  Watchdog spawns developer with context                            │
│  Developer loads AGENT.md → /developer-workflow                    │
│  Developer reads message, updates prd.json:                       │
│  {                                                                  │
│    "agents.developer.status": "implementing",                    │
│    "agents.developer.currentTaskId": "feat-001"                   │
│  }                                                                  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  T2: Developer invokes code-research sub-agent                     │
├─────────────────────────────────────────────────────────────────────┤
│  Task("code-research", {                                           │
│    prompt: "Find existing movement patterns"                      │
│  })                                                                │
│                                                                     │
│  → Returns: {                                                      │
│      "files": ["src/player/PlayerController.ts"],                  │
│      "patterns": ["useRapierPhysics", "WASD controls"]            │
│    }                                                                │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  T3: Developer implements feature                                   │
├─────────────────────────────────────────────────────────────────────┤
│  Loads dev-r3f-r3f-physics skill                                    │
│  Loads dev-multiplayer-server-authoritative skill                  │
│  Writes code following patterns                                    │
│  Sends heartbeat: status_update to watchdog                        │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  T4: Developer requests validation                                 │
├─────────────────────────────────────────────────────────────────────┤
│  Developer writes: .claude/session/messages/qa/msg-dev-001.json    │
│  {                                                                  │
│    "type": "validation_request",                                  │
│    "payload": { "taskId": "feat-001" }                             │
│  }                                                                  │
│  Developer exits                                                   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  T5: QA Worker validates                                          │
├─────────────────────────────────────────────────────────────────────┤
│  Watchdog spawns QA with context                                   │
│  QA loads AGENT.md → /qa-workflow                                 │
│  QA runs: type-check ✓ lint ✓ test ✓ build ✓                   │
│  QA runs browser tests ✓                                         │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  T6: QA reports success                                            │
├─────────────────────────────────────────────────────────────────────┤
│  QA writes: .claude/session/messages/pm/msg-qa-001.json           │
│  {                                                                  │
│    "type": "task_complete",                                       │
│    "payload": { "taskId": "feat-001", "result": "PASS" }          │
│  }                                                                  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  T7: PM Coordinator completes task                                 │
├─────────────────────────────────────────────────────────────────────┤
│  PM updates prd.json:                                              │
│  {                                                                  │
│    "items.feat-001.status": "complete",                           │
│    "items.feat-001.passes": true                                  │
│  }                                                                  │
│  PM initiates retrospective                                       │
└─────────────────────────────────────────────────────────────────────┘
```

### Example 2: Bug Report Flow (Event-Driven)

```
┌─────────────────────────────────────────────────────────────────────┐
│  T1: QA finds bug during validation                               │
├─────────────────────────────────────────────────────────────────────┤
│  QA writes: .claude/session/messages/developer/msg-qa-bug1.json   │
│  {                                                                  │
│    "type": "bug_report",                                           │
│    "payload": {                                                    │
│      "taskId": "feat-001",                                        │
│      "bugs": [                                                      │
│        { "file": "src/player/PlayerController.ts",                 │
│          "line": 42,                                               │
│          "error": "Type 'any' not allowed"                        │
│        }                                                             │
│      ]                                                               │
│    }                                                                 │
│  }                                                                   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  T2: Developer receives bug report                                  │
├─────────────────────────────────────────────────────────────────────┤
│  Developer loads context from bug report                           │
│  Developer fixes bug                                                │
│  Developer re-runs feedback loops                                   │
│  Developer sends new validation_request                            │
└─────────────────────────────────────────────────────────────────────┘
```

### Example 3: Sequential Mode Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│  PHASE 1: PM Coordinator                                          │
├─────────────────────────────────────────────────────────────────────┤
│  Starts, selects task, writes handoff:                             │
│  {                                                                  │
│    "targetAgent": "developer",                                     │
│    "context": "Implement feat-001",                                │
│    "timestamp": "..."                                             │
│  }                                                                  │
│  PM exits                                                          │
└─────────────────────────────────────────────────────────────────────┘
                              │
                    (User manually starts next agent)
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  PHASE 2: Developer Worker                                        │
├─────────────────────────────────────────────────────────────────────┤
│  Starts, reads handoff, loads AGENT.md                             │
│  Implements feature, runs validation                               │
│  Writes next handoff:                                              │
│  {                                                                  │
│    "targetAgent": "qa",                                           │
│    "context": "Validate feat-001",                                │
│    "timestamp": "..."                                             │
│  }                                                                  │
│  Developer exits                                                   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                    (User manually starts next agent)
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  PHASE 3: QA Validator                                           │
├─────────────────────────────────────────────────────────────────────┤
│  Starts, reads handoff, loads AGENT.md                             │
│  Runs validation                                                  │
│  If pass: Returns to PM (via handoff or message)                  │
│  If fail: Returns to Developer (via handoff or message)            │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Key Principles Summary

| Principle | Description |
|-----------|-------------|
| **AGENT.md is primary** | Loaded first, defines agent identity |
| **Sub-agents are specialists** | Invoked via Task tool for focused work |
| **prd.json is source of truth** | All state tracked here |
| **Messages coordinate agents** | File-based inbox system |
| **Watchdog orchestrates** | Spawns agents, monitors health |
| **Exit after work** | Workers complete work and exit, watchdog restarts |
| **Heartbeats prevent timeout** | Agents send status during long operations |

---

**Document Version**: 1.0
**Last Updated**: 2026-01-23
**For**: Ralph Orchestra v3.0+
