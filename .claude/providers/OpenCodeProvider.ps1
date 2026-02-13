# OpenCode CLI Provider Implementation
# Source: . "$PSScriptRoot\OpenCodeProvider.ps1"

class OpenCodeProvider : CliProvider {
    <#
    .SYNOPSIS
    Provider implementation for OpenCode CLI (opencode.ai).

    .NOTES
    OpenCode has two modes:
    
    1. TUI mode (interactive):
       opencode --agent ralph-pm
       
    2. Run mode (non-interactive):
       opencode run --agent ralph-pm "message"
    
    For Ralph Orchestra, we use TUI mode launched in a new terminal window
    so users can interact with the agent directly.

    Agent mapping:
    - pm -> ralph-pm
    - developer -> ralph-developer
    - qa -> ralph-qa
    - techartist -> ralph-techartist
    - gamedesigner -> ralph-gamedesigner
    #>

    [string] $ServerUrl = $null
    hidden [hashtable] $AgentMap = @{
        "pm" = "ralph-pm"
        "developer" = "ralph-developer"
        "qa" = "ralph-qa"
        "techartist" = "ralph-techartist"
        "gamedesigner" = "ralph-gamedesigner"
    }

    OpenCodeProvider() : base() {
        $this.Name = "opencode"
        $this.Executable = "opencode"
        $this.DefaultArgs = @()
        $this.SupportsMessages = $true
    }

    OpenCodeProvider([hashtable]$Config) : base($Config) {
        $this.Name = "opencode"
        if (-not $this.Executable) { $this.Executable = "opencode" }
        if ($Config.ServerUrl) { $this.ServerUrl = $Config.ServerUrl }
    }

    [bool] TestAvailable() {
        return Test-ProviderAvailable -Executable $this.Executable
    }

    [string] MapAgentName([string]$RalphAgent) {
        if ($this.AgentMap.ContainsKey($RalphAgent)) {
            return $this.AgentMap[$RalphAgent]
        }
        return "ralph-$RalphAgent"
    }

    [string[]] BuildAgentCommand(
        [string]$SlashCommand,
        [string]$MessagePayload,
        [string]$ProjectRoot,
        [string]$AgentName,
        [hashtable]$Options
    ) {
        $cliArgs = @()
        
        # TUI mode with --prompt flag for interactive sessions with pre-filled prompt
        # opencode --agent ralph-pm --prompt "message"
        if (-not [string]::IsNullOrWhiteSpace($this.ServerUrl)) {
            $cliArgs += "--attach"
            $cliArgs += $this.ServerUrl
        }

        $openCodeAgent = $this.MapAgentName($AgentName)
        $cliArgs += "--agent"
        $cliArgs += $openCodeAgent
        
        # Pre-fill the prompt in TUI mode
        if (-not [string]::IsNullOrWhiteSpace($MessagePayload)) {
            $cliArgs += "--prompt"
            $cliArgs += $MessagePayload
        } else {
            # Default startup prompt for Ralph agents
            $cliArgs += "--prompt"
            $cliArgs += "Read pending messages from ./.claude/session/pending-messages-$AgentName.json and process them according to your workflow."
        }

        return $cliArgs
    }
    
    [string[]] GetMcpConfigArgs([string]$AgentName, [string]$ProjectRoot) {
        # OpenCode reads MCP from opencode.json - no CLI args needed
        return @()
    }
    
    [string] GetMcpConfigPath([string]$AgentName, [string]$ProjectRoot) {
        $opencodeConfig = Join-Path $ProjectRoot "opencode.json"
        if (Test-Path $opencodeConfig) { return $opencodeConfig }
        
        $claudeConfig = Join-Path $ProjectRoot ".claude\settings.$AgentName.json"
        if (Test-Path $claudeConfig) { return $claudeConfig }
        
        return $null
    }
    
    [void] InitializeSession([string]$ProjectRoot) {
        $opencodeConfig = Join-Path $ProjectRoot "opencode.json"
        if (-not (Test-Path $opencodeConfig)) {
            Write-Host "[OpenCode] No opencode.json found. Copy opencode.example.json to opencode.json" -ForegroundColor Yellow
        }
    }
    
    [hashtable] GetCapabilities() {
        return @{
            SupportsMessages = $true
            ServerMode = $this.ServerMode
            SupportsMcpConfig = $true
            SupportsSlashCommands = $false
            RequiresPermissions = $false
            UsesFileBasedMessages = $false
            UsesNativeAgents = $true
            CanAttachToServer = $true
            ReadsClaudeSkills = $true
            RequiresNewWindow = $true  # OpenCode TUI needs its own terminal window
        }
    }
    
    [string] GetDisplayName() {
        return "OpenCode CLI"
    }
}

function New-OpenCodeProvider {
    param(
        [hashtable]$Config = @{},
        [string]$ServerUrl = $null
    )
    
    if ($ServerUrl) {
        $Config.ServerUrl = $ServerUrl
    }
    
    return [OpenCodeProvider]::new($Config)
}
