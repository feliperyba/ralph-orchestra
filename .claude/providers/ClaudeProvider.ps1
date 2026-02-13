# Claude CLI Provider Implementation
# Implements the CliProvider interface for Anthropic's Claude CLI
# Source: . "$PSScriptRoot\ClaudeProvider.ps1"

. "$PSScriptRoot\CliProvider-Interface.ps1"

class ClaudeProvider : CliProvider {
    <#
    .SYNOPSIS
    Provider implementation for Anthropic's Claude CLI.
    
    .DESCRIPTION
    Implements the CliProvider interface for the official Claude CLI.
    This is the original CLI that Ralph Orchestra was built around.
    
    .NOTES
    Claude CLI invocation pattern:
    claude [options] --dangerously-skip-permissions "/slash-command --args"
    #>
    
    ClaudeProvider() : base() {
        $this.Name = "claude"
        $this.Executable = "claude"
        $this.DefaultArgs = @("--dangerously-skip-permissions")
        $this.SupportsMessages = $true
        $this.ServerMode = "standalone"
    }
    
    ClaudeProvider([hashtable]$Config) : base($Config) {
        $this.Name = "claude"
        if (-not $this.Executable) { $this.Executable = "claude" }
        if ($this.DefaultArgs.Count -eq 0) { $this.DefaultArgs = @("--dangerously-skip-permissions") }
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
        
        # Add default args (like --dangerously-skip-permissions)
        $args += $this.DefaultArgs
        
        # Build the prompt (slash command + optional message)
        $prompt = $SlashCommand
        
        if (-not [string]::IsNullOrWhiteSpace($MessagePayload)) {
            # Claude CLI accepts --message argument
            # Escape double quotes for Windows CMD compatibility
            $safePayload = $MessagePayload -replace '"', '\"'
            $prompt += " --message '$safePayload'"
        }
        
        # Add the prompt as a single argument
        $args += $prompt
        
        return $args
    }
    
    [string[]] GetMcpConfigArgs([string]$AgentName, [string]$ProjectRoot) {
        $mcpArgs = @()
        
        # Check for agent-specific MCP config
        $agentConfig = Join-Path $ProjectRoot ".claude\settings.$AgentName.json"
        if (Test-Path $agentConfig) {
            $mcpArgs += "--mcp-config"
            $mcpArgs += ".\.claude\settings.$AgentName.json"
            return $mcpArgs
        }
        
        # Check for main ralph MCP config
        $mainConfig = Join-Path $ProjectRoot ".claude\ralph-config.json"
        if (Test-Path $mainConfig) {
            $mcpArgs += "--mcp-config"
            $mcpArgs += ".\.claude\ralph-config.json"
            return $mcpArgs
        }
        
        return $mcpArgs
    }
    
    [string] GetMcpConfigPath([string]$AgentName, [string]$ProjectRoot) {
        $agentConfig = Join-Path $ProjectRoot ".claude\settings.$AgentName.json"
        if (Test-Path $agentConfig) {
            return $agentConfig
        }
        
        $mainConfig = Join-Path $ProjectRoot ".claude\ralph-config.json"
        if (Test-Path $mainConfig) {
            return $mainConfig
        }
        
        return $null
    }
    
    [hashtable] GetCapabilities() {
        return @{
            SupportsMessages = $true
            ServerMode = "standalone"
            MaxMessageSize = $null
            SupportsAsync = $false
            SupportsMcpConfig = $true
            SupportsSlashCommands = $true
            RequiresPermissions = $true  # Claude needs --dangerously-skip-permissions
        }
    }
    
    [string] GetDisplayName() {
        return "Claude CLI"
    }
}

# ============================================================================
# EXPORT FUNCTION FOR FACTORY
# ============================================================================

function New-ClaudeProvider {
    <#
    .SYNOPSIS
    Create a new ClaudeProvider instance.
    #>
    param([hashtable]$Config = @{})
    
    return [ClaudeProvider]::new($Config)
}
