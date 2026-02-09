# PRD Starter Wizard

> Interactive project setup wizard for Ralph Orchestra that generates complete project configurations through an 11-phase guided process.

## Overview

The PRD Starter Wizard automates Ralph Orchestra project initialization by:
- Collecting project requirements through conversational prompts
- Researching similar projects and best practices
- Creating game design documents (for game projects)
- Generating PM-quality PRDs
- Scaffolding complete project structure with agents, scripts, and documentation

**Key Features:**
- **State persistence** - Resume from any phase if interrupted
- **Sub-agent automation** - Research, GDD, and PRD creation handled by specialized agents
- **Template presets** - Quick-start with Web, Game, Mobile, Backend, Data, or DevOps templates
- **Cross-platform** - Windows (PowerShell) and Unix (Bash) support

## Quick Start

### Via Claude CLI

```bash
# Launch wizard with slash command
/ralph-prd-starter

# Or invoke the skill directly
/skill ralph-prd-starter
```

### Manual Python Invocation

```bash
# Windows
cd .claude/scripts/prd-starter
python cli.py --action generate --state ..\..\..\..\.claude\session\prd-starter-state.json

# macOS/Linux
cd .claude/scripts/prd-starter
python cli.py --action generate --state ../../../.claude/session/prd-starter-state.json
```

## 11-Phase Workflow

### Phase 1: Entry Point

**Choose wizard experience:**
- **Quick Start** - Pre-configured templates, skip to Phase 8 (features)
- **Standard** - Guided configuration with sensible defaults
- **Expert** - Full control over all settings

**State saved:** `wizardMode`

### Phase 2: Preset Selection (Quick Start Only)

**Available presets:**

| Template | Agents | Orchestration | Use Case |
|----------|--------|---------------|----------|
| Web App | PM, Developer, QA | Event-driven | Web applications, SPAs |
| Game Project | PM, Developer, QA, Game Designer, Tech Artist | Event-driven | Game development |
| Mobile App | PM, Developer, QA, Mobile Specialist | Sequential | iOS/Android apps |
| Backend Service | PM, Developer, QA, DevOps | Event-driven | APIs, microservices |
| Data Pipeline | PM, Developer, QA, Data Engineer | Sequential | ETL, analytics |
| DevOps Platform | PM, Developer, QA, DevOps | Event-driven | Infrastructure, CI/CD |

**State saved:** `projectData`, `agentsData`, `orchestrationData` (preset values)

### Phase 3: Project Identity

**Collected information:**
- Project name (alphanumeric + hyphens)
- Description (1-2 sentences)
- Category (web/game/mobile/backend/data/devops/other)
- Tech stack (comma-separated list)
- Project location (absolute path, defaults to current directory)

**Validation:**
- Name must be alphanumeric with hyphens
- Category must match allowed values
- Path must be valid and writable

**State saved:** `projectData`

### Phase 4: Agent Configuration

**Agent definition:**
1. Count (1-20 recommended, 3-10 typical)
2. For each agent:
   - Name (lowercase, e.g., "developer")
   - Display name (e.g., "Senior Developer")
   - Role description (1 sentence)
   - Skills (MCP servers or custom skills)
   - Allowed tools (default: Read, Write, Edit, List, Grep, Bash)

**Validation:**
- Names must be lowercase alphanumeric + hyphens
- Each agent must have unique name

**State saved:** `agentsData`

### Phase 5: Orchestration Mode

**Modes:**

| Mode | Description | Best For |
|------|-------------|----------|
| Event-Driven | Watchdog + message queue | Teams, parallel work, async coordination |
| Sequential | Linear handoffs | Solo dev, simple workflows |
| HITL | Human-in-the-loop learning | Training, observing agent behavior |

**Additional configuration:**
- Watchdog monitoring enabled (event mode only)
- Auto-resume on failure
- Message deduplication

**State saved:** `orchestrationData`

### Phase 6: MCP Server Configuration

**Available servers:**
- gitkraken - Git operations
- fetch - HTTP requests
- playwright - Browser automation
- vision - Image analysis
- websearch - Web search
- memory - Agent memory
- filesystem - File operations

**Special option:** "default" selects gitkraken + fetch

**State saved:** `mcpData`

### Phase 7: Quality Standards

**Standard gates:**
- Code review required (yes/no)
- Automated tests required (yes/no)
- Documentation required (yes/no)
- Performance benchmarks required (yes/no)

**Custom standards:** Comma-separated list or "none"

**State saved:** `qualityData`

### Phase 8: Initial Features

**Format:** Natural language feature descriptions, one per line

**Example:**
```
User authentication with email and password
Dashboard with project overview and metrics
File upload with drag-and-drop support
done
```

Type "done" to finish.

**State saved:** `featuresData`

### Phase 8b: Deep Research

**Automated research process:**
1. Wizard invokes `pm-research-specialist` subagent
2. Subagent researches 3-5 similar projects
3. Identifies 5-10 best practices for category/tech stack
4. Generates 5-10 clarifying questions

**User interaction:**
- Review research findings (similar projects, best practices)
- Answer clarifying questions
- Responses inform PRD generation

**State saved:** `researchData`

**Generated file:** `docs/research-summary.md` (Phase 10)

### Phase 8c: GDD Creation (Games Only)

**Conditional:** Only runs if `category === "game"`

**Automated GDD process:**
1. Wizard invokes `gamedesigner-thermite-facilitator` subagent
2. Subagent runs multi-persona Boardroom Retreat design session
3. Personas debate design decisions
4. Generate 10-15 design decisions (DEC-NNN)
5. Generate 5-10 open questions (OQ-NNN)
6. Create comprehensive GDD document

**State saved:** `gddData`

**Generated files (Phase 10):**
- `docs/design/decision_log.md`
- `docs/design/open_questions.md`
- `docs/design/gdd.md`

### Phase 8d: PRD Creation

**Automated PRD process:**
1. Wizard invokes `pm-prd-creator` subagent
2. Subagent analyzes all project context:
   - Project identity and agents
   - Features and quality standards
   - Research findings
   - GDD decisions (if game)
   - User answers to clarifying questions
3. Creates comprehensive `prd.json` with:
   - Structured user stories with acceptance criteria
   - Technical requirements and architecture
   - Non-functional requirements
   - Game design alignment (if applicable)
   - Priorities and dependencies

**Review process:**
- Subagent presents PRD summary
- User reviews and requests changes (iterative)
- User approves final version

**State saved:** `prdData` (approved = true, prdPath)

**Generated file:** `prd.json` (Phase 10)

### Phase 9: Review & Confirm

**Summary display:**
- Project name, description, category, tech stack
- Agent count and names
- Orchestration mode
- Quality standards
- Features count
- Research projects analyzed
- PRD approval status

**User choice:**
- **Generate** - Proceed to Phase 10
- **Edit** - Return to specific phase
- **Restart** - Start over from Phase 1
- **Exit** - Save state and quit

### Phase 10: Project Generation

**Python generator invocation:**
```bash
cd .claude/scripts/prd-starter
python cli.py --action generate --state {path_to_state.json}
```

**Generated files:**

| Category | Files |
|----------|-------|
| Agent configs | `agents/{name}/AGENT.md`, `agents/{name}/SKILLS.md` |
| MCP settings | `.claude/settings.{name}.json` |
| Scripts | Updated orchestration scripts (watchdog, message-queue, ralph-session) |
| Documentation | `docs/research-summary.md`, `docs/design/*` (games), `README.md`, `CLAUDE.md` |
| PRD | `prd.json` |
| Init scripts | `scripts/init-project.ps1`, `scripts/init-project.sh` |

**Script updates:**
- `watchdog-event.ps1` - Adds agents to ValidateSet
- `watchdog-single.ps1` - Adds agents to handoff pattern
- `message-queue.ps1` - Adds agents to message routing
- `ralph-event-session.ps1` - Adds agent directories
- `ralph-single-session.ps1` - Adds agent validation

### Phase 11: Completion

**Next steps:**
1. Run initialization script
2. Review generated documentation
3. Start orchestration with `/ralph-coordinator-event` or `/ralph-coordinator-single`

**Post-generation options:**
- Run initialization now
- View generated files
- Exit wizard

**State cleanup:** Archive to `.claude/session/archive/` (optional)

## State Management

### State File

**Location:** `.claude/session/prd-starter-state.json`

**Schema version:** 4.0.0

**Structure:**
```json
{
  "_version": "4.0.0",
  "_lastUpdated": "2026-02-08T12:00:00Z",
  "currentPhase": 1,
  "projectData": { ... },
  "agentsData": { ... },
  "orchestrationData": { ... },
  "mcpData": { ... },
  "qualityData": { ... },
  "featuresData": { ... },
  "researchData": { ... },
  "gddData": { ... },
  "prdData": { ... },
  "wizardMode": ""
}
```

### Resume Capability

**On wizard invocation with existing state:**
```
Found previous session at Phase {currentPhase}.

1. Resume from Phase {currentPhase}
2. Restart from beginning
3. Exit wizard

Select option (1-3):
```

**Resume behavior:**
- Loads all previous data
- Displays current phase prompt
- Continues normal flow

**Restart behavior:**
- Backs up existing state to `.claude/session/archive/`
- Creates new empty state
- Starts from Phase 1

### Manual State Editing

**Advanced users can edit state directly:**
```json
{
  "currentPhase": 5,  // Jump to Phase 5
  "projectData": {
    "name": "my-project",  // Pre-fill values
    // ...
  }
}
```

**⚠️ Warning:** Invalid state structure may cause generator errors.

## Outputs

### Agent Files

**Path:** `agents/{name}/`

**AGENT.md structure:**
```markdown
---
name: {name}
description: {role}
tools: {allowed_tools}
---

# {display_name}

You are the **{display_name}** for {project_name}.

## Responsibilities
{role_description}

## Skills
{skills_list}

## Workflow
{orchestration_specific_instructions}
```

**SKILLS.md:** Index of available skills for the agent

### MCP Settings

**Path:** `.claude/settings.{name}.json`

**Structure:**
```json
{
  "mcpServers": {
    "gitkraken": {
      "command": "npx",
      "args": ["-y", "@gitkraken/mcp-server"],
      "env": {}
    }
    // ... other servers
  }
}
```

### Documentation

**research-summary.md:** Similar projects, best practices, Q&A from Phase 8b

**GDD files (games only):**
- `docs/design/decision_log.md` - Design decisions with rationale
- `docs/design/open_questions.md` - Unresolved design questions
- `docs/design/gdd.md` - Comprehensive game design document

**prd.json:** Production-ready PRD with user stories, technical requirements, and acceptance criteria

**README.md:** Project overview, setup instructions, agent descriptions, orchestration commands

**CLAUDE.md:** Project-specific Claude Code instructions, workflow rules, coding standards

### Initialization Scripts

**Windows:** `scripts/init-project.ps1`
**Unix:** `scripts/init-project.sh`

**Actions:**
- Install dependencies based on tech stack
- Setup virtual environments (Python, Node, etc.)
- Initialize git repository
- Create required directories
- Run initial build/compile

## Manual Invocation

If automatic generator invocation fails, use manual commands:

### Windows
```powershell
cd .claude\scripts\prd-starter
python cli.py --action generate --state ..\..\..\..\claude\session\prd-starter-state.json
```

### macOS/Linux
```bash
cd .claude/scripts/prd-starter
python cli.py --action generate --state ../../../.claude/session/prd-starter-state.json
```

### Python Wrapper
```bash
# From project root
.claude/scripts/prd-starter/prd-starter-generator.py --state .claude/session/prd-starter-state.json
```

## Error Handling

### Invalid Input

**Behavior:** Prompt user to re-enter with valid format/options
**Resolution:** Provide examples and acceptable values

### Subagent Failure

**Phases affected:** 8b (research), 8c (GDD), 8d (PRD)

**Behavior:** Log error, offer retry or skip

**Resolution:**
- Check subagent definition exists in `.claude/agents/`
- Verify subagent has required tools
- Review subagent error output for details

### Generator Failure

**Phase affected:** 10 (generation)

**Behavior:** Display error output, provide manual invocation path

**Common causes:**
- Missing Python dependencies
- Invalid state structure
- Permission errors writing files
- Template rendering errors

**Resolution:**
- Verify Python 3.8+ installed
- Check state file is valid JSON
- Ensure write permissions in project directory
- Review generator output for specific error

### State Corruption

**Detection:** Invalid JSON or missing required fields

**Behavior:** Offer to reset or repair, backup to archive/

**Resolution:**
- Validate JSON syntax: `python -m json.tool .claude/session/prd-starter-state.json`
- Compare against template: `.claude/templates/prd-starter-state-template.json`
- Manually fix or restart wizard

## Best Practices

### Planning

- **Research first** - Review similar projects before starting wizard
- **Prepare tech stack list** - Know your dependencies upfront
- **Define agent responsibilities** - Clear role separation prevents conflicts

### During Wizard

- **Be specific** - Detailed feature descriptions produce better PRDs
- **Answer thoughtfully** - Clarifying questions inform architecture decisions
- **Review thoroughly** - Phase 9 summary is your last chance to edit

### After Generation

- **Run initialization immediately** - Setup environment while setup is fresh
- **Review generated files** - Understand what was created for your project
- **Customize as needed** - Generated files are starting points, not final products

## Related Documentation

- [Getting Started](getting-started.md) - Ralph Orchestra basics
- [Orchestration Modes](orchestration-modes.md) - Event-driven vs Sequential vs HITL
- [Configuration](configuration.md) - Agent and MCP configuration details
- [PRD Starter Workflows](prd-starter-workflows.md) - Integrating wizard outputs with orchestration
- [PRD Starter Templates](prd-starter-templates.md) - Template architecture and customization

---

*Last updated: 2026-02-08*
