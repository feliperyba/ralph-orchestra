# Ralph Orchestra - Claude Documentation

## Overview

**Ralph Orchestra** is a multi-agent autonomous development framework that coordinates multiple Claude CLI agents to work together on software development tasks.

### Key Features

- **Multi-Agent Coordination** - PM, Developer, and QA agents with modular skills
- **Four Orchestration Modes** - Event-driven, Sequential, Polling, or HITL
- **Watchdog Process** - Never-exit orchestrator that manages agent lifecycle
- **Message-Based Communication** - File-based messages for agent coordination
- **Scale-Adaptive Planning** - PM adjusts approach based on PRD task count (0-4)
- **Skill Improvement** - Agents research and propose skill updates during retrospectives

### Quick Start

```powershell
# Event-driven mode (recommended - parallel with message queues)
.\.claude\scripts\ralph-event-session.ps1

# Sequential mode (token-efficient - one agent at a time)
.\.claude\scripts\ralph-single-session.ps1

# Polling mode (legacy - parallel with 30s polling)
.\.claude\scripts\ralph-multi-session.ps1

# HITL mode (learn the flow before going AFK)
/ralph-hitl
```

### Documentation

| Document | Purpose |
|----------|---------|
| [README.md](README.md) | Project overview and quick start |
| [docs/getting-started.md](docs/getting-started.md) | Installation, prerequisites, first run |
| [docs/orchestration-modes.md](docs/orchestration-modes.md) | All 4 orchestration modes explained |
| [docs/architecture.md](docs/architecture.md) | System architecture, agent roles, message flow |
| [docs/configuration.md](docs/configuration.md) | PRD format, agent settings, watchdog config |
| [docs/extending.md](docs/extending.md) | Adding custom agents, skills, routing |
| [docs/monitoring.md](docs/monitoring.md) | Dashboard, logs, troubleshooting |
| [.claude/scripts/README.md](.claude/scripts/README.md) | Script reference |
| [agents/\*/AGENT.md](agents/) | Per-agent behavior instructions |
| [agents/\*/skills/](agents/) | Modular skills (YAML frontmatter) |
| [.claude/skills/](.claude/skills/) | Orchestration skills & routers |

---

## Agent Roles

- **PM Agent** ([`agents/pm/AGENT.md`](agents/pm/AGENT.md)) - Coordinator that selects tasks, assigns work, runs retrospectives
- **Developer Agent** ([`agents/developer/AGENT.md`](agents/developer/AGENT.md)) - Implements features with domain-specific skills
- **QA Agent** ([`agents/qa/AGENT.md`](agents/qa/AGENT.md)) - Validates implementations with tests and browser checks
- **Game Designer Agent** ([`agents/gamedesigner/AGENT.md`](agents/gamedesigner/AGENT.md)) - Creates GDDs, answers design questions, playtests

## MCP Server Configuration

Each agent has specific MCP servers configured:

- **Developer Agent** - GitHub, filesystem, web-search, brave-search
- **QA Agent** - Playwright, filesystem, GitHub
- **PM Agent** - GitHub, web-search, filesystem
- **Game Designer Agent** - GitHub, filesystem, web-search

See [`.claude/settings.{agent}.json`](.claude/) for details.

---

## Ralph Wiggum Autonomous Development

Ralph Wiggum is a plugin that enables autonomous AI development loops with multi-agent coordination. It allows PM, Developer, and QA agents to work together without human intervention across multiple terminal sessions.

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

# Terminal 3: QA Agent (Worker)
/ralph-worker-event --agent qa

# OR Sequential Mode (token-efficient, one agent at a time):
/ralph-coordinator-single
/ralph-worker-single --agent developer
/ralph-worker-single --agent qa
```

### Commands

| Command                     | Purpose                                      |
| --------------------------- | -------------------------------------------- |
| `/ralph-coordinator-event`  | Start PM agent in event-driven mode          |
| `/ralph-coordinator-single` | Start PM agent in sequential mode            |
| `/ralph-worker-event --agent X` | Start worker agent (developer/qa) in event-driven |
| `/ralph-worker-single --agent X` | Start worker agent (developer/qa) in sequential |
| `/ralph-hitl`               | Single iteration mode for learning           |
| `/cancel-ralph`             | Cancel active loop                           |

### How Ralph Works

1. **PM Agent** reviews `prd.json`, applies scale-adaptive planning (0-4), and assigns tasks
2. **Developer Agent** implements features using R3F skills and runs feedback loops
3. **QA Agent** validates with tests, browser checks, and structured bug reports
4. **PM Agent** updates PRD status, runs retrospective, proposes skill improvements
5. Progress tracked in `progress.txt` and `.claude/session/` files
6. Each iteration commits work
7. Loop continues until all PRD items have `passes: true`

### Session Files

| File                                     | Purpose                                  |
| ---------------------------------------- | ---------------------------------------- |
| `prd.json`                               | Project requirements with `passes` field |
| `progress.txt`                           | Session progress log                     |
| `.claude/session/coordinator-state.json` | Shared coordination state                |
| `.claude/session/current-task.json`      | Active task details                      |
| `.claude/session/handoff-signal.json`    | Agent switching signals (sequential)     |
| `.claude/session/messages/`              | Message queues (event-driven)            |

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
   │ (inbox) │            │ (inbox) │            │ (inbox) │
   └─────────┘            └─────────┘            └─────────┘
```

**Sequential Mode (Token-Efficient):**

```
   ┌─────────┐            ┌─────────┐            ┌─────────┐
   │   PM    │ ─handoff─▶ │Developer│ ─handoff─▶ │   QA    │
   │  Agent  │            │  Agent  │            │  Agent  │
   └─────────┘            └─────────┘            └─────────┘
        ▲                                              │
        └──────────────────────────────────────────────┘
                        (one at a time)
```

### Best Practices

1. **Start with HITL mode** - Use `/ralph-hitl` to learn behavior before going AFK
2. **Use max-iterations** - Always set a safety limit (default: 50)
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

- [`agents/pm/AGENT.md`](agents/pm/AGENT.md) - PM instructions + [skills/](agents/pm/skills/)
- [`agents/developer/AGENT.md`](agents/developer/AGENT.md) - Developer instructions + [skills/](agents/developer/skills/)
- [`agents/qa/AGENT.md`](agents/qa/AGENT.md) - QA instructions + [skills/](agents/qa/skills/)

### Example PRD Item

```json
{
  "id": "feat-001",
  "category": "architectural",
  "priority": "high",
  "title": "Vehicle Physics Implementation",
  "acceptanceCriteria": ["Vehicle spawns at origin", "WASD controls work", "Physics runs at 60fps"],
  "passes": false,
  "agent": "developer"
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
