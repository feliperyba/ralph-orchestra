# Ralph Watchdog - Event-Driven Multi-Agent Mode
# Uses Actor Model with Event Sourcing architecture
#
# Architecture:
# - ActorSupervisor class for agent lifecycle management
# - Event log (eventlog.ps1) for state persistence
# - Event bus (event-bus.ps1) for pipe-based messaging
# - Simplified message protocol (12 core types)
# - Bidirectional named pipes for messaging
# - True event-driven operation (no polling)

param(
    [int]$HealthCheckIntervalMs = 100,   # Supervision loop interval
    [int]$GracefulShutdownSeconds = 30,
    [switch]$NoDashboard = $false,
    [switch]$Debug = $false,
    [string]$ProjectRoot = "",
    [int]$MaxIterations = 0  # 0 = use config default
)

$ErrorActionPreference = "Stop"

# Determine project root
if (-not $ProjectRoot) {
    $ProjectRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
}

# Source configuration
. "$PSScriptRoot\..\core\ralph-config.ps1"

# Source new modules (Event Sourcing + Actor Model)
. "$PSScriptRoot\..\v2-architecture\eventlog.ps1"
. "$PSScriptRoot\..\v2-architecture\event-bus.ps1"
. "$PSScriptRoot\..\v2-architecture\supervisor.ps1"
. "$PSScriptRoot\..\v2-architecture\message-protocol.ps1"

# Source watchdog common utilities (existing)
$commonModule = Join-Path $PSScriptRoot "Watchdog-Common.ps1"
if (Test-Path $commonModule) {
    . $commonModule
}

$config = Get-RalphConfig
$paths = Get-RalphPaths -ProjectRoot $ProjectRoot

# Directories
$Script:LogDir = Join-Path $paths.SessionDir "logs"
$Script:SessionDir = $paths.SessionDir

# Create logs directory
if (-not (Test-Path $Script:LogDir)) {
    New-Item -ItemType Directory -Path $Script:LogDir -Force | Out-Null
}

# ============================================================================
# LOGGING
# ============================================================================

$Script:ActivityLog = [System.Collections.Generic.Queue[string]]::new()
$Script:MaxActivityLogSize = 5
$Script:LastLogRotationCheck = [DateTime]::MinValue

function Write-WatchdogLog {
    <#
    .SYNOPSIS
    Write a message to the watchdog log and optionally display.
    #>
    param(
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::White
    )

    $timestamp = Get-Date -Format "HH:mm:ss"
    $logEntry = "[$timestamp] $Message"

    # Add to activity log buffer
    $Script:ActivityLog.Enqueue($logEntry)

    # Keep only last N entries
    while ($Script:ActivityLog.Count -gt $Script:MaxActivityLogSize) {
        $null = $Script:ActivityLog.Dequeue()
    }

    # Check log rotation
    $logFile = Join-Path $Script:LogDir "watchdog.log"
    if (([DateTime]::UtcNow - $Script:LastLogRotationCheck).TotalSeconds -gt 60) {
        $Script:LastLogRotationCheck = [DateTime]::UtcNow
        Invoke-LogRotation -LogFile $logFile
    }

    # Write to log file
    "$timestamp $Message" | Out-File -FilePath $logFile -Append -Encoding utf8

    # Only write to console if dashboard is disabled
    if ($NoDashboard) {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Invoke-LogRotation {
    param([string]$LogFile)

    if (-not (Test-Path $LogFile)) { return }

    try {
        $maxSizeMB = if ($config.Watchdog.MaxLogSizeMB) { $config.Watchdog.MaxLogSizeMB } else { 50 }
        $maxSizeBytes = $maxSizeMB * 1MB

        $fileInfo = Get-Item $LogFile -ErrorAction SilentlyContinue
        if (-not $fileInfo -or $fileInfo.Length -lt $maxSizeBytes) { return }

        # Rotate: .log -> .log.1, .log.1 -> .log.2, .log.2 -> .log.3, delete .log.3
        for ($i = 2; $i -ge 0; $i--) {
            $src = if ($i -eq 0) { $LogFile } else { "$LogFile.$i" }
            $dst = "$LogFile.$($i + 1)"
            if (Test-Path $src) {
                if ($i -eq 2) {
                    Remove-Item $dst -Force -ErrorAction SilentlyContinue
                }
                Move-Item -Path $src -Destination $dst -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        # Log rotation failure is non-critical
    }
}

# ============================================================================
# SUPERVISOR (Actor Model)
# ============================================================================

$Script:Supervisor = $null

function Initialize-Supervisor {
    <#
    .SYNOPSIS
    Initialize the ActorSupervisor with the session directory.
    #>
    $Script:Supervisor = [ActorSupervisor]::new($paths.SessionDir, "main")
    Write-WatchdogLog "Supervisor initialized" -Color Green
}

# ============================================================================
# MESSAGE PROCESSING
# ============================================================================

function Process-MessageFromAgent {
    <#
    .SYNOPSIS
    Process a message received from an agent.

    .PARAMETER Message
    The message object received from an agent.

    .PARAMETER FromAgent
    The agent that sent this message.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object]$Message,

        [Parameter(Mandatory=$true)]
        [string]$FromAgent
    )

    # Convert legacy message type if needed
    $msgType = $Message.type
    if ($msgType -notin $Script:MessageTypes) {
        $msgType = Convert-LegacyMessageType -LegacyType $msgType
    }

    # Log the message
    Write-WatchdogLog "[$FromAgent] -> $($Message.to): $msgType" -Color Cyan

    # Route message based on type
    switch ($msgType) {
        "AgentStatus" {
            # Update agent status in supervisor
            Write-Host "[WATCHDOG] Agent status from $FromAgent`: $($Message.payload.status)" -ForegroundColor DarkGray
        }

        "WorkAssign" {
            # PM assigning work to worker
            if ($FromAgent -eq "pm") {
                $targetAgent = $Message.to
                if ($Script:Supervisor.Actors.ContainsKey($targetAgent)) {
                    Send-MessageToAgent -AgentName $targetAgent -Message $Message
                } else {
                    # Start the target agent if not running
                    Write-WatchdogLog "Starting $targetAgent for work assignment" -Color Yellow
                    $Script:Supervisor.StartActor($targetAgent)
                    # Small delay to let agent initialize
                    Start-Sleep -Milliseconds 500
                    Send-MessageToAgent -AgentName $targetAgent -Message $Message
                }
            }
        }

        "WorkComplete" {
            # Worker completed work - notify PM
            Send-MessageToAgent -AgentName "pm" -Message $Message
        }

        "ProblemReport" {
            # Bug or quality issue - route to PM
            Send-MessageToAgent -AgentName "pm" -Message $Message
        }

        "Query" {
            # Question from one agent to another
            $targetAgent = $Message.to
            Send-MessageToAgent -AgentName $targetAgent -Message $Message
        }

        "Response" {
            # Answer to a question
            $targetAgent = $Message.to
            Send-MessageToAgent -AgentName $targetAgent -Message $Message
        }

        "ValidationResult" {
            # QA validation result - send to PM
            Send-MessageToAgent -AgentName "pm" -Message $Message
        }

        "System" {
            # System message (shutdown, error)
            if ($Message.payload.systemEvent -eq "shutdown") {
                Write-WatchdogLog "Shutdown request from $FromAgent" -Color Yellow
            }
        }

        default {
            Write-Warning "[WATCHDOG] Unknown message type: $msgType from $FromAgent"
        }
    }
}

# ============================================================================
# DASHBOARD
# ============================================================================

function Show-WatchdogDashboard {
    <#
    .SYNOPSIS
    Display the watchdog dashboard with agent status.
    #>
    param(
        [int]$Iteration,
        [int]$MaxIterations
    )

    Clear-Host

    # Header
    Write-Host "=== RALPH WATCHDOG V2 ===" -ForegroundColor Cyan
    Write-Host "Iteration: $Iteration / $MaxIterations" -ForegroundColor Cyan
    Write-Host "Uptime: $(([DateTime]::UtcNow - $Script:WatchdogStartTime).ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
    Write-Host ""

    # Supervisor status
    if ($Script:Supervisor) {
        Write-Host "--- SUPERVISOR ---" -ForegroundColor Green
        Write-Host "Total Restarts: $($Script:Supervisor.TotalRestarts)" -ForegroundColor White
        Write-Host ""

        # Agent status
        Write-Host "--- AGENTS ---" -ForegroundColor Green
        $status = $Script:Supervisor.GetStatus()
        foreach ($agentName in $status.Keys) {
            $agent = $status[$agentName]

            $statusColor = if ($agent.hasExited) { "Red" } else { "Green" }
            $workColor = "White"

            Write-Host "[$agentName]" -ForegroundColor $statusColor -NoNewline
            Write-Host " PID: $($agent.pid)" -ForegroundColor DarkGray -NoNewline
            Write-Host " Restarts: $($agent.restartCount)" -ForegroundColor DarkGray
        }
    }

    Write-Host ""

    # Activity log
    Write-Host "--- ACTIVITY ---" -ForegroundColor Green
    foreach ($logEntry in $Script:ActivityLog) {
        Write-Host $logEntry
    }

    Write-Host ""
}

# ============================================================================
# MAIN LOOP
# ============================================================================

function Start-WatchdogV2 {
    <#
    .SYNOPSIS
    Start the watchdog V2 main loop.
    #>

    # Initialize
    Write-Host "=== RALPH WATCHDOG V2 ===" -ForegroundColor Cyan
    Write-Host "Using Actor Model with Event Sourcing architecture" -ForegroundColor Cyan
    Write-Host ""

    # Initialize supervisor
    Initialize-Supervisor

    # Start PM agent first (coordinator)
    Write-Host "Starting PM agent..." -ForegroundColor Cyan
    $Script:Supervisor.StartActor("pm")

    # Main parameters
    $iteration = 0
    $Script:WatchdogStartTime = [DateTime]::UtcNow
    $Script:MaxIterationsLimit = if ($MaxIterations -gt 0) { $MaxIterations } else { $config.MaxIterations }
    $Script:SessionComplete = $false

    # Session loop
    try {
        while (-not $Script:SessionComplete -and $iteration -lt $Script:MaxIterationsLimit) {
            $iteration++

            # 1. Supervise (check for crashed agents and restart)
            $Script:Supervisor.Supervise()

            # 2. Read messages from all agent pipes (non-blocking)
            $messages = Receive-AllPendingMessages

            foreach ($msgEnvelope in $messages) {
                Process-MessageFromAgent -Message $msgEnvelope.Message -FromAgent $msgEnvelope.AgentName
            }

            # 3. Deliver undelivered messages (retry failed sends)
            Retry-AllUndelivered

            # 4. Update agent status from event log (materialized view)
            Export-AgentStatus

            # 5. Check session completion
            # TODO: Add logic to check if all PRD items are complete

            # 6. Display dashboard
            if (-not $NoDashboard) {
                Show-WatchdogDashboard -Iteration $iteration -MaxIterations $Script:MaxIterationsLimit
                Start-Sleep -Milliseconds 100
            } else {
                Start-Sleep -Milliseconds $HealthCheckIntervalMs
            }
        }

        Write-WatchdogLog "Watchdog session completed" -Color Green
    }
    finally {
        # Shutdown
        Write-Host ""
        Write-Host "Shutting down watchdog..." -ForegroundColor Yellow

        if ($Script:Supervisor) {
            # Send shutdown to all agents
            $shutdownMsg = New-SystemMessage -From "watchdog" -To "*" -SystemEventType "shutdown" -Message "Watchdog shutting down"
            Broadcast-Message -Message $shutdownMsg

            # Wait a bit for graceful shutdown
            Start-Sleep -Seconds 2

            # Stop all agents
            $Script:Supervisor.StopAll()

            # Close all pipes
            Close-AllPipes
        }

        Write-Host "Watchdog shutdown complete" -ForegroundColor Green
    }
}

# ============================================================================
# ENTRY POINT
# ============================================================================

# Auto-start if this script is executed directly
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
    Start-WatchdogV2
}
