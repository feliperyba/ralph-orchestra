# `/ralph-prd-starter` Command

Project-agnostic agent setup wizard for Ralph Orchestra.

## Quick Start

```
/ralph-prd-starter
```

## Description

The `ralph-prd-starter` command launches an interactive setup wizard that guides you through configuring Ralph Orchestra for your project. It supports:

- **Any project type** - Web, game, mobile, backend, data, DevOps, or custom
- **Custom agents** - Define N agents with any roles, skills, and permissions
- **Cross-platform** - Works on Windows, macOS, and Linux
- **Research-backed** - Researches best practices between phases
- **State persistence** - Resume from any phase if interrupted

## Usage

### CLI

```bash
# From Claude Code CLI
/ralph-prd-starter

# Or use the skill directly
/skill ralph-prd-starter
```

### IDE (VSCode)

Invoke the skill from the command palette or inline.

## Workflow

The wizard guides you through 8 phases:

| Phase | Description | Output |
|-------|-------------|--------|
| 1 | Project Identification | Project type, name, description |
| 2 | Agent Configuration | N agents with roles, skills, permissions |
| 3 | Workflow Pattern | Waterfall, Collaborative, or Autonomous |
| 4 | Orchestration Mode | Event-driven, Sequential, or HITL |
| 5 | Technology Stack | Frontend, backend, database, tools |
| 6 | Quality Standards | TypeScript, testing, linting, CI/CD |
| 7 | Initial Features | Feature list with acceptance criteria |
| 8 | Review & Confirm | Summary and file generation |

## Generated Files

After confirmation, the following files are generated:

### For Each Agent
- `agents/{name}/AGENT.md` - Agent behavior definition
- `agents/{name}/SKILLS.md` - Skills index
- `.claude/settings.{name}.json` - MCP configuration

### Project Files
- `prd.json` - Initial PRD with features

### Updated Scripts
- `watchdog-event.ps1` - Adds agents to ValidateSet
- `watchdog-single.ps1` - Adds agents to handoff pattern
- `message-queue.ps1` - Adds agents to message routing
- `ralph-event-session.ps1` - Adds agent directories
- `ralph-single-session.ps1` - Adds agent validation

## State Persistence

Progress is saved in `.claude/session/prd-starter-state.json`:

```json
{
  "version": "1.0.0",
  "startedAt": "2026-01-23T10:00:00Z",
  "completedAt": null,
  "currentPhase": "agent_configuration",
  "phases": { ... }
}
```

To resume, simply invoke `/ralph-prd-starter` again - it will detect the state file and continue from where you left off.

## Manual Generator Invocation

After the state file is complete, you can manually invoke the generator:

### Windows (PowerShell)
```powershell
.\.claude\scripts\prd-starter-generator.ps1 -Action generate -StateFile .claude\session\prd-starter-state.json -Verbose
```

### Mac/Linux (Bash)
```bash
python3 .claude/scripts/prd-starter-generator.py --action generate --state .claude/session/prd-starter-state.json --verbose
```

### Reset State
```powershell
# Windows
.\.claude\scripts\prd-starter-generator.ps1 -Action reset

# Mac/Linux
python3 .claude/scripts/prd-starter-generator.py --action reset
```

## Requirements

- Python 3.8+
- Jinja2 (`pip install jinja2`)
- PyYAML (`pip install pyyaml`)
- JSONSchema (`pip install jsonschema`)

Or install all dependencies:
```bash
pip install -r .claude/scripts/prd-starter-requirements.txt
```

## Examples

### Web Application Setup
```
Phase 1: Web Application → React, TypeScript
Phase 2: Developer (React + TS), QA (Playwright)
Phase 3: Collaborative workflow
Phase 4: Event-driven orchestration
Phase 5: Vite, Vitest, ESLint
Phase 6: TypeScript strict, 80% coverage
Phase 7: Auth feature, Dashboard feature
Phase 8: Generate
```

### Game Development Setup
```
Phase 1: Game Development → Three.js, React Three Fiber
Phase 2: Developer (R3F), Tech Artist (shaders), QA (E2E)
Phase 3: Collaborative workflow
Phase 4: Event-driven orchestration
Phase 5: Vite, Playwright
Phase 6: TypeScript strict, 80% coverage
Phase 7: Player controller, Physics, UI overlay
Phase 8: Generate
```

## See Also

- [agents/prd-starter/AGENT.md](../../agents/prd-starter/AGENT.md) - Agent behavior
- [.claude/skills/ralph-prd-starter/SKILL.md](../skills/ralph-prd-starter/SKILL.md) - Skill implementation
- [.claude/scripts/prd-starter-generator.py](../scripts/prd-starter-generator.py) - Generator code
- [README.md](../../README.md) - Ralph Orchestra overview
