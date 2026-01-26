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
- **Deep research phase** - Researches similar projects and best practices
- **GDD creation for games** - Thermite design sessions for game projects
- **PM-generated PRD** - Final PRD created by PM agent with full expertise
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

The wizard guides you through 11 phases:

| Phase | Description | Output |
|-------|-------------|--------|
| 1 | Entry Point | Quick Start, Standard, or Expert mode |
| 2 | Preset Selection (Quick only) | Pre-configured agent templates |
| 3 | Project Identity | Name, description, category, tech stack |
| 4-7 | Configuration | Agents, orchestration, quality standards |
| 8 | Initial Features | Natural language feature descriptions |
| 8b | Deep Research (NEW) | Research findings + clarifying questions |
| 8c | GDD Creation (Games only) | Thermite session + design documents |
| 8d | PRD Creation (NEW) | PM-generated prd.json with review |
| 9 | Review & Confirm | Final summary before generation |
| 10-11 | Project Init + Workflows | Initialization scripts and docs |

### New Phases in v4.0

**Phase 8b - Deep Research:**
- Launches `pm-research-specialist` sub-agent
- Researches similar projects and best practices
- Generates 5-10 targeted clarifying questions
- User answers questions to refine project scope

**Phase 8c - GDD Creation (Games only):**
- Launches `gamedesigner-thermite-facilitator`
- Runs Boardroom Retreat with expert personas
- Creates design decisions (DEC-NNN) and open questions (OQ-NNN)
- Generates GDD documents in `docs/design/`

**Phase 8d - PRD Creation:**
- Launches `pm-prd-creator` agent
- Uses PM expertise for proper PRD structure
- Incorporates research, GDD, and user answers
- Presents PRD for user review before final approval

## Generated Files

After confirmation, the following files are generated:

### For Each Agent
- `agents/{name}/AGENT.md` - Agent behavior definition
- `agents/{name}/SKILLS.md` - Skills index
- `.claude/settings.{name}.json` - MCP configuration

### Project Files
- `prd.json` - Initial PRD with features (created by PM agent in Phase 8d)
- `docs/research-summary.md` - Research findings (created in Phase 8b)
- `docs/design/` - GDD documents for game projects (created in Phase 8c)
  - `decision_log.md` - Design decisions
  - `open_questions.md` - Unresolved questions
  - `gdd.md` - GDD summary

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
  "version": "4.0.0",
  "startedAt": "2026-01-26T10:00:00Z",
  "completedAt": null,
  "currentPhase": "deep_research",
  "researchData": { ... },
  "gddData": { ... },
  "prdSpecification": { ... }
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
