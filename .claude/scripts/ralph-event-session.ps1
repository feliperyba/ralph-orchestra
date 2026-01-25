# Ralph Event-Driven Session Launcher
# Starts the event-driven multi-agent orchestration system
#
# Usage:
#   .\.claude\scripts\ralph-event-session.ps1
#   .\.claude\scripts\ralph-event-session.ps1 -NoDashboard
#   .\.claude\scripts\ralph-event-session.ps1 -Debug
#   .\.claude\scripts\ralph-event-session.ps1 -MaxIterations 100

param(
    [switch]$NoDashboard = $false,
    [switch]$Debug = $false,
    [string]$ProjectRoot = "",
    [int]$MaxIterations = 0  # 0 = use config default from ralph-config.ps1
)

$ErrorActionPreference = "Stop"

# Determine project root
if (-not $ProjectRoot) {
    $ProjectRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
}

Set-Location $ProjectRoot

# Paths
$sessionDir = Join-Path $ProjectRoot ".claude\session"
$messagesDir = Join-Path $sessionDir "messages"
$logsDir = Join-Path $sessionDir "logs"
$scriptsDir = Join-Path $ProjectRoot ".claude\scripts"

# Create directories
$directories = @($sessionDir, $messagesDir, $logsDir)
$directories += @("pm", "developer", "qa", "gamedesigner", "techartist", "watchdog") | ForEach-Object { Join-Path $messagesDir $_ }

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# Clear old session data
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  RALPH - Event-Driven Multi-Agent" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project: $ProjectRoot"
Write-Host "Session: $sessionDir"
Write-Host ""

# ============================================================================
# STARTUP CLEANUP - Remove stale messages from previous sessions
# ============================================================================

function Invoke-StartupCleanup {
    <#
    .SYNOPSIS
    Cleans up stale messages and orphaned files from previous sessions.

    .DESCRIPTION
    - Removes message files older than 1 hour
    - Removes orphaned .tmp files
    - Clears dead letter queue
    #>
    $maxAgeMinutes = 60  # Messages older than 1 hour are considered stale

    Write-Host "Running startup cleanup..." -ForegroundColor Cyan

    # Clean old messages from each inbox
    $totalCleaned = 0
    foreach ($agent in @("pm", "developer", "qa", "gamedesigner", "techartist", "watchdog")) {
        $inbox = Join-Path $messagesDir $agent
        if (Test-Path $inbox) {
            $now = [DateTime]::UtcNow
            $oldMessages = Get-ChildItem -Path $inbox -Filter "msg-*.json" -ErrorAction SilentlyContinue |
                Where-Object { ($now - $_.LastWriteTimeUtc).TotalMinutes -gt $maxAgeMinutes }

            if ($oldMessages.Count -gt 0) {
                $oldMessages | Remove-Item -Force -ErrorAction SilentlyContinue
                $totalCleaned += $oldMessages.Count
                Write-Host "  Cleaned $($oldMessages.Count) old message(s) from $agent inbox" -ForegroundColor DarkGray
            }
        }
    }

    # Clean orphaned .tmp files from all inboxes
    $tmpFiles = Get-ChildItem -Path $messagesDir -Recurse -Filter "*.json.tmp" -ErrorAction SilentlyContinue
    if ($tmpFiles.Count -gt 0) {
        $tmpFiles | Remove-Item -Force -ErrorAction SilentlyContinue
        Write-Host "  Cleaned $($tmpFiles.Count) orphaned .tmp file(s)" -ForegroundColor DarkGray
        $totalCleaned += $tmpFiles.Count
    }

    # Clear dead letter queue
    $deadLetterDir = Join-Path $messagesDir "deadletter"
    if (Test-Path $deadLetterDir) {
        try {
            $dlqCount = @(Get-ChildItem -Path $deadLetterDir -File -ErrorAction SilentlyContinue).Count
            if ($dlqCount -gt 0) {
                Remove-Item -Path $deadLetterDir -Recurse -Force -ErrorAction Stop
                New-Item -ItemType Directory -Path $deadLetterDir -Force | Out-Null
                Write-Host "  Cleared $dlqCount message(s) from dead letter queue" -ForegroundColor DarkGray
            }
        } catch {
            Write-Host "  Failed to clear dead letter queue: $_" -ForegroundColor Yellow
        }
    }

    if ($totalCleaned -gt 0) {
        Write-Host "Startup cleanup complete: $totalCleaned item(s) removed" -ForegroundColor Green
    } else {
        Write-Host "Startup cleanup: No stale items found" -ForegroundColor DarkGray
    }
    Write-Host ""
}

# Run startup cleanup automatically (safe - only removes stale messages)
Invoke-StartupCleanup

# Ask about cleaning old session
$cleanSession = $false  # Default: DON'T clean - only clean if user explicitly says "y"
if (Test-Path (Join-Path $ProjectRoot "prd.json.session")) {
    Write-Host "Existing session found." -ForegroundColor Yellow
    $response = Read-Host "Clear old session data? (y/n, default: n)"
    if ($response -eq "y") {
        $cleanSession = $true
    }
}

if ($cleanSession) {
    Write-Host "Cleaning session data..." -ForegroundColor Yellow

    # Clear message queues
    Get-ChildItem -Path $messagesDir -Recurse -Filter "*.json" -ErrorAction SilentlyContinue | Remove-Item -Force

    # Clear logs
    Get-ChildItem -Path $logsDir -Filter "*.log" -ErrorAction SilentlyContinue | Remove-Item -Force

    # Clear legacy state files (no longer used - state is in prd.json.session)
    @(
        "coordinator-state.json",
        "current-task.json",
        "handoff-log.json",
        "pending-handoff.json",
        "handoff-signal.json",
        "session-complete.flag"
    ) | ForEach-Object {
        $file = Join-Path $sessionDir $_
        if (Test-Path $file) { Remove-Item $file -Force }
    }

    # Clear prd.json.session if exists
    $prdSessionFile = Join-Path $ProjectRoot "prd.json.session"
    if (Test-Path $prdSessionFile) { Remove-Item $prdSessionFile -Force }

    Write-Host "Session cleaned." -ForegroundColor Green
}

# Check for PRD
$prdFile = Join-Path $ProjectRoot "prd.json"
if (-not (Test-Path $prdFile)) {
    Write-Host ""
    Write-Host "WARNING: No prd.json found!" -ForegroundColor Yellow
    Write-Host "Create a PRD file with your tasks before starting." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Example prd.json structure:"
    Write-Host @"
{
  "name": "Project Name",
  "version": "1.0.0",
  "features": [
    {
      "id": "feat-001",
      "title": "Feature title",
      "description": "Feature description",
      "priority": 1,
      "status": "pending",
      "passes": false
    }
  ]
}
"@ -ForegroundColor DarkGray
    Write-Host ""
    $continue = Read-Host "Continue anyway? (y/n)"
    if ($continue -ne "y") {
        exit 0
    }
}

Write-Host ""
Write-Host "Starting event-driven watchdog..." -ForegroundColor Cyan
Write-Host ""
Write-Host "ARCHITECTURE:" -ForegroundColor Yellow
Write-Host "  - All 3 agents run in parallel"
Write-Host "  - Communication via message queue"
Write-Host "  - PM handles all priority decisions"
Write-Host "  - Developer can use git worktrees"
Write-Host "  - No polling - event-driven"
Write-Host ""

# Show max iterations setting
if ($MaxIterations -gt 0) {
    Write-Host "Max Iterations: $MaxIterations (override)" -ForegroundColor Yellow
} else {
    . "$PSScriptRoot\ralph-config.ps1"
    $config = Get-RalphConfig
    Write-Host "Max Iterations: $($config.MaxIterations) (default)" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Press Ctrl+C in watchdog window to stop all agents." -ForegroundColor DarkGray
Write-Host ""

# Build watchdog arguments
$watchdogArgs = @()
if ($NoDashboard) { $watchdogArgs += "-NoDashboard" }
if ($Debug) { $watchdogArgs += "-Debug" }
if ($MaxIterations -gt 0) { $watchdogArgs += "-MaxIterations", $MaxIterations }
$watchdogArgs += "-ProjectRoot", "`"$ProjectRoot`""

$watchdogScript = Join-Path $scriptsDir "watchdog-event.ps1"

# Start watchdog
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $watchdogScript @watchdogArgs

Write-Host ""
Write-Host "Session ended." -ForegroundColor Cyan
