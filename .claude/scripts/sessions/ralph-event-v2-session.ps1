# Ralph Event Session V2 Launcher
# Uses the new Actor Model with Event Sourcing architecture
#
# This is the new launcher that uses:
# - watchdog-event-v2.ps1 (new supervisor-based watchdog)
# - eventlog.ps1 (event sourcing)
# - event-bus.ps1 (bidirectional pipes)
# - supervisor.ps1 (actor supervision)
# - message-protocol.ps1 (simplified messages)
# - agent-runtime.ps1 (agent runtime library)

param(
    [int]$MaxIterations = 200,
    [switch]$NoDashboard = $false,
    [switch]$Debug = $false,
    [string]$ProjectRoot = ""
)

$ErrorActionPreference = "Stop"

# Banner
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         RALPH ORCHESTRV2 - EVENT-DRIVEN MODE                      ║" -ForegroundColor Cyan
Write-Host "║    Actor Model + Event Sourcing + CQRS Architecture                ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Determine project root
if (-not $ProjectRoot) {
    $ProjectRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
}

Write-Host "Project Root: $ProjectRoot" -ForegroundColor DarkGray
Write-Host "Max Iterations: $MaxIterations" -ForegroundColor DarkGray
Write-Host ""

# Check for PRD
$prdPath = Join-Path $ProjectRoot "prd.json"
if (-not (Test-Path $prdPath)) {
    Write-Error "PRD not found at $prdPath"
    Write-Host "Create a prd.json file in the project root before starting Ralph." -ForegroundColor Yellow
    exit 1
}

Write-Host "PRD found: $prdPath" -ForegroundColor Green
Write-Host ""

# Source the V2 watchdog
. "$PSScriptRoot\..\watchdog\watchdog-event-v2.ps1"

# Start the watchdog
try {
    Start-WatchdogV2 `
        -MaxIterations $MaxIterations `
        -NoDashboard:$NoDashboard `
        -Debug:$Debug `
        -ProjectRoot $ProjectRoot
}
catch {
    Write-Error "Watchdog failed: $_"
    Write-Host ""
    Write-Host "For troubleshooting, check the watchdog log at:" -ForegroundColor Yellow
    Write-Host "  .claude/session/logs/watchdog.log" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Ralph session completed." -ForegroundColor Green
Write-Host ""
