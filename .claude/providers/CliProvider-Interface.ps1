# CliProvider Interface - Abstract Base Class
# This defines the contract for all CLI providers (Claude, OpenCode, etc.)
# Source this file in other scripts: . "$PSScriptRoot\CliProvider-Interface.ps1"

# ============================================================================
# CLI PROVIDER INTERFACE
# ============================================================================

class CliProvider {
    <#
    .SYNOPSIS
    Abstract base class for CLI providers.
    
    .DESCRIPTION
    Defines the contract for CLI providers that Ralph Orchestra can use.
    Each provider (Claude, OpenCode, etc.) must implement this interface.
    
    .NOTES
    PowerShell classes don't support true abstract methods, so we throw
    NotImplementedException for methods that must be overridden.
    #>
    
    [string] $Name = "base"
    [string] $Executable = ""
    [string[]] $DefaultArgs = @()
    [bool] $SupportsMessages = $true
    [string] $ServerMode = "standalone"  # standalone, server, or hybrid
    
    CliProvider() {
        # Default constructor
    }
    
    CliProvider([hashtable]$Config) {
        if ($Config.Name) { $this.Name = $Config.Name }
        if ($Config.Executable) { $this.Executable = $Config.Executable }
        if ($Config.DefaultArgs) { $this.DefaultArgs = $Config.DefaultArgs }
        if ($Config.SupportsMessages -ne $null) { $this.SupportsMessages = $Config.SupportsMessages }
        if ($Config.ServerMode) { $this.ServerMode = $Config.ServerMode }
    }
    
    <#
    .SYNOPSIS
    Test if the CLI executable is available on the system.
    #>
    [bool] TestAvailable() {
        throw [System.NotImplementedException]::new("TestAvailable must be overridden")
    }
    
    <#
    .SYNOPSIS
    Get the full path to the executable.
    #>
    [string] GetExecutablePath() {
        return $this.Executable
    }
    
    <#
    .SYNOPSIS
    Build the command line arguments to invoke an agent.
    
    .PARAMETER SlashCommand
    The slash command to execute (e.g., "/ralph-coordinator-event")
    
    .PARAMETER MessagePayload
    JSON payload of messages to deliver to the agent (optional)
    
    .PARAMETER ProjectRoot
    Path to the project root directory
    
    .PARAMETER AgentName
    Name of the agent being started (pm, developer, qa, etc.)
    
    .PARAMETER Options
    Additional provider-specific options
    
    .RETURNS
    Array of command line arguments (executable not included)
    #>
    [string[]] BuildAgentCommand(
        [string]$SlashCommand,
        [string]$MessagePayload,
        [string]$ProjectRoot,
        [string]$AgentName,
        [hashtable]$Options
    ) {
        throw [System.NotImplementedException]::new("BuildAgentCommand must be overridden")
    }
    
    <#
    .SYNOPSIS
    Build the full command string for logging/debugging.
    #>
    [string] BuildFullCommandString(
        [string]$SlashCommand,
        [string]$MessagePayload,
        [string]$ProjectRoot,
        [string]$AgentName,
        [hashtable]$Options
    ) {
        $args = $this.BuildAgentCommand($SlashCommand, $MessagePayload, $ProjectRoot, $AgentName, $Options)
        return "$($this.Executable) " + ($args -join " ")
    }
    
    <#
    .SYNOPSIS
    Get the path to MCP configuration for a specific agent.
    
    .DESCRIPTION
    Different CLIs have different ways of configuring MCP servers.
    This method returns the appropriate config path for the provider.
    
    .PARAMETER AgentName
    Name of the agent (pm, developer, qa, etc.)
    
    .PARAMETER ProjectRoot
    Path to the project root
    
    .RETURNS
    Full path to the MCP config file, or $null if using default config
    #>
    [string] GetMcpConfigPath([string]$AgentName, [string]$ProjectRoot) {
        return $null
    }
    
    <#
    .SYNOPSIS
    Get MCP configuration arguments for the CLI.
    
    .RETURNS
    String array of MCP-related arguments, or empty array if none
    #>
    [string[]] GetMcpConfigArgs([string]$AgentName, [string]$ProjectRoot) {
        throw [System.NotImplementedException]::new("GetMcpConfigArgs must be overridden")
    }
    
    <#
    .SYNOPSIS
    Initialize the session for this provider.
    
    .DESCRIPTION
    Called once at session start. Can be used to create directories,
    start server processes, or perform other setup.
    #>
    [void] InitializeSession([string]$ProjectRoot) {
        # Default: no-op
    }
    
    <#
    .SYNOPSIS
    Cleanup after session ends.
    #>
    [void] CleanupSession([string]$ProjectRoot) {
        # Default: no-op
    }
    
    <#
    .SYNOPSIS
    Get provider-specific capabilities.
    
    .RETURNS
    Hashtable of capability name -> boolean/value
    #>
    [hashtable] GetCapabilities() {
        return @{
            SupportsMessages = $this.SupportsMessages
            ServerMode = $this.ServerMode
            MaxMessageSize = $null  # null = unlimited
            SupportsAsync = $false
        }
    }
    
    <#
    .SYNOPSIS
    Get the display name for logging.
    #>
    [string] GetDisplayName() {
        return $this.Name
    }
    
    <#
    .SYNOPSIS
    Validate that a message payload is acceptable for this provider.
    #>
    [bool] ValidateMessagePayload([string]$MessagePayload) {
        if ([string]::IsNullOrWhiteSpace($MessagePayload)) {
            return $true  # Empty is fine
        }
        
        try {
            $null = $MessagePayload | ConvertFrom-Json
            return $true
        } catch {
            return $false
        }
    }
    
    <#
    .SYNOPSIS
    Sanitize a string for safe command-line use.
    #>
    [string] SanitizeForCommandLine([string]$Input) {
        if ([string]::IsNullOrWhiteSpace($Input)) { return $Input }
        
        # Remove potentially dangerous characters
        $sanitized = $Input -replace '`', '``'
        $sanitized = $sanitized -replace '"', '`"'
        $sanitized = $sanitized -replace '\$', '`$'
        
        return $sanitized
    }
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Get-ProviderConfigPath {
    <#
    .SYNOPSIS
    Get the path to the CLI provider configuration file.
    #>
    param([string]$ProjectRoot = (Get-Location).Path)
    
    # Check for project-local config first
    $localConfig = Join-Path $ProjectRoot "cli-provider.json"
    if (Test-Path $localConfig) {
        return $localConfig
    }
    
    # Then check global config
    $globalConfig = Join-Path $env:USERPROFILE ".ralph\cli-provider.json"
    if (Test-Path $globalConfig) {
        return $globalConfig
    }
    
    return $null
}

function Get-ProviderFromEnv {
    <#
    .SYNOPSIS
    Get the provider name from environment variable.
    #>
    $envProvider = [Environment]::GetEnvironmentVariable("RALPH_CLI_PROVIDER")
    if (-not [string]::IsNullOrWhiteSpace($envProvider)) {
        return $envProvider.ToLower().Trim()
    }
    return $null
}

function Test-ProviderAvailable {
    <#
    .SYNOPSIS
    Test if a CLI executable is available on the system.
    #>
    param([string]$Executable)
    
    try {
        $null = Get-Command $Executable -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}
