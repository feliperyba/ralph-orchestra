# PRD Starter Wizard - Phase Details

Complete phase-by-phase instructions for the Ralph PRD Starter wizard.

**Related Documentation:**
- [SKILL.md](SKILL.md) - Main skill definition
- [STATE-SCHEMA.md](STATE-SCHEMA.md) - State structure reference
- [docs/prd-starter-templates.md](../../docs/prd-starter-templates.md) - Template system

---

## Phase 1: Entry Point

**Purpose:** Determine wizard complexity level

**Prompt:**
```
Welcome to Ralph Orchestra PRD Starter! 🚀

This wizard will help you set up a complete Ralph Orchestra project.

Choose your setup mode:

1. **Quick Start** - Natural language project descriptions analyzer. Detects the needed configuration, minimal questions (~5 min)
2. **Standard** - Guided setup with best practice defaults (~15 min)
3. **Expert** - Full control over all configuration (~30 min)

Select mode (1-3):
```

**Input Validation:**
- Must be 1, 2, or 3

**State Updates:**
```json
{
  "wizardMode": "quick-start" | "standard" | "expert",
  "currentPhase": "presets" (if quick-start) | "project" (otherwise),
  "startedAt": "2026-02-08T10:30:00.000Z",
  "lastModified": "2026-02-08T10:30:00.000Z",
  "phaseHistory": ["entry"]
}
```

**Next Phase:**
- Quick Start → Phase 2 (Project Definition)
- Standard/Expert → Phase 3 (Project)

---

## Phase 2: Project Definition

**2.1 Project Name**
```
What is your project name?
Example: thermite-game, my-dashboard, data-pipeline-v2
```

**2.2 Project Description**
```
One-line description of your project:
Example: "Bomberman-inspired extraction game with Tarkov mechanics"
```

**2.3 PRD Starter Project Analyzer**
1. Run subagent `prd-starter-project-analyzer` with the current context collected. Define all the needed information from the step 2.3 until the step 7.3 based on the output. Based on the confidence level, can ask the user questions to fill the gaps.
2. Present to the user the suggested package and tools. Use AskUserQuestion tool for confirmation or suggest a guided path
  **IF CONFIRMED:** Skip to step 8
  **IF GUIDED PATH:** Continue to step 3
---

## Phase 3: Project Identity

**Purpose:** Define project fundamentals

**Prompts:**

**3.1 Category**
```
Project category:

1. Game Development
2. Web Application
3. API Server
4. Data/ML Pipeline
5. Mobile App
6. Other

Select category (1-6):
```

**3.2 Tech Stack**
```
Primary tech stack:
Example: "React Three Fiber + Phaser", "Next.js + PostgreSQL", "Python + FastAPI"
```

**3.3 Success Factors** (multi-select)
```
What matters most for this project? (Select all that apply)

1. Speed to market
2. Code quality
3. Visual excellence
4. Multiplayer reliability
5. Mobile performance
6. Accessibility
7. SEO optimization
8. Real-time features
9. Data processing

Enter numbers separated by commas (e.g., 1,3,4):
```

**Input Validation:**
- `name`: Non-empty, lowercase-with-hyphens pattern
- `description`: Non-empty, max 200 chars
- `category`: Must match enum value
- `techStack`: Non-empty string
- `teamSize`: Must match enum value
- `projectScale`: Must match enum value
- `successFactors`: Array of valid factor strings

**State Updates:**
```json
{
  "project": {
    "name": "thermite-game",
    "description": "Bomberman-inspired extraction game",
    "category": "game-development",
    "techStack": "React Three Fiber + Phaser",
    "teamSize": "solo",
    "projectScale": "prototype-mvp",
    "successFactors": ["speed-to-market", "visual-excellence", "multiplayer-reliability"]
  },
  "currentPhase": "agents",
  "phaseHistory": ["entry", "project"]
}
```

**Next Phase:** Phase 4 (Agents)

---

## Phase 4: Agent Configuration

**Purpose:** Define which agents to enable and their roles

**Prompts:**

**4.1 Core Agents** (if not preset)
```
Configure your Ralph Orchestra agents:

Available agents:
[ ] pm           - Product Manager (coordinates workflow)
[ ] developer    - Developer (implements features)
[ ] techartist   - Tech Artist (visual content, shaders, assets)
[ ] qa           - QA Engineer (testing, validation)
[ ] gamedesigner - Game Designer (GDD, mechanics, playtesting)

Which agents do you need? (Enter letters: e.g., p,d,q for PM, Dev, QA)
```

**4.2 Agent Customization** (Expert mode only)
```
For each enabled agent, configure:

Agent: pm
- Skills to include: [pm-organization-*, pm-planning-*] (comma-separated)
- Sub-agents: [list available, allow selection]
- MCP Servers: [github, filesystem, web-search] (comma-separated)

[Repeat for each agent]
```

**Standard Mode Defaults:**
- PM: All pm-* skills, no subagents, basic MCP servers
- Developer: All dev-* skills, standard subagents, code MCP servers
- QA: All qa-* skills, testing subagents, testing MCP servers
- TechArtist: All ta-* skills, asset subagents, visual MCP servers
- GameDesigner: All gd-* skills, including thermite, design MCP servers

**Input Validation:**
- At least one agent must be enabled
- Skills must match available skill patterns
- MCP servers must match available servers

**State Updates:**
```json
{
  "agents": {
    "pm": {
      "enabled": true,
      "skills": ["pm-organization-*", "pm-planning-*", "pm-router"],
      "subAgents": [],
      "mcpServers": ["github", "filesystem", "web-search"]
    },
    "developer": {
      "enabled": true,
      "skills": ["dev-r3f-*", "dev-typescript-*", "developer-workflow"],
      "subAgents": ["developer-implementation", "qa-code-review"],
      "mcpServers": ["github", "filesystem"]
    }
    // ... other agents
  },
  "currentPhase": "orchestration",
  "phaseHistory": ["entry", "project", "agents"]
}
```

**Next Phase:** Phase 5 (Orchestration)

---

## Phase 5: Orchestration Mode

**Purpose:** Choose how agents coordinate

**Prompt:**
```
Agent orchestration mode:

1. **Event-Driven** (Recommended) - Agents respond to events autonomously
   - Best for: Active development with multiple agents
   - Requires: Watchdog running in background

2. **Sequential** - Agents work in defined order (PM → Dev → QA)
   - Best for: Predictable workflows, single-threaded tasks
   - Simpler setup, no watchdog needed

3. **HITL (Human-In-The-Loop)** - You approve each agent action
   - Best for: Learning the system, critical changes
   - Full control, slower iteration

Select mode (1-3):
```

**Additional Configuration:**

**For Event-Driven:**
```
Max iterations per agent: [200]
Context reset threshold (%): [70]
Heartbeat interval (seconds): [30]
```

**Input Validation:**
- Mode must be one of: "event-driven", "sequential", "hitl"
- Iterations: 1-1000
- Threshold: 50-90
- Heartbeat: 10-300

**State Updates:**
```json
{
  "orchestration": {
    "mode": "event-driven",
    "maxIterations": 200,
    "contextResetThreshold": 70,
    "heartbeatInterval": 30
  },
  "currentPhase": "mcp_config" (expert) | "quality" (standard/quick),
  "phaseHistory": ["entry", "project", "agents", "orchestration"]
}
```

**Next Phase:**
- Expert → Phase 6 (MCP Config)
- Standard/Quick → Phase 7 (Quality)

---

## Phase 6: MCP Configuration

**Conditional:** Only for `wizardMode === "expert"`

**Purpose:** Fine-tune MCP server configuration

**Prompt:**
```
MCP Server Configuration

Available servers:
- github: GitHub API integration
- filesystem: File system operations
- web-search: Web search capabilities
- brave-search: Brave search API
- playwright: Browser automation
- vision: Image analysis
- blender: 3D asset operations
- shadertoy: Shader development

For each agent, which MCP servers should be enabled?

Agent: pm
Current: [github, filesystem, web-search]
Add/Remove servers (or press Enter to keep): 
```

**Input Validation:**
- Server names must match available MCP servers
- At least one MCP server per agent recommended

**State Updates:**
```json
{
  "agents": {
    "pm": {
      "mcpServers": ["github", "filesystem", "web-search", "brave-search"]
    }
    // Updated per agent
  },
  "currentPhase": "quality",
  "phaseHistory": ["entry", "project", "agents", "orchestration", "mcp_config"]
}
```

**Next Phase:** Phase 7 (Quality)

---

## Phase 7: Quality Standards

**Purpose:** Define code quality requirements

**Prompts:**

**7.1 TypeScript Strictness** (if applicable)
```
TypeScript strictness level:

1. Strict - Full type safety, no `any`, strictNullChecks
2. Standard - Recommended settings, some flexibility
3. Loose - Minimal checks, fast prototyping

Select level (1-3):
```

**7.2 Test Coverage**
```
Test coverage target (%): [85]
(Recommended: 70-95%)
```

**7.3 Code Quality Rules**
```
Enforce quality rules:
- [ ] No `any` types (TypeScript)
- [ ] No `@ts-ignore` comments
- [ ] Lint rules: [eslint-recommended | custom | none]
- [ ] Commit convention: [[ralph] | conventional | custom]
- [ ] CI/CD Integration: [github-actions | gitlab-ci | none]

Select rules to enforce (comma-separated numbers):
```

**Input Validation:**
- Coverage: 0-100
- Rules: boolean values
- Commit convention: Must match enum
- CI/CD: Must match enum

**State Updates:**
```json
{
  "qualityStandards": {
    "typescriptStrictness": "strict",
    "testCoverageTarget": 85,
    "noAnyTypes": true,
    "noTsIgnore": true,
    "lintRules": "eslint-recommended",
    "commitConvention": "[ralph]",
    "ciCdIntegration": "github-actions",
    "additionalGates": ["require-tests", "require-docs"]
  },
  "currentPhase": "features",
  "phaseHistory": ["entry", "project", "agents", "orchestration", "quality"]
}
```

**Next Phase:** Phase 8 (Features)

---

## Phase 8: Initial Features

**Purpose:** Collect high-level feature descriptions

**Prompt:**
```
Describe the key features of your project (one per line).
Use natural language - the PM will refine these later.

Examples:
- "Players can move around a 2D grid and place bombs"
- "Real-time multiplayer with latency compensation"
- "Visual effects for explosions with particle systems"

Enter features (type 'done' when finished):
```

**Input Process:**
1. User enters feature descriptions (one per prompt)
2. Auto-assign IDs: feat-001, feat-002, etc.
3. Continue until user types "done"
4. Minimum: 1 feature required

**Input Validation:**
- At least one feature required
- Each feature: 10-500 characters

**State Updates:**
```json
{
  "features": [
    {
      "id": "feat-001",
      "description": "Players can move around a 2D grid and place bombs",
      "category": "gameplay",
      "priority": "high"
    },
    {
      "id": "feat-002",
      "description": "Real-time multiplayer with latency compensation",
      "category": "technical",
      "priority": "high"
    }
  ],
  "currentPhase": "deep_research",
  "phaseHistory": ["entry", "project", "agents", "orchestration", "quality", "features"]
}
```

**Next Phase:** Phase 8b (Deep Research)

---

## Phase 8b: Deep Research

**Purpose:** Research best practices using PM subagent

**Display:**
```
Running research phase...

Analyzing: {category} projects using {techStack}
Researching: Best practices, common pitfalls, recommended libraries

This may take 2-3 minutes...
```

**Subagent Invocation:**
```
Use pm-research-specialist subagent:
- Pass: project metadata, tech stack, features
- Subagent outputs: ./.claude/session/research-findings.json
```

**Subagent Output Structure:** (See `research-output-template.json`)
```json
{
  "similarProjects": [...],
  "bestPractices": [...],
  "commonPitfalls": [...],
  "techStackInsights": {...},
  "questionsAsked": [
    {
      "id": "Q-001",
      "question": "Will you need server-authoritative physics?",
      "context": "For multiplayer games...",
      "impact": "Affects architecture...",
      "category": "technical"
    }
  ],
  "recommendedRefinements": [...],
  "references": [...]
}
```

**After Subagent Completes:**
1. Read `./.claude/session/research-findings.json`
2. Extract `questionsAsked` array
3. If questions exist, proceed to Phase 8b-user
4. If no questions, skip to Phase 8c/8d

**State Updates:**
```json
{
  "researchData": {
    "similarProjects": [...],
    "bestPractices": [...],
    // ... full research findings
    "questionsAsked": [...]
  },
  "currentPhase": "user_questions",
  "phaseHistory": [..., "deep_research"]
}
```

**Next Phase:** Phase 8b-user (User Questions) or Phase 8c/8d

---

## Phase 8b-user: User Questions

**Conditional:** Only if research phase generated questions

**Purpose:** Collect user answers to PM's clarifying questions

**Display:**
```
The PM has {count} questions to help refine the project:
```

**For each question:**
```
Question {n} of {total}: [{category}]

{question}

Context: {context}
Impact: {impact}

Your answer:
```

**Input Process:**
1. Display questions one at a time
2. Collect free-text answers
3. Allow "skip" for optional questions
4. Store answers with timestamps

**State Updates:**
```json
{
  "researchData": {
    "questionsAnswered": [
      {
        "questionId": "Q-001",
        "question": "Will you need server-authoritative physics?",
        "answer": "Yes, we need server authority for competitive integrity",
        "answeredAt": "2026-02-08T10:45:00.000Z"
      }
    ]
  },
  "currentPhase": "gdd_creation" (if game) | "prd_creation",
  "phaseHistory": [..., "user_questions"]
}
```

**Next Phase:**
- If game project → Phase 8c (GDD)
- Otherwise → Phase 8d (PRD)

---

## Phase 8c: GDD Creation

**Conditional:** Only if `project.category === "game-development"`

**Purpose:** Run Thermite design session for game design

**Display:**
```
Starting Thermite Design Session...

This creative session will explore game design through simulated team discussion.
The gamedesigner-thermite-facilitator will:
- Run boardroom retreat with 8 expert personas
- Define design pillars and document core mechanics
- Record design decisions (DEC-NNN) and open questions (OQ-NNN)
- Create complete design artifact set following thermite-design standards

Personas: Shinji Tanaka, Viktor Volkov, Elena Vasquez, Marcus Chen, 
          Sarah Okonkwo, Dr. Maya Reyes, Wei Zhang, Jordan Ellis

This may take 5-10 minutes...
```

**Subagent Invocation:**
```
Use gamedesigner-thermite-facilitator subagent:
- Pass: project metadata, features, research findings
- Subagent creates 11+ artifacts in docs/design/:
  1. session_001_[topic].md - Session summary
  2. decision_log.md - All design decisions
  3. open_questions.md - Unresolved questions
  4. gdd.md - Main GDD summary
  5. core_loop.md - Gameplay loop specification
  6. economy_model.md - Economy systems and balance
  7. map_templates.md - Map design and flow
  8. gear_registry.md - Items with counterplay
  9. visual_language.md - Visual/audio design
  10. tech_spec.md - Technical architecture
  11. mvd_checklist.md - Prototype readiness
- Subagent writes: ./.claude/session/gdd-findings.json (complete structured output)
```

**Subagent Output Structure:** (See `gdd-output-template.json` v2.0)
```json
{
  "version": "2.0.0",
  "skill": "thermite-design",
  "gddData": {
    "sessionInfo": {
      "sessionNumber": 1,
      "participants": ["Shinji Tanaka - ...", "Viktor Volkov - ..."]
    },
    "designDecisions": [{id, title, status, session, pillars, context, decision, 
                         rationale, alternativesConsidered, dissent, validationNeeded, dependencies}],
    "openQuestions": [{id, question, priority, raisedInSession, owner, blockerFor, tags, suggestedInvestigation}],
    "designPillars": [{name, description, guardrails, kpi}],
    "coreMechanics": [{name, description, pillars, interactions, riskFactors, skillExpression}],
    "tensionsExplored": [...],
    "actionItems": [...]
  },
  "artifactsToCreate": {...}
}
```

**After Subagent Completes:**
```
Design session complete!

✓ Session: session_001_[topic].md
✓ Decisions made: {count} (see decision_log.md)
✓ Open questions: {count} (see open_questions.md)
✓ Design pillars: {comma-separated list}
✓ Core mechanics documented: {count}

Artifacts created in docs/design/:
  - session_001_[topic].md    (session summary)
  - decision_log.md            (all decisions with full context)
  - open_questions.md          (unresolved questions)
  - gdd.md                     (main GDD summary)
  - core_loop.md               (gameplay loop spec)
  - economy_model.md           (economy systems)
  - map_templates.md           (map design)
  - gear_registry.md           (items and counterplay)
  - visual_language.md         (visual/audio design)
  - tech_spec.md               (technical architecture)
  - mvd_checklist.md           (prototype readiness)

Full structured data: ./.claude/session/gdd-findings.json

Ready to proceed to PRD creation.
```

**State Update Strategy:**

**Minimal State (for orchestration):**
```json
{
  "gddData": {
    "designDecisions": [
      {
        "id": "DEC-001",
        "title": "Title only",
        "status": "Decided",
        "pillars": ["Pillar names"],
        "decision": "What was decided",
        "validationNeeded": ["What to test"]
      }
    ],
    "openQuestions": [
      {
        "id": "OQ-001",
        "question": "Question text",
        "priority": "high",
        "owner": "Persona name",
        "tags": ["tags"]
      }
    ],
    "designPillars": ["Pillar 1", "Pillar 2"],
    "coreMechanics": [{"name": "Mechanic", "description": "Brief desc"}],
    "thermiteSessionType": "boardroom-retreat",
    "participants": ["Persona 1", "Persona 2"]
  }
}
```

**Rich Data Location:**
- **gdd-findings.json** - Complete structured output with all fields (context, rationale, dissent, dependencies, alternatives, tensions, action items, etc.)
- **docs/design/*.md** - Human-readable design documentation

**Why this approach:**
- State file stays lean for orchestration and CLI display
- Rich design context preserved in gdd-findings.json for PRD integration
- Markdown artifacts provide human-readable collaboration documents
- pm-prd-creator subagent reads gdd-findings.json directly for complete context

**State Updates:**
```json
{
  "gddData": {minimal subset as above},
  "currentPhase": "prd_creation",
  "phaseHistory": [..., "gdd_creation"]
}
```

**Next Phase:** Phase 8d (PRD Creation)

---

## Phase 8d: PRD Creation

**Purpose:** Generate comprehensive PRD using PM subagent

**Display:**
```
Creating Product Requirements Document...

The PM will synthesize:
- Project requirements
- Research findings
- User answers
- GDD decisions (if game)

Into a comprehensive PRD with:
- Feature specifications
- Acceptance criteria
- Technical recommendations
- Agent assignments

This may take 3-5 minutes...
```

**Subagent Invocation:**
```
Use pm-prd-creator subagent:
- Pass: project, agents, features, research, GDD (if game)
- Subagent outputs: prd.json
- Subagent presents summary for approval
- Iterate until user approves
```

**Subagent Output Structure:** (See `prd-template.json`)
```json
{
  "metadata": {...},
  "goals": {...},
  "features": [...],
  "technical": {...},
  "nonFunctional": {...},
  "gameDesign": {...},  // If game project
  "team": {...},
  "outOfScope": [...],
  "items": [...]
}
```

**Approval Loop:**
```
PRD Summary:
- Features defined: {count}
- Technical items: {count}
- Agent assignments: {list}

Review PRD? (yes/no/edit):
- yes: Approve and continue
- no: Request changes (iterate)
- edit: Manually edit prd.json
```

**After Approval:**
```
PRD approved and saved to prd.json

Ready for final review and generation.
```

**State Updates:**
```json
{
  "prdSpecification": {
    "refinedFeatures": [...],
    "acceptanceCriteria": [...],
    "dependencies": [...],
    "priorities": {...},
    "technicalRecommendations": [...],
    "agentAssignments": {...},
    "approved": true,
    "approvedAt": "2026-02-08T11:00:00.000Z",
    "prdPath": "prd.json"
  },
  "currentPhase": "final_review",
  "phaseHistory": [..., "prd_creation"]
}
```

**Next Phase:** Phase 9 (Final Review)

---

## Phase 9: Final Review

**Purpose:** Review complete configuration before generation

**Display:**
```
=== PRD Starter Final Review ===

Project: {name}
Description: {description}
Category: {category}
Tech Stack: {techStack}

Enabled Agents: {list}
Orchestration: {mode}
Features: {count}

Research completed: ✓
Questions answered: {count}
GDD created: {✓ if game}
PRD approved: ✓

Files to be generated:
- {count} agent configurations
- {count} settings files
- {count} scripts
- Documentation (README, research summary, etc.)

Proceed with generation? (yes/no/edit):
```

**Options:**
1. **yes** - Proceed to generation (Phase 10)
2. **no** - Cancel, save state for later
3. **edit** - Go back to specific phase

**If edit selected:**
```
Which phase to edit?
1. Project details
2. Agent configuration
3. Orchestration mode
4. Quality standards
5. Features
6. Research (re-run)
7. PRD (re-run)

Select phase (1-7):
```

**State Updates:**
```json
{
  "currentPhase": "completed",
  "phaseHistory": [..., "final_review"]
}
```

**Next Phase:** Phase 10 (Generation)

---

## Phase 10: Project Generation

**Purpose:** Execute Python generator to create all files

**Display:**
```
Generating project files...

Step 1/7: Creating agent directories...
Step 2/7: Generating agent configurations...
Step 3/7: Creating settings files...
Step 4/7: Updating orchestration scripts...
Step 5/7: Generating documentation...
Step 6/7: Copying support files...
Step 7/7: Creating README and init scripts...

Generation complete! ✓
```

**Generator Invocation:**
```bash
cd ./.claude/scripts/prd-starter
python cli.py generate --state ../../.././.claude/session/prd-starter-state.json
```

**Generator Process:**
1. Load state file
2. Validate configuration
3. Create agent directories
4. Generate agent files from templates
5. Generate settings files
6. Update watchdog/message-queue scripts
7. Generate documentation
8. Copy support files
9. Create README and init scripts

**Error Handling:**
```
If generation fails:

Generation error: {error_message}

Troubleshooting options:
1. View full error log
2. Retry generation
3. Manual generation instructions
4. Save state and exit

Select option (1-4):
```

**Manual Generation Instructions:**
```
To generate manually:

1. Navigate to generator directory:
   cd ./.claude/scripts/prd-starter

2. Run generator:
   python cli.py generate

3. Check output for errors

4. Verify files created in:
   - ./.claude/agents/
   - ./.claude/settings.*.json
   - docs/
```

**State Updates:**
```json
{
  "generationResults": {
    "filesCreated": [
      "./.claude/agents/pm/AGENT.md",
      "./.claude/agents/developer/AGENT.md",
      "./.claude/settings.pm.json",
      // ... all generated files
    ],
    "filesModified": [
      "./.claude/scripts/watchdog/run.ps1",
      // ... modified files
    ],
    "errors": [],
    "warnings": ["Optional: some non-critical warnings"]
  },
  "completedAt": "2026-02-08T11:10:00.000Z",
  "currentPhase": "completed"
}
```

**Next Phase:** Phase 11 (Completion)

---

## Phase 11: Completion

**Purpose:** Provide next steps and confirm setup

**Display:**
```
=== Ralph Orchestra Project Setup Complete! ===

✓ {count} agents configured
✓ {count} settings files created
✓ Documentation generated
✓ Orchestration scripts updated

Your project is ready!

Next steps:

1. Review generated files:
   - ./.claude/agents/          (Agent definitions)
   - ./.claude/settings.*.json  (MCP configurations)
   - docs/                    (Documentation)
   - prd.json                 (Product requirements)

2. Start the orchestration system:
   
   # Event-Driven mode:
   ./scripts/ralph-start-watch.ps1
   
   # Sequential mode:
   ./scripts/ralph-session-sequential.ps1
   
   # HITL mode:
   ./scripts/ralph-session-hitl.ps1

3. Invoke agents:
   
   /pm    - Call Product Manager
   /dev   - Call Developer
   /qa    - Call QA Engineer

4. Monitor progress:
   - Check ./.claude/session/prd-events.json for events
   - View ./.claude/logs/ for agent logs

5. Read the documentation:
   - README.md - Project overview
   - CLAUDE.md - Claude integration guide
   - docs/research-summary.md - Research findings

Need help? Check docs/ or run:
./scripts/ralph-help.ps1

Happy building! 🚀
```

**State Updates:**
```json
{
  "currentPhase": "completed",
  "completedAt": "2026-02-08T11:10:00.000Z"
}
```

**Cleanup:**
- State file persists for reference
- Archive option available
- Wizard can be re-run to regenerate

---

## Phase Transitions

**General Flow:**
```
entry → presets? → project → agents → orchestration → mcp_config? → quality 
  → features → deep_research → user_questions? → gdd_creation? → prd_creation 
  → final_review → completed
```

**Conditional Phases:**
- `presets`: Only if Quick Start mode
- `mcp_config`: Only if Expert mode
- `user_questions`: Only if research generated questions
- `gdd_creation`: Only if game project

**Skip Logic:**
- Quick Start: Skip mcp_config
- Standard: Skip mcp_config
- Expert: Include all phases
- Non-game: Skip gdd_creation

---

## State Persistence

**After Each Phase:**
```bash
# Atomic write pattern
cat > ./.claude/session/prd-starter-state.json.tmp << 'EOF'
{
  updated state JSON
}
EOF
mv ./.claude/session/prd-starter-state.json.tmp ./.claude/session/prd-starter-state.json
```

**Resume Logic:**
```bash
# Check for existing state
if [ -f ./.claude/session/prd-starter-state.json ]; then
  current_phase=$(jq -r '.currentPhase' ./.claude/session/prd-starter-state.json)
  echo "Found session at phase: $current_phase"
  # Offer resume
fi
```

---

## Validation Checkpoints

**Before Phase Transitions:**
1. Validate current phase data
2. Ensure required fields present
3. Check data types and ranges
4. Verify dependencies met

**Before Generation:**
1. Validate complete state structure
2. Check all required phases completed
3. Verify subagent outputs exist
4. Validate file paths and references

**After Generation:**
1. Verify files created
2. Check file contents valid
3. Validate against schemas
4. Confirm no errors logged
