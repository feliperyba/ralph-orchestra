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
# Script is at: .claude/scripts/watchdog/watchdog-event-v2.ps1
# PSScriptRoot = .claude/scripts/watchdog
# Project root is: (script dir) -> .. (scripts/) -> .. (.claude/) -> .. (project root) = 3 levels up
if (-not $ProjectRoot) {
    $ProjectRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
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

        "CLIInvoke" {
            # Broker requesting CLI invocation
            Write-WatchdogLog "CLI invoke request from $FromAgent" -Color Yellow

            $agentName = $Message.payload.agentName
            $messageFile = $Message.payload.messageFile
            $responseFile = $Message.payload.responseFile

            # Spawn CLI process
            $invokeId = $Script:Supervisor.SpawnCLIProcess($agentName, $messageFile, $responseFile)

            if (-not $invokeId) {
                # Send immediate failure response if spawn failed
                $errorMsg = New-CLICompleteMessage -To $FromAgent -AgentName $agentName -Success $false -ExitCode -1 -Error "Failed to spawn CLI process"
                Send-MessageToAgent -AgentName $FromAgent -Message $errorMsg
            }
        }

        "CLIComplete" {
            # CLI completed notification - already handled by supervisor's SuperviseCLIProcesses
            # This is just for logging
            Write-Host "[WATCHDOG] CLI complete: $($Message.payload.agentName) - success: $($Message.payload.success)" -ForegroundColor DarkGray
        }

        default {
            Write-Warning "[WATCHDOG] Unknown message type: $msgType from $FromAgent"
        }
    }
}

# ============================================================================
# DASHBOARD - Row-based rendering for flicker-free updates
# ============================================================================

# Track previous dashboard content for diffing
$Script:DashboardLines = $null
$Script:DashboardColors = $null
$Script:DashboardInitialized = $false

function Show-WatchdogDashboard {
    <#
    .SYNOPSIS
    Display the watchdog dashboard using selective row updates.
    Only updates rows that have changed - no full redraws.
    #>
    param(
        [int]$Iteration,
        [int]$MaxIterations
    )

    $rawUI = $Host.UI.RawUI

    # Calculate uptime
    $uptime = ([DateTime]::UtcNow - $Script:WatchdogStartTime).ToString('hh\:mm\:ss')

    # Build dashboard lines
    $newLines = [System.Collections.Generic.List[string]]::new()
    $newColors = [System.Collections.Generic.List[ConsoleColor]]::new()

    # Header
    $newLines.Add("=== RALPH WATCHDOG V2 ===")
    $newColors.Add([ConsoleColor]::Cyan)
    $newLines.Add("Iteration: $Iteration / $MaxIterations")
    $newColors.Add([ConsoleColor]::Cyan)
    $newLines.Add("Uptime: $uptime")
    $newColors.Add([ConsoleColor]::Cyan)
    $newLines.Add("")
    $newColors.Add([ConsoleColor]::White)

    # Supervisor status
    if ($Script:Supervisor) {
        $newLines.Add("--- SUPERVISOR ---")
        $newColors.Add([ConsoleColor]::Green)
        $newLines.Add("Total Restarts: $($Script:Supervisor.TotalRestarts)")
        $newColors.Add([ConsoleColor]::White)
        $newLines.Add("")
        $newColors.Add([ConsoleColor]::White)

        # Agent status
        $newLines.Add("--- AGENTS ---")
        $newColors.Add([ConsoleColor]::Green)
        $status = $Script:Supervisor.GetStatus()
        foreach ($agentName in $status.Keys) {
            $agent = $status[$agentName]
            $statusColor = if ($agent.hasExited) { [ConsoleColor]::Red } else { [ConsoleColor]::Green }
            $newLines.Add("[$agentName] PID: $($agent.pid)  Restarts: $($agent.restartCount)")
            $newColors.Add($statusColor)
        }
    }

    $newLines.Add("")
    $newColors.Add([ConsoleColor]::White)

    # Activity log (last 5 entries)
    $newLines.Add("--- ACTIVITY ---")
    $newColors.Add([ConsoleColor]::Green)
    $recentActivity = $Script:ActivityLog | Select-Object -Last 5
    foreach ($logEntry in $recentActivity) {
        $newLines.Add($logEntry)
        $newColors.Add([ConsoleColor]::White)
    }

    $newLines.Add("")
    $newColors.Add([ConsoleColor]::White)
    $newLines.Add("Press Ctrl+C to shutdown")
    $newColors.Add([ConsoleColor]::DarkGray)

    # First time initialization
    if (-not $Script:DashboardInitialized) {
        Clear-Host
        $Script:DashboardInitialized = $true
        for ($i = 0; $i -lt $newLines.Count; $i++) {
            Write-Host $newLines[$i] -ForegroundColor $newColors[$i] -NoNewline
            Write-Host ""
        }
        $Script:DashboardLines = [string[]]$newLines
        $Script:DashboardColors = [ConsoleColor[]]$newColors
        return
    }

    # Compare with previous and only update changed rows
    $origPos = $rawUI.CursorPosition
    $maxLines = [Math]::Max($newLines.Count, $Script:DashboardLines.Count)

    for ($i = 0; $i -lt $maxLines; $i++) {
        # Check if this row changed
        $lineChanged = $false
        if ($i -ge $newLines.Count) {
            # Row was removed - need to clear it
            $lineChanged = $true
        } elseif ($i -ge $Script:DashboardLines.Count) {
            # New row - need to write it
            $lineChanged = $true
        } elseif ($newLines[$i] -ne $Script:DashboardLines[$i] -or $newColors[$i] -ne $Script:DashboardColors[$i]) {
            # Content or color changed
            $lineChanged = $true
        }

        if ($lineChanged) {
            # Move cursor to this row
            $rawUI.CursorPosition = @{ X = 0; Y = $i }

            if ($i -lt $newLines.Count) {
                # Write new content
                Write-Host $newLines[$i] -ForegroundColor $newColors[$i] -NoNewline
            }

            # Clear to end of line
            $bufferWidth = $rawUI.BufferSize.Width
            $currentLen = if ($i -lt $newLines.Count) { $newLines[$i].Length } else { 0 }
            if ($currentLen -lt $bufferWidth) {
                Write-Host (" " * ($bufferWidth - $currentLen)) -NoNewline
            }
        }
    }

    # Store current state
    $Script:DashboardLines = [string[]]$newLines
    $Script:DashboardColors = [ConsoleColor[]]$newColors
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

    # Track iterations based on PRD task completion (not supervisor frames)
    $Script:CompletedTaskCount = 0
    $prdPath = Join-Path $ProjectRoot "prd.json"
    if (Test-Path $prdPath) {
        $prd = Get-Content $prdPath | ConvertFrom-Json
        $Script:CompletedTaskCount = ($prd | Where-Object { $_.passes -eq $true }).Count
    }

    # Session loop
    try {
        while (-not $Script:SessionComplete -and $iteration -lt $Script:MaxIterationsLimit) {
            # Check PRD for completed tasks and update iteration count
            $prdPath = Join-Path $ProjectRoot "prd.json"
            if (Test-Path $prdPath) {
                $prd = Get-Content $prdPath | ConvertFrom-Json
                $newCompletedCount = ($prd | Where-Object { $_.passes -eq $true }).Count
                if ($newCompletedCount -gt $Script:CompletedTaskCount) {
                    $tasksJustCompleted = $newCompletedCount - $Script:CompletedTaskCount
                    $iteration += $tasksJustCompleted
                    $Script:CompletedTaskCount = $newCompletedCount
                    Write-WatchdogLog "Iteration advanced: $tasksJustCompleted task(s) completed (total: $iteration / $($Script:MaxIterationsLimit))" -Color Green
                }
            }

            # 1. Supervise (check for crashed agents and restart)
            $Script:Supervisor.Supervise()

            # 1.5. Supervise CLI processes (check for completion/timeout)
            $Script:Supervisor.SuperviseCLIProcesses()

            # 2. Read messages from all agent pipes (non-blocking)
            $messages = Receive-AllPendingMessages

            foreach ($msgEnvelope in $messages) {
                Process-MessageFromAgent -Message $msgEnvelope.Message -FromAgent $msgEnvelope.AgentName
            }

            # 3. Deliver undelivered messages (retry failed sends)
            $null = Retry-AllUndelivered

            # 4. Update agent status from event log (materialized view)
            $null = Export-AgentStatus

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
    # Track child processes spawned by this watchdog
    $Script:WatchdogChildProcesses = [System.Collections.Generic.HashSet[int]]::new()

    # Register the cleanup script for exit signals
    trap {
        Write-Host ""
        Write-Host "[WATCHDOG] Error: $_" -ForegroundColor Red

        # Cleanup: close pipes and kill child processes only
        try {
            if ($Script:Supervisor) {
                $Script:Supervisor.StopAll()
            }
            Close-AllPipes
        } catch {
            # Ignore cleanup errors
        }

        exit 1
    }

    # Set up cleanup action for graceful shutdown
    $cleanupAction = {
        Write-Host ""
        Write-Host "[WATCHDOG] Shutdown triggered..." -ForegroundColor Yellow

        # Close all pipes first
        try {
            Close-AllPipes
        } catch {
            # Ignore cleanup errors
        }

        # Kill only child processes spawned by this watchdog
        try {
            $sessionPid = $PID

            # Read session marker to get parent session PID
            $sessionMarkerFile = Join-Path $paths.SessionDir "session-pid.txt"
            $parentSessionPid = $null
            if (Test-Path $sessionMarkerFile) {
                try {
                    $sessionData = Get-Content $sessionMarkerFile | ConvertFrom-Json
                    $parentSessionPid = $sessionData.SessionPid
                } catch {
                    # Invalid marker file
                }
            }

            # Function to check if a process is in our session tree
            function Test-IsSessionChild {
                param([int]$TargetPid)

                if ($TargetPid -eq $sessionPid) { return $true }  # It's us
                if ($TargetPid -eq $parentSessionPid) { return $true }  # It's our parent

                # Check ancestors
                try {
                    $targetProc = Get-Process -Id $TargetPid -ErrorAction SilentlyContinue
                    if (-not $targetProc) { return $false }

                    $ancestorPid = $targetProc.Parent.Id
                    $maxDepth = 5
                    $depth = 0

                    while ($ancestorPid -and $depth -lt $maxDepth) {
                        if ($ancestorPid -eq $sessionPid -or $ancestorPid -eq $parentSessionPid) {
                            return $true
                        }
                        try {
                            $ancestorProc = Get-Process -Id $ancestorPid -ErrorAction SilentlyContinue
                            if ($ancestorProc) {
                                $ancestorPid = $ancestorProc.Parent.Id
                            } else {
                                break
                            }
                        } catch {
                            break
                        }
                        $depth++
                    }
                } catch {
                    return $false
                }

                return $false
            }

            # Get all Ralph PowerShell processes
            $ralphProcesses = Get-Process -Name "pwsh", "powershell" -ErrorAction SilentlyContinue | Where-Object {
                try {
                    $cmdLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $($_.Id)" -ErrorAction SilentlyContinue).CommandLine
                    $cmdLine -and ($cmdLine.Contains("Start-AgentLoop") -or $cmdLine.Contains("agent-runtime.ps1"))
                } catch {
                    $false
                }
            }

            # Only kill processes that are in our session tree
            $killedCount = 0
            foreach ($proc in $ralphProcesses) {
                if (Test-IsSessionChild -TargetPid $proc.Id) {
                    try {
                        Write-Host "[WATCHDOG] Killing child process (PID: $($proc.Id))" -ForegroundColor DarkGray
                        $proc.Kill()
                        $killedCount++
                    } catch {
                        # Process already exited
                    }
                }
            }

            if ($killedCount -gt 0) {
                Start-Sleep -Milliseconds 200
            }
        } catch {
            # Ignore cleanup errors
        }

        Write-Host "[WATCHDOG] Cleanup complete" -ForegroundColor Green
    }

    # Register cleanup for Ctrl+C and normal exit
    [Console]::TreatControlCAsInput = $false
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action $cleanupAction -ErrorAction SilentlyContinue

    Start-WatchdogV2
}
