# Ralph Orchestra - Claude Documentation

## Overview

**Ralph Orchestra** is a multi-agent autonomous development framework that coordinates multiple Claude CLI agents to work together on software development tasks.

### Key Features

- **Multi-Agent Coordination** - PM, Developer, Tech Artist, QA, and Game Designer agents with modular skills
- **Three Orchestration Modes** - Event-driven, Sequential, or HITL
- **Watchdog Process** - Never-exit orchestrator that manages agent lifecycle
- **Named Pipe Messaging** - Ultra-fast inter-agent communication (< 10ms delivery)
- **Scale-Adaptive Planning** - PM adjusts approach based on PRD task count (0-4)
- **Skill Improvement** - Agents research and propose skill updates during retrospectives
- **Git Worktrees** - Developer and Tech Artist can work in parallel without conflicts

### Quick Start

```powershell
# Event-driven mode (recommended - parallel with named pipes)
.\.claude\scripts\ralph-event-session.ps1

# Sequential mode (token-efficient - one agent at a time)
.\.claude\scripts\ralph-single-session.ps1

# Polling mode (legacy - parallel with 30s polling)
.\.claude\scripts\ralph-multi-session.ps1

# HITL mode (learn the flow before going AFK)
/ralph-hitl
```

### Documentation

| Document                                                   | Purpose                                        |
| ---------------------------------------------------------- | ---------------------------------------------- |
| [README.md](README.md)                                     | Project overview and quick start               |
| [docs/getting-started.md](docs/getting-started.md)         | Installation, prerequisites, first run         |
| [docs/orchestration-modes.md](docs/orchestration-modes.md) | All 4 orchestration modes explained            |
| [docs/architecture.md](docs/architecture.md)               | System architecture, agent roles, message flow |
| [docs/configuration.md](docs/configuration.md)             | PRD format, agent settings, watchdog config    |
| [docs/extending.md](docs/extending.md)                     | Adding custom agents, skills, routing          |
| [docs/monitoring.md](docs/monitoring.md)                   | Dashboard, logs, troubleshooting               |
| [.claude/scripts/README.md](.claude/scripts/README.md)     | Script reference                               |
| [agents/\*/AGENT.md](agents/)                              | Per-agent behavior instructions                |
| [.claude/skills/](.claude/skills/)                         | Centralized orchestration skills (56+ skills)  |

---

## Agent Roles

- **PM Agent** ([`agents/pm/AGENT.md`](agents/pm/AGENT.md)) - Coordinator that selects tasks, assigns work, runs retrospectives
- **Developer Agent** ([`agents/developer/AGENT.md`](agents/developer/AGENT.md)) - Implements features with domain-specific skills
- **Tech Artist Agent** ([`agents/techartist/AGENT.md`](agents/techartist/AGENT.md)) - Creates visual assets, shaders, and effects
- **QA Agent** ([`agents/qa/AGENT.md`](agents/qa/AGENT.md)) - Validates implementations with tests and browser checks
- **Game Designer Agent** ([`agents/gamedesigner/AGENT.md`](agents/gamedesigner/AGENT.md)) - Creates GDDs, answers design questions, playtests

## MCP Server Configuration

Each agent has specific MCP servers configured:

- **Developer Agent** - GitHub, filesystem, web-search, brave-search
- **Tech Artist Agent** - Playwright, filesystem, GitHub, Vision, Blender, Shadertoy, Image-process
- **QA Agent** - Playwright, filesystem, GitHub, Vision
- **PM Agent** - GitHub, web-search, brave-search, filesystem
- **Game Designer Agent** - GitHub, filesystem, web-search, brave-search, Playwright, Vision

See [`.claude/settings.{agent}.json`](.claude/) for details.

---

## Ralph Wiggum Autonomous Development

Ralph Wiggum is a plugin that enables autonomous AI development loops with multi-agent coordination. It allows PM, Developer, Tech Artist, QA, and Game Designer agents to work together without human intervention across multiple terminal sessions.

### Quick Start

```powershell
# Option 1: Event-Driven (Recommended)
.\.claude\scripts\ralph-event-session.ps1

# Option 2: Sequential (Token-Efficient)
.\.claude\scripts\ralph-single-session.ps1

# Option 3: Manual Terminal Setup

# Event-Driven Mode (parallel agents):
# Terminal 1: PM Agent (Coordinator)
/ralph-coordinator-event

# Terminal 2: Developer Agent (Worker)
/ralph-worker-event --agent developer

# Terminal 3: Tech Artist Agent (Worker)
/ralph-worker-event --agent techartist

# Terminal 4: QA Agent (Worker)
/ralph-worker-event --agent qa

# Terminal 5: Game Designer Agent (Worker)
/ralph-worker-event --agent gamedesigner

# OR Sequential Mode (token-efficient, one agent at a time):
/ralph-coordinator-single
/ralph-worker-single --agent developer
/ralph-worker-single --agent techartist
/ralph-worker-single --agent qa
/ralph-worker-single --agent gamedesigner
```

### Commands

| Command                          | Purpose                                                                   |
| -------------------------------- | ------------------------------------------------------------------------- |
| `/ralph-coordinator-event`       | Start PM agent in event-driven mode                                       |
| `/ralph-coordinator-single`      | Start PM agent in sequential mode                                         |
| `/ralph-worker-event --agent X`  | Start worker agent (developer/techartist/qa/gamedesigner) in event-driven |
| `/ralph-worker-single --agent X` | Start worker agent (developer/techartist/qa/gamedesigner) in sequential   |
| `/ralph-hitl`                    | Single iteration mode for learning                                        |
| `/cancel-ralph`                  | Cancel active loop                                                        |

### How Ralph Works

1. **PM Agent** reviews `prd.json`, applies scale-adaptive planning (0-4), and assigns tasks
2. **Developer Agent** implements features using R3F skills and runs feedback loops
3. **Tech Artist Agent** creates visual assets, shaders, and effects
4. **QA Agent** validates with tests, browser checks, and structured bug reports
5. **Game Designer Agent** creates GDDs, provides design guidance, and performs playtesting
6. **PM Agent** updates PRD status, runs retrospective, proposes skill improvements
7. Progress tracked in `progress.txt` and `.claude/session/` files
8. Each iteration commits work
9. Loop continues until all PRD items have `passes: true`

### Session Files

| File                                     | Purpose                                  |
| ---------------------------------------- | ---------------------------------------- |
| `prd.json`                               | Project requirements with `passes` field |
| `progress.txt`                           | Session progress log                     |
| `.claude/session/coordinator-state.json` | Shared coordination state                |
| `.claude/session/current-task.json`      | Active task details                      |
| `.claude/session/handoff-signal.json`    | Agent switching signals (sequential)     |
| `.claude/session/messages/`              | Message queues (event-driven)            |
| `.claude/session/pipes/`                 | Named pipe endpoints (Phase 2)           |

### Multi-Session Architecture

**Event-Driven Mode (Recommended):**

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
   │ (inbox) │            │ (pipes) │            │ (pipes) │
   └─────────┘            └─────────┘            └─────────┘
        │                      │                      │
        └──────────────────────┼──────────────────────┼───────────────────┐
                               ▼                      ▼                   ▼
                    ┌──────────────────┐    ┌───────────────┐   ┌───────────────┐
                    │  Message Queues  │    │ TechArtist    │   │ GameDesigner  │
                    │   (Named Pipes)  │    │  (pipes)      │   │  (pipes)      │
                    └──────────────────┘    └───────────────┘   └───────────────┘
```

**Sequential Mode (Token-Efficient):**

```
   ┌─────────┐            ┌─────────┐            ┌─────────┐
   │   PM    │ ─handoff─▶ │Developer│ ─handoff─▶ │TechArtist│ ─handoff─▶
   │  Agent  │            │  Agent  │            │  Agent   │
   └─────────┘            └─────────┘            └─────────┘
        ▲                                              │
        └──────────────────────────────────────────────┘
                        (one at a time)
```

### Best Practices

1. **Start with HITL mode** - Use `/ralph-hitl` to learn behavior before going AFK
2. **Use max-iterations** - Always set a safety limit (default: 200)
3. **Define clear scope** - PRD items with explicit acceptance criteria
4. **Track progress** - `progress.txt` logs all completed work
5. **Review commits** - Check git log after loop completes
6. **Small tasks** - Keep PRD items focused for better quality

### Quality Standards

All Ralph work follows production standards:

- No `any` types without justification
- Test coverage > 80% for new code
- Documentation for complex logic
- All feedback loops must pass (type-check, lint, test, build)

### Ralph Documentation

**Orchestration Skills:**

- [`.claude/skills/ralph-core.md`](.claude/skills/ralph-core.md) - Core orchestration concepts
- [`.claude/skills/ralph-router.md`](.claude/skills/ralph-router.md) - Routes to agent skills
- [`.claude/skills/ralph-handoff.md`](.claude/skills/ralph-handoff.md) - Handoff protocol
- [`.claude/skills/ralph-event-protocol.md`](.claude/skills/ralph-event-protocol.md) - Event-driven messaging

**Agent Behavior:**

- [`agents/pm/AGENT.md`](agents/pm/AGENT.md) - PM instructions
- [`agents/developer/AGENT.md`](agents/developer/AGENT.md) - Developer instructions
- [`agents/techartist/AGENT.md`](agents/techartist/AGENT.md) - Tech Artist instructions
- [`agents/qa/AGENT.md`](agents/qa/AGENT.md) - QA instructions
- [`agents/gamedesigner/AGENT.md`](agents/gamedesigner/AGENT.md) - Game Designer instructions

### Example PRD Item

```json
{
  "id": "feat-001",
  "category": "architectural",
  "priority": "high",
  "title": "Vehicle Physics Implementation",
  "description": "Implement vehicle physics with realistic collision and controls",
  "acceptanceCriteria": [
    "Vehicle spawns at origin",
    "WASD controls work correctly",
    "Physics runs at 60fps"
  ],
  "agent": "developer",
  "passes": false
}
```

### See Also

- [README.md](README.md) - Full project documentation with orchestration modes
- [.claude/scripts/README.md](.claude/scripts/README.md) - Script reference and mode selection guide
- [Claude CLI Documentation](https://docs.anthropic.com/en/docs/claude-cli)

### Ralph Troubleshooting

#### Agent stops polling after a few actions

**Symptoms**: Worker or coordinator stops working after completing N tasks.

**Solutions**:

1. Check that skill files have proper YAML frontmatter with `category` field
2. Verify `.claude/hooks/stop-hook.ps1` returns exit code 42
3. Check terminal for any error messages
4. For sequential mode, verify handoff signals are being written
5. For event-driven mode, check message queue in `.claude/session/messages/`

#### Context window overflow

**Symptoms**: Agent becomes slow, forgets previous context, or gives inconsistent responses.

**Solutions**:

1. The agent should automatically detect and reset context at ~70% capacity
2. Manual reset: Output `<promise>CONTEXT_RESET</promise>` in the agent's session
3. Check `.claude/session/context-reset-count.txt` to see how many resets occurred
4. Reset count is tracked automatically and displayed in hook output

#### Session files not found

**Symptoms**: "Waiting for coordinator..." or "Session file not found" errors.

**Solutions**:

1. Use launcher scripts (`ralph-event-session.ps1`, `ralph-single-session.ps1`) which auto-create session
2. For manual setup, ensure `.claude/session/` directory exists
3. For event-driven mode, ensure `.claude/session/messages/` subdirectories exist
4. Check file permissions on the session directory

#### Named pipe issues

**Symptoms**: Messages not delivering between agents.

**Solutions**:

1. Check that watchdog is running (creates named pipes)
2. Verify `.claude/session/pipes/` directory exists
3. System should automatically fallback to file queue if pipes fail
4. Restart session if issues persist

#### MCP filesystem path errors

**Symptoms**: "Path not found" or filesystem MCP errors.

**Solutions**:

1. Check `.claude/settings.{agent}.json` has correct project paths
2. Paths should point to current project, not old directories
3. Update paths if project location changed

---

## See Also

- [README.md](README.md) - Full project documentation with orchestration modes
- [docs/](docs/) - Detailed documentation on getting started, architecture, configuration, and more
- [.claude/scripts/README.md](.claude/scripts/README.md) - Script reference and mode selection guide
- [Claude CLI Documentation](https://docs.anthropic.com/en/docs/claude-cli)
