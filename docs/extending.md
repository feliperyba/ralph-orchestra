# Extending Ralph Orchestra

This guide covers how to extend Ralph Orchestra with custom agents, skills, CLI providers, and routing.

## CLI Provider System

Ralph Orchestra supports multiple AI CLIs through a provider abstraction. Each provider implements a common interface that handles CLI-specific invocation patterns.

### Provider Architecture

```
.claude/providers/
├── CliProvider.psm1            # Module with base class + helpers
├── ClaudeProvider.ps1          # Claude CLI implementation
├── OpenCodeProvider.ps1        # OpenCode CLI implementation
└── ProviderFactory.ps1         # Factory + registration
```

**Important**: Providers use PowerShell modules (`.psm1`) with `using module` for proper class inheritance. This avoids TypeNotFound parse errors that occur with dot-sourced scripts.

### Provider Interface

All providers inherit from the `CliProvider` base class:

```powershell
class CliProvider {
    [string] $Name
    [string] $Executable
    [string[]] $DefaultArgs
    [bool] $SupportsMessages
    
    # Required methods
    [bool] TestAvailable()
    [string[]] BuildAgentCommand($SlashCommand, $MessagePayload, $ProjectRoot, $AgentName, $Options)
    [string[]] GetMcpConfigArgs($AgentName, $ProjectRoot)
    
    # Optional methods
    [hashtable] GetCapabilities()
    [string] GetDisplayName()
    [void] InitializeSession($ProjectRoot)
}
```

### Provider Differences

| Aspect | Claude Provider | OpenCode Provider |
|--------|-----------------|-------------------|
| **Executable** | `claude` | `opencode` |
| **Agent Selection** | `--agent` in slash command | `--agent ralph-developer` flag |
| **Message Delivery** | `--message '{json}'` CLI arg | `-m`/`--command` CLI arg (primary), file-based fallback |
| **MCP Config** | `--mcp-config` CLI arg | Auto-loaded from `opencode.json` |
| **Skills** | `.claude/skills/` | `.claude/skills/` (native support) |

### Adding a New CLI Provider

#### Step 1: Create the Provider Class

Create `.claude/providers/MyProvider.ps1`:

```powershell
# IMPORTANT: Use 'using module' for proper class inheritance
using module .\CliProvider.psm1

class MyProvider : CliProvider {
    MyProvider() : base() {
        $this.Name = "myprovider"
        $this.Executable = "myprovider-cli"
        $this.DefaultArgs = @("--non-interactive")
        $this.SupportsMessages = $true  # or $false if file-based
    }
    
    MyProvider([hashtable]$Config) : base($Config) {
        $this.Name = "myprovider"
        if (-not $this.Executable) { $this.Executable = "myprovider-cli" }
    }
    
    [bool] TestAvailable() {
        return Test-ProviderAvailable -Executable $this.Executable
    }
    
    [string[]] BuildAgentCommand(
        [string]$SlashCommand,
        [string]$MessagePayload,
        [string]$ProjectRoot,
        [string]$AgentName,
        [hashtable]$Options
    ) {
        $args = @()
        $args += $this.DefaultArgs
        
        # Build command based on how your CLI accepts input
        if ($this.SupportsMessages -and $MessagePayload) {
            $args += "--message"
            $args += $MessagePayload
        }
        
        $args += $SlashCommand
        return $args
    }
    
    [string[]] GetMcpConfigArgs([string]$AgentName, [string]$ProjectRoot) {
        # Return MCP config args if your CLI supports them
        return @()
    }
    
    [hashtable] GetCapabilities() {
        return @{
            SupportsMessages = $this.SupportsMessages
            ServerMode = "standalone"
            UsesFileBasedMessages = -not $this.SupportsMessages
        }
    }
    
    [string] GetDisplayName() {
        return "My Provider CLI"
    }
}

function New-MyProvider {
    param([hashtable]$Config = @{})
    return [MyProvider]::new($Config)
}
```

#### Step 2: Register the Provider

Edit `.claude/providers/ProviderFactory.ps1`:

```powershell
. "$PSScriptRoot\MyProvider.ps1"

$Script:ProviderRegistry = @{
    "claude" = "New-ClaudeProvider"
    "opencode" = "New-OpenCodeProvider"
    "myprovider" = "New-MyProvider"  # Add this line
}
```

#### Step 3: Add Configuration

Update `cli-provider.json`:

```json
{
  "provider": "myprovider",
  "providers": {
    "myprovider": {
      "executable": "myprovider-cli",
      "defaultArgs": ["--non-interactive"],
      "supportsMessages": true
    }
  }
}
```

### Provider Selection Priority

1. **Command Line**: `ralph-event-session.ps1 -Provider opencode`
2. **Environment Variable**: `$env:RALPH_CLI_PROVIDER = "opencode"`
3. **Config File**: `cli-provider.json` → `"provider": "opencode"`
4. **Default**: `claude`

### Using Providers

```powershell
# Get provider instance
$provider = Get-CliProvider -ProviderName "opencode"

# Check availability
if ($provider.TestAvailable()) {
    # Build command for an agent
    $args = $provider.BuildAgentCommand(
        "/ralph-worker-event --agent developer",
        $messagePayload,
        $projectRoot,
        "developer",
        @{}
    )
    
    # Execute: $provider.Executable $args
}
```

---

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

## Adding Custom Agents

### Step 1: Create Agent Directory Structure

```
agents/myagent/
├── AGENT.md              # Core behavior instructions
├── SKILLS.md             # Skills index
├── skills/               # Modular skills
│   └── myagent-skill.md
├── checklists/
│   └── review.md
└── references/
    └── patterns.md
```

### Step 2: Create AGENT.md

```markdown
# YOU ARE THE MY AGENT

## When to Use This Agent
- Task category contains "mydomain"
- PM assigns tasks with agent=myagent

## Your Workflow
1. Read task requirements
2. Perform work
3. Run feedback loops
4. Commit with [ralph] [myagent] prefix
5. Send status_update to watchdog
```

### Step 3: Update ralph-config.ps1

```powershell
$Script:AgentConfig = @{
    # ... existing agents ...
    "myagent" = @{
        Type = "worker"
        Command = "/ralph-worker-event --agent myagent"
        DisplayName = "My Agent"
        Color = "White"
    }
}
```

### Step 4: Update Watchdog Scripts

In `watchdog-event.ps1`, add to the switch statement:

```powershell
$slashCommand = switch ($AgentName) {
    "pm" { "/ralph-coordinator-event" }
    "developer" { "/ralph-worker-event --agent developer" }
    "qa" { "/ralph-worker-event --agent qa" }
    "techartist" { "/ralph-worker-event --agent techartist" }
    "gamedesigner" { "/ralph-worker-event --agent gamedesigner" }
    "myagent" { "/ralph-worker-event --agent myagent" }  # Add this
}
```

### Step 5: For OpenCode - Add Agent Configuration

In `opencode.json`:

```json
{
  "agent": {
    "ralph-myagent": {
      "description": "My custom agent",
      "mode": "primary",
      "prompt": "Load skill 'shared-core' then skill 'myagent-workflow'. You are My Agent in Ralph Orchestra."
    }
  }
}
```

In `OpenCodeProvider.ps1`, add to the AgentMap:

```powershell
hidden [hashtable] $AgentMap = @{
    # ... existing mappings ...
    "myagent" = "ralph-myagent"
}
```

---

## CI/CD Integration

You can integrate Ralph into your CI/CD pipeline with provider selection:

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
      provider:
        description: 'CLI Provider'
        default: 'claude'
        type: choice
        options: [claude, opencode]

jobs:
  ralph:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup CLI
        run: |
          if ("${{ inputs.provider }}" -eq "claude") {
            npm install -g @anthropic-ai/claude-cli
          } else {
            # Install opencode
            npm install -g opencode
          }

      - name: Run Ralph
        env:
          RALPH_CLI_PROVIDER: ${{ inputs.provider }}
          RALPH_MAX_ITERATIONS: 50
        run: |
          if ("${{ inputs.mode }}" -eq "event") {
            .\.claude\scripts\ralph-event-session.ps1 -NoDashboard
          } else {
            .\.claude\scripts\ralph-single-session.ps1 -NoDashboard
          }
```

## Further Reading

- [Architecture](./architecture.md) - System architecture overview
- [Configuration](./configuration.md) - Agent settings and PRD format
- [Agent Documentation](../agents/) - Per-agent behavior docs
