# CLI Provider Factory
# Creates and manages CLI provider instances
# Source: . "$PSScriptRoot\ProviderFactory.ps1"

. "$PSScriptRoot\CliProvider-Interface.ps1"
. "$PSScriptRoot\ClaudeProvider.ps1"
. "$PSScriptRoot\OpenCodeProvider.ps1"

# ============================================================================
# PROVIDER REGISTRY
# ============================================================================

$Script:ProviderRegistry = @{
    "claude" = "New-ClaudeProvider"
    "opencode" = "New-OpenCodeProvider"
}

# ============================================================================
# FACTORY FUNCTIONS
# ============================================================================

function Get-AvailableProviders {
    <#
    .SYNOPSIS
    Get list of available CLI providers.
    
    .RETURNS
    Array of provider names that are registered.
    #>
    return @($Script:ProviderRegistry.Keys)
}

function Get-DefaultProvider {
    <#
    .SYNOPSIS
    Get the default provider name.
    
    .DESCRIPTION
    Returns 'claude' as the default provider for backwards compatibility.
    #>
    return "claude"
}

function Test-ProviderRegistered {
    <#
    .SYNOPSIS
    Check if a provider name is registered.
    #>
    param([string]$ProviderName)
    
    return $Script:ProviderRegistry.ContainsKey($ProviderName.ToLower())
}

function Get-CliProvider {
    <#
    .SYNOPSIS
    Get a CLI provider instance based on configuration.
    
    .DESCRIPTION
    Creates and returns a CLI provider instance. Provider selection order:
    1. Explicit $ProviderName parameter
    2. RALPH_CLI_PROVIDER environment variable
    3. cli-provider.json config file
    4. Default (claude)
    
    .PARAMETER ProviderName
    Explicit provider name to use (claude, opencode)
    
    .PARAMETER ProjectRoot
    Path to project root for config file lookup
    
    .PARAMETER Config
    Optional hashtable with provider-specific configuration
    
    .RETURNS
    CliProvider instance
    
    .EXAMPLE
    $provider = Get-CliProvider -ProviderName "opencode"
    #>
    param(
        [string]$ProviderName = "",
        [string]$ProjectRoot = (Get-Location).Path,
        [hashtable]$Config = @{}
    )
    
    $selectedProvider = $null
    
    # 1. Check explicit parameter
    if (-not [string]::IsNullOrWhiteSpace($ProviderName)) {
        $selectedProvider = $ProviderName.ToLower().Trim()
    }
    
    # 2. Check environment variable
    if ([string]::IsNullOrWhiteSpace($selectedProvider)) {
        $envProvider = Get-ProviderFromEnv
        if (-not [string]::IsNullOrWhiteSpace($envProvider)) {
            $selectedProvider = $envProvider
        }
    }
    
    # 3. Check config file
    if ([string]::IsNullOrWhiteSpace($selectedProvider)) {
        $configPath = Get-ProviderConfigPath -ProjectRoot $ProjectRoot
        if ($configPath) {
            try {
                $configContent = Get-Content $configPath -Raw | ConvertFrom-Json
                if ($configContent.provider) {
                    $selectedProvider = $configContent.provider.ToLower().Trim()
                }
                # Merge file config with passed config
                if ($configContent.providers -and $configContent.providers.$selectedProvider) {
                    $fileConfig = $configContent.providers.$selectedProvider
                    foreach ($key in $fileConfig.PSObject.Properties.Name) {
                        if (-not $Config.ContainsKey($key)) {
                            $Config[$key] = $fileConfig.$key
                        }
                    }
                }
            } catch {
                Write-Warning "Failed to parse cli-provider.json: $_"
            }
        }
    }
    
    # 4. Fall back to default
    if ([string]::IsNullOrWhiteSpace($selectedProvider)) {
        $selectedProvider = Get-DefaultProvider
    }
    
    # Validate provider is registered
    if (-not (Test-ProviderRegistered -ProviderName $selectedProvider)) {
        Write-Warning "Unknown provider '$selectedProvider'. Available: $($Script:ProviderRegistry.Keys -join ', ')"
        $selectedProvider = Get-DefaultProvider
    }
    
    # Create the provider instance
    $factoryFunction = $Script:ProviderRegistry[$selectedProvider]
    $provider = & $factoryFunction -Config $Config
    
    # Validate provider is available
    if (-not $provider.TestAvailable()) {
        Write-Warning "CLI executable '$($provider.Executable)' not found. Please install $selectedProvider CLI."
    }
    
    return $provider
}

function Initialize-ProviderSession {
    <#
    .SYNOPSIS
    Initialize a session for the given provider.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [CliProvider]$Provider,
        
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $Provider.InitializeSession($ProjectRoot)
}

function Register-Provider {
    <#
    .SYNOPSIS
    Register a new provider type.
    
    .DESCRIPTION
    Allows extending Ralph with custom CLI providers.
    
    .PARAMETER Name
    Unique provider name (lowercase, alphanumeric with hyphens)
    
    .PARAMETER FactoryFunction
    Name of the function that creates provider instances
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [string]$FactoryFunction
    )
    
    $normalizedName = $Name.ToLower().Trim()
    $Script:ProviderRegistry[$normalizedName] = $FactoryFunction
    
    Write-Host "Registered CLI provider: $normalizedName" -ForegroundColor Green
}

# ============================================================================
# CONFIGURATION HELPERS
# ============================================================================

function New-CliProviderConfig {
    <#
    .SYNOPSIS
    Create a default cli-provider.json configuration file.
    
    .PARAMETER Path
    Where to create the config file (default: project root)
    
    .PARAMETER Provider
    Default provider to set
    #>
    param(
        [string]$Path = (Join-Path (Get-Location).Path "cli-provider.json"),
        [string]$Provider = "claude"
    )
    
    $config = @{
        "`$schema" = "./.claude/schemas/cli-provider.schema.json"
        provider = $Provider
        fallbackProvider = "claude"
        providers = @{
            claude = @{
                executable = "claude"
                defaultArgs = @("--dangerously-skip-permissions")
                supportsMessages = $true
            }
            opencode = @{
                executable = "opencode"
                defaultArgs = @("run")
                supportsMessages = $true
                serverMode = "standalone"
            }
        }
    }
    
    $config | ConvertTo-Json -Depth 5 | Out-File -FilePath $Path -Encoding utf8
    
    Write-Host "Created cli-provider.json at: $Path" -ForegroundColor Green
    Write-Host "Default provider: $Provider" -ForegroundColor Cyan
}

function Get-ProviderInfo {
    <#
    .SYNOPSIS
    Get information about available providers and current selection.
    #>
    param([string]$ProjectRoot = (Get-Location).Path)
    
    $info = @{
        AvailableProviders = @(Get-AvailableProviders)
        DefaultProvider = Get-DefaultProvider
        EnvProvider = Get-ProviderFromEnv
        ConfigPath = Get-ProviderConfigPath -ProjectRoot $ProjectRoot
    }
    
    # Try to get selected provider
    $provider = Get-CliProvider -ProjectRoot $ProjectRoot
    $info.SelectedProvider = $provider.Name
    $info.ProviderAvailable = $provider.TestAvailable()
    $info.ProviderExecutable = $provider.Executable
    
    return $info
}

function Show-ProviderStatus {
    <#
    .SYNOPSIS
    Display current provider configuration status.
    #>
    param([string]$ProjectRoot = (Get-Location).Path)
    
    $info = Get-ProviderInfo -ProjectRoot $ProjectRoot
    
    Write-Host ""
    Write-Host "=== Ralph CLI Provider Status ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Available Providers: " -NoNewline
    Write-Host ($info.AvailableProviders -join ", ") -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Selection Priority:" -ForegroundColor White
    Write-Host "  1. RALPH_CLI_PROVIDER env: " -NoNewline
    if ($info.EnvProvider) {
        Write-Host $info.EnvProvider -ForegroundColor Green
    } else {
        Write-Host "(not set)" -ForegroundColor DarkGray
    }
    Write-Host "  2. Config file: " -NoNewline
    if ($info.ConfigPath) {
        Write-Host $info.ConfigPath -ForegroundColor Green
    } else {
        Write-Host "(not found)" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "Selected Provider: " -NoNewline
    Write-Host $info.SelectedProvider -ForegroundColor Magenta
    Write-Host "Executable: " -NoNewline
    Write-Host $info.ProviderExecutable -ForegroundColor White
    Write-Host "Available: " -NoNewline
    if ($info.ProviderAvailable) {
        Write-Host "YES" -ForegroundColor Green
    } else {
        Write-Host "NO (not installed)" -ForegroundColor Red
    }
    Write-Host ""
}
