# Extending Ralph Orchestra

This guide covers how to extend Ralph Orchestra with custom agents, skills, and routing.

## Agent Configuration

All agents are defined in `.claude/scripts/ralph-config.ps1`:

```powershell
$Script:AgentConfig = @{
    "pm" = @{
        Type = "coordinator"
        Command = "/ralph-coordinator-event"
        DisplayName = "PM (Coordinator)"
        Color = "Magenta"
    }
    "developer" = @{
        Type = "worker"
        Command = "/ralph-worker-event --agent developer"
        DisplayName = "Developer"
        Color = "Cyan"
    }
    "techartist" = @{
        Type = "worker"
        Command = "/ralph-worker-event --agent techartist"
        DisplayName = "Tech Artist"
        Color = "Green"
    }
    "qa" = @{
        Type = "worker"
        Command = "/ralph-worker-event --agent qa"
        DisplayName = "QA"
        Color = "Yellow"
    }
    "gamedesigner" = @{
        Type = "worker"
        Command = "/ralph-worker-event --agent gamedesigner"
        DisplayName = "Game Designer"
        Color = "Blue"
    }
}
```

## Understanding the Skill Variant System

Ralph uses a **skill variant pattern** where a single skill handles multiple agent types via arguments.

### How ralph-worker Works

**Skill Definition:**
```yaml
---
name: ralph-worker
description: Worker loop - execute tasks assigned by coordinator
category: orchestration
arguments:
  --agent: "developer" or "qa" or "gamedesigner" or "techartist"
---
```

**Invocation:**
```bash
/ralph-worker-event --agent developer   # Runs as Developer (event-driven)
/ralph-worker-single --agent developer  # Runs as Developer (sequential)
/ralph-worker-event --agent qa          # Runs as QA (event-driven)
/ralph-worker-single --agent techartist # Runs as Tech Artist (sequential)
/ralph-worker-event --agent gamedesigner # Runs as Game Designer (event-driven)
```

**Inside the skill**, the agent checks `$arguments.agent` to determine:
- Which agent-specific instructions to follow (coding vs validation vs assets)
- What state files to update
- What MCP servers are available

## Worker vs Coordinator Pattern

| Aspect | Coordinator (PM) | Workers (Dev/QA/GameDesigner/TechArtist) |
|--------|-------------------|------------------------------------------|
| **Type** | `Type = "coordinator"` | `Type = "worker"` |
| **Instances** | Single instance | Multiple can run in parallel |
| **Command** | No `--agent` argument | Requires `--agent` argument |
| **State File** | Owns `coordinator-state.json` | Polls for tasks assigned to them |

## Adding Custom Agents

### Step 1: Create Agent Directory Structure

For example, to add a new worker agent (techartist is already included as an example):

```
agents/techartist/
└── AGENT.md              # Core behavior instructions
```

**Note:** Skills are centralized in `.claude/skills/` (folder-based), and sub-agents are in `.claude/agents/*.agent.md`.

### Step 2: Create AGENT.md

```markdown
# YOU ARE THE TECH ARTIST AGENT

# Your job: CREATE 3D/2D ASSETS, SHADERS, AND VISUAL EFFECTS

## When to Use This Agent

- Task category contains "visual", "shader", "effects", "ui-polish"
- PM assigns tasks with agent=techartist
- Asset creation is needed after Developer completes logic

## Your Workflow

1. Read asset requirements from current-task.json
2. Read GDD for artistic references
3. Create assets/shaders using R3F patterns
4. Test in browser via Playwright
5. Run feedback loops (type-check, lint, build)
6. Commit work with [ralph] [techartist] prefix
7. Send asset_ready to QA
```

### Step 3: Update ralph-config.ps1

Add your new agent to the `AgentConfig` hashtable:

```powershell
$Script:AgentConfig = @{
    # ... existing agents ...
    "techartist" = @{
        Type = "worker"
        Command = "/ralph-worker-event --agent techartist"
        DisplayName = "Tech Artist"
        Color = "Green"
    }
}
```

### Step 4: Update Watchdog Scripts

**For Sequential Mode** (`.claude/scripts/watchdog-single.ps1`):

```powershell
# Add to valid agents array (around line 102)
$validAgents = @("pm", "developer", "techartist", "qa", "gamedesigner")

# Add to switch statement (around line 293)
$slashCommand = switch ($AgentName) {
    "pm" { "/ralph-coordinator-single" }
    "developer" { "/ralph-worker-single --agent developer" }
    "techartist" { "/ralph-worker-single --agent techartist" }
    "qa" { "/ralph-worker-single --agent qa" }
    "gamedesigner" { "/ralph-worker-single --agent gamedesigner" }
}
```

### Step 5: Update ralph-worker Skill

Modify `.claude/skills/ralph-worker.md` to include your new agent:

```markdown
## Determine Your Agent Type

Check the `--agent` argument:

- **"developer"**: Implement features and run feedback loops
- **"techartist"**: Create visual assets, shaders, and effects
- **"qa"**: Validate implementations with tests and browser checks
- **"gamedesigner"**: Create GDDs and answer design questions
```

### Step 6: Create Agent-Specific Settings (Optional)

Create `.claude/settings.techartist.json`:

```json
{
  "mcpServers": {
    "filesystem": { ... },
    "github": { ... },
    "web-search": { ... },
    "playwright": { ... },
    "vision": { ... },
    "blender": {
      "command": "npx",
      "args": ["-y", "blender-mcp"]
    },
    "shadertoy": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-shadertoy"]
    },
    "image-process": {
      "command": "npx",
      "args": ["-y", "@x007xyz/image-process-mcp-server"]
    }
  }
}
```

### Step 7: Test Your New Agent

```bash
# Manual testing (event-driven)
/ralph-worker-event --agent techartist

# Sequential mode
.\.claude\scripts\ralph-single-session.ps1 -InitialAgent techartist

# Add test task to prd.json
{
  "id": "vis-001",
  "title": "Create vehicle materials",
  "category": "visual",
  "agent": "techartist",
  "status": "pending",
  "passes": false
}
```

## Git Worktrees for Parallel Development

Developer and Tech Artist can work simultaneously using git worktrees:

### How It Works

```
project/
├── .git/
├── src/                    # Main working tree (Developer)
└── worktrees/
    ├── dev-feature-001/    # Developer worktree
    └── ta-visuals-002/     # Tech Artist worktree
```

### Setting Up Worktrees

The system automatically creates worktrees when needed. Each agent gets their own working tree, eliminating merge conflicts:

- Developer works on logic/server code
- Tech Artist works on visuals/assets
- Changes are isolated until merged

### Benefits

- No merge conflicts between parallel agents
- Each agent has their own isolated workspace
- Changes can be tested independently before merging

## Skill Routing

The `.claude/skills/ralph-router.md` skill routes tasks to appropriate domain skills based on:

- **Agent type** - PM, Developer, Tech Artist, QA, Game Designer
- **Task category** - architectural, functional, visual, integration, polish
- **Task content** - Keywords in title/description

### Adding Custom Routes

Edit `.claude/skills/ralph-router.md`:

```markdown
## Routing Table

| Signal Pattern | Target Skill |
|----------------|--------------|
| agent=developer | agents/developer/ |
| agent=techartist | agents/techartist/ |
| task contains "ui" | skills/ui-patterns.md |
| task contains "shader" | skills/shader-creation.md |
```

## Adding Custom Sub-agents

Sub-agents allow main agents to delegate focused work to specialized, lower-cost models. This keeps the main agent's context clean and reduces token usage.

### Sub-agent Benefits

- **Cost Optimization** - Use Haiku for search tasks (~77% cost reduction)
- **Clean Context** - Main agent doesn't accumulate search results
- **Specialized Expertise** - Each sub-agent has focused instructions

### When to Use Haiku vs Sonnet

| Model | Use For | Examples |
|-------|---------|----------|
| **Haiku** | Fast search, research, parsing | Finding files, parsing test output, locating assets |
| **Sonnet** | Implementation, design, validation | Creating features, writing GDDs, code review |

### Creating a Sub-agent

Sub-agents are defined in `.claude/agents/*.agent.md` with YAML frontmatter:

#### Example 1: Haiku Search Sub-agent

```markdown
---
name: asset-researcher
description: Research existing assets in src/assets/ before requesting new ones from Tech Artist
model: haiku
tools: Read, Glob, Grep
disallowedTools: Write, Edit, Bash
---

You are an asset research specialist. Your job is to quickly find visual asset files.

## Search Strategy

1. Use **Glob** to find matching files by pattern (e.g., `**/*.png`, `**/*.glb`)
2. Use **Grep** to search within files for specific asset names
3. Use **Read** to verify asset metadata if needed

## Output Format

Return concise results:
- path/to/file.png
- path/to/shader.glsl (lines 10-25 relevant)

**Keep output brief** - this is a fast search subagent.
```

#### Example 2: Sonnet Implementation Sub-agent

```markdown
---
name: implementation
description: Implement features using R3F/TypeScript patterns following research findings
model: sonnet
skills:
  - dev-r3f-r3f-fundamentals
  - dev-r3f-r3f-physics
tools: Read, Write, Edit, Bash
---

You are an implementation specialist. Your job is to implement features following researched patterns.

## Implementation Workflow

1. Read research findings from code-researcher
2. Load appropriate skills based on task keywords
3. Implement following existing patterns
4. Run type-check and lint
5. Commit with conventional commit format

## Quality Standards

- NO `any` types without justification
- NO `@ts-ignore` or `@ts-expect-error`
- Follow existing code conventions
```

### Sub-agent YAML Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique identifier (used for delegation) |
| `description` | Yes | Brief description of when to use this sub-agent |
| `model` | Yes | `haiku` or `sonnet` |
| `tools` | No | Allowed tools (defaults to all if omitted) |
| `disallowedTools` | No | Tools to explicitly forbid |

### Invoking Sub-agents from Main Agent

In the main agent's AGENT.md, document available sub-agents:

```markdown
## Subagent Delegation

| Subagent | Model | Purpose | When to Use |
|----------|-------|---------|-------------|
| `code-research` | Haiku | Fast file search | Finding similar code |
| `implementation` | Sonnet | Feature implementation | Implementing features |

### Delegation Pattern

```
"Use the {subagent-name} subagent to {brief task description}"
```

Examples:
- "Use the code-research subagent to find components using useFrame hook"
- "Use the implementation subagent to implement player jump mechanics"
- "Use the asset-researcher subagent to find all texture files for the vehicle"
```

### Directory Structure

```
.claude/agents/              # FLAT: no subdirectories
├── implementation.agent.md  # Sonnet - Code implementation
├── code-quality.agent.md    # Sonnet - Code quality checks
├── code-research.agent.md   # Haiku - Fast search
├── validation.agent.md      # Haiku - Pre-commit validation
├── commit.agent.md          # Sonnet - Git commits
├── browser-validator.agent.md  # Sonnet - Browser testing
├── gdd-documenter.agent.md     # Sonnet - GDD creation
├── prd-organizer.agent.md      # Sonnet - PRD organization
├── task-researcher.agent.md    # Sonnet - PM task research
└── ... (16+ more sub-agents)
```

## Thermite Design Integration

The Game Designer agent uses the [thermite-design](.claude/skills/gd-thermite-integration/SKILL.md) skill for structured design sessions:

### Design Pillars

- Meaningful Risk - Every action matters
- Readable Chaos - Chaotic but parseable
- Compressed Tension - 5-8 minute matches
- Earned Mastery - Skill beats gear
- Sustainable Economy - Patchable, not exploitable

### Design Session Types

- Mechanic design - Define gameplay systems
- Level design - Map and environment creation
- Character design - Classes and abilities
- Weapon design - Items and equipment
- Playtesting - Validation via Playwright MCP

## Custom Handoff Logic

For advanced workflows, you can customize handoff behavior.

### Override Handoff Function

In `watchdog-single.ps1`, you can add custom logic:

```powershell
function Invoke-Handoff {
    param(
        [string]$FromAgent,
        [string]$ToAgent,
        [string]$Context
    )

    # Custom pre-handoff logic
    if ($FromAgent -eq "developer" -and $ToAgent -eq "qa") {
        Write-Host "Running pre-QA tests..." -ForegroundColor Cyan
        & npm run test
    }

    # Standard handoff logic
    Stop-SingleAgent -Graceful -Reason "handoff_to_$ToAgent"
    Start-Sleep -Seconds 2
    Start-SingleAgent -AgentName $ToAgent -HandoffContext $Context
}
```

## Skill Variant Best Practices

1. **Use `--agent` for variants** of the same pattern:
   - `/ralph-worker-event --agent developer`
   - `/ralph-worker-event --agent techartist`
   - `/ralph-worker-event --agent qa`
   - `/ralph-worker-event --agent gamedesigner`

2. **Use separate slash commands** for fundamentally different behaviors:
   - `/ralph-coordinator-event` (event-driven orchestration)
   - `/ralph-coordinator-single` (sequential orchestration)
   - `/ralph-hitl` (single iteration)

3. **Keep skill content generic** - use the `--agent` value to branch behavior

4. **Document agent-specific paths** clearly in the skill file

## CI/CD Integration

You can integrate Ralph into your CI/CD pipeline:

```yaml
# .github/workflows/ralph.yml
name: Ralph Autonomous Development

on:
  workflow_dispatch:
    inputs:
      mode:
        description: 'Orchestration mode'
        default: 'event'
        type: choice
        options: [event, sequential]

jobs:
  ralph:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Claude CLI
        run: npm install -g @anthropic-ai/claude-cli

      - name: Run Ralph
        run: |
          $env:RALPH_MAX_ITERATIONS = 50
          if ("${{ inputs.mode }}") -eq "event" {
            .\.claude\scripts\ralph-event-session.ps1
          } else {
            .\.claude\scripts\ralph-single-session.ps1
          }
```

## Further Reading

- [Architecture](../core/architecture.md) - System architecture overview
- [Configuration](../core/configuration.md) - Agent settings and PRD format
- [Agent Documentation](../../agents/) - Per-agent behavior docs
