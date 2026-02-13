# CliProvider Module - Base classes and helpers for CLI providers
# This module provides the CliProvider base class and utility functions
# Usage: using module .\CliProvider.psm1

# ============================================================================
# CLI PROVIDER BASE CLASS
# ============================================================================

class CliProvider {

    [string] $Name = "base"
    [string] $Executable = ""
    [string[]] $DefaultArgs = @()
    [bool] $SupportsMessages = $true
    [string] $ServerMode = "standalone"

    CliProvider() {}

    CliProvider([hashtable]$Config) {
        if ($Config.Name) { $this.Name = $Config.Name }
        if ($Config.Executable) { $this.Executable = $Config.Executable }
        if ($Config.DefaultArgs) { $this.DefaultArgs = $Config.DefaultArgs }
        if ($Config.SupportsMessages -ne $null) { $this.SupportsMessages = $Config.SupportsMessages }
        if ($Config.ServerMode) { $this.ServerMode = $Config.ServerMode }
    }

    [bool] TestAvailable() {
        throw [System.NotImplementedException]::new("TestAvailable must be overridden")
    }

    [string[]] BuildAgentCommand(
        [string]$SlashCommand,
        [string]$MessagePayload,
        [string]$ProjectRoot,
        [string]$AgentName,
        [hashtable]$Options
    ) {
        throw [System.NotImplementedException]::new("BuildAgentCommand must be overridden")
    }

    [string[]] GetMcpConfigArgs([string]$AgentName, [string]$ProjectRoot) {
        return @()
    }

    [string] GetMcpConfigPath([string]$AgentName, [string]$ProjectRoot) {
        return $null
    }

    [void] InitializeSession([string]$ProjectRoot) {}

    [void] CleanupSession([string]$ProjectRoot) {}

    [hashtable] GetCapabilities() {
        return @{
            SupportsMessages = $this.SupportsMessages
            ServerMode = $this.ServerMode
            UsesFileBasedMessages = $false
        }
    }

    [string] GetDisplayName() {
        return $this.Name
    }
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Test-ProviderAvailable {
    param([string]$Executable)
    try {
        $null = Get-Command $Executable -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Get-ProviderConfigPath {
    param([string]$ProjectRoot = (Get-Location).Path)

    $localConfig = Join-Path $ProjectRoot "cli-provider.json"
    if (Test-Path $localConfig) { return $localConfig }

    $globalConfig = Join-Path $env:USERPROFILE ".ralph\cli-provider.json"
    if (Test-Path $globalConfig) { return $globalConfig }

    return $null
}

function Get-ProviderFromEnv {
    $envProvider = [Environment]::GetEnvironmentVariable("RALPH_CLI_PROVIDER")
    if (-not [string]::IsNullOrWhiteSpace($envProvider)) {
        return $envProvider.ToLower().Trim()
    }
    return $null
}

# Export members for use by importing scripts
Export-ModuleMember -Function 'Test-ProviderAvailable', 'Get-ProviderConfigPath', 'Get-ProviderFromEnv'
