---
name: ralph-prd-starter
description: Interactive project setup wizard for Ralph Orchestra. Guides through 11 phases configuring agents, orchestration, quality standards, features, research, GDD (games), and PM-generated PRD. Use when user wants to set up a new Ralph Orchestra project or mentions "PRD starter", "project setup wizard", or "initialize Ralph project".
model: opus
allowed-tools: Read File, Write File, Edit File, List Directory, Grep Search, Bash Command, mcp__web-search-prime__webSearchPrime
---

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

## Workflow

**CRITICAL: Invoke and follow the protocols in `ralph-prd-starter` skill. Must follow this skill for detailed information over how to behave on each phase.**
**CRITICAL: Must Invoke the  `prd-starter-project-analyzer` subagent for NLP-based project analyzer once collected enough information about the project scope**

## 11-Phase Overview

**CRITICAL:** Always prefer to use the `AskUserQuestion` tool whenever need user confirmation in between the steps.

| Phase | Purpose | Output |
|-------|---------|--------|
| 1 | Entry Point | Wizard mode selection |
| 2 | Preset Selection | Quick Start templates (optional) |
| 3 | Project Identity | Name, description, category, tech stack |
| 3.3 | Run subagent `prd-starter-project-analyzer` for context polish.
| 4 | Agent Configuration | Agent definitions (names, roles, skills) |
| 5 | Orchestration Mode | Event-driven, Sequential, or HITL |
| 6 | MCP Servers | Server selection and configuration |
| 7 | Quality Standards | Code review, tests, docs requirements |
| 8 | Initial Features | Feature descriptions (natural language) |
| 8b | Deep Research | pm-research-specialist subagent |
| 8c | GDD Creation | gamedesigner-thermite-facilitator (games only) |
| 8d | PRD Creation | pm-prd-creator subagent |
| 9 | Review & Confirm | Display summary, await approval |
| 10 | Project Generation | Invoke Python generator |
| 11 | Completion | Display next steps |

## Generated Files

After confirmation, the following files are generated:

### For Each Agent
- `./.claude/skills/{name}-workflow/SKILL.md` - Agent behavior definition
- `./.claude/settings.{name}.json` - MCP configuration

### Project Files
- `prd.json` - Initial PRD with features (created by PM agent in Phase 8d)
- `docs/research-summary.md` - Research findings (created in Phase 8b)
- `docs/design/` - GDD documents for game projects (created in Phase 8c)
  - `decision_log.md` - Design decisions
  - `open_questions.md` - Unresolved questions
  - `specs.md` - Project specifications (for non-games)
  - `gdd.md` - GDD summary (for games)

### Updated Scripts
- `watchdog-event.ps1` - Adds agents to ValidateSet
- `watchdog-single.ps1` - Adds agents to handoff pattern
- `message-queue.ps1` - Adds agents to message routing
- `ralph-event-session.ps1` - Adds agent directories
- `ralph-single-session.ps1` - Adds agent validation

## State Persistence

Progress is saved in `./.claude/session/prd-starter-state.json`:

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
.\.claude\scripts\prd-starter-generator.ps1 -Action generate -StateFile .\.claude\session\prd-starter-state.json -Verbose
```

### Mac/Linux (Bash)
```bash
python3 ./.claude/scripts/prd-starter-generator.py --action generate --state ./.claude/session/prd-starter-state.json --verbose
```

### Reset State
```powershell
# Windows
.\.claude\scripts\prd-starter-generator.ps1 -Action reset

# Mac/Linux
python3 ./.claude/scripts/prd-starter-generator.py --action reset
```

## Requirements

- Python 3.8+
- Jinja2 (`pip install jinja2`)
- PyYAML (`pip install pyyaml`)
- JSONSchema (`pip install jsonschema`)

Or install all dependencies:
```bash
pip install -r ./.claude/scripts/prd-starter-requirements.txt
```

## See Also
- [./.claude/skills/ralph-prd-starter/SKILL.md](../skills/ralph-prd-starter/SKILL.md) - Skill implementation
- [./.claude/scripts/prd-starter-generator.py](../scripts/prd-starter-generator.py) - Generator code
