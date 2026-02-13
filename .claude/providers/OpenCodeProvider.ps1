# OpenCode CLI Provider Implementation
# Source: . "$PSScriptRoot\OpenCodeProvider.ps1"

using module .\CliProvider.psm1

class OpenCodeProvider : CliProvider {
    <#
    .SYNOPSIS
    Provider implementation for OpenCode CLI (opencode.ai).

    .NOTES
    OpenCode CLI invocation:
    opencode run --agent ralph-developer -m "prompt or JSON"

    Agent mapping:
    - pm -> ralph-pm
    - developer -> ralph-developer
    - qa -> ralph-qa
    - techartist -> ralph-techartist
    - gamedesigner -> ralph-gamedesigner

    Message delivery priority:
    1. -m/--command argument (primary) - sends prompt/JSON directly to agent
    2. File-based fallback - reads from ./.claude/session/pending-messages-{agent}.json
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
        $this.SupportsMessages = $true  # Now supports --message argument
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
        $cliArgs += "run"

        if (-not [string]::IsNullOrWhiteSpace($this.ServerUrl)) {
            $cliArgs += "--attach"
            $cliArgs += $this.ServerUrl
        }

        $openCodeAgent = $this.MapAgentName($AgentName)
        $cliArgs += "--agent"
        $cliArgs += $openCodeAgent

        # Primary: Use -m/--command argument if available (like Claude CLI)
        if (-not [string]::IsNullOrWhiteSpace($MessagePayload)) {
            $cliArgs += "-m"
            $cliArgs += $MessagePayload
        } else {
            # Fallback: File-based message delivery
            $cliArgs += "-m"
            $cliArgs += "Start processing your pending messages from ./.claude/session/pending-messages-$AgentName.json"
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
            UsesFileBasedMessages = $true
            UsesNativeAgents = $true
            CanAttachToServer = $true
            ReadsClaudeSkills = $true
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
