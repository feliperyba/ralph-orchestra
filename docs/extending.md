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

```
agents/designer/
├── AGENT.md              # Core behavior instructions
├── SKILLS.md             # Skills index
├── skills/               # Modular skills
│   ├── ui-patterns.md
│   ├── accessibility.md
│   └── design-systems.md
├── checklists/
│   └── design-review.md
└── references/
    └── component-library.md
```

### Step 2: Create AGENT.md

```markdown
# YOU ARE THE DESIGNER AGENT

# Your job: CREATE and REVIEW UI/UX designs

## When to Use This Agent

- Task category contains "design", "ui", "ux", "accessibility"
- PM assigns tasks with agent=designer
- Design review is needed before implementation

## Your Workflow

1. Read design requirements from current-task.json
2. Create/update UI components following design system
3. Ensure accessibility standards (WCAG 2.1 AA)
4. Document design decisions
```

### Step 3: Update ralph-config.ps1

Add your new agent to the `AgentConfig` hashtable:

```powershell
$Script:AgentConfig = @{
    # ... existing agents ...
    "designer" = @{
        Type = "worker"
        Command = "/ralph-worker-event --agent designer"
        DisplayName = "Designer"
        Color = "Blue"
    }
}
```

### Step 4: Update Watchdog Scripts

**For Sequential Mode** (`.claude/scripts/watchdog-single.ps1`):

```powershell
# Add to valid agents array (around line 102)
$validAgents = @("pm", "developer", "qa", "designer")

# Add to switch statement (around line 293)
$slashCommand = switch ($AgentName) {
    "pm" { "/ralph-coordinator-single" }
    "developer" { "/ralph-worker-single --agent developer" }
    "qa" { "/ralph-worker-single --agent qa" }
    "designer" { "/ralph-worker-single --agent designer" }
}
```

### Step 5: Update ralph-worker Skill

Modify `.claude/skills/ralph-worker.md` to include your new agent:

```markdown
## Determine Your Agent Type

Check the `--agent` argument:

- **"developer"**: Implement features and run feedback loops
- **"qa"**: Validate implementations with tests and browser checks
- **"designer"**: Create and review UI/UX designs

## Designer Agent Path

**IF `--agent == "designer"`**:

Look for tasks where:
- `currentTask.assignedAgent == "designer"`
- `currentTask.status` is "assigned" or "needs_revision"

**When you find work**:
1. Update your status to "working"
2. Read task specs from `current-task.json`
3. Create/update designs following design system
4. Ensure accessibility (WCAG 2.1 AA)
5. Document design decisions
6. Update task status to "ready_for_review"
7. HANDOFF to qa or developer as appropriate
```

### Step 6: Create Agent-Specific Settings (Optional)

Create `.claude/settings.designer.json`:

```json
{
  "mcpServers": {
    "filesystem": { ... },
    "figma": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-figma"]
    }
  }
}
```

### Step 7: Test Your New Agent

```bash
# Manual testing (event-driven)
/ralph-worker-event --agent designer

# Sequential mode
.\.claude\scripts\ralph-single-session.ps1 -InitialAgent designer

# Add test task to prd.json
{
  "id": "design-001",
  "title": "Design login page",
  "agent": "designer",
  "status": "pending",
  "passes": false
}
```

## Skill Routing

The `.claude/skills/ralph-router.md` skill routes tasks to appropriate domain skills based on:

- **Agent type** - PM, Developer, QA, Game Designer
- **Task category** - architectural, functional, integration, polish
- **Task content** - Keywords in title/description

### Adding Custom Routes

Edit `.claude/skills/ralph-router.md`:

```markdown
## Routing Table

| Signal Pattern | Target Skill |
|----------------|--------------|
| agent=designer | agents/designer/ |
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
