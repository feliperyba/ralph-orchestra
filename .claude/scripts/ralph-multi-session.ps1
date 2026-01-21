# Ralph Multi-Session Launcher (Windows PowerShell)
# Launches the watchdog which spawns and monitors all agents
# Each agent runs in its own visible window with activity monitoring

param(
    [int]$IdleTimeoutSeconds = 120,   # Restart if no output for this long
    [int]$StartupGraceSeconds = 60,   # Grace period before idle checks
    [int]$MaxRestarts = 5,
    [switch]$NoDashboard = $false,
    [switch]$NoAutoRestart = $false,
    [string[]]$Agents = @("pm", "developer", "qa"),
    [int]$MaxIterations = 0  # 0 = use config default from ralph-config.ps1
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Get-Item $scriptDir).Parent.Parent.FullName

# Source configuration for max iterations default
. "$scriptDir\ralph-config.ps1"
$config = Get-RalphConfig
$maxIter = if ($MaxIterations -gt 0) { $MaxIterations } else { $config.MaxIterations }

Write-Host "=== Ralph Multi-Session Launcher ===" -ForegroundColor Cyan
Write-Host "Project Root: $projectRoot"
Write-Host "Agents: $($Agents -join ', ')"
Write-Host "Idle Timeout: ${IdleTimeoutSeconds}s"
Write-Host "Startup Grace: ${StartupGraceSeconds}s"
Write-Host "Max Iterations: $maxIter"
Write-Host "Auto-Restart: $(if (-not $NoAutoRestart) { 'ENABLED' } else { 'DISABLED' })"
Write-Host ""

# Launch watchdog (which spawns and monitors all agents)
$watchdogPath = Join-Path $scriptDir "watchdog.ps1"

if (-not (Test-Path $watchdogPath)) {
    Write-Host "Error: Watchdog script not found: $watchdogPath" -ForegroundColor Red
    exit 1
}

# Build arguments as hashtable for splatting
$watchdogArgs = @{
    IdleTimeoutSeconds = $IdleTimeoutSeconds
    StartupGraceSeconds = $StartupGraceSeconds
    MaxRestarts = $MaxRestarts
    Agents = $Agents
}

if ($NoDashboard) { $watchdogArgs.NoDashboard = $true }
if ($NoAutoRestart) { $watchdogArgs.NoAutoRestart = $true }
if ($MaxIterations -gt 0) { $watchdogArgs.MaxIterations = $MaxIterations }

# Run watchdog directly (it manages everything)
Write-Host "Starting watchdog..." -ForegroundColor Yellow
Write-Host ""

& $watchdogPath @watchdogArgs
