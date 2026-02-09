# PRD Starter State Schema

Complete reference for the PRD Starter state file structure (v4.0).

**Related Documentation:**
- [SKILL.md](SKILL.md) - Main skill definition
- [PHASES.md](PHASES.md) - Phase-by-phase instructions
- [docs/prd-starter-templates.md](../../docs/prd-starter-templates.md) - Template system

**State File Location:** `./.claude/session/prd-starter-state.json`

---

## Schema Version

**Version:** 4.0.0  
**Template:** `prd-starter-state-template.json`

```json
{
  "_version": "4.0.0",
  "_template": "prd-starter-state"
}
```

---

## Root Properties

### Metadata

**Timestamps:**
```json
{
  "startedAt": "2026-02-08T10:30:00.000Z",
  "completedAt": "2026-02-08T11:10:00.000Z",  // null until completed
  "lastModified": "2026-02-08T10:45:00.000Z"
}
```

**Type Definitions:**
- `startedAt`: ISO 8601 timestamp (wizard start)
- `completedAt`: ISO 8601 timestamp or `null`
- `lastModified`: ISO 8601 timestamp (last state update)

### Wizard Configuration

```json
{
  "wizardMode": "quick-start | standard | expert",
  "selectedPreset": "preset-name" | null
}
```

**Enum Values:**
- `wizardMode`: `"quick-start"`, `"standard"`, `"expert"`
- `selectedPreset`: Preset filename (without `.json`) or `null`

### Phase Tracking

```json
{
  "currentPhase": "entry",
  "currentSubPhase": null,
  "phaseHistory": ["entry", "project", "features"]
}
```

**Phase Enum:**
- `"entry"` - Phase 1: Entry point
- `"presets"` - Phase 2: Preset selection
- `"project"` - Phase 3: Project identity
- `"agents"` - Phase 4: Agent configuration
- `"orchestration"` - Phase 5: Orchestration mode
- `"mcp_config"` - Phase 6: MCP configuration
- `"quality"` - Phase 7: Quality standards
- `"features"` - Phase 8: Features collection
- `"deep_research"` - Phase 8b: Research subagent
- `"user_questions"` - Phase 8b-user: User answers
- `"gdd_creation"` - Phase 8c: GDD subagent
- `"prd_creation"` - Phase 8d: PRD subagent
- `"final_review"` - Phase 9: Review and confirm
- `"completed"` - Phase 10-11: Generation complete

**Type Definitions:**
- `currentPhase`: Current phase enum value
- `currentSubPhase`: Optional sub-phase identifier (string or null)
- `phaseHistory`: Array of phase names in order completed

---

## Project Configuration

Complete project identity and metadata.

```json
{
  "project": {
    "name": "thermite-game",
    "description": "Bomberman-inspired extraction game with Tarkov mechanics",
    "category": "game-development",
    "techStack": "React Three Fiber + Phaser + Colyseus",
    "teamSize": "solo",
    "projectScale": "prototype-mvp",
    "successFactors": [
      "speed-to-market",
      "visual-excellence",
      "multiplayer-reliability"
    ]
  }
}
```

**Field Definitions:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | ✓ | Project name (lowercase-with-hyphens) |
| `description` | string | ✓ | One-line description (max 200 chars) |
| `category` | enum | ✓ | Project category (see below) |
| `techStack` | string | ✓ | Primary technologies used |
| `teamSize` | enum | ✓ | Team size category (see below) |
| `projectScale` | enum | ✓ | Project scale/phase (see below) |
| `successFactors` | array | ✓ | Key success metrics (see below) |

**Category Enum:**
- `"game-development"`
- `"web-application"`
- `"api-server"`
- `"data-ml-pipeline"`
- `"mobile-app"`
- `"other"`

**Team Size Enum:**
- `"solo"` - Individual developer
- `"small"` - 2-5 people
- `"medium"` - 6-20 people
- `"enterprise"` - 20+ people

**Project Scale Enum:**
- `"prototype-mvp"` - Quick experimentation
- `"startup-product"` - Production-ready, iterating
- `"production-system"` - Enterprise-grade

**Success Factors:**
- `"speed-to-market"`
- `"code-quality"`
- `"visual-excellence"`
- `"multiplayer-reliability"`
- `"mobile-performance"`
- `"accessibility"`
- `"seo"`
- `"real-time-features"`
- `"data-processing"`

---

## Agent Configuration

Configuration for each Ralph Orchestra agent.

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
    },
    "techartist": {
      "enabled": false,
      "skills": [],
      "subAgents": [],
      "mcpServers": []
    },
    "qa": {
      "enabled": true,
      "skills": ["qa-browser-testing", "qa-validation-*"],
      "subAgents": ["qa-code-review"],
      "mcpServers": ["playwright", "filesystem"]
    },
    "gamedesigner": {
      "enabled": false,
      "skills": [],
      "subAgents": [],
      "mcpServers": []
    }
  }
}
```

**Agent Structure:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `enabled` | boolean | ✓ | Whether agent is active |
| `skills` | array | ✓ | Skill patterns (supports wildcards) |
| `subAgents` | array | ✓ | Sub-agent names to invoke |
| `mcpServers` | array | ✓ | MCP server identifiers |

**Available Agents:**
- `pm` - Product Manager
- `developer` - Developer
- `techartist` - Tech Artist
- `qa` - QA Engineer
- `gamedesigner` - Game Designer

**Common Skills:**
- PM: `pm-organization-*`, `pm-planning-*`, `pm-router`
- Developer: `dev-r3f-*`, `dev-typescript-*`, `developer-workflow`
- Tech Artist: `ta-r3f-*`, `ta-shader-*`, `ta-assets-*`
- QA: `qa-browser-testing`, `qa-validation-*`, `qa-reporting-*`
- Game Designer: `gd-design-*`, `gd-gdd-*`, `gd-thermite-integration`

**Common Sub-Agents:**
- `developer-implementation`
- `qa-code-review`
- `techartist-asset-creator`
- `gamedesigner-thermite-facilitator`

**MCP Servers:**
- `github` - GitHub API
- `filesystem` - File operations
- `web-search` - Web search
- `brave-search` - Brave API
- `playwright` - Browser automation
- `vision` - Image analysis
- `blender` - 3D operations
- `shadertoy` - Shader development

---

## Orchestration Configuration

Settings for agent coordination.

```json
{
  "orchestration": {
    "mode": "event-driven",
    "maxIterations": 200,
    "contextResetThreshold": 70,
    "heartbeatInterval": 30
  }
}
```

**Field Definitions:**

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `mode` | enum | - | Orchestration mode (see below) |
| `maxIterations` | number | 1-1000 | Max iterations per agent |
| `contextResetThreshold` | number | 50-90 | Context reset % threshold |
| `heartbeatInterval` | number | 10-300 | Heartbeat seconds |

**Mode Enum:**
- `"event-driven"` - Agents respond to events autonomously
- `"sequential"` - Agents work in defined order
- `"hitl"` - Human-in-the-loop approval

---

## Quality Standards

Code quality and testing requirements.

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
  }
}
```

**Field Definitions:**

| Field | Type | Description |
|-------|------|-------------|
| `typescriptStrictness` | enum | TS strictness: `"strict"`, `"standard"`, `"loose"` |
| `testCoverageTarget` | number | Coverage % target (0-100) |
| `noAnyTypes` | boolean | Forbid `any` types |
| `noTsIgnore` | boolean | Forbid `@ts-ignore` |
| `lintRules` | enum | Lint preset: `"eslint-recommended"`, `"custom"`, `"none"` |
| `commitConvention` | enum | Commit format: `"[ralph]"`, `"conventional"`, `"custom"` |
| `ciCdIntegration` | enum | CI/CD: `"github-actions"`, `"gitlab-ci"`, `"none"` |
| `additionalGates` | array | Extra quality gates (strings) |

---

## Features

Initial feature list collected from user.

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
  ]
}
```

**Feature Structure:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Auto-generated ID (feat-NNN) |
| `description` | string | Natural language description |
| `category` | string | Auto-categorized (gameplay, technical, visual, etc.) |
| `priority` | string | Auto-assigned (high, medium, low) |

---

## Research Data

Output from pm-research-specialist subagent.

```json
{
  "researchData": {
    "similarProjects": [
      {
        "name": "Bomberman.js",
        "url": "https://github.com/example/bomberman",
        "relevance": "Open source Bomberman implementation",
        "techStack": ["JavaScript", "Canvas"],
        "lessons": ["Grid-based movement patterns", "Collision detection"]
      }
    ],
    "bestPractices": [
      {
        "practice": "Server-authoritative physics",
        "reason": "Prevents cheating in multiplayer",
        "source": "Gaffer On Games",
        "applicability": "Critical for competitive games"
      }
    ],
    "commonPitfalls": [
      {
        "pitfall": "Client-side prediction without reconciliation",
        "consequence": "Rubber-banding and desync",
        "avoidance": "Implement snapshot interpolation",
        "severity": "high"
      }
    ],
    "techStackInsights": {
      "strengths": ["Rich 3D rendering", "Strong typing"],
      "weaknesses": ["Bundle size", "Learning curve"],
      "recommendedLibraries": ["@react-three/drei", "colyseus"]
    },
    "questionsAsked": [
      {
        "id": "Q-001",
        "question": "Will you need server-authoritative physics?",
        "context": "For competitive multiplayer...",
        "impact": "Affects architecture decisions",
        "category": "technical"
      }
    ],
    "questionsAnswered": [
      {
        "questionId": "Q-001",
        "question": "Will you need server-authoritative physics?",
        "answer": "Yes, for competitive integrity",
        "answeredAt": "2026-02-08T10:45:00.000Z"
      }
    ],
    "recommendedRefinements": ["Split networking feature into client/server"],
    "references": ["https://gafferongames.com"],
    "discoveredCommands": {
      "runtime": "node",
      "runtimeSource": "package.json engines field",
      "discoveredAt": "2026-02-08T10:42:00.000Z",
      "confidence": "high",
      "commands": {
        "packageManager": "npm",
        "init": "npm init",
        "install": "npm install",
        "dev": "npm run dev",
        "build": "npm run build",
        "test": "npm test",
        "typeCheck": "npm run type-check"
      },
      "feedbackLoops": ["Type checking on save", "Hot reload in dev"],
      "discoverySources": ["package.json", "README.md", "similar projects"]
    }
  }
}
```

**See:** `./.claude/templates/research-output-template.json` for complete structure

---

## GDD Data

Output from gamedesigner-thermite-facilitator subagent.

**State Storage Strategy:**
- **State file (.json)**: Minimal subset for orchestration and CLI display
- **gdd-findings.json**: Complete structured output with all fields (context, dissent, tensions, etc.)
- **docs/design/*.md**: Human-readable design documentation (11+ artifacts)

**Minimal State Format (in prd-starter-state.json):**
```json
{
  "gddData": {
    "designDecisions": [
      {
        "id": "DEC-001",
        "title": "Grid-based movement with 8 directions",
        "status": "Decided",
        "pillars": ["Meaningful Risk", "Readable Chaos"],
        "decision": "8-directional grid movement",
        "validationNeeded": ["Playtest movement feel"]
      }
    ],
    "openQuestions": [
      {
        "id": "OQ-001",
        "question": "Should bombs have different blast patterns?",
        "priority": "medium",
        "owner": "Viktor Volkov",
        "tags": ["gameplay", "mechanics"]
      }
    ],
    "designPillars": [
      "Meaningful Risk",
      "Readable Chaos",
      "Compressed Tension"
    ],
    "coreMechanics": [
      {
        "name": "Bomb Placement",
        "description": "Player places bomb, explodes after 3 seconds"
      }
    ],
    "thermiteSessionType": "boardroom-retreat",
    "participants": ["Shinji Tanaka", "Viktor Volkov"]
  }
}
```

**Rich Format (in ./.claude/session/gdd-findings.json):**
See `./.claude/templates/gdd-output-template.json` v2.0 for complete schema including:
- Full decision context, rationale, alternatives, dissent, dependencies
- Open questions with blockerFor, raisedInSession, suggestedInvestigation
- Design pillars with descriptions, guardrails, KPIs
- Core mechanics with interactions, riskFactors, skillExpression
- Tensions explored between personas
- Action items with owners and priorities
- Session metadata and next session recommendations

**Artifact Files (in docs/design/):**
```
session_001_[topic].md    - Session summary with discussion flow
decision_log.md            - All design decisions chronologically
open_questions.md          - Unresolved questions requiring answers
gdd.md                     - Main GDD summary indexing all work
core_loop.md               - Gameplay loop specification
economy_model.md           - Economy systems and balance
map_templates.md           - Map design and layouts
gear_registry.md           - Items with stats and counterplay
visual_language.md         - Visual and audio design
tech_spec.md               - Technical architecture
mvd_checklist.md           - Prototype readiness checklist
```

---

## PRD Specification

Output from pm-prd-creator subagent.

```json
{
  "prdSpecification": {
    "refinedFeatures": [
      {
        "id": "feat-001-refined",
        "originalId": "feat-001",
        "title": "Grid-based Movement System",
        "description": "8-directional grid movement with smooth interpolation",
        "category": "gameplay",
        "priority": "P0",
        "assignedTo": "developer",
        "estimatedComplexity": "medium",
        "dependencies": ["feat-002"],
        "acceptanceCriteria": [
          "Player moves on 8 directions using WASD/Arrow keys",
          "Movement snaps to grid cells",
          "Smooth interpolation between cells (200ms)"
        ]
      }
    ],
    "acceptanceCriteria": {
      "feat-001-refined": [
        "Player moves on 8 directions using WASD/Arrow keys",
        "Movement snaps to grid cells"
      ]
    },
    "dependencies": {
      "feat-001-refined": ["feat-002"]
    },
    "priorities": {
      "P0": ["feat-001-refined"],
      "P1": ["feat-003-refined"],
      "P2": ["feat-005-refined"]
    },
    "technicalRecommendations": [
      "Use ECS pattern for entity management",
      "Implement client prediction with server reconciliation"
    ],
    "agentAssignments": {
      "developer": ["feat-001-refined", "feat-002-refined"],
      "techartist": ["feat-004-refined"],
      "qa": ["all-features"]
    },
    "approved": true,
    "approvedAt": "2026-02-08T11:00:00.000Z",
    "prdPath": "prd.json"
  }
}
```

**See:** `./.claude/templates/prd-template.json` for complete structure

**PRD File:** `prd.json` (written by pm-prd-creator)

---

## Generation Results

Results from Python generator execution.

```json
{
  "generationResults": {
    "filesCreated": [
      "./.claude/agents/pm/AGENT.md",
      "./.claude/agents/pm/SKILLS.md",
      "./.claude/agents/developer/AGENT.md",
      "./.claude/settings.pm.json",
      "./.claude/settings.developer.json",
      "docs/research-summary.md",
      "README.md",
      "CLAUDE.md"
    ],
    "filesModified": [
      "./.claude/scripts/watchdog/run.ps1",
      "./.claude/scripts/message-queue/queue-processor.ps1"
    ],
    "errors": [],
    "warnings": [
      "Optional: Tech Artist not enabled, skipping visual tools setup"
    ]
  }
}
```

**Field Definitions:**

| Field | Type | Description |
|-------|------|-------------|
| `filesCreated` | array | Paths of files created by generator |
| `filesModified` | array | Paths of files modified by generator |
| `errors` | array | Error messages (generation failures) |
| `warnings` | array | Warning messages (non-critical issues) |

---

## Complete Example

Full state file example for a game project:

```json
{
  "_comment": "PRD Starter State File v4.0",
  "_version": "4.0.0",
  "_template": "prd-starter-state",

  "startedAt": "2026-02-08T10:30:00.000Z",
  "completedAt": "2026-02-08T11:10:00.000Z",
  "lastModified": "2026-02-08T11:10:00.000Z",

  "wizardMode": "standard",
  "selectedPreset": null,

  "currentPhase": "completed",
  "currentSubPhase": null,
  "phaseHistory": [
    "entry",
    "project",
    "agents",
    "orchestration",
    "quality",
    "features",
    "deep_research",
    "user_questions",
    "gdd_creation",
    "prd_creation",
    "final_review",
    "completed"
  ],

  "project": {
    "name": "thermite-game",
    "description": "Bomberman-inspired extraction game with Tarkov mechanics",
    "category": "game-development",
    "techStack": "React Three Fiber + Phaser + Colyseus",
    "teamSize": "solo",
    "projectScale": "prototype-mvp",
    "successFactors": [
      "speed-to-market",
      "visual-excellence",
      "multiplayer-reliability"
    ]
  },

  "agents": {
    "pm": {
      "enabled": true,
      "skills": ["pm-organization-*", "pm-planning-*", "pm-router"],
      "subAgents": [],
      "mcpServers": ["github", "filesystem", "web-search"]
    },
    "developer": {
      "enabled": true,
      "skills": ["dev-r3f-*", "dev-phaser-*", "developer-workflow"],
      "subAgents": ["developer-implementation"],
      "mcpServers": ["github", "filesystem"]
    },
    "techartist": {
      "enabled": false,
      "skills": [],
      "subAgents": [],
      "mcpServers": []
    },
    "qa": {
      "enabled": true,
      "skills": ["qa-gameplay-testing", "qa-multiplayer-testing"],
      "subAgents": ["qa-gameplay-tester"],
      "mcpServers": ["playwright", "filesystem"]
    },
    "gamedesigner": {
      "enabled": true,
      "skills": ["gd-design-*", "gd-thermite-integration"],
      "subAgents": ["gamedesigner-thermite-facilitator"],
      "mcpServers": ["filesystem", "web-search"]
    }
  },

  "orchestration": {
    "mode": "event-driven",
    "maxIterations": 200,
    "contextResetThreshold": 70,
    "heartbeatInterval": 30
  },

  "qualityStandards": {
    "typescriptStrictness": "strict",
    "testCoverageTarget": 85,
    "noAnyTypes": true,
    "noTsIgnore": true,
    "lintRules": "eslint-recommended",
    "commitConvention": "[ralph]",
    "ciCdIntegration": "github-actions",
    "additionalGates": ["require-tests"]
  },

  "features": [
    {
      "id": "feat-001",
      "description": "Grid-based movement with 8 directions",
      "category": "gameplay",
      "priority": "high"
    },
    {
      "id": "feat-002",
      "description": "Bomb placement and explosion mechanics",
      "category": "gameplay",
      "priority": "high"
    }
  ],

  "researchData": {
    "similarProjects": [...],
    "bestPractices": [...],
    "commonPitfalls": [...],
    "techStackInsights": {...},
    "questionsAsked": [...],
    "questionsAnswered": [...],
    "recommendedRefinements": [...],
    "references": [...],
    "discoveredCommands": {...}
  },

  "gddData": {
    "designDecisions": [...],
    "openQuestions": [...],
    "designPillars": [...],
    "coreMechanics": [...],
    "thermiteSessionType": "boardroom-retreat",
    "participants": ["Shinji Tanaka", "Viktor Volkov"]
  },

  "prdSpecification": {
    "refinedFeatures": [...],
    "acceptanceCriteria": {...},
    "dependencies": {...},
    "priorities": {...},
    "technicalRecommendations": [...],
    "agentAssignments": {...},
    "approved": true,
    "approvedAt": "2026-02-08T11:00:00.000Z",
    "prdPath": "prd.json"
  },

  "generationResults": {
    "filesCreated": [...],
    "filesModified": [...],
    "errors": [],
    "warnings": []
  }
}
```

---

## Validation Rules

### Required Fields

**All States:**
- `_version`
- `startedAt`
- `lastModified`
- `wizardMode`
- `currentPhase`

**When Phase ≥ project:**
- `project.*` (all fields)

**When Phase ≥ agents:**
- At least one agent with `enabled: true`

**When Phase ≥ features:**
- At least one feature in `features` array

**When completed:**
- `completedAt` must be set
- `generationResults.filesCreated` must be non-empty

### Field Constraints

**Strings:**
- `project.name`: 3-50 chars, lowercase-with-hyphens
- `project.description`: 10-200 chars
- Feature descriptions: 10-500 chars

**Numbers:**
- `orchestration.maxIterations`: 1-1000
- `orchestration.contextResetThreshold`: 50-90
- `orchestration.heartbeatInterval`: 10-300
- `qualityStandards.testCoverageTarget`: 0-100

**Arrays:**
- `features`: Minimum 1 item
- `project.successFactors`: Minimum 1 item
- Agent `skills`: Minimum 1 item if enabled
- Agent `mcpServers`: Minimum 1 item if enabled

### Conditional Requirements

**If wizardMode === "quick-start":**
- `selectedPreset` should not be null (unless custom selected)

**If project.category === "game-development":**
- `gddData` should be populated when phase ≥ gdd_creation
- Agent `gamedesigner` should be enabled

**If phase ≥ user_questions:**
- `researchData.questionsAnswered` should match `questionsAsked`

**If phase === completed:**
- All conditional phases must be in `phaseHistory`
- `prdSpecification.approved` must be true
- `generationResults.errors` should be empty

---

## State Transitions

### Phase Progression

```
entry
  ↓ (wizardMode selected)
presets? (only if quick-start)
  ↓ (preset selected or skipped)
project
  ↓ (project configured)
agents
  ↓ (agents configured)
orchestration
  ↓ (mode selected)
mcp_config? (only if expert)
  ↓ (MCP servers configured)
quality
  ↓ (standards set)
features
  ↓ (features collected)
deep_research
  ↓ (research completed)
user_questions? (only if questions asked)
  ↓ (questions answered)
gdd_creation? (only if game)
  ↓ (GDD created)
prd_creation
  ↓ (PRD approved)
final_review
  ↓(user confirms)
completed
```

### State Updates Per Phase

**Each phase transition:**
1. Update `currentPhase` to next phase
2. Append previous phase to `phaseHistory`
3. Update `lastModified` timestamp
4. Persist state atomically

**On completion:**
1. Set `currentPhase` = `"completed"`
2. Set `completedAt` timestamp
3. Populate `generationResults`
4. Final state write

---

## Resume Logic

**On wizard invocation:**

```bash
# Check for existing state
if [ -f ./.claude/session/prd-starter-state.json ]; then
  # Read current phase
  current_phase=$(jq -r '.currentPhase' ./.claude/session/prd-starter-state.json)
  
  if [ "$current_phase" != "completed" ]; then
    # Offer resume
    echo "Found incomplete session at phase: $current_phase"
    echo "1. Resume from $current_phase"
    echo "2. Restart"
    # ... handle choice
  fi
fi
```

**Resume from phase:**
- Load full state
- Display phase summary
- Continue from `currentPhase`
- Maintain `phaseHistory`

---

## Migration Notes

**From v3.0 to v4.0:**

Changes:
- Added `_template` field
- Renamed `gddData.thermiteSession` → `thermiteSessionType`
- Added `discoveredCommands` to `researchData`
- Added `currentSubPhase` field
- Added `questionsAnswered` array

Migration:
```python
if state.get("_version") == "3.0.0":
    state["_version"] = "4.0.0"
    state["_template"] = "prd-starter-state"
    if "gddData" in state:
        state["gddData"]["thermiteSessionType"] = state["gddData"].pop("thermiteSession", "boardroom-retreat")
    if "researchData" in state:
        state["researchData"]["discoveredCommands"] = {}
        state["researchData"]["questionsAnswered"] = []
```

---

## Related Files

**Templates:**
- `./.claude/templates/prd-starter-state-template.json` - State template
- `./.claude/templates/research-output-template.json` - Research structure
- `./.claude/templates/gdd-output-template.json` - GDD structure
- `./.claude/templates/prd-template.json` - PRD structure

**Generated From State:**
- `./.claude/agents/{name}/AGENT.md` - Agent definitions
- `./.claude/settings.{name}.json` - MCP settings
- `docs/research-summary.md` - Research summary
- `docs/design/*.md` - GDD documentation
- `prd.json` - Product requirements

**Scripts:**
- `./.claude/scripts/prd-starter/loader.py` - State loading
- `./.claude/scripts/prd-starter/validator.py` - State validation
- `./.claude/scripts/prd-starter/generator.py` - Generation orchestration
