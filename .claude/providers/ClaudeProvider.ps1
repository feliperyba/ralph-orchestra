# Claude CLI Provider Implementation
# Source: . "$PSScriptRoot\ClaudeProvider.ps1"

using module .\CliProvider.psm1

class ClaudeProvider : CliProvider {
    <#
    .SYNOPSIS
    Provider implementation for Anthropic's Claude CLI.

    .NOTES
    Claude CLI invocation:
    claude --dangerously-skip-permissions "/slash-command --message '{json}'"
    #>

    ClaudeProvider() : base() {
        $this.Name = "claude"
        $this.Executable = "claude"
        $this.DefaultArgs = @("--dangerously-skip-permissions")
        $this.SupportsMessages = $true
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
        $args += $this.DefaultArgs

        $prompt = $SlashCommand
        if (-not [string]::IsNullOrWhiteSpace($MessagePayload)) {
            $safePayload = $MessagePayload -replace '"', '\"'
            $prompt += " --message '$safePayload'"
        }

        $args += $prompt
        return $args
    }

    [string[]] GetMcpConfigArgs([string]$AgentName, [string]$ProjectRoot) {
        $mcpArgs = @()

        $agentConfig = Join-Path $ProjectRoot ".claude\settings.$AgentName.json"
        if (Test-Path $agentConfig) {
            $mcpArgs += "--mcp-config"
            $mcpArgs += ".\.claude\settings.$AgentName.json"
            return $mcpArgs
        }

        $mainConfig = Join-Path $ProjectRoot ".claude\ralph-config.json"
        if (Test-Path $mainConfig) {
            $mcpArgs += "--mcp-config"
            $mcpArgs += ".\.claude\ralph-config.json"
            return $mcpArgs
        }

        return @()
    }

    [string] GetMcpConfigPath([string]$AgentName, [string]$ProjectRoot) {
        $agentConfig = Join-Path $ProjectRoot ".claude\settings.$AgentName.json"
        if (Test-Path $agentConfig) { return $agentConfig }

        $mainConfig = Join-Path $ProjectRoot ".claude\ralph-config.json"
        if (Test-Path $mainConfig) { return $mainConfig }

        return $null
    }

    [hashtable] GetCapabilities() {
        return @{
            SupportsMessages = $true
            ServerMode = "standalone"
            SupportsMcpConfig = $true
            SupportsSlashCommands = $true
            RequiresPermissions = $true
            UsesFileBasedMessages = $false
        }
    }

    [string] GetDisplayName() {
        return "Claude CLI"
    }
}

function New-ClaudeProvider {
    param([hashtable]$Config = @{})
    return [ClaudeProvider]::new($Config)
}
