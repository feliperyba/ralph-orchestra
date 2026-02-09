---
name: prd-starter-configurator
description: Detailed configuration interview protocol for PRD Starter Phases 3-7. Handles Project Identity, Agent Config, Orchestration, MCP, and Quality Standards.
---

# PRD Starter Configurator Skill

Detailed instructions for conducting the configuration interview (Phases 3-7).

## Phase Flow

```
Phase 3: Project Identity
    ↓
Phase 4: Agent Configuration  
    ↓
Phase 5: Orchestration Mode
    ↓
Phase 6: MCP Config (expert only)
    ↓
Phase 7: Quality Standards
    ↓
Return JSON to parent
```

---

## Phase 3: Project Identity

### 3.1 - Confirm Basic Info
User already provided name and description. Display for confirmation:

```
Project: {name}
Description: {description}

Continue with this info? (yes/edit)
```

### 3.2 - Category Selection

**Prompt:**
```
Project category:

1. Game Development
2. Web Application
3. API Server
4. Data/ML Pipeline
5. Mobile App
6. Desktop Application
7. DevOps/Infrastructure
8. E-commerce Platform
9. Other

Select category (1-9):
```

**Processing:**
- Map number to category enum
- If analyzer suggested category with confidence > 0.75, pre-select and confirm

### 3.3 - Tech Stack

**Prompt:**
```
Primary tech stack:
(Frameworks, languages, key libraries)

Examples:
- "React Three Fiber + Phaser + Colyseus"
- "Next.js + PostgreSQL + Prisma"
- "Python + FastAPI + MongoDB"

Tech stack: {analyzer.suggestedTechStack}
```

### 3.4 - Team Size

**Prompt:**
```
Team size:

1. Solo - Just you
2. Small Team (2-5 people)
3. Medium Team (6-15 people)
4. Large Team (16+ people)

Select size (1-4):
```

### 3.5 - Project Scale

**Prompt:**
```
Project scale:

1. Prototype/MVP - Exploring ideas, quick iteration
2. Production - Shipping to real users
3. Enterprise - Large-scale, mission-critical
4. Experimental - Research, learning, testing

Select scale (1-4):
```

### 3.6 - Success Factors (Multi-select)

**Prompt:**
```
What matters most for this project? (Select all that apply)

1. Speed to market
2. Code quality
3. Visual excellence
4. Multiplayer reliability (games)
5. Mobile performance
6. Accessibility
7. SEO optimization
8. Real-time features
9. Data processing
10. Security & compliance

Enter numbers separated by commas (e.g., 1,3,4):
```

**Processing:**
- Parse comma-separated list
- Map to factor enum values
- Store in `project.successFactors` array

### 3.7 - Additional Game-Specific Fields

**If category is "game-development":**

**Platform:**
```
Target platform:

1. Web (Browser)
2. Mobile (iOS/Android)
3. Desktop (Windows/Mac/Linux)
4. Console (PlayStation/Xbox/Switch)
5. Multiple platforms

Select (1-5):
```

**Multiplayer:**
```
Multiplayer support:

1. Single-player only
2. Local multiplayer (same device)
3. Online multiplayer
4. Both local and online

Select (1-4):
```

**Dimensionality:**
```
Visual style:

1. 2D
2. 3D
3. 2.5D (Isometric)
4. Text-based

Select (1-4):
```

---

## Phase 4: Agent Configuration

### 4.1 - Present Analyzer Suggestions

```
Based on your project, I recommend these agents:

{for each suggested agent}
  [X] {agent.name} - {agent.role}
{/for}

These agents will work together to:
- PM: Coordinate workflow and assign tasks
- Developer: Implement features
- QA: Test and validate
- {other agents based on project type}

Accept these agents? (yes/customize)
```

### 4.2 - Agent Selection (if customize)

**Quick Start:** Skip customization, use suggestions
**Standard:** Allow enable/disable agents
**Expert:** Full customization (skills, subagents, MCP)

**Standard Mode:**
```
Available agents:

[ ] pm            - Product Manager (workflow coordination)
[ ] developer     - Developer (feature implementation)
[ ] qa            - QA Engineer (testing, validation)
[ ] techartist    - Tech Artist (visuals, shaders, assets)
[ ] gamedesigner  - Game Designer (GDD, mechanics, playtesting)

Which agents do you need?
Enter letters (p=pm, d=developer, q=qa, t=techartist, g=gamedesigner):
```

### 4.3 - Agent Details (Expert Mode Only)

For each enabled agent:

**Skills:**
```
Agent: {agent.name}

Available skill categories:
{list skill patterns for this agent role}

Default skills: {default_skills}

Customize skills? (no/yes):
```

**Sub-agents:**
```
Available sub-agents for {agent.name}:
{list sub-agents from .claude/agents/ matching this role}

Default sub-agents: {default_subagents}

Customize sub-agents? (no/yes):
```

**MCP Servers:**
```
MCP Server access for {agent.name}:
{list relevant MCP servers}

Default servers: {default_mcp}

Customize MCP access? (no/yes):
```

### 4.4 - Populate Agent Configs

For each agent, create full configuration:

```json
{
  "enabled": true,
  "role": "developer",
  "displayName": "Developer",
  "skills": ["developer-workflow", "dev-r3f-*", "dev-multiplayer-*"],
  "subAgents": ["code-research", "task-researcher"],
  "mcpServers": ["github", "filesystem", "playwright"]
}
```

**Default Mappings:**

**PM:**
- Skills: `["pm-workflow", "pm-organization-*", "pm-planning-*", "pm-improvement-*"]`
- Sub-agents: `["pm-research-specialist", "pm-prd-creator", "test-planner"]`
- MCP: `["github", "filesystem", "web-search-prime", "gitkraken"]`

**Developer:**
- Skills: `["developer-workflow", "dev-typescript-*", "shared-*"]`
- Additional for games: `["dev-r3f-*", "dev-phaser-*", "dev-multiplayer-*"]`
- Sub-agents: `["code-research", "task-researcher"]`
- MCP: `["github", "filesystem", "playwright"]`

**QA:**
- Skills: `["qa-workflow", "qa-validation-*", "qa-e2e-*", "qa-unit-*"]`
- Additional for games: `["qa-gameplay-testing", "qa-multiplayer-testing"]`
- Sub-agents: `["test-creator", "visual-validator", "code-review"]`
- MCP: `["github", "filesystem", "playwright", "zai-mcp-server"]`

**Tech Artist:**
- Skills: `["techartist-workflow", "ta-ui-*", "ta-phaser-*"]`
- Sub-agents: `["asset-researcher", "visual-reference-researcher"]`
- MCP: `["github", "filesystem", "zai-mcp-server", "playwright"]`

**Game Designer:**
- Skills: `["gamedesigner-workflow", "gd-design-*", "thermite-design"]`
- Sub-agents: `["gamedesigner-thermite-facilitator", "gamedesigner-gdd-documenter", "asset-analyst"]`
- MCP: `["github", "filesystem", "web-search-prime", "zai-mcp-server", "playwright"]`

---

## Phase 5: Orchestration Mode

### 5.1 - Mode Selection

**Prompt:**
```
Agent orchestration mode:

1. Event-Driven (Recommended)
   - Agents work in parallel, respond to events
   - Best for: Active development with multiple agents
   - Requires: Watchdog script running

2. Sequential
   - Agents work in order (PM → Dev → QA → PM)
   - Best for: Predictable workflows, learning the system
   - Simpler setup, no background process

3. HITL (Human-In-The-Loop)
   - Manual approval for each agent action
   - Best for: Critical changes, full control
   - Slowest, most hands-on

Select mode (1-3):
```

### 5.2 - Event-Driven Configuration

**If mode is "event-driven":**

**Max Iterations:**
```
Maximum iterations per agent session: [200]
(Range: 50-1000, default: 200)
```

**Context Reset Threshold:**
```
Context reset at what % of max tokens: [70]
(Range: 50-90, default: 70)
```

**Heartbeat Interval:**
```
Agent health check interval (seconds): [30]
(Range: 10-300, default: 30)
```

**Parallel Agents:**
```
Allow multiple agents to work simultaneously? (yes/no): [yes]
```

### 5.3 - Build Orchestration Config

```json
{
  "mode": "event-driven",
  "maxIterations": 200,
  "contextResetThreshold": 70,
  "heartbeatInterval": 30,
  "parallelAgents": true
}
```

---

## Phase 6: MCP Configuration

**Conditional:** Only run if `wizardMode === "expert"`

### 6.1 - Global MCP Server List

Available MCP servers:
- `github` - GitHub/GitKraken integration
- `gitkraken` - GitKraken Pro features
- `filesystem` - File system operations
- `web-search-prime` - Web search capabilities
- `playwright` - Browser automation and E2E testing
- `zai-mcp-server` - Vision AI for image analysis
- `blender` - 3D asset operations (if installed)
- `shadertoy` - Shader development (if installed)

### 6.2 - Per-Agent Configuration

For each enabled agent:

**Prompt:**
```
Agent: {agent.name}
Current MCP servers: {agent.mcpServers.join(', ')}

Modify MCP access?
+ Add servers: [enter names separated by commas]
- Remove servers: [enter names separated by commas]
(or press Enter to keep current)
```

### 6.3 - Build MCP Config

```json
{
  "servers": {
    "github": {
      "enabled": true,
      "agents": ["pm", "developer", "qa", "gamedesigner"]
    },
    "filesystem": {
      "enabled": true,
      "agents": ["pm", "developer", "qa", "techartist", "gamedesigner"]
    },
    "web-search-prime": {
      "enabled": true,
      "agents": ["pm", "gamedesigner"]
    },
    "playwright": {
      "enabled": true,
      "agents": ["developer", "qa", "gamedesigner"]
    },
    "gitkraken": {
      "enabled": true,
      "agents": ["pm", "developer", "qa"]
    },
    "zai-mcp-server": {
      "enabled": true,
      "agents": ["qa", "techartist", "gamedesigner"]
    }
  }
}
```

---

## Phase 7: Quality Standards

### 7.1 - Code Review Requirements

**Prompt:**
```
Code quality enforcement:

1. [ ] No `any` types (TypeScript)
2. [ ] No `@ts-ignore` comments
3. [ ] Enforce type safety
4. [ ] Run linter before commit
5. [ ] Code review checklist

Select rules to enforce (e.g., 1,2,3,4,5 or 'all'):
```

### 7.2 - Testing Requirements

**Test Coverage:**
```
Minimum test coverage target (%): [70]
(Recommended: 70-95%, strict: 85+)
```

**Test Types:**
```
Required test types:

1. [ ] Unit tests (Vitest)
2. [ ] E2E tests (Playwright)
3. [ ] Integration tests
4. [ ] Visual regression tests (games/UI)

Select required tests (e.g., 1,2 or 'all'):
```

### 7.3 - Documentation Requirements

**Prompt:**
```
Documentation requirements:

1. [ ] README.md with setup instructions
2. [ ] PRD (Product Requirements Document)
3. [ ] GDD (Game Design Document) - for games
4. [ ] Inline code comments
5. [ ] Architecture documentation

Select required docs (e.g., 1,2,3 or 'all'):
```

### 7.4 - Validation Pipeline

**Prompt:**
```
Automated validation steps:

1. [ ] Type check (tsc)
2. [ ] Linter (eslint)
3. [ ] Unit tests
4. [ ] Build validation
5. [ ] E2E tests

Select validation steps (e.g., 1,2,3,4 or 'all'):
```

### 7.5 - Build Quality Config

```json
{
  "codeReview": {
    "required": true,
    "checkForAnyTypes": true,
    "checkForTsIgnore": true,
    "enforceTypeScript": true
  },
  "testing": {
    "unitTestsRequired": true,
    "e2eTestsRequired": true,
    "minCoverage": 70,
    "testFramework": "vitest",
    "e2eFramework": "playwright"
  },
  "documentation": {
    "requireGDD": true,
    "requirePRD": true,
    "requireReadme": true,
    "requireInlineComments": false
  },
  "validation": {
    "runTypeCheck": true,
    "runLinter": true,
    "runTests": true,
    "runBuild": true
  }
}
```

---

## Final Assembly

After completing all phases, assemble the complete configuration JSON:

```json
{
  "project": { /* Phase 3 */ },
  "agents": { /* Phase 4 */ },
  "orchestration": { /* Phase 5 */ },
  "mcpConfig": { /* Phase 6 if expert */ },
  "qualityStandards": { /* Phase 7 */ }
}
```

## Validation Before Return

✅ **Required Checks:**
1. At least one agent enabled
2. If event-driven mode, PM must be enabled
3. All enabled agents have valid MCP server references
4. Test coverage is 0-100
5. Project name matches pattern: `^[a-z0-9-]+$`
6. All enum values are valid

## Error Handling

If validation fails:
1. Display specific error
2. Re-prompt for the invalid field
3. Re-validate
4. Only return when all checks pass

## Output Format

Return ONLY the JSON configuration object. No additional text, no markdown code blocks around it.

```json
{
  "project": {...},
  "agents": {...},
  "orchestration": {...},
  "mcpConfig": {...},
  "qualityStandards": {...}
}
```
