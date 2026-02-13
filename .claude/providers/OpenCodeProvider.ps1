# OpenCode CLI Provider Implementation
# Implements the CliProvider interface for OpenCode CLI
# Source: . "$PSScriptRoot\OpenCodeProvider.ps1"

. "$PSScriptRoot\CliProvider-Interface.ps1"

class OpenCodeProvider : CliProvider {
    <#
    .SYNOPSIS
    Provider implementation for OpenCode CLI.
    
    .DESCRIPTION
    Implements the CliProvider interface for OpenCode CLI (opencode.ai).
    OpenCode is an open-source AI coding agent that supports similar
    patterns to Claude CLI but with different command-line syntax.
    
    .NOTES
    OpenCode CLI invocation patterns:
    - Interactive: opencode
    - Non-interactive: opencode run "prompt"
    - With server: opencode run --attach http://localhost:4096 "prompt"
    
    OpenCode natively reads .claude/skills/ and .opencode/skills/
    #>
    
    [string] $ServerUrl = $null
    
    OpenCodeProvider() : base() {
        $this.Name = "opencode"
        $this.Executable = "opencode"
        $this.DefaultArgs = @("run")
        $this.SupportsMessages = $true
        $this.ServerMode = "standalone"
    }
    
    OpenCodeProvider([hashtable]$Config) : base($Config) {
        $this.Name = "opencode"
        if (-not $this.Executable) { $this.Executable = "opencode" }
        if ($this.DefaultArgs.Count -eq 0) { $this.DefaultArgs = @("run") }
        if ($Config.ServerUrl) { $this.ServerUrl = $Config.ServerUrl }
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
        
        # Add "run" subcommand
        $args += "run"
        
        # Add server attachment if configured
        if (-not [string]::IsNullOrWhiteSpace($this.ServerUrl)) {
            $args += "--attach"
            $args += $this.ServerUrl
        }
        
        # Build the prompt
        # OpenCode accepts slash commands directly in the prompt
        $prompt = $SlashCommand
        
        if (-not [string]::IsNullOrWhiteSpace($MessagePayload)) {
            # Escape the JSON payload for command line
            $safePayload = $MessagePayload -replace '"', '\"'
            $prompt += " --message `"$safePayload`""
        }
        
        # Add the prompt
        $args += $prompt
        
        return $args
    }
    
    [string[]] GetMcpConfigArgs([string]$AgentName, [string]$ProjectRoot) {
        # OpenCode reads MCP config from opencode.json's "mcp" section
        # It also reads .claude/settings.*.json for compatibility
        # No CLI args needed - config is auto-loaded
        return @()
    }
    
    [string] GetMcpConfigPath([string]$AgentName, [string]$ProjectRoot) {
        # OpenCode reads from opencode.json primarily
        $opencodeConfig = Join-Path $ProjectRoot "opencode.json"
        if (Test-Path $opencodeConfig) {
            return $opencodeConfig
        }
        
        # Falls back to .claude settings for compatibility
        $claudeConfig = Join-Path $ProjectRoot ".claude\settings.$AgentName.json"
        if (Test-Path $claudeConfig) {
            return $claudeConfig
        }
        
        return $null
    }
    
    [void] InitializeSession([string]$ProjectRoot) {
        # OpenCode reads skills from:
        # - .opencode/skills/*/SKILL.md
        # - .claude/skills/*/SKILL.md (auto-detected)
        # - ~/.config/opencode/skills/*/SKILL.md
        
        # Ensure opencode.json exists with basic structure if not present
        $opencodeConfig = Join-Path $ProjectRoot "opencode.json"
        if (-not (Test-Path $opencodeConfig)) {
            Write-Host "[OpenCode] No opencode.json found - will use .claude/settings for MCP" -ForegroundColor DarkGray
        }
    }
    
    [hashtable] GetCapabilities() {
        return @{
            SupportsMessages = $true
            ServerMode = $this.ServerMode
            MaxMessageSize = $null
            SupportsAsync = $true  # OpenCode supports async via server
            SupportsMcpConfig = $true
            SupportsSlashCommands = $true
            RequiresPermissions = $false  # OpenCode handles permissions differently
            CanAttachToServer = $true
            ReadsClaudeSkills = $true  # Native .claude/skills/ support
        }
    }
    
    [string] GetDisplayName() {
        return "OpenCode CLI"
    }
}

# ============================================================================
# EXPORT FUNCTION FOR FACTORY
# ============================================================================

function New-OpenCodeProvider {
    <#
    .SYNOPSIS
    Create a new OpenCodeProvider instance.
    #>
    param(
        [hashtable]$Config = @{},
        [string]$ServerUrl = $null
    )
    
    if ($ServerUrl) {
        $Config.ServerUrl = $ServerUrl
    }
    
    return [OpenCodeProvider]::new($Config)
}
