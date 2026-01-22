# Ralph Config Generator
# Generates individual agent settings files from the consolidated ralph-config.json
# Run this script after modifying ralph-config.json to regenerate all settings

param(
    [string]$ConfigPath = (Join-Path (Split-Path $PSScriptRoot -Parent) "ralph-config.json"),
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"

function Write-ConfigLog {
    param([string]$Message, [ConsoleColor]$Color = "White")
    Write-Host "[Ralph-Config] $Message" -ForegroundColor $Color
}

function Get-AgentSettingsPath {
    param([string]$AgentName)
    Join-Path $PSScriptRoot "settings.$AgentName.json"
}

function New-AgentSettingsFile {
    <#
    .SYNOPSIS
    Generate an individual agent settings file from the master config.
    #>
    param(
        [string]$AgentName,
        [PSCustomObject]$Config,
        [PSCustomObject]$AgentsConfig
    )

    $agentConfig = $AgentsConfig.$AgentName
    if (-not $agentConfig) {
        Write-ConfigLog "ERROR: Agent '$AgentName' not found in config" -Color Red
        return $false
    }

    $serverNames = $agentConfig.mcpServers
    if (-not $serverNames) {
        Write-ConfigLog "WARNING: No MCP servers defined for '$AgentName'" -Color Yellow
        $serverNames = @()
    }

    # Build agent-specific mcpServers object
    $agentMcpServers = @{}
    foreach ($serverName in $serverNames) {
        if ($Config.mcpServers.$serverName) {
            $agentMcpServers[$serverName] = $Config.mcpServers.$serverName
        } else {
            Write-ConfigLog "WARNING: MCP server '$serverName' not found in config for '$AgentName'" -Color Yellow
        }
    }

    # Create the settings object
    $settings = @{
        mcpServers = $agentMcpServers
    }

    # Write to file
    $settingsPath = Get-AgentSettingsPath -AgentName $AgentName
    $settings | ConvertTo-Json -Depth 10 | Out-File -FilePath $settingsPath -Encoding UTF8

    if ($Verbose) {
        Write-ConfigLog "Generated $settingsPath with $($serverNames.Count) servers" -Color Cyan
    }

    return $true
}

function Set-SessionSettings {
    <#
    .SYNOPSIS
    Apply session settings from ralph-config.json to ralph-config.ps1 variables.
    #>
    param(
        [PSCustomObject]$Config
    )

    $sessionConfigPath = Join-Path $PSScriptRoot "ralph-config.ps1"
    if (-not (Test-Path $sessionConfigPath)) {
        Write-ConfigLog "WARNING: ralph-config.ps1 not found, skipping session settings" -Color Yellow
        return $false
    }

    # Read the existing ralph-config.ps1 to find where to insert settings
    $configContent = Get-Content $sessionConfigPath -Raw

    # Update the config hash with new session values
    # Note: This is a simplified approach - in production you might want to use proper parsing
    $sessionSettings = $Config.session
    $perfSettings = $Config.performance

    $configContent = $configContent -replace '\$Script:RalphConfig\.MaxIterations\s*=\s*\d+',
        "`$Script:RalphConfig.MaxIterations = $($sessionSettings.maxIterations)"
    $configContent = $configContent -replace '\$Script:RalphConfig\.HeartbeatInterval\s*=\s*\d+',
        "`$Script:RalphConfig.HeartbeatInterval = $($sessionSettings.heartbeatInterval)"
    $configContent = $configContent -replace '\$Script:RalphConfig\.ContextResetThreshold\s*=\s*\d+',
        "`$Script:RalphConfig.ContextResetThreshold = $($sessionSettings.contextResetThreshold)"

    # Save the updated config
    $configContent | Out-File -FilePath $sessionConfigPath -Encoding UTF8 -Force

    if ($Verbose) {
        Write-ConfigLog "Updated session settings in ralph-config.ps1" -Color Green
    }

    return $true
}

# ============================================================================
# MAIN
# ============================================================================

Write-ConfigLog "Ralph Orchestra Configuration Generator" -Color Cyan
Write-ConfigLog "=====================================" -Color Cyan

# Validate config path exists
if (-not (Test-Path $ConfigPath)) {
    Write-ConfigLog "ERROR: Config file not found: $ConfigPath" -Color Red
    exit 1
}

# Load master config
try {
    $configContent = Get-Content $ConfigPath -Raw | ConvertFrom-Json
} catch {
    Write-ConfigLog "ERROR: Failed to parse $ConfigPath : $_" -Color Red
    exit 1
}

Write-ConfigLog "Loaded config version: $($configContent.version)" -Color Green

# Generate settings for each agent
$agents = $configContent.agents
$successCount = 0

foreach ($agentName in $agents.PSObject.Properties.Name) {
    if (New-AgentSettingsFile -AgentName $agentName -Config $configContent -AgentsConfig $agents) {
        $successCount++
    }
}

Write-ConfigLog "Generated $successCount agent settings files" -Color Green

# Apply session settings
$null = Set-SessionSettings -Config $configContent
if ($?) {
    Write-ConfigLog "Session settings updated" -Color Green
}

Write-ConfigLog "" -Color White
Write-ConfigLog "Configuration generation complete!" -Color Green
