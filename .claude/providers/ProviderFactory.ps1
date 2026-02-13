# CLI Provider Factory
# Creates and manages CLI provider instances
# Source: . "$PSScriptRoot\ProviderFactory.ps1"

using module .\CliProvider.psm1
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
    return @($Script:ProviderRegistry.Keys)
}

function Get-DefaultProvider {
    return "claude"
}

function Test-ProviderRegistered {
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
        $selectedProvider = Get-ProviderFromEnv
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
                # Merge file config
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

function Test-ProviderInterface {
    param([object]$Provider)
    
    $requiredMembers = @('Name', 'Executable', 'TestAvailable', 'BuildAgentCommand')
    foreach ($member in $requiredMembers) {
        if (-not ($Provider.PSObject.Properties.Name -contains $member -or 
                  $Provider.PSObject.Methods.Name -contains $member)) {
            return $false
        }
    }
    return $true
}

function Initialize-ProviderSession {
    param(
        [Parameter(Mandatory=$true)]
        [object]$Provider,
        
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    if (-not (Test-ProviderInterface -Provider $Provider)) {
        throw "Invalid provider: missing required interface members"
    }
    
    $Provider.InitializeSession($ProjectRoot)
}

function Register-Provider {
    <#
    .SYNOPSIS
    Register a new provider type.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [string]$FactoryFunction
    )
    
    $Script:ProviderRegistry[$Name.ToLower()] = $FactoryFunction
    Write-Host "Registered CLI provider: $Name" -ForegroundColor Green
}

# ============================================================================
# CONVENIENCE FUNCTIONS
# ============================================================================

function New-CliProviderConfig {
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
                defaultArgs = @()
                supportsMessages = $false
                serverMode = "standalone"
            }
        }
    }
    
    $config | ConvertTo-Json -Depth 5 | Out-File -FilePath $Path -Encoding utf8
    Write-Host "Created cli-provider.json at: $Path" -ForegroundColor Green
}

function Show-ProviderStatus {
    param([string]$ProjectRoot = (Get-Location).Path)
    
    Write-Host ""
    Write-Host "=== Ralph CLI Provider Status ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Available Providers: " -NoNewline
    Write-Host ((Get-AvailableProviders) -join ", ") -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Selection Priority:" -ForegroundColor White
    Write-Host "  1. RALPH_CLI_PROVIDER env: " -NoNewline
    $envProvider = Get-ProviderFromEnv
    if ($envProvider) {
        Write-Host $envProvider -ForegroundColor Green
    } else {
        Write-Host "(not set)" -ForegroundColor DarkGray
    }
    Write-Host "  2. Config file: " -NoNewline
    $configPath = Get-ProviderConfigPath -ProjectRoot $ProjectRoot
    if ($configPath) {
        Write-Host $configPath -ForegroundColor Green
    } else {
        Write-Host "(not found)" -ForegroundColor DarkGray
    }
    Write-Host ""
    
    $provider = Get-CliProvider -ProjectRoot $ProjectRoot
    Write-Host "Selected Provider: " -NoNewline
    Write-Host $provider.Name -ForegroundColor Magenta
    Write-Host "Executable: " -NoNewline
    Write-Host $provider.Executable -ForegroundColor White
    Write-Host "Available: " -NoNewline
    if ($provider.TestAvailable()) {
        Write-Host "YES" -ForegroundColor Green
    } else {
        Write-Host "NO (not installed)" -ForegroundColor Red
    }
    Write-Host ""
}
