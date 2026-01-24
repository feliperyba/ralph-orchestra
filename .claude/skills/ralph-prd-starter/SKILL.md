---
name: ralph-prd-starter
description: Project-agnostic agent setup wizard for Ralph Orchestra - guides users through creating custom agents, skills, and configuration
category: orchestration
depends-on: [ralph-core]
---

# Ralph PRD Starter

> "Set up Ralph Orchestra for YOUR project - custom agents, skills, and configs in minutes."

## Quick Start

Invoke this command to start the setup wizard:
```
/ralph-prd-starter
```

The agent will guide you through 8 phases to configure Ralph Orchestra for your project.

## When to Use This Skill

Use `/ralph-prd-starter` when:
- Setting up Ralph Orchestra for a new project
- Adding custom agents to your project
- Reconfiguring existing agents
- Generating initial PRD from feature ideas
- Updating orchestration mode or workflow patterns

## Phase Overview

| Phase | Description | Research Sources |
|-------|-------------|------------------|
| 1. Project Identification | Project type, name, description | Project type best practices |
| 2. Agent Configuration | Add agents (iterative, with sub-phases) | BMAD methodology, role definitions, skills marketplace |
| 3. Workflow Pattern | Waterfall, Collaborative, Autonomous | SDLC patterns, Agile methodologies |
| 4. Orchestration Mode | Event-driven, Sequential, HITL | Ralph Orchestra architecture |
| 5. Technology Stack | Frontend, backend, database, tools | Latest framework best practices |
| 6. Quality Standards | TypeScript, testing, linting, CI/CD | Industry quality benchmarks |
| 7. Initial Features | Parse and categorize features | BMAD workflow patterns |
| 8. Review and Confirm | Summary and generation | (Review only) |

## Agent Configuration Sub-Phases

Phase 2 runs iteratively - one agent at a time:

| Sub-Phase | Description |
|-----------|-------------|
| 2.1 | Select agent type (PM, Developer, QA, etc. or custom) |
| 2.2 | Define agent role (research + user input consolidation) |
| 2.3 | Configure agent skills (research + selection) |
| 2.4 | Set up tools, MCP, and sub-agents |
| 2.5 | Define file permissions |
| 2.6 | Complete agent or add another |

## Implementation

### 1. Initialize State Management

On first invocation, create the state file:

```powershell
# Read or create state file
$statePath = ".claude/session/prd-starter-state.json"
if (-not (Test-Path $statePath)) {
    $state = @{
        version = "1.0.0"
        startedAt = (Get-Date).ToUniversalTime().ToString("o")
        completedAt = $null
        currentPhase = "project_identification"
        currentSubPhase = $null
        phases = @{}
    } | ConvertTo-Json -Depth 20
    $state | Out-File -FilePath $statePath -Encoding utf8
}
```

### 2. Run Phase Questions

Use `AskUserQuestion` for all user inputs:

```
Question: What is the name and brief description of your project?

Options:
- [ ] Web Application (e.g., React, Vue, Svelte)
- [ ] Game Development (e.g., Unity, Unreal, Three.js)
- [ ] Mobile App (e.g., React Native, Flutter)
- [ ] Backend/API (e.g., Node.js, Python, Go)
- [ ] Data/ML Project (e.g., Python, TensorFlow)
- [ ] DevOps/Infrastructure (e.g., Terraform, Kubernetes)
- [ ] Other (describe your project type)
```

Always include "Other" for free-form input.

### 3. Research Between Phases

After each phase, before moving to the next, perform research:

```
"I've selected {{PROJECT_TYPE}}. Let me research best practices for this type of project..."
```

Research sources vary by phase:
- **Phase 1**: Similar projects, architecture patterns
- **Phase 2 (per agent)**: Role definitions, BMAD methodology, skills marketplace
- **Phase 3**: SDLC patterns (Agile, Waterfall, Hybrid)
- **Phase 5**: Latest best practices for selected tech stack

### 4. Update State File

After each phase completion, update the state:

```powershell
# Update phase status
$state.phases.project_identification = @{
    status = "completed"
    completedAt = (Get-Date).ToUniversalTime().ToString("o")
    data = @{
        projectType = "web"
        projectName = "MyProject"
        projectDescription = "..."
        researchFindings = @(...)
    }
}
```

### 5. Delegate to Subagents

Use these subagents for specialized work:

| Subagent | Purpose |
|----------|---------|
| `researcher` | Web research for role/skill definitions |
| `analyzer` | Analyze user inputs, extract requirements |
| `generator` | Generate agent/skill files |
| `validator` | Validate configuration before generation |

Example delegation:
```
"Use the researcher subagent to find best practices for {{ROLE}} agents in {{PROJECT_TYPE}} projects"
```

### 6. Generate Files

After Phase 8 (Review and Confirm), invoke the Python generator:

**Windows:**
```powershell
.\.claude\scripts\prd-starter-generator.ps1 -Action generate -StateFile .claude\session\prd-starter-state.json
```

**Mac/Linux:**
```bash
python3 .claude/scripts/prd-starter-generator.py --action generate --state .claude/session/prd-starter-state.json
```

This generates:
- `agents/{name}/AGENT.md` - Custom agent files
- `.claude/settings.{name}.json` - MCP configurations
- `prd.json` - Initial PRD with features
- Updated watchdog scripts with new agents

### 7. Verify Generation

After generation completes, verify:

1. Check all agent directories exist
2. Verify AGENT.md files have correct frontmatter
3. Confirm MCP settings are valid
4. Validate prd.json format
5. Check scripts were updated

## Anti-Patterns

- **Don't skip questions**: All phases are required for complete setup
- **Don't skip research**: Research provides context for better decisions
- **Don't hardcode values**: Always gather from user or research
- **Don't bypass validation**: Use schemas before generating files
- **Don't forget "Other" option**: Allow free-form for every question

## State Persistence

The state file persists across invocations:
- Location: `.claude/session/prd-starter-state.json`
- Resumable from any phase
- Tracks research findings per phase
- Records user decisions with rationale

## Cross-Platform Support

The generator works on all platforms:
- **Windows**: Use `.prd-starter-generator.ps1`
- **Mac/Linux**: Use `.prd-starter-generator.sh` or call Python directly
- **Python 3.8+** required with jinja2, pyyaml, jsonschema

## Output Files

| File | Generated When |
|------|----------------|
| `agents/{name}/AGENT.md` | Each agent configured |
| `agents/{name}/SKILLS.md` | Each agent configured |
| `.claude/settings.{name}.json` | Each agent configured |
| `prd.json` | Phase 7 complete |
| Watchdog scripts updated | After generation |

## See Also

- [ralph-core.md](ralph-core.md) - Core Ralph Orchestra concepts
- [worker-protocol.md](worker-protocol.md) - Agent lifecycle
- [event-protocol.md](event-protocol.md) - Event-driven messaging
- `.claude/schemas/agent-config.schema.json` - Configuration validation
- `.claude/scripts/prd-starter-generator.py` - Generator implementation
