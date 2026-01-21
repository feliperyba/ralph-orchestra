# Ralph Orchestra - Multi-Agent Autonomous Development Framework

A powerful, extensible framework for orchestrating multiple AI agents (Claude) to work together on software development tasks. Agents coordinate through shared state files and can operate in parallel or sequential modes.

## 🎯 What is Ralph Orchestra?

Ralph Orchestra enables **autonomous software development** by coordinating multiple Claude CLI agents with different roles:

- **PM Agent** (Coordinator) - Selects tasks, assigns work, runs retrospectives
- **Developer Agent** (Worker) - Implements features, writes code, runs feedback loops
- **QA Agent** (Worker) - Validates implementations, runs tests, reports bugs

The agents communicate through shared JSON state files and can run indefinitely until all tasks are complete.

## 🚀 Quick Start

### Prerequisites

- [Claude CLI](https://docs.anthropic.com/en/docs/claude-cli) installed and authenticated
- PowerShell 5.1+ (Windows) or Bash (Linux/macOS)
- Node.js 18+ (for the example project)

### Installation

```bash
git clone https://github.com/feliperyba/ralph-orchestra
cd ralph-orchestra
npm install
```

### Running Agents

#### Option 1: Event-Driven Mode ⭐ Recommended

All **three agents run in parallel** with message-based communication (no polling).

```powershell
# Windows PowerShell
.\.claude\scripts\ralph-event-session.ps1
```

**How it works:**

1. Watchdog starts all 3 agents with message inboxes
2. PM assigns tasks via messages → Developer picks up from inbox
3. Developer completes → sends validation request to QA
4. QA validates → sends result back to PM
5. PM updates PRD, runs retrospective at end

**Benefits:** Parallel execution, no polling overhead, message history

#### Option 2: Sequential Mode (Token-Efficient)

Only **one agent runs at a time**. A watchdog process orchestrates handoffs.

```powershell
# Windows PowerShell
.\.claude\scripts\ralph-single-session.ps1
```

**How it works:**

1. Watchdog starts PM agent
2. PM selects a task, writes handoff signal → Watchdog kills PM, starts Developer
3. Developer implements, writes handoff signal → Watchdog kills Developer, starts QA
4. QA validates, writes handoff signal → Watchdog kills QA, starts PM
5. Repeat until all tasks complete

**Benefits:** ~70% lower token usage, simpler debugging, clear execution flow

#### Option 3: Parallel Mode (Polling-Based)

All **three agents run simultaneously**, each polling for work every 30s.

```powershell
# Windows PowerShell
.\.claude\scripts\ralph-multi-session.ps1
```

**Benefits:** Simple implementation, agents can work on different tasks concurrently

#### Option 4: HITL Mode (Human-in-the-Loop)

Run a **single iteration with full visibility** - ideal for learning before going AFK.

```
/ralph-hitl
```

**Benefits:** Watch exactly what happens, learn the flow, then switch to autonomous

> **💡 See also:** [Usage Interfaces](#-usage-interfaces) for a detailed comparison of PowerShell Scripts, Claude CLI, and Claude Code IDE.

### Stopping Agents

- **Ctrl+C** in the watchdog terminal
- Run `/cancel-ralph` in any agent terminal
- All tasks complete → agents output `<promise>RALPH_COMPLETE</promise>`
- Max iterations reached → watchdog stops all agents gracefully

---

## 🔄 Max Iterations Configuration

### What is an Iteration?

**One iteration = one complete development cycle (PM→Dev→QA→PM):**

```
PM selects task → assigns to developer
    ↓
Developer implements feature
    ↓
QA validates implementation (reports bugs OR passes)
    ↓
PM receives QA's result
    ↓
Iteration counter increments (regardless of pass/fail)
```

This means if QA finds bugs and the task needs rework, that still counts as 1 iteration.

### Setting Max Iterations

**Method 1: Environment Variable (Recommended)**

```powershell
# Set for current session
$env:RALPH_MAX_ITERATIONS = 100
.\.claude\scripts\ralph-event-session.ps1

# Or set permanently (system-wide)
[System.Environment]::SetEnvironmentVariable('RALPH_MAX_ITERATIONS', '100', 'User')
```

**Method 2: Script Parameter Override**

```powershell
# Event-driven mode
.\.claude\scripts\ralph-event-session.ps1 -MaxIterations 50

# Sequential mode
.\.claude\scripts\ralph-single-session.ps1 -MaxIterations 50

# Polling mode
.\.claude\scripts\ralph-multi-session.ps1 -MaxIterations 50
```

**Method 3: Edit Configuration Default**

Edit [`.claude/scripts/ralph-config.ps1`](.claude/scripts/ralph-config.ps1) line 132:

```powershell
MaxIterations = Get-EnvInt -Name "RALPH_MAX_ITERATIONS" -Default 100
```

### Default Values

| Configuration                                                        | Default Value          |
| -------------------------------------------------------------------- | ---------------------- |
| Config file ([`ralph-config.ps1`](.claude/scripts/ralph-config.ps1)) | 200 iterations         |
| Environment variable                                                 | `RALPH_MAX_ITERATIONS` |
| Session script parameter                                             | Overrides env var      |
| Hardcoded fallback (stop-hook)                                       | 50 iterations          |

### Stopping Conditions

Agents stop when **EITHER**:

1. **All PRD tasks have `passes: true`** → Normal completion
2. **Max iterations reached** → `status = "max_iterations_reached"`

Both the watchdog and all child agent processes will gracefully terminate.

### Monitoring Iteration Progress

The coordinator state file tracks iterations:

```json
{
  "maxIterations": 200,
  "iteration": 5,
  "status": "running"
}
```

View with:

```powershell
Get-Content .claude\session\coordinator-state.json | ConvertFrom-Json
```

---

## 💻 Usage Interfaces

Ralph can be invoked through **three different interfaces**, each with different trade-offs:

### Interface Comparison

| Interface              | How to Invoke                               | Session Setup | Token Efficiency | Best For                      |
| ---------------------- | ------------------------------------------- | ------------- | ---------------- | ----------------------------- |
| **PowerShell Scripts** | `.\.claude\scripts\ralph-event-session.ps1` | Automatic     | Medium           | Production, autonomous runs   |
| **Claude CLI**         | `/ralph-coordinator` in terminal            | Manual        | Standard         | Direct agent control          |
| **Claude Code IDE**    | `/ralph-hitl` in chat                       | Semi-auto     | Standard         | Learning, integrated workflow |

### PowerShell Scripts (Recommended for Production)

**Full orchestration with watchdog:**

```powershell
# Event-driven (parallel, message queues) - Recommended
.\.claude\scripts\ralph-event-session.ps1

# Sequential (token-efficient)
.\.claude\scripts\ralph-single-session.ps1

# Polling-based (legacy)
.\.claude\scripts\ralph-multi-session.ps1
```

**What happens:**

1. Watchdog process starts and creates `.claude/session/`
2. All agents launch in separate terminal windows
3. Watchdog monitors health and orchestrates handoffs
4. Real-time dashboard shows agent status

**Benefits:**

- Automatic session management
- Health monitoring and auto-restart on crash
- Real-time progress dashboard
- Graceful shutdown handling (Ctrl+C)

**Ideal for:** Running autonomous development sessions while you're away from the computer.

### Claude CLI (Terminal)

**Direct slash commands in separate terminals:**

```bash
# Terminal 1: PM Coordinator
/ralph-coordinator

# Terminal 2: Developer Worker
/ralph-worker --agent developer

# Terminal 3: QA Worker
/ralph-worker --agent qa

# Single iteration (learning mode)
/ralph-hitl
```

**What happens:**

1. Each terminal runs a single agent
2. Agents communicate via shared state files in `.claude/session/`
3. You must create `.claude/session/` directory first (agents auto-create it)
4. Manual setup of each terminal required

**Benefits:**

- Full visibility into each agent's thinking process
- Can intervene at any time
- No watchdog overhead
- Easier debugging

**Differences from PowerShell scripts:**
| Aspect | PowerShell Scripts | Claude CLI |
|--------|-------------------|------------|
| Session setup | Automatic | Manual |
| Crash recovery | ✓ Auto-restart | ✗ Manual restart |
| Progress dashboard | ✓ Real-time | ✗ Terminal output only |
| Multi-terminal | ✓ Auto-spawned | Manual setup |
| Health monitoring | ✓ Heartbeat checks | ✗ |

**Ideal for:** Learning how Ralph works, debugging agent behavior, or when you want hands-on control.

### Claude Code IDE (VSCode Extension)

**Slash commands directly in the chat interface:**

```
/ralph-hitl
```

**What happens:**

1. IDE loads agent settings from `.claude/settings.{agent}.json`
2. Skills are loaded automatically based on YAML frontmatter `category` field
3. File operations use IDE's native tools (Read, Write, Edit, Grep)
4. Progress visible in IDE output panel

**Benefits:**

- Integrated with your development workflow
- Native file operations (no terminal context switching)
- Auto skill loading based on task category
- See agent reasoning in real-time

**Differences from CLI:**

| Feature             | PowerShell Scripts | Claude CLI    | Claude Code IDE    |
| ------------------- | ------------------ | ------------- | ------------------ |
| Session auto-create | ✓                  | ✓             | ✓                  |
| Watchdog monitoring | ✓                  | ✗             | ✗                  |
| Multi-terminal      | ✓                  | Manual        | ✗ (single session) |
| Skill auto-loading  | ✗                  | ✗             | ✓                  |
| Dashboard           | ✓                  | ✗             | ✗                  |
| Crash recovery      | ✓                  | ✗             | ✗                  |
| File operations     | Bash commands      | Bash commands | Native IDE tools   |

**Skill Auto-Loading in IDE:**

The IDE automatically loads skills based on the YAML frontmatter:

```yaml
---
name: ralph-router
description: Routes to appropriate Ralph skills based on agent role
category: orchestration
depends-on: []
---
```

When you invoke `/ralph-hitl`, the IDE:

1. Loads all skills with `category: orchestration` from `.claude/skills/`
2. The router skill determines which domain-specific skills to load
3. Agent-specific skills load from `agents/{role}/skills/`

**Ideal for:** Learning the flow, single-iteration testing, or when you want the agent integrated with your IDE workflow.

### Quick Reference: Which Interface Should I Use?

| Scenario                                   | Recommended Interface                           |
| ------------------------------------------ | ----------------------------------------------- |
| **Going AFK, let agents run autonomously** | PowerShell Scripts (`ralph-event-session.ps1`)  |
| **Learning how Ralph works**               | CLI or IDE (`/ralph-hitl`)                      |
| **Debugging agent behavior**               | CLI (separate terminals for visibility)         |
| **Quick task while coding**                | IDE (`/ralph-hitl` in chat)                     |
| **Production environment**                 | PowerShell Scripts (with watchdog)              |
| **Token-constrained session**              | PowerShell Scripts (`ralph-single-session.ps1`) |

---

## 📁 Project Structure

```
Ralph Orchestra/
├── .claude/
│   ├── commands/           # Slash commands for agents
│   │   ├── ralph-coordinator.md        # PM parallel mode
│   │   ├── ralph-coordinator-single.md # PM sequential mode
│   │   ├── ralph-worker.md             # Dev/QA parallel mode
│   │   ├── ralph-worker-single.md      # Dev/QA sequential mode
│   │   └── cancel-ralph.md             # Graceful shutdown
│   │
│   ├── scripts/            # Orchestration scripts
│   │   ├── watchdog-event.ps1        # Event-driven orchestrator
│   │   ├── watchdog-single.ps1       # Sequential mode orchestrator
│   │   ├── watchdog.ps1              # Polling mode orchestrator
│   │   ├── ralph-event-session.ps1   # Event-driven launcher
│   │   ├── ralph-single-session.ps1  # Sequential mode launcher
│   │   ├── ralph-multi-session.ps1   # Polling mode launcher
│   │   ├── message-queue.ps1         # Message queue functions
│   │   ├── worktree-manager.ps1      # Git worktree management
│   │   └── ralph-config.ps1          # Shared configuration
│   │
│   ├── skills/             # Orchestration skills (YAML frontmatter)
│   │   ├── ralph-core.md             # Core orchestration concepts
│   │   ├── ralph-router.md           # Routes to agent skills
│   │   ├── ralph-coordinator.md      # PM polling mode
│   │   ├── ralph-coordinator-single.md # PM sequential mode
│   │   ├── ralph-worker.md           # Worker polling mode
│   │   ├── ralph-worker-single.md    # Worker sequential mode
│   │   ├── ralph-handoff.md          # Handoff protocol
│   │   ├── ralph-event-protocol.md   # Event-driven messaging
│   │   ├── ralph-hitl.md             # Human-in-the-loop mode
│   │   ├── r3f-router.md             # R3F skill routing
│   │   └── cancel-ralph.md           # Graceful shutdown
│   │
│   ├── session/            # Runtime state (gitignored)
│   │   ├── coordinator-state.json    # Main coordination state
│   │   ├── current-task.json         # Active task details
│   │   ├── handoff-signal.json       # Agent switching signals
│   │   ├── pending-handoff.json      # Context for next agent
│   │   ├── messages/                 # Event-driven message queues
│   │   └── logs/                     # Agent output logs
│   │
│   ├── hooks/              # Claude CLI hooks
│   │   ├── stop-hook.ps1   # Keep-alive for parallel mode
│   │   └── hooks.json      # Hook configuration
│   │
│   └── settings.*.json     # Per-agent Claude settings
│
├── agents/                 # Modular agent definitions
│   ├── pm/
│   │   ├── AGENT.md        # PM behavior instructions
│   │   ├── SKILLS.md       # Skills index
│   │   ├── skills/         # Modular skills
│   │   │   ├── task-selection.md     # Priority algorithm
│   │   │   ├── retrospective.md      # Retrospective facilitation
│   │   │   ├── skill-improvement.md  # MCP-based skill updates
│   │   │   └── scale-adaptive.md     # Scale 0-4 planning
│   │   ├── checklists/     # Validation checklists
│   │   │   ├── prd-validation.md     # PRD field validation
│   │   │   └── task-handoff.md       # Handoff protocol
│   │   └── references/     # Reference docs
│   │       └── state-files.md        # State file structure
│   │
│   ├── developer/
│   │   ├── AGENT.md        # Developer behavior instructions
│   │   ├── SKILLS.md       # Skills index
│   │   ├── skills/         # Modular skills
│   │   │   ├── r3f-fundamentals.md   # R3F scene composition
│   │   │   ├── r3f-materials.md      # Materials & shaders
│   │   │   ├── r3f-physics.md        # Rapier physics
│   │   │   ├── r3f-performance.md    # Performance optimization
│   │   │   ├── feedback-loops.md     # Type/lint/test/build
│   │   │   └── typescript-patterns.md # TS best practices
│   │   ├── checklists/     # Validation checklists
│   │   │   ├── pre-commit.md         # Pre-commit checks
│   │   │   └── code-quality.md       # Code standards
│   │   └── references/     # Reference docs
│   │       └── code-patterns.md      # Reusable templates
│   │
│   └── qa/
│       ├── AGENT.md        # QA behavior instructions
│       ├── SKILLS.md       # Skills index
│       ├── skills/         # Modular skills
│       │   ├── validation-workflow.md # Full validation pipeline
│       │   ├── browser-testing.md    # Playwright MCP testing
│       │   └── bug-reporting.md      # Bug report format
│       ├── checklists/     # Validation checklists
│       │   └── validation-checks.md  # Comprehensive checks
│       └── references/     # Reference docs
│           └── browser-testing-patterns.md # Playwright patterns
│
├── prd.json                # Product Requirements Document (tasks)
├── CLAUDE.md               # Project context for Claude
└── README.md               # This file
```

---

## 🔄 Orchestration Modes

Ralph Orchestra supports **four orchestration modes** for different use cases:

### Mode Comparison

| Mode             | Agents Running | Communication   | Token Usage | Best For                  |
| ---------------- | -------------- | --------------- | ----------- | ------------------------- |
| **Sequential**   | 1 at a time    | Handoff files   | Lowest      | Learning, debugging       |
| **Polling**      | 3 simultaneous | Polling (30s)   | High        | Legacy, simple projects   |
| **Event-Driven** | 3 simultaneous | Message queues  | Medium      | Production, complex tasks |
| **HITL**         | 1 at a time    | User-controlled | Lowest      | Learning before going AFK |

### Sequential Mode (Handoff-Based)

```
┌─────────────────────────────────────────────────────────────────────┐
│                         WATCHDOG PROCESS                             │
│                    (Orchestrates agent switching)                    │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
        ▼                       ▼                       ▼
   ┌─────────┐            ┌─────────┐            ┌─────────┐
   │   PM    │ ─handoff─▶ │Developer│ ─handoff─▶ │   QA    │
   │  Agent  │            │  Agent  │            │  Agent  │
   └─────────┘            └─────────┘            └─────────┘
        ▲                                              │
        └──────────────────────────────────────────────┘
                        handoff (loop)
```

**Handoff Protocol:**

1. Agent writes to `handoff-signal.json` with target and context
2. Watchdog detects signal, gracefully stops current agent
3. Watchdog writes `pending-handoff.json` with context
4. Watchdog starts target agent, which reads pending context

### Event-Driven Mode (Message-Based) ⭐ Recommended

```
┌─────────────────────────────────────────────────────────────────────┐
│                    WATCHDOG (Message Broker)                         │
│              (Routes messages, monitors health)                      │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        ▼                       ▼                       ▼
   ┌─────────┐            ┌─────────┐            ┌─────────┐
   │   PM    │◄──────────►│Developer│◄──────────►│   QA    │
   │ (inbox) │            │ (inbox) │            │ (inbox) │
   └─────────┘            └─────────┘            └─────────┘
        │                      │                      │
        └──────────────────────┼──────────────────────┘
                               ▼
                    ┌──────────────────┐
                    │  Message Queues  │
                    │   (File-based)   │
                    └──────────────────┘
```

**Message Types:** `task_assign`, `validation_request`, `bug_report`, `task_complete`, `question/answer`

### Parallel Mode (Polling-Based) - Legacy

```
┌─────────────────────────────────────────────────────────────────────┐
│                         WATCHDOG PROCESS                             │
│              (Monitors health, restarts crashed agents)              │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        ▼                       ▼                       ▼
   ┌─────────┐            ┌─────────┐            ┌─────────┐
   │   PM    │            │Developer│            │   QA    │
   │ (polls) │            │ (polls) │            │ (polls) │
   └────┬────┘            └────┬────┘            └────┬────┘
        │                      │                      │
        └──────────────────────┼──────────────────────┘
                               ▼
                    ┌──────────────────┐
                    │  Shared State    │
                    │   JSON Files     │
                    └──────────────────┘
```

---

## 📋 Task Lifecycle

```
┌──────────────────────────────────────────────────────────────────────┐
│                         TASK LIFECYCLE                                │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────┐  │
│  │ 1. SELECT   │───▶│ 2. ASSIGN   │───▶│ 3. IMPLEMENT            │  │
│  │   (PM)      │    │  (PM→Dev)   │    │   (Developer)           │  │
│  │             │    │             │    │                         │  │
│  │ Read PRD    │    │ Update      │    │   - R3F fundamentals    │  │
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

### Scale-Adaptive Planning

The PM agent uses scale levels (0-4) based on PRD task count:

| Scale | Task Count | Parallelism | Overhead    | Planning Style      |
| ----- | ---------- | ----------- | ----------- | ------------------- |
| 0     | 1-3        | None        | Minimal     | Direct execution    |
| 1     | 4-8        | Low         | Light       | Simple grouping     |
| 2     | 9-15       | Medium      | Moderate    | Dependency analysis |
| 3     | 16-30      | High        | Significant | Critical path focus |
| 4     | 31+        | Very High   | Heavy       | Phased rollout      |

---

## 📄 PRD Format (prd.json)

The Product Requirements Document defines all tasks:

```json
{
  "projectName": "My Project",
  "version": "1.0.0",
  "features": [
    {
      "id": "feat-001",
      "title": "User Authentication",
      "priority": "high",
      "status": "pending",
      "passes": false,
      "dependencies": [],
      "acceptanceCriteria": [
        "Users can register with email/password",
        "Users can log in and receive JWT token",
        "Protected routes require valid token"
      ],
      "technicalNotes": "Use bcrypt for password hashing"
    },
    {
      "id": "feat-002",
      "title": "User Profile Page",
      "priority": "medium",
      "status": "pending",
      "passes": false,
      "dependencies": ["feat-001"],
      "acceptanceCriteria": ["Display user info from JWT", "Allow profile picture upload"]
    }
  ]
}
```

**Key Fields:**

- `passes: false` → Task needs work
- `passes: true` → Task completed and validated
- `dependencies` → Task IDs that must be complete first
- `status` → "pending", "in_progress", "ready_for_qa", "passed", "failed"

---

## 🔧 Configuration

### Agent Settings (.claude/settings.\*.json)

Each agent can have custom Claude CLI settings:

```json
{
  "model": "claude-sonnet-4-20250514",
  "permissions": {
    "allow": ["Read", "Write", "Edit", "Bash", "Computer"],
    "deny": []
  },
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-filesystem", "/path/to/project"]
    }
  }
}
```

### Watchdog Configuration

```powershell
# Sequential mode options
.\.claude\scripts\ralph-single-session.ps1 `
    -InitialAgent "pm" `           # Start with PM (default)
    -GracefulShutdownSeconds 30 `  # Wait time before force-kill
    -MaxRestarts 3 `               # Retries before longer wait
    -NoDashboard                   # Disable live dashboard

# Parallel mode options
.\.claude\scripts\ralph-multi-session.ps1 `
    -IdleTimeoutSeconds 120 `      # Restart if no activity
    -CheckIntervalMs 2000 `        # Health check frequency
    -Agents "pm","developer","qa"  # Which agents to run
```

---

## 🧩 Extending Ralph Orchestra

### Modular Agent Structure

Each agent follows a modular structure with YAML frontmatter:

```
agents/<role>/
├── AGENT.md              # Core behavior instructions
├── SKILLS.md             # Skills index with links
├── skills/               # Modular skill files
│   ├── skill-name.md     # Progressive levels (1-5)
│   └── ...
├── checklists/           # Validation checklists
│   └── checklist-name.md
└── references/           # Reference documentation
    └── reference-name.md
```

**Skill File Format (YAML Frontmatter):**

```yaml
---
name: skill-name
description: Brief description of the skill
category: domain|orchestration|validation
depends-on: [other-skill]
---
# Skill Name

## Level 1: Fundamentals
...
## Level 5: Expert Patterns
...
## Anti-Patterns
❌ **DON'T:** Bad practice
✅ **DO:** Good practice
```

### Adding Custom Agents

#### Understanding the Skill Variant System

Ralph uses a **skill variant pattern** where a single skill can handle multiple agent types via arguments. The key example is `ralph-worker`:

**How ralph-worker Works:**

```yaml
---
name: ralph-worker
description: Worker loop - execute tasks assigned by coordinator
category: orchestration
arguments:
  --agent: "developer" or "qa"
---
```

**Invocation:**

```bash
/ralph-worker --agent developer  # Runs as Developer
/ralph-worker --agent qa          # Runs as QA
```

**Inside the skill**, the agent checks `$arguments.agent` to determine:

- Which skills directory to load (`agents/developer/skills/` vs `agents/qa/skills/`)
- What behavior to follow (coding vs validation)
- What state files to update

#### Agent Configuration (ralph-config.ps1)

All agents are defined in [`.claude/scripts/ralph-config.ps1`](.claude/scripts/ralph-config.ps1):

```powershell
$Script:AgentConfig = @{
    "pm" = @{
        Type = "coordinator"
        Command = "/ralph-coordinator"
        DisplayName = "PM (Coordinator)"
        Color = "Magenta"
    }
    "developer" = @{
        Type = "worker"
        Command = "/ralph-worker --agent developer"
        DisplayName = "Developer"
        Color = "Cyan"
    }
    "qa" = @{
        Type = "worker"
        Command = "/ralph-worker --agent qa"
        DisplayName = "QA"
        Color = "Yellow"
    }
}
```

#### Step-by-Step: Adding a "Designer" Agent

**Step 1: Create Agent Directory Structure**

```
agents/designer/
├── AGENT.md              # Core behavior instructions
├── SKILLS.md             # Skills index
├── skills/               # Modular skills
│   ├── ui-patterns.md
│   ├── accessibility.md
│   └── design-systems.md
├── checklists/
│   └── design-review.md
└── references/
    └── component-library.md
```

**Step 2: Create AGENT.md**

```markdown
# YOU ARE THE DESIGNER AGENT

# Your job: CREATE and REVIEW UI/UX designs

## When to Use This Agent

- Task category contains "design", "ui", "ux", "accessibility"
- PM assigns tasks with agent=designer
- Design review is needed before implementation

## Your Workflow

1. Read design requirements from current-task.json
2. Create/update UI components following design system
3. Ensure accessibility standards (WCAG 2.1 AA)
4. Document design decisions
```

**Step 3: Update ralph-config.ps1**

Add the new agent to the `AgentConfig` hashtable in [`.claude/scripts/ralph-config.ps1`](.claude/scripts/ralph-config.ps1:210):

```powershell
$Script:AgentConfig = @{
    # ... existing agents ...
    "designer" = @{
        Type = "worker"
        Command = "/ralph-worker --agent designer"
        DisplayName = "Designer"
        Color = "Blue"
    }
}
```

**Step 4: Create Slash Command (Optional)**

Create [`.claude/commands/ralph-designer.md`](.claude/commands/ralph-designer.md):

````markdown
---
description: Start Designer agent for UI/UX work
---

# /ralph-designer

Start the **Designer** agent for UI/UX tasks.

## Usage

```bash
/ralph-designer
```
````

````

## What It Does

- Reviews design requirements
- Creates accessible UI components
- Follows design system patterns

**Step 5: Update Watchdog Scripts**

Modify [`.claude/scripts/watchdog-single.ps1`](.claude/scripts/watchdog-single.ps1:293):

```powershell
$slashCommand = switch ($AgentName) {
    "pm" { "/ralph-coordinator-single" }
    "developer" { "/ralph-worker-single --agent developer" }
    "qa" { "/ralph-worker-single --agent qa" }
    "designer" { "/ralph-worker-single --agent designer" }  # Add this
}
````

Also update the valid agents array in [`.claude/scripts/watchdog-single.ps1`](.claude/scripts/watchdog-single.ps1:102):

```powershell
$validAgents = @("pm", "developer", "qa", "designer")  # Add "designer"
```

**Step 6: Update ralph-worker Skill**

Modify [`.claude/skills/ralph-worker.md`](.claude/skills/ralph-worker.md:88) to include the new agent type:

```markdown
## Determine Your Agent Type

Check the `--agent` argument:

- **"developer"**: Implement features and run feedback loops
- **"qa"**: Validate implementations with tests and browser checks
- **"designer"**: Create and review UI/UX designs # Add this
```

Add a new section for the Designer's workflow:

```markdown
## Designer Agent Path

**IF `--agent == "designer"`**:

Look for tasks where:

- `currentTask.assignedAgent == "designer"`
- `currentTask.status` is "assigned" or "needs_revision"

**When you find work**:

1. Update your status to "working"
2. Read task specs from `current-task.json`
3. Create/update designs following design system
4. Ensure accessibility (WCAG 2.1 AA)
5. Document design decisions
6. Update task status to "ready_for_review"
7. HANDOFF to qa or developer as appropriate
```

**Step 7: Create Agent-Specific Settings**

Create [`.claude/settings.designer.json`](.claude/settings.designer.json):

```json
{
  "mcpServers": {
    "filesystem": { ... },
    "figma": {  # Design tool integration
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-figma"]
    }
  }
}
```

#### Worker vs Coordinator Pattern

| Aspect         | Coordinator (PM)              | Workers (Dev/QA/Designer)              |
| -------------- | ----------------------------- | -------------------------------------- |
| **Type**       | `Type = "coordinator"`        | `Type = "worker"`                      |
| **Instances**  | Single instance               | Multiple instances can run in parallel |
| **Command**    | No `--agent` argument         | Requires `--agent` argument            |
| **State File** | Owns `coordinator-state.json` | Polls for tasks assigned to them       |

#### Skill Variant Best Practices

1. **Use `--agent` for variants** of the same pattern:
   - `/ralph-worker --agent developer`
   - `/ralph-worker --agent qa`
   - `/ralph-worker --agent designer`

2. **Use separate slash commands** for fundamentally different behaviors:
   - `/ralph-coordinator` (orchestration)
   - `/ralph-hitl` (single iteration)

3. **Keep skill content generic** - use the `--agent` value to branch behavior

4. **Document agent-specific paths** clearly in the skill file

#### Testing Your New Agent

1. **Manual testing:**

   ```bash
   /ralph-worker --agent designer
   ```

2. **Sequential mode:**

   ```powershell
   .\.claude\scripts\ralph-single-session.ps1 -InitialAgent designer
   ```

3. **Add test task to prd.json:**

   ```json
   {
     "id": "design-001",
     "title": "Design login page",
     "agent": "designer",
     "status": "pending",
     "passes": false
   }
   ```

4. **Verify:**
   - Agent loads correct skills from `agents/designer/skills/`
   - Handoff signals work correctly
   - Watchdog recognizes the agent type

### Custom Skill Routing

Add entries to [`.claude/skills/ralph-router.md`](.claude/skills/ralph-router.md):

```markdown
## Routing Table

| Signal Pattern     | Target Skill          |
| ------------------ | --------------------- |
| agent=designer     | agents/designer/      |
| task contains "ui" | skills/ui-patterns.md |
```

### Custom Handoff Logic

For the watchdog to recognize your new agent, modify the switch statement in [`.claude/scripts/watchdog-single.ps1`](.claude/scripts/watchdog-single.ps1:293):

```powershell
$slashCommand = switch ($AgentName) {
    "pm" { "/ralph-coordinator-single" }
    "developer" { "/ralph-worker-single --agent developer" }
    "qa" { "/ralph-worker-single --agent qa" }
    "designer" { "/ralph-worker-single --agent designer" }  # New agent
}
```

### Integrating with CI/CD

```yaml
# .github/workflows/ralph.yml
name: Ralph Autonomous Development

on:
  workflow_dispatch:
    inputs:
      mode:
        description: 'Orchestration mode'
        default: 'event'
        type: choice
        options:
          - event
          - sequential
          - parallel

jobs:
  ralph:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Claude CLI
        run: npm install -g @anthropic-ai/claude-cli

      - name: Run Ralph
        run: |
          switch ("${{ inputs.mode }}") {
            "event" { .\.claude\scripts\ralph-event-session.ps1 }
            "sequential" { .\.claude\scripts\ralph-single-session.ps1 }
            "parallel" { .\.claude\scripts\ralph-multi-session.ps1 }
          }
```

### Custom State Files

Add your own coordination files in `.claude/session/`:

```powershell
# In ralph-config.ps1, add to Get-RalphPaths
$paths = @{
    SessionDir = $sessionDir
    CoordinatorState = Join-Path $sessionDir "coordinator-state.json"
    CurrentTask = Join-Path $sessionDir "current-task.json"
    MessagesDir = Join-Path $sessionDir "messages"  # Event-driven queues
    # Add custom files:
    DesignSpecs = Join-Path $sessionDir "design-specs.json"
    ApiContracts = Join-Path $sessionDir "api-contracts.json"
}
```

---

## 🛠️ Troubleshooting

### Agents Not Switching (Sequential Mode)

1. Check if `handoff-signal.json` is being created:

   ```powershell
   cat .\.claude\session\handoff-signal.json
   ```

2. Run the test script:

   ```powershell
   .\.claude\scripts\test-handoff-detection.ps1 -CreateTestSignal
   ```

3. Verify agent commands include handoff instructions

### Agents Stop Polling (Parallel Mode)

1. Check heartbeats in `coordinator-state.json`
2. Verify `AGENT.md` files have "NEVER STOP POLLING" instructions
3. Check watchdog logs for restart events

### Context Window Overflow

- Agents auto-reset at ~70% context capacity
- Reduce task complexity or split into smaller tasks
- Use sequential mode (lower token usage per session)

### PowerShell Execution Policy

```powershell
# Allow script execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Claude CLI Not Found

```bash
# Install Claude CLI
npm install -g @anthropic-ai/claude-cli

# Verify installation
claude --version
```

---

## 📊 Monitoring

### Dashboard (Event-Driven / Parallel Mode)

The watchdog displays a live dashboard:

```
================================================================================
  RALPH WATCHDOG - Event-Driven Mode
================================================================================

  Uptime: 01:23:45  |  Messages: 42  |  Tasks: 3/8

  AGENT STATUS
  --------------------------------------------------------------------------
  pm         | PID: 1234 | RUNNING | Inbox: 2   | Processed: 15
  developer  | PID: 5678 | RUNNING | Inbox: 1   | Processed: 20
  qa         | PID: 9012 | RUNNING | Inbox: 0   | Processed: 7
  --------------------------------------------------------------------------

  Press Ctrl+C to stop watchdog
================================================================================
```

### Log Files

All agent output is logged to `.claude/session/logs/`:

- `pm.log` - PM agent output
- `developer.log` - Developer agent output
- `qa.log` - QA agent output
- `watchdog-summary.log` - Session summary on exit

### Message History (Event-Driven)

Messages are archived in `.claude/session/messages/archive/` for debugging.

---

## 🔐 Security Considerations

- **`--dangerously-skip-permissions`**: Used for autonomous operation. Only run in trusted environments.
- **MCP Servers**: Filesystem access is scoped to project directory
- **State Files**: Contain task details, not credentials
- **Git Commits**: Agents commit with their own identity

---

## 📚 Additional Resources

### Internal Documentation

- [Usage Interfaces](#-usage-interfaces) - PowerShell Scripts, Claude CLI, and Claude Code IDE comparison
- [Adding Custom Agents](#-adding-custom-agents) - Step-by-step guide for adding new agent types
- [Orchestration Modes](#-orchestration-modes) - Sequential, Event-Driven, and Polling modes
- [Project Structure](#-project-structure) - Directory layout and file organization

### Agent Skills

- **PM Agent**: [Task Selection](agents/pm/skills/task-selection.md), [Scale-Adaptive](agents/pm/skills/scale-adaptive.md), [Retrospective](agents/pm/skills/retrospective.md)
- **Developer Agent**: [R3F Fundamentals](agents/developer/skills/r3f-fundamentals.md), [R3F Performance](agents/developer/skills/r3f-performance.md), [Feedback Loops](agents/developer/skills/feedback-loops.md)
- **QA Agent**: [Validation Workflow](agents/qa/skills/validation-workflow.md), [Browser Testing](agents/qa/skills/browser-testing.md)

### External Documentation

- [Claude CLI Documentation](https://docs.anthropic.com/en/docs/claude-cli)
- [MCP Protocol](https://modelcontextprotocol.io/)
- [React Three Fiber](https://docs.pmnd.rs/react-three-fiber)
- [Rapier Physics](https://rapier.rs/)

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run the agents to validate
5. Submit a pull request

---

## 📜 License

MIT License - See [LICENSE](LICENSE) for details.

---

## 📖 References and Inspiration

This project was conceived and developed based on the following resources:

### Core Multi-Agent Frameworks

- **[BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD)** - Breakthrough Make And Deliver method for AI agent orchestration
- **[Agents.md](https://agents.md/)** - Comprehensive guide on AI agent architectures and patterns
- **[Agent Skills.md](https://agent-skills.md/)** - Best practices for designing and implementing agent skills

### Ralph Wiggum Autonomous Development

- **[Ralph Wiggum - Claude Code](https://github.com/anthropics/claude-code/blob/main/plugins/ralph-wiggum/README.md)** - Official Ralph Wiggum plugin documentation
- **[Tips for AI Coding with Ralph Wiggum](https://www.aihero.dev/tips-for-ai-coding-with-ralph-wiggum)** - Practical guide for effective Ralph usage
- **[Ralph Multi-Session Architecture](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum)** - Multi-agent orchestration patterns

### Claude AI & MCP

- **[Claude CLI Documentation](https://docs.anthropic.com/en/docs/claude-cli)** - Official Claude CLI reference
- **[Model Context Protocol (MCP)](https://modelcontextprotocol.io/)** - Standard for connecting AI models to external tools
- **[MCP Servers](https://github.com/modelcontextprotocol)** - Collection of official MCP server implementations
- **[Anthropic Claude Documentation](https://docs.anthropic.com/)** - Comprehensive Claude API and CLI documentation

---
