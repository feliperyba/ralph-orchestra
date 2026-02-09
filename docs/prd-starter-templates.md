# PRD Starter Templates Reference

> Complete reference for template-driven generation in Ralph Orchestra PRD Starter

## Overview

PRD Starter uses a **hybrid approach**: AI reasoning (subagents) generates structured data, deterministic templates transform data into consistent artifacts.

**Benefits:**
- ✅ AI applies domain expertise and creativity
- ✅ Templates ensure consistency across projects
- ✅ State file provides audit trail of all decisions
- ✅ Generation is reproducible from state + templates

## Template Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ Phase 1-8: User Input → prd-starter-state.json                  │
└───────────────────────────┬─────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│ Phase 8b: pm-research-specialist Subagent                       │
│   Input: projectData, featuresData                              │
│   Reasoning: Research similar projects, best practices          │
│   Output: ./.claude/session/research-findings.json                │
│   Template: research-output-template.json                       │
└───────────────────────────┬─────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│ Wizard: Extract questions, collect user answers                 │
│   Updates: researchData in state.json                           │
└───────────────────────────┬─────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│ Phase 8c: gamedesigner-thermite-facilitator Subagent (Games)    │
│   Input: projectData, researchData                              │
│   Reasoning: Multi-persona Boardroom Retreat design session     │
│   Output: ./.claude/session/gdd-findings.json                     │
│           docs/design/decision_log.md (human-readable)          │
│           docs/design/open_questions.md (human-readable)        │
│           docs/design/gdd.md (human-readable)                   │
│   Template: gdd-output-template.json                            │
└───────────────────────────┬─────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│ Wizard: Update gddData in state.json                            │
└───────────────────────────┬─────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│ Phase 8d: pm-prd-creator Subagent                               │
│   Input: ALL context (project, agents, features, research, GDD) │
│   Reasoning: Create PM-quality PRD with proper structure        │
│   Output: prd.json (extended from prd-template.json)            │
│   Present: Summary for user approval                            │
└───────────────────────────┬─────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│ Wizard: Update prdData.approved in state.json                   │
└───────────────────────────┬──────────────────────────────────── ┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│ Phase 10: Python Generator (cli.py → generator.py)              │
│   Input: prd-starter-state.json                                 │
│   Process: Transform state via Jinja2 templates                 │
│   Output: All project artifacts                                 │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                 ┌──────────▼──────────┬──────────────────┐
                 │                     │                  │
         ┌───────▼──────┐    ┌────────▼────────┐  ┌─────▼───────┐
         │ Agent Files  │    │ Scripts Updated │  │ Docs        │
         │ - AGENT.md   │    │ - watchdog-*.ps1│  │ - README.md │
         │ - SKILLS.md  │    │ - message-queue │  │ - CLAUDE.md │
         │ - settings   │    │ - ralph-session │  └─────────────┘
         └──────────────┘    └─────────────────┘
```

## Template Catalog

### Input Templates (Subagent Outputs)

#### research-output-template.json
**Used by:** pm-research-specialist subagent  
**Purpose:** Structure research findings  
**Location:** `./.claude/templates/research-output-template.json`  
**Output file:** `./.claude/session/research-findings.json`

**Key sections:**
```json
{
  "similarProjects": [...],      // 3-5 relevant projects
  "bestPractices": [...],         // 5-10 practices for tech stack
  "commonPitfalls": [...],        // Common mistakes to avoid
  "techStackInsights": {...},     // Strengths/weaknesses
  "questionsAsked": [...],        // Clarifying questions (Q-001, Q-002...)
  "questionsAnswered": [...],     // User answers with timestamps
  "recommendedRefinements": [...],// Feature improvements based on research
  "references": [...]             // URLs and documentation
}
```

**Why structured:** Enables wizard to extract questions, generator to create research-summary.md, PRD creator to reference insights

#### gdd-output-template.json
**Used by:** gamedesigner-thermite-facilitator subagent  
**Purpose:** Structure complete game design session output  
**Location:** `./.claude/templates/gdd-output-template.json`  
**Version:** 2.0.0
**Output files:** 
- `./.claude/session/gdd-findings.json` (complete structured data)
- `docs/design/session_001_[topic].md` (session summary)
- `docs/design/decision_log.md` (all design decisions)
- `docs/design/open_questions.md` (unresolved questions)
- `docs/design/gdd.md` (main GDD summary)
- `docs/design/core_loop.md` (gameplay loop specification)
- `docs/design/economy_model.md` (economy systems)
- `docs/design/map_templates.md` (map design)
- `docs/design/gear_registry.md` (items and equipment)
- `docs/design/visual_language.md` (visual/audio design)
- `docs/design/tech_spec.md` (technical architecture)
- `docs/design/mvd_checklist.md` (prototype readiness)

**Key sections (v2.0 expanded):**
```json
{
  "skill": "thermite-design",
  "gddData": {
    "sessionInfo": {              // Session metadata with 8 Thermite personas
      "sessionNumber": 1,
      "participants": ["Shinji Tanaka - ...", "Viktor Volkov - ..."]
    },
    "designDecisions": [{          // DEC-001, DEC-002... with full context
      "id", "title", "status", "session", "date", "pillars",
      "context", "decision", "rationale", "alternativesConsidered",
      "dissent", "validationNeeded", "dependencies"
    }],
    "openQuestions": [{            // OQ-001, OQ-002... with ownership
      "id", "question", "priority", "raisedInSession", "owner",
      "blockerFor", "tags", "suggestedInvestigation"
    }],
    "designPillars": [{            // Rich pillar objects
      "name", "description", "guardrails", "kpi"
    }],
    "coreMechanics": [{            // Rich mechanic objects
      "name", "description", "pillars", "interactions",
      "riskFactors", "skillExpression"
    }],
    "tensionsExplored": [...],     // Design debates (e.g., complexity vs simplicity)
    "keyInsights": [...],          // Major learnings from session
    "actionItems": [...]           // Tasks with owners and priorities
  },
  "artifactsToCreate": {           // Maps file paths to descriptions
    "docs/design/session_001_topic.md": "...",
    "docs/design/decision_log.md": "...",
    "docs/design/core_loop.md": "...",
    // ... 11+ total artifacts
  }
}
```

**Storage Strategy:**
- **gdd-findings.json**: Complete structured output (all fields, rich objects)
- **State file**: Minimal subset (IDs, titles, basic fields for orchestration)
- **Markdown artifacts**: Human-readable documentation (11+ files)

**Why triple format:**
- JSON (complete): PRD integration and programmatic access
- JSON (minimal): State file stays lean for CLI/orchestration
- Markdown: Human review, collaboration, version control

**Template changes in v2.0:**
- Fixed JSON validity (was invalid in v1.0)
- Changed `skill` from "gamedesigner-thermite-integration" to "thermite-design"
- Added `dependencies` field to decisions (blocks/blockedBy)
- Added `skillExpression` field to core mechanics
- Expanded `artifactsToCreate` to 11+ Thermite artifacts
- Added `tensionsExplored` and `actionItems` sections
- Enriched `sessionInfo` with all 8 Thermite personas

#### prd-template.json
**Used by:** pm-prd-creator subagent (extended), generator (fallback)  
**Purpose:** Structure PRD with orchestration items  
**Location:** `./.claude/templates/prd-template.json`  
**Output file:** `prd.json`

**Base structure:**
```json
{
  "project": "name",
  "version": "1.0.0",
  "quality": "production",
  "session": {...},               // Orchestration session state
  "agents": {...},                // Agent status tracking
  "items": [                      // Task items for orchestration
    {
      "id": "feat-001",
      "category": "architectural|feature|bugfix",
      "priority": "high|medium|low",
      "title": "...",
      "description": "...",
      "acceptanceCriteria": [...],
      "verificationSteps": [...],
      "agent": "developer|qa|gamedesigner",
      "status": "pending|in-progress|completed"
    }
  ]
}
```

**PM-extended structure** (pm-prd-creator adds):
```json
{
  // ... base structure ...
  "metadata": {...},              // Version, stakeholders
  "goals": {...},                 // Primary goal, objectives
  "features": [...],              // User stories with acceptance criteria
  "technical": {...},             // Architecture, tech stack, quality standards
  "nonFunctional": {...},         // Performance, security, scalability
  "gameDesign": {...},            // GDD integration (games only)
  "team": {...},                  // Agent roles and responsibilities
  "outOfScope": [...]             // Explicit exclusions
}
```

**Why extensible:** Base template for minimal PRDs, PM subagent extends with full PM expertise

### Output Templates (Generator Produces)

#### agent-template.md
**Used by:** agent_generator.py  
**Purpose:** Generate agent behavior definitions  
**Location:** `./.claude/templates/agent-template.md`  
**Output files:** `agents/{name}/AGENT.md`

**Template variables:**
```jinja2
{{ agent.display_name }}         # Agent display name
{{ agent.description }}           # Role description
{{ agent.role }}                  # Role type (developer, pm, qa, etc.)
{{ agent.primary_responsibility }}# Main responsibility
{{ project.name }}                # Project name
{{ now }}                         # Generation timestamp
```

**Generated sections:**
- Core Responsibilities (role-specific)
- Startup Sequence (load PRD, check skills)
- Decision Framework (state machine)
- Task Type to Skill Mapping
- Feedback Loops (tech-stack specific)
- Message Protocols

**Customization:** Template has conditionals for different agent roles

#### settings-template.json
**Used by:** agent_generator.py  
**Purpose:** Generate MCP server configurations  
**Location:** `./.claude/templates/settings-template.json`  
**Output files:** `./.claude/settings.{agent}.json`

**Template variables:**
```jinja2
{{ mcp_servers }}                 # List of MCP server names
```

**Generated structure:**
```json
{
  "mcpServers": {
    "gitkraken": {
      "command": "npx",
      "args": ["-y", "@gitkraken/mcp-server"]
    },
    "fetch": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-fetch"]
    }
    // ... other servers
  }
}
```

#### README-project-template.md
**Used by:** readme_generator.py  
**Purpose:** Generate project README  
**Location:** `./.claude/templates/README-project-template.md`  
**Output file:** `README.md`

**Template variables:**
```jinja2
{{ project_config.name }}         # Project name
{{ project_config.description }}  # Project description
{{ tech_stack }}                  # Tech stack details
{{ agents_config }}               # Agent configurations
```

**Generated sections:**
- Project Overview
- Tech Stack
- Getting Started (init commands)
- Agent Descriptions
- Orchestration Commands
- Project Structure

#### CLAUDE-project-template.md
**Used by:** readme_generator.py  
**Purpose:** Generate CLAUDE.md instructions  
**Location:** `./.claude/templates/CLAUDE-project-template.md`  
**Output file:** `CLAUDE.md`

**Template variables:**
```jinja2
{{ project_config.name }}         # Project name
{{ tech_stack }}                  # Tech stack
{{ quality_standards }}           # Quality gates
```

**Generated sections:**
- Project-specific coding standards
- Tech stack conventions
- Testing requirements
- Workflow rules
- Agent coordination guidelines

## Generator Pipeline

### Phase 10 Execution

**Entry point:** `cli.py --action generate --state {state_file}`

**Pipeline:**
```python
1. cli.py:
   - Load prd-starter-state.json
   - Convert state to ProjectConfig (loader.py)
   - Attach research/GDD/PRD data to project_config
   - Call generator.generate_all()

2. generator.py:
   - For each agent in projectConfig.agents:
       - agent_generator.generate_agent() → uses agent-template.md
       - agent_generator.generate_agent_settings() → uses settings-template.json
   - script_manager.update_watchdog_scripts() → updates ValidateSet
   - script_manager.update_message_queue() → updates routing
   - script_manager.update_session_scripts() → updates agent lists
   - docs_generator.generate_init_script() → creates init scripts
   - readme_generator.generate_readme() → uses README-project-template.md
   - readme_generator.generate_claude_md() → uses CLAUDE-project-template.md
   - docs_generator.generate_research_summary() → transforms research JSON to markdown
   - docs_generator.generate_gdd_summary() → already done by subagent
   - docs_generator.generate_prd() → prd.json already written by subagent

3. Output verification:
   - Count generated files
   - Report success/errors
   - Display next steps
```

## Template Variables Reference

### Common Variables

| Variable | Type | Source | Description |
|----------|------|--------|-------------|
| `project_config` | ProjectConfig | State loader | Complete project configuration |
| `agent` | AgentConfig | ProjectConfig.agents | Single agent configuration |
| `tech_stack` | dict | State | Runtime, package manager, commands |
| `now` | datetime | System | Generation timestamp |
| `mcp_servers` | list[str] | AgentConfig | MCP servers for agent |
| `agents_config` | dict | Generator | All agents with roles |
| `quality_standards` | list[str] | ProjectConfig | Quality gates |

### State-to-Template Mapping

| State Field | Template Variable | Used In |
|-------------|-------------------|---------|
| `projectData.name` | `project_config.name` | All templates |
| `projectData.description` | `project_config.description` | README, CLAUDE |
| `projectData.techStack` | `tech_stack` | README, init scripts |
| `agentsData.agents[]` | `agents_config` | agent-template.md, settings |
| `researchData` | `research_data` | research-summary.md |
| `gddData` | `gdd_data` | decision_log.md, gdd.md |
| `qualityData.standards` | `quality_standards` | CLAUDE.md, agent-template.md |

## Customization

### Modifying Templates

**Location:** `./.claude/templates/`

**Process:**
1. Edit template file (Jinja2 syntax)
2. Test with generator: `python cli.py --action generate --state test-state.json`
3. Review generated output
4. Iterate until satisfied
5. Commit template changes

**Example custom section in agent-template.md:**
```jinja2
{% if project.category == 'game' %}
## Game-Specific Responsibilities
- Review GDD at `docs/design/gdd.md` before implementing mechanics
- Follow design decisions (DEC-NNN) from decision log
- Flag design conflicts with PM and Game Designer
{% endif %}
```

### Adding New Templates

**Use case:** Generate additional project artifacts

**Steps:**
1. Create template file in `./.claude/templates/`
2. Add generation method to appropriate generator class:
   - `agent_generator.py` - Agent-related
   - `docs_generator.py` - Documentation
   - `readme_generator.py` - Project docs
   - `script_manager.py` - Scripts
3. Call method from `generator.generate_all()`
4. Update constants.py if file should be copied to new projects

**Example:**
```python
# In docs_generator.py
def generate_contributing_guide(self, project_config: ProjectConfig) -> bool:
    """Generate CONTRIBUTING.md from template."""
    try:
        template = self.renderer.env.get_template("contributing-template.md")
        content = template.render(project=project_config, now=datetime.now())
        
        contrib_file = self.project_root / "CONTRIBUTING.md"
        contrib_file.write_text(content, encoding='utf-8')
        return True
    except Exception as e:
        print(f"Error generating contributing guide: {e}")
        return False
```

## Debugging

### Template Rendering Issues

**Symptom:** Variable not found or rendering error

**Debug steps:**
1. Check template syntax: Jinja2 requires `{{ var }}` for output, `{% for %}` for logic
2. Verify variable exists: `print(project_config.__dict__)` before rendering
3. Check template path: Generator looks in `./.claude/templates/` relative to project root
4. Test template alone:
   ```python
   from jinja2 import Template
   template = Template("{{ project_config.name }}")
   print(template.render(project_config=config))
   ```

### State-to-Template Mismatch

**Symptom:** Generated file missing expected data

**Debug steps:**
1. Verify state file structure: `cat ./.claude/session/prd-starter-state.json | jq`
2. Check loader conversion: `python -c "from loader import state_to_project_config; ..."`
3. Print variables before template: Add debug logs to generator methods
4. Compare with template expectations: Review template variables used

### Subagent Output Issues

**Symptom:** Subagent doesn't produce expected JSON

**Debug steps:**
1. Check output file exists: `./.claude/session/research-findings.json`
2. Validate JSON structure: `python -m json.tool research-findings.json`
3. Compare with template: `diff research-findings.json ./.claude/templates/research-output-template.json`
4. Review subagent prompt: Ensure it references correct template

## Best Practices

### Template Design

✅ **DO:**
- Use semantic variable names (`project.name`, not `p.n`)
- Add comments explaining complex logic
- Provide fallbacks for optional variables: `{{ var | default('fallback') }}`
- Keep templates focused on structure, not business logic
- Version templates alongside generator code

❌ **DON'T:**
- Hardcode project-specific values in templates
- Mix presentation and data transformation (do transformation in generator)
- Use deeply nested conditionals (extract to helper functions)
- Assume variables always exist (use safe navigation: `project?.name`)

### Subagent Output Design

✅ **DO:**
- Follow template structure exactly
- Use consistent IDs (Q-001, DEC-001, OQ-001)
- Include timestamps for auditability
- Validate JSON before writing file
- Write both JSON (for programs) and Markdown (for humans) when appropriate

❌ **DON'T:**
- Invent new JSON structures not in template
- Skip required fields (even if empty arrays)
- Use inconsistent naming (camelCase vs snake_case)
- Embed unstructured text in structured fields

### Generator Integration

✅ **DO:**
- Load templates once, reuse TemplateRenderer
- Handle missing template gracefully (fallback to code generation)
- Log which template produced each file
- Validate generated output (syntax check, required fields)
- Report errors with context (which template, which variable)

❌ **DON'T:**
- Silently fail on template errors
- Mix template generation with manual string concatenation
- Assume template always exists
- Skip validation of generated files

## Related Documentation

- [PRD Starter Wizard](prd-starter.md) - Complete wizard phases
- [PRD Starter Workflows](prd-starter-workflows.md) - Using generated artifacts
- [Architecture](architecture.md) - Overall system architecture

---

*Last updated: 2026-02-08*
