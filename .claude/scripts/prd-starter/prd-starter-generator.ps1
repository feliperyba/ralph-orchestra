<#
.SYNOPSIS
    Cross-platform PRD Starter generator wrapper for Windows

.DESCRIPTION
    This script wraps the Python-based PRD Starter generator for Windows
    systems. It automatically detects Python and invokes the generator
    with all passed arguments.

.PARAMETER Action
    Action to perform: generate, validate, or reset

.PARAMETER StateFile
    Path to prd-starter-state.json file

.PARAMETER ConfigFile
    Path to agent configuration JSON file

.PARAMETER ProjectRoot
    Project root directory (default: current directory)

.PARAMETER Verbose
    Enable verbose output

.EXAMPLE
    .\prd-starter-generator.ps1 -Action generate -StateFile .\.claude\session\prd-starter-state.json

.EXAMPLE
    .\prd-starter-generator.ps1 -Action validate -ConfigFile .\.claude\session\agent-config.json

.EXAMPLE
    .\prd-starter-generator.ps1 -Action reset
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet("generate", "validate", "reset")]
    [string]$Action = "generate",

    [string]$StateFile,

    [string]$ConfigFile,

    [string]$ProjectRoot = ".",

    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Find Python executable
$python = $null
$pythonCommands = @("python", "python3", "py")

foreach ($cmd in $pythonCommands) {
    try {
        $python = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($python) {
            break
        }
    } catch {
        continue
    }
}

if (-not $python) {
    Write-Error "Python not found. Please install Python 3.8+ to use PRD Starter."
    Write-Host "Download from: https://www.python.org/downloads/" -ForegroundColor Cyan
    exit 1
}

# Verify Python version
try {
    $versionOutput = & $python --version 2>&1
    if ($versionOutput -match 'Python (\d+)\.(\d+)') {
        $major = [int]$matches[1]
        $minor = [int]$matches[2]
        if ($major -lt 3 -or ($major -eq 3 -and $minor -lt 8)) {
            Write-Error "Python 3.8+ required. Found: $versionOutput"
            exit 1
        }
    }
} catch {
    Write-Warning "Could not verify Python version"
}

# Check for required packages
$requirementsFile = Join-Path $PSScriptRoot "prd-starter-requirements.txt"
if (Test-Path $requirementsFile) {
    try {
        $missing = @()

        # Check if jinja2 is available
        & $python -c "import jinja2" 2>$null
        if ($LASTEXITCODE -ne 0) { $missing += "jinja2" }

        # Check if pyyaml is available
        & $python -c "import yaml" 2>$null
        if ($LASTEXITCODE -ne 0) { $missing += "pyyaml" }

        # Check if jsonschema is available
        & $python -c "import jsonschema" 2>$null
        if ($LASTEXITCODE -ne 0) { $missing += "jsonschema" }

        if ($missing.Count -gt 0) {
            Write-Host "Installing missing Python packages: $($missing -join ', ')" -ForegroundColor Yellow
            & $python -m pip install -r $requirementsFile
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to install required packages. Please run manually:"
                Write-Host "  pip install -r $requirementsFile" -ForegroundColor Cyan
                exit 1
            }
        }
    } catch {
        Write-Warning "Could not check for required packages"
    }
}

# Build arguments
$argsList = @()

if ($Action) {
    $argsList += "--action"
    $argsList += $Action
}

if ($StateFile) {
    $argsList += "--state"
    $argsList += $StateFile
}

if ($ConfigFile) {
    $argsList += "--config"
    $argsList += $ConfigFile
}

if ($ProjectRoot) {
    $argsList += "--project-root"
    $argsList += $ProjectRoot
}

if ($Verbose) {
    $argsList += "--verbose"
}

# Invoke Python script (now in prd-starter subdirectory)
$scriptPath = Join-Path $PSScriptRoot "prd-starter\prd-starter-generator.py"

if (-not (Test-Path $scriptPath)) {
    Write-Error "Generator script not found: $scriptPath"
    exit 1
}

try {
    & $python $scriptPath @argsList
    exit $LASTEXITCODE
} catch {
    Write-Error "Error running generator: $_"
    exit 1
}
