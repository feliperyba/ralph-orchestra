# Extending Ralph Orchestra

This guide covers how to extend Ralph Orchestra with custom agents, skills, and routing.

## Agent Configuration

All agents are defined in `./.claude/scripts/ralph-config.ps1`:

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
  --agent: "developer" or "qa" or "gamedesigner"
---
```

**Invocation:**
```bash
/ralph-worker-event --agent developer   # Runs as Developer (event-driven)
/ralph-worker-single --agent developer  # Runs as Developer (sequential)
/ralph-worker-event --agent qa          # Runs as QA (event-driven)
/ralph-worker-single --agent gamedesigner  # Runs as Game Designer
```

**Inside the skill**, the agent checks `$arguments.agent` to determine:
- Which skills directory to load (`agents/developer/skills/` vs `agents/qa/skills/`)
- What behavior to follow (coding vs validation)
- What state files to update

## Worker vs Coordinator Pattern

| Aspect | Coordinator (PM) | Workers (Dev/QA/GameDesigner) |
|--------|-------------------|-------------------------------|
| **Type** | `Type = "coordinator"` | `Type = "worker"` |
| **Instances** | Single instance | Multiple can run in parallel |
| **Command** | No `--agent` argument | Requires `--agent` argument |
| **State File** | Owns `coordinator-state.json` | Polls for tasks assigned to them |

## Adding Custom Agents

### Step 1: Create Agent Directory Structure

For example, to add a Tech Artist agent (already included):

```
agents/techartist/
├── AGENT.md              # Core behavior instructions
├── SKILLS.md             # Skills index
├── skills/               # Modular skills
│   ├── r3f-fundamentals.md
│   ├── r3f-materials.md
│   ├── shader-sdf.md
│   ├── postfx-effects.md
│   ├── particles-gpu.md
│   ├── asset-workflow.md
│   ├── shader-development.md
│   └── visual-polish.md
├── checklists/
│   ├── asset-quality.md
│   ├── shader-review.md
│   └── visual-consistency.md
└── references/
    ├── material-presets.md
    └── shader-patterns.md
```

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

Add your new agent to the `AgentConfig` hashtable (already done for techartist):

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

**For Sequential Mode** (`./.claude/scripts/watchdog-single.ps1`):

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

Modify `./.claude/skills/ralph-worker.md` to include your new agent:

```markdown
## Determine Your Agent Type

Check the `--agent` argument:

- **"developer"**: Implement features and run feedback loops
- **"techartist"**: Create visual assets, shaders, and effects
- **"qa"**: Validate implementations with tests and browser checks
- **"gamedesigner"**: Create GDDs and answer design questions

## Tech Artist Agent Path

**IF `--agent == "techartist"`**:

Look for tasks where:
- `currentTask.assignedAgent == "techartist"`
- `currentTask.status` is "assigned" or "needs_fixes"

**When you find work**:
1. Update your status to "working"
2. Read task specs from `current-task.json`
3. Read GDD for artistic references
4. Create assets/shaders using R3F patterns
5. Test in browser via Playwright
6. Run feedback loops (type-check, lint, build)
7. Commit work with [ralph] [techartist] prefix
8. Update task status to "ready_for_qa"
9. Wait for the next message or handoff
```

### Step 6: Create Agent-Specific Settings (Optional)

Create `./.claude/settings.techartist.json` (already included):

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

## Skill Routing

The `./.claude/skills/ralph-router.md` skill routes tasks to appropriate domain skills based on:

- **Agent type** - PM, Developer, Tech Artist, QA, Game Designer
- **Task category** - architectural, functional, visual, integration, polish
- **Task content** - Keywords in title/description

### Adding Custom Routes

Edit `./.claude/skills/ralph-router.md`:

```markdown
## Routing Table

| Signal Pattern | Target Skill |
|----------------|--------------|
| agent=developer | agents/developer/ |
| agent=techartist | agents/techartist/ |
| task contains "ui" | skills/ui-patterns.md |
| task contains "shader" | skills/shader-creation.md |
```

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

- [Architecture](./architecture.md) - System architecture overview
- [Configuration](./configuration.md) - Agent settings and PRD format
- [Agent Documentation](../agents/) - Per-agent behavior docs
