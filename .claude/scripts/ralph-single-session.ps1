# Ralph Single-Agent Session Launcher
# Launches the single-agent orchestration mode where only one agent runs at a time
# Usage: .\.claude\scripts\ralph-single-session.ps1 [-InitialAgent pm|developer|qa]

param(
    [string]$InitialAgent = "pm",
    [int]$GracefulShutdownSeconds = 30,
    [int]$MaxRestarts = 3,
    [switch]$NoDashboard = $false,
    [switch]$Debug = $false
)

$ErrorActionPreference = "Stop"

# Determine project root
$ProjectRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName

Write-Host ""
Write-Host "=== Ralph Single-Agent Session Launcher ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project Root: $ProjectRoot"
Write-Host "Initial Agent: $InitialAgent"
Write-Host "Graceful Shutdown: ${GracefulShutdownSeconds}s"
Write-Host "Max Restarts: $MaxRestarts"
Write-Host "Dashboard: $(if ($NoDashboard) { 'DISABLED' } else { 'ENABLED' })"
Write-Host ""

# Validate initial agent
if ($InitialAgent -notin @("pm", "developer", "qa")) {
    Write-Host "ERROR: InitialAgent must be 'pm', 'developer', or 'qa'" -ForegroundColor Red
    exit 1
}

# Source configuration
. "$PSScriptRoot\ralph-config.ps1"
$paths = Get-RalphPaths -ProjectRoot $ProjectRoot

# Ensure session directory exists
if (-not (Test-Path $paths.SessionDir)) {
    New-Item -ItemType Directory -Path $paths.SessionDir -Force | Out-Null
    Write-Host "Created session directory: $($paths.SessionDir)"
}

# Initialize coordinator-state.json if it doesn't exist
$stateFile = Join-Path $paths.SessionDir "coordinator-state.json"
if (-not (Test-Path $stateFile)) {
    $initialState = @{
        sessionId = "ralph-single-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        startedAt = [DateTime]::UtcNow.ToString("o")
        maxIterations = 50
        iteration = 1
        status = "running"
        orchestrationMode = "single-agent"
        currentAgent = $InitialAgent
        currentTask = $null
        stats = @{
            totalTasks = 0
            completed = 0
            failed = 0
        }
    }
    
    $initialState | ConvertTo-Json -Depth 10 | Out-File -FilePath $stateFile -Encoding UTF8
    Write-Host "Initialized coordinator-state.json"
}

# Initialize handoff-log.json if it doesn't exist
$handoffFile = Join-Path $paths.SessionDir "handoff-log.json"
if (-not (Test-Path $handoffFile)) {
    $handoffLog = @{
        sessionId = "ralph-single-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        orchestrationMode = "single-agent"
        handoffs = @()
    }
    
    $handoffLog | ConvertTo-Json -Depth 10 | Out-File -FilePath $handoffFile -Encoding UTF8
    Write-Host "Initialized handoff-log.json"
}

Write-Host ""
Write-Host "Starting single-agent watchdog..." -ForegroundColor Yellow
Write-Host ""

# Build arguments
$watchdogArgs = @(
    "-File", "$PSScriptRoot\watchdog-single.ps1",
    "-ProjectRoot", $ProjectRoot,
    "-InitialAgent", $InitialAgent,
    "-GracefulShutdownSeconds", $GracefulShutdownSeconds,
    "-MaxRestarts", $MaxRestarts
)

if ($NoDashboard) {
    $watchdogArgs += "-NoDashboard"
}

if ($Debug) {
    $watchdogArgs += "-Debug"
}

# Start watchdog in current terminal (not a new window)
& powershell.exe -NoProfile -ExecutionPolicy Bypass @watchdogArgs
