# Ralph Watchdog - Event-Driven Multi-Agent Mode
# All agents run in parallel, watchdog routes messages between them
# No polling from agents - watchdog is the message broker
#
# Key Features:
# 1. ALL agents run simultaneously (PM, Developer, QA)
# 2. Agents communicate via message queue, not polling
# 3. Watchdog routes messages to appropriate agent
# 4. PM handles all priority decisions
# 5. Developer can use git worktrees for parallel tasks
# 6. Token-efficient: no polling loops in agents

param(
    [int]$MessageCheckIntervalMs = 500,    # How often to check message queue
    [int]$HealthCheckIntervalMs = 10000,   # How often to check agent health 
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

# Source configuration and message queue
. "$PSScriptRoot\ralph-config.ps1"
. "$PSScriptRoot\message-queue.ps1"
# Message-state-manager is already sourced by message-queue.ps1

# Source watchdog common utilities
. "$PSScriptRoot\Watchdog-Common.ps1"

$config = Get-RalphConfig
$paths = Get-RalphPaths -ProjectRoot $ProjectRoot

# Directories
$Script:LogDir = Join-Path $paths.SessionDir "logs"
$Script:SessionDir = $paths.SessionDir
if (-not (Test-Path $Script:LogDir)) {
    New-Item -ItemType Directory -Path $Script:LogDir -Force | Out-Null
}

# Initialize message queue
Initialize-MessageQueue -SessionDir $paths.SessionDir

# Initialize message state manager for idempotency tracking
Initialize-MessageStateManager -SessionDir $paths.SessionDir

# FIX: Clear stale consolidation mode on fresh watchdog startup
# This prevents getting stuck in consolidation mode from previous sessions
$consolidationFile = Join-Path $paths.SessionDir "consolidation-mode.json"
$persistentStateDir = Join-Path $paths.SessionDir "persistent-state"

# Only clear if this appears to be a fresh watchdog start (no running agents)
$hasRunningAgents = $false
foreach ($agentName in @("pm", "developer", "qa", "gamedesigner", "techartist")) {
    $pidFile = Join-Path $paths.SessionDir "$agentName.pid"
    if (Test-Path $pidFile) {
        try {
            $agentPid = Get-Content $pidFile -ErrorAction SilentlyContinue
            if ($agentPid) {
                $proc = Get-Process -Id $agentPid -ErrorAction SilentlyContinue
                if ($proc -and -not $proc.HasExited) {
                    $hasRunningAgents = $true
                }
            }
        } catch {}
    }
}

# If no running agents, clear stale consolidation state
if (-not $hasRunningAgents) {
    if (Test-Path $consolidationFile) {
        Remove-Item $consolidationFile -Force -ErrorAction SilentlyContinue
        Write-Host "[WATCHDOG] Cleared stale consolidation mode file" -ForegroundColor Yellow
    }
    if (Test-Path $persistentStateDir) {
        Remove-Item $persistentStateDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[WATCHDOG] Cleared stale persistent-state directory" -ForegroundColor Yellow
    }
}

# ============================================================================
# LOGGING
# ============================================================================

# Activity log buffer for dashboard display - use Queue for O(1) operations
$Script:ActivityLog = [System.Collections.Generic.Queue[string]]::new()
$Script:MaxActivityLogSize = 5
$Script:LastLogRotationCheck = [DateTime]::MinValue

function Write-WatchdogLog {
    param(
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    
    # Add to activity log buffer (for dashboard)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    $Script:ActivityLog.Enqueue($logEntry)
    
    # Keep only last N entries - O(1) dequeue
    while ($Script:ActivityLog.Count -gt $Script:MaxActivityLogSize) {
        $null = $Script:ActivityLog.Dequeue()
    }
    
    # Check if log rotation is needed (check once per minute)
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
    <#
    .SYNOPSIS
    Rotate log file if it exceeds MaxLogSizeMB.
    Keeps up to 3 rotated files.
    #>
    param([string]$LogFile)
    
    if (-not (Test-Path $LogFile)) { return }
    
    try {
        $maxSizeMB = $config.MaxLogSizeMB
        if (-not $maxSizeMB) { $maxSizeMB = 50 }
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
# STATE TRACKING
# ============================================================================

$Script:WatchdogStartTime = [DateTime]::UtcNow
$Script:TotalIterations = 0
$Script:TotalMessagesRouted = 0
$Script:SessionComplete = $false
$Script:LastHealthCheck = [DateTime]::MinValue

# Max iterations - use parameter or config default
$Script:MaxIterationsLimit = if ($MaxIterations -gt 0) { $MaxIterations } else { $config.MaxIterations }

# Startup mode: Only PM receives messages until it sends first message
# This prevents workers from spawning with stale messages before PM consolidates
$Script:StartupMode = $true
$Script:StartupModeStartTime = [DateTime]::UtcNow
$Script:StartupModeTimeoutSeconds = 300  # 5 minutes max

# PM startup loop protection - track restart attempts during startup mode
$Script:PMStartupAttempts = 0
$Script:MaxPMStartupAttempts = 3  # After 3 failed attempts, force exit startup mode

# Timeout cooldown tracking - prevents spamming work_blocked messages
$Script:LastTimeoutSent = @{}
$Script:TimeoutCooldownMinutes = 5  # Minimum minutes between timeout messages per agent

# Agent tracking
# ProcessState: stopped, running (actual process state)
# WorkStatus: idle, working, waiting, ready, etc. (from agent status_update messages)
$Script:Agents = @{
    "pm" = @{
        Process = $null
        StartTime = $null
        ProcessState = "stopped"   # Tracks if process is running
        WorkStatus = "idle"        # Tracks agent's reported work status
        RestartCount = 0
        CurrentTask = $null
        CurrentMessage = $null     # Current message being processed
        LastActivity = [DateTime]::MinValue
        LastDeliveryTime = [DateTime]::MinValue  # When messages were last delivered
    }
    "developer" = @{
        Process = $null
        StartTime = $null
        ProcessState = "stopped"
        WorkStatus = "idle"
        RestartCount = 0
        CurrentTask = $null
        CurrentMessage = $null
        LastActivity = [DateTime]::MinValue
        LastDeliveryTime = [DateTime]::MinValue
        Worktrees = @()  # Active worktrees for parallel work
    }
    "qa" = @{
        Process = $null
        StartTime = $null
        ProcessState = "stopped"
        WorkStatus = "idle"
        RestartCount = 0
        CurrentTask = $null
        CurrentMessage = $null
        LastActivity = [DateTime]::MinValue
        LastDeliveryTime = [DateTime]::MinValue
    }
    "gamedesigner" = @{
        Process = $null
        StartTime = $null
        ProcessState = "stopped"
        WorkStatus = "idle"
        RestartCount = 0
        CurrentTask = $null
        CurrentMessage = $null
        LastActivity = [DateTime]::MinValue
        LastDeliveryTime = [DateTime]::MinValue
    }
    "techartist" = @{
        Process = $null
        StartTime = $null
        ProcessState = "stopped"
        WorkStatus = "idle"
        RestartCount = 0
        CurrentTask = $null
        CurrentMessage = $null
        LastActivity = [DateTime]::MinValue
        LastDeliveryTime = [DateTime]::MinValue
    }
}

# Delivery grace period - don't re-deliver messages to an agent within this window
$Script:DeliveryGraceSeconds = 10

# ============================================================================
# AGENT MANAGEMENT
# ============================================================================

function Start-Agent {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("pm", "developer", "qa", "gamedesigner", "techartist")]
        [string]$AgentName,
        
        [array]$PendingMessages = @()  # Messages to deliver to agent on startup
    )
    
    $logFile = Join-Path $Script:LogDir "$AgentName.log"
    
    # Clear old log file
    if (Test-Path $logFile) {
        Remove-Item $logFile -Force
    }
    "" | Out-File -FilePath $logFile -Encoding utf8
    
    # Use event-driven slash commands
    $slashCommand = switch ($AgentName) {
        "pm" { "/ralph-coordinator-event" }
        "developer" { "/ralph-worker-event --agent developer" }
        "qa" { "/ralph-worker-event --agent qa" }
        "gamedesigner" { "/ralph-worker-event --agent gamedesigner" }
        "techartist" { "/ralph-worker-event --agent techartist" }
    }
    
    $windowTitle = "Ralph Event: $AgentName"
    $scriptFile = Join-Path $Script:LogDir "$AgentName-runner.ps1"
    
    # Create inbox path for this agent (individual message files: msg-{agent}-{timestamp}-{seq}.json)
    $inboxPath = Join-Path $paths.SessionDir "messages/$AgentName"

    # Write pending messages to a context file for agent to read on startup
    # Note: Individual message files are written to inboxPath above; this is for context delivery
    $pendingFile = Join-Path $Script:SessionDir "pending-messages-$AgentName.json"
    $pendingFileForScript = $pendingFile  # Same path, used in script generation
    if ($PendingMessages.Count -gt 0) {
        $pendingData = @{
            agent = $AgentName
            messageCount = $PendingMessages.Count
            messages = $PendingMessages
            timestamp = [DateTime]::UtcNow.ToString("o")
        }
        $pendingData | ConvertTo-Json -Depth 10 | Out-File -FilePath $pendingFile -Encoding UTF8
        Write-WatchdogLog "Delivered $($PendingMessages.Count) messages to $AgentName" -Color Magenta
    } else {
        # Clear any old pending file
        if (Test-Path $pendingFile) { Remove-Item $pendingFile -Force }
    }
    
    # Create runner script with sanitized values to prevent command injection
    $safeProjectRoot = Get-SafeScriptString $ProjectRoot
    $safePendingFile = Get-SafeScriptString $pendingFileForScript
    $safeLogFile = Get-SafeScriptString $logFile
    # Note: $slashCommand is from a trusted switch statement, not user input
    
    $scriptContent = @"
`$Host.UI.RawUI.WindowTitle = "$windowTitle"
Set-Location "$safeProjectRoot"

Write-Host "========================================"  -ForegroundColor Cyan
Write-Host "  RALPH EVENT-DRIVEN: $AgentName" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Initialize message queue for this agent process
# Note: After Set-Location above, $PWD is the project root (not $PSScriptRoot which is the runner script location)
Write-Host "Initializing message queue..." -ForegroundColor DarkGray
`$mqScript = Join-Path `$PWD ".claude\scripts\message-queue.ps1"
if (Test-Path `$mqScript) {
    . `$mqScript
    if (Get-Command Initialize-MessageQueue -ErrorAction SilentlyContinue) {
        Initialize-MessageQueue -SessionDir (Join-Path `$PWD ".claude\session")
        Write-Host "Message queue loaded successfully" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Failed to load message queue functions" -ForegroundColor Red
        Write-Host "Script was sourced but Initialize-MessageQueue not found" -ForegroundColor Red
        Write-Host "Script path: `$mqScript" -ForegroundColor Red
        Start-Sleep -Seconds 10
        exit 1
    }
} else {
    Write-Host "ERROR: Message queue script not found at: `$mqScript" -ForegroundColor Red
    Write-Host "Current directory: `$PWD" -ForegroundColor Red
    Start-Sleep -Seconds 10
    exit 1
}

# Verify key functions are available
`$requiredFunctions = @("Get-PendingMessages", "Send-AgentMessage", "Remove-AgentMessage", "Get-GlobalMessageState")
`$missingFunctions = `$requiredFunctions | Where-Object { -not (Get-Command `$_ -ErrorAction SilentlyContinue) }
if (`$missingFunctions) {
    Write-Host "ERROR: Missing message queue functions: (`$missingFunctions -join ', ')" -ForegroundColor Red
    Start-Sleep -Seconds 10
    exit 1
}

Write-Host "Mode: EVENT-DRIVEN MULTI-AGENT"
Write-Host "Working Dir: $safeProjectRoot"
Write-Host ""

# Check for pending messages delivered by watchdog
`$pendingFile = "$safePendingFile"
if (Test-Path `$pendingFile) {
    Write-Host "PENDING MESSAGES AVAILABLE:" -ForegroundColor Yellow
    Get-Content `$pendingFile | Write-Host -ForegroundColor DarkYellow
    Write-Host ""
}

Write-Host "Starting Claude CLI..." -ForegroundColor Yellow
Write-Host ""

# Run claude
`$exitCode = 0
try {
    claude "$slashCommand" --dangerously-skip-permissions
    `$exitCode = `$LASTEXITCODE
} catch {
    Write-Host "ERROR: `$_" -ForegroundColor Red
    `$exitCode = 1
}

Write-Host ""
Write-Host "========================================"  -ForegroundColor Yellow
Write-Host "  Agent session ended (exit code: `$exitCode)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

# Write exit status
`$exitCode | Out-File -FilePath "$safeLogFile.exit" -Encoding utf8

# Keep window open briefly
Start-Sleep -Seconds 5
"@

    $scriptContent | Out-File -FilePath $scriptFile -Encoding utf8 -Force
    
    try {
        $process = Start-Process "powershell.exe" `
            -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptFile `
            -PassThru `
            -WindowStyle Normal
        
        $Script:Agents[$AgentName].Process = $process
        $Script:Agents[$AgentName].StartTime = [DateTime]::UtcNow
        $Script:Agents[$AgentName].ProcessState = "running"
        # If we're delivering messages, assume agent is working; otherwise starting
        $Script:Agents[$AgentName].WorkStatus = if ($PendingMessages.Count -gt 0) { "working" } else { "starting" }
        $Script:Agents[$AgentName].LastActivity = [DateTime]::UtcNow
        
        Write-WatchdogLog "$AgentName started (PID: $($process.Id))" -Color Green
        
        # Send ready message to watchdog
        Send-AgentMessage -From $AgentName -To "watchdog" -Type "agent_ready" -Payload @{
            agent = $AgentName
            startTime = [DateTime]::UtcNow.ToString("o")
        }
        
        return $true
    } catch {
        Write-WatchdogLog "Failed to start $AgentName : $_" -Color Red
        return $false
    }
}

function Stop-Agent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,
        [switch]$Graceful = $false,
        [string]$Reason = "unknown"
    )

    $agent = $Script:Agents[$AgentName]

    # Skip if agent doesn't exist, has no process, is already stopped, or process has exited
    if (-not $agent) { return }
    if (-not $agent.Process) { return }
    if ($agent.ProcessState -eq "stopped") { return }
    if ($agent.Process.HasExited) {
        # Update state to reflect actual status
        $agent.ProcessState = "stopped"
        return
    }

    Write-WatchdogLog "Stopping $AgentName ($Reason)" -Color Yellow

    if ($Graceful) {
        # Send shutdown message
        Send-AgentMessage -From "watchdog" -To $AgentName -Type "shutdown" -Payload @{
            reason = $Reason
        } -Priority "urgent"

        # Wait for graceful shutdown
        $deadline = [DateTime]::UtcNow.AddSeconds($GracefulShutdownSeconds)
        while ([DateTime]::UtcNow -lt $deadline) {
            if ($agent.Process.HasExited) { break }
            Start-Sleep -Milliseconds 500
        }
    }
    
    try {
        if (-not $agent.Process.HasExited) {
            # Kill child processes first
            $parentPid = $agent.Process.Id
            Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | 
                Where-Object { $_.ParentProcessId -eq $parentPid } | 
                ForEach-Object {
                    try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
                }
            
            $agent.Process.Kill()
            $agent.Process.WaitForExit(5000) | Out-Null
        }
    } catch {
        # Log but continue cleanup
        Write-WatchdogLog "Error stopping $AgentName process: $_" -Color Yellow
    } finally {
        # Always dispose the process object to release handles
        if ($agent.Process) {
            try { $agent.Process.Dispose() } catch {}
        }
        # Always update state to ensure clean tracking
        $Script:Agents[$AgentName].Process = $null
        $Script:Agents[$AgentName].ProcessState = "stopped"
        $Script:Agents[$AgentName].WorkStatus = "idle"
        $Script:Agents[$AgentName].CurrentMessage = $null
    }
}

function Restart-Agent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,
        [string]$Reason = "unknown"
    )
    
    $agent = $Script:Agents[$AgentName]
    $agent.RestartCount++
    
    Write-WatchdogLog "Restarting $AgentName (#$($agent.RestartCount), $Reason)" -Color Yellow
    
    Stop-Agent -AgentName $AgentName -Reason $Reason
    Start-Sleep -Seconds 2
    
    return Start-Agent -AgentName $AgentName
}

function Test-AgentHealth {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName
    )
    
    $agent = $Script:Agents[$AgentName]
    
    # Check if process is running
    if (-not $agent.Process -or $agent.Process.HasExited) {
        return "dead"
    }
    
    # Check for stale agent (no activity in a while)
    $staleThreshold = $config.StaleAgentThreshold
    $timeSinceActivity = ([DateTime]::UtcNow - $agent.LastActivity).TotalSeconds
    
    if ($timeSinceActivity -gt $staleThreshold) {
        return "stale"
    }
    
    return "healthy"
}

function Start-AllAgents {
    Write-WatchdogLog "Starting agents in PM-first initialization mode..." -Color Cyan

    # PM-FIRST MODE: Always start PM agent first
    # PM will assess state, clear stale messages, and send activation messages to workers as needed
    # This eliminates wasteful idle agent startup - workers only run when they have work
    Write-WatchdogLog "Starting PM agent to assess session state and activate workers..." -Color Green
    $null = Start-Agent -AgentName "pm"

    # Note: Workers will be started by watchdog when:
    # 1. PM sends task_assign → Developer starts
    # 2. PM sends test_plan_request → QA starts
    # 3. PM sends retrospective_initiate → Developer, Tech Artist, QA, GameDesigner start
    # 4. PM sends playtest_request → GameDesigner starts
}

function Invoke-MainLoop {
    <#
    .SYNOPSIS
    Main watchdog loop for message queue mode.
    Agents run in parallel, watchdog monitors queues and delivers messages.
    #>

    Write-WatchdogLog "Entering main monitoring loop..." -Color Cyan

    while (-not $Script:SessionComplete) {
        # 1. Process watchdog's messages (status updates, etc.)
        Invoke-ProcessWatchdogMessages

        # 2. Deliver pending messages to agents
        Invoke-DeliverPendingMessages

        # 3. Check agent health
        Invoke-HealthCheck

        # 4. Check for retrospective file and start watcher if needed
        $retroFile = Join-Path $Script:SessionDir "retrospective.txt"
        if ((Test-Path $retroFile) -and -not $Script:RetrospectiveWatcher) {
            Start-RetrospectiveWatcher
        }

        # 5. Check retrospective timeout for idle agents
        Test-RetrospectiveTimeout

        # 5.5. Check agent state timeouts (awaiting_* states)
        Test-AgentStateTimeout

        # 5.6. Check startup mode timeout
        if ($Script:StartupMode) {
            $elapsed = ([DateTime]::UtcNow - $Script:StartupModeStartTime).TotalSeconds
            if ($elapsed -gt $Script:StartupModeTimeoutSeconds) {
                Write-WatchdogLog "STARTUP MODE TIMEOUT (${elapsed}s) - forcing exit" -Color Yellow
                Write-WatchdogLog "PM did not send env_ready within timeout - check PM startup sequence" -Color Red
                Exit-StartupMode
            }
        }

        # 6. Check for session completion
        if (Test-SessionComplete) {
            Write-WatchdogLog "Session complete - shutting down agents" -Color Green
            $Script:SessionComplete = $true
            break
        }

        # 7. Update dashboard
        # Sync agent status from prd.json first (source of truth)
        Sync-AgentStatusFromState

        if (-not $NoDashboard) {
            Show-EventDashboard
        }

        # Check for max iterations
        if ($Script:MaxIterationsLimit -gt 0 -and $Script:TotalIterations -ge $Script:MaxIterationsLimit) {
            Write-WatchdogLog "Max iterations reached: $Script:TotalIterations" -Color Yellow
            $Script:SessionComplete = $true
            break
        }

        # Sleep before next iteration (don't busy-wait)
        Start-Sleep -Milliseconds $MessageCheckIntervalMs
    }
}

function Stop-AllAgents {
    param(
        [switch]$Graceful = $false,
        [string]$Reason = "shutdown"
    )

    Write-WatchdogLog "Stopping all agents..." -Color Cyan

    # Stop retrospective watcher if active
    Stop-RetrospectiveWatcher

    foreach ($agentName in @("pm", "developer", "qa", "gamedesigner", "techartist")) {
        Stop-Agent -AgentName $agentName -Graceful:$Graceful -Reason $Reason
    }
}

# ============================================================================
# MESSAGE ROUTING
# ============================================================================

function Invoke-ProcessWatchdogMessages {
    # Process messages sent to watchdog (status updates, etc.)
    $messages = Get-PendingMessages -Agent "watchdog"
    
    foreach ($msg in $messages) {
        switch ($msg.type) {
            "agent_ready" {
                # Only log if not in startup mode (to avoid spamming during PM startup loop)
                if (-not $Script:StartupMode -or $msg.from -ne "pm") {
                    Write-WatchdogLog "Agent ready: $($msg.from)" -Color Green
                } else {
                    # Silent during startup - PM agent_ready is expected and logged in startup attempt count
                }
            }
            "status_update" {
                $agent = $msg.from
                $Script:Agents[$agent].LastActivity = [DateTime]::UtcNow
                $Script:Agents[$agent].WorkStatus = $msg.payload.status  # Update WorkStatus, not ProcessState
                $Script:Agents[$agent].CurrentTask = $msg.payload.currentTask
                
                # Status updates are silent - shown in dashboard
            }
            "work_complete" {
                # Session complete signal
                if ($msg.payload.type -eq "session_complete") {
                    Write-WatchdogLog "Session complete signal received!" -Color Green
                    $Script:SessionComplete = $true
                }
            }
            "error" {
                Write-WatchdogLog "Error from $($msg.from): $($msg.payload.error)" -Color Red
            }
            "context_checkpoint" {
                # Worker hit context limit and sent checkpoint
                $agent = $msg.from
                $checkpoint = $msg.payload

                Write-WatchdogLog "$agent context checkpoint: $($checkpoint.contextPercent)% - step: $($checkpoint.step)" -Color Yellow

                # Save checkpoint to session for agent recovery
                $checkpointFile = Join-Path $Script:SessionDir "context-checkpoint-$agent-$($checkpoint.taskId).json"
                $checkpoint | ConvertTo-Json -Depth 10 | Out-File -FilePath $checkpointFile -Encoding UTF8

                # Log checkpoint details
                $completedCount = if ($checkpoint.completedSteps) { $checkpoint.completedSteps.Count } else { 0 }
                $remainingCount = if ($checkpoint.remainingSteps) { $checkpoint.remainingSteps.Count } else { 0 }
                Write-WatchdogLog "Checkpoint saved: $completedCount completed, $remainingCount remaining" -Color DarkGray

                # Restart the agent with checkpoint context
                if ($Script:Agents[$agent].Process -and -not $Script:Agents[$agent].Process.HasExited) {
                    Stop-Agent -AgentName $agent -Reason "context_checkpoint"
                    Start-Sleep -Seconds 2
                }

                # Start agent with checkpoint - watchdog will deliver checkpoint context
                $null = Start-Agent -AgentName $agent

                Write-WatchdogLog "$agent restarted from context checkpoint" -Color Green
            }
        }

        # STARTUP MODE: Exit startup mode when PM sends env_ready
        # This indicates PM has completed consolidation and is ready for normal operations
        # Exiting on ANY PM message (like status_update) would exit startup mode too early,
        # causing workers to spawn with stale messages before PM consolidates
        if ($Script:StartupMode -and $msg.from -eq "pm" -and $msg.type -eq "env_ready") {
            Exit-StartupMode
            # Reset PM startup counter when env_ready is received (successful startup)
            $Script:PMStartupAttempts = 0
        }

        # Acknowledge message (with state tracking for idempotency)
        $null = Invoke-AcknowledgeMessageSafe -MessageId $msg.id -Agent "watchdog"
    }
}

function Invoke-DeliverPendingMessages {
    <#
    .SYNOPSIS
    Check if agents have pending messages and deliver them by restarting agent with context
    This is the key mechanism - agents don't poll, watchdog delivers messages by restart
    #>

    $counts = Get-MessageCount

    foreach ($agentName in @("pm", "developer", "qa", "gamedesigner", "techartist")) {
        $count = $counts[$agentName]
        if ($count -gt 0) {
            # STARTUP MODE: Skip worker agents during startup - only PM receives messages
            # This prevents workers from spawning with stale messages before PM consolidates
            if ($Script:StartupMode -and $agentName -ne "pm") {
                Write-WatchdogLog "${agentName}: skipping during startup mode (has $count pending message(s))" -Color DarkGray
                continue
            }

            $agent = $Script:Agents[$agentName]
            
            # IMPROVED: Verify actual process state, not just cached object
            # This fixes race condition where process exits but watchdog still has reference
            $processActuallyRunning = $false
            if ($agent.Process) {
                try {
                    # Refresh the process state - check if actually still running
                    if (-not $agent.Process.HasExited) {
                        # Process is actually running - verify by getting the process again
                        $actualProcess = Get-Process -Id $agent.Process.Id -ErrorAction SilentlyContinue
                        if ($actualProcess) {
                            $processActuallyRunning = $true
                            $actualProcess.Dispose()  # Clean up the check process
                        } else {
                            # PID not found - process exited, clean up
                            try { $agent.Process.Dispose() } catch {}
                            $Script:Agents[$agentName].Process = $null
                            $Script:Agents[$agentName].ProcessState = "stopped"
                            $Script:Agents[$agentName].WorkStatus = "idle"
                        }
                    } else {
                        # Process has exited - clean up the reference
                        try { $agent.Process.Dispose() } catch {}
                        $Script:Agents[$agentName].Process = $null
                        $Script:Agents[$agentName].ProcessState = "stopped"
                        $Script:Agents[$agentName].WorkStatus = "idle"
                    }
                } catch {
                    # Process object is invalid or access error - clean up
                    try { $agent.Process.Dispose() } catch {}
                    $Script:Agents[$agentName].Process = $null
                    $Script:Agents[$agentName].ProcessState = "stopped"
                    $Script:Agents[$agentName].WorkStatus = "idle"
                }
            }

            $isWorking = $agent.WorkStatus -in @("working", "starting")

            # Only skip if process is ACTUALLY running AND working
            if ($processActuallyRunning -and $isWorking) {
                continue  # Don't interrupt working/starting agents
            }
            
            # GRACE PERIOD CHECK: Don't re-deliver to an agent that just received messages
            # This prevents restart loops when acknowledgment or status updates are slow
            # IMPORTANT: Only apply grace period if process is ACTUALLY running AND agent is healthy
            # If process has exited OR agent is stale, allow immediate delivery
            $timeSinceLastDelivery = ([DateTime]::UtcNow - $agent.LastDeliveryTime).TotalSeconds
            $agentHealth = Test-AgentHealth -AgentName $agentName
            if ($processActuallyRunning -and $timeSinceLastDelivery -lt $Script:DeliveryGraceSeconds -and $agentHealth -ne "stale") {
                # Still within grace period - skip this agent
                continue
            }
            
            # Get the pending messages
            $pendingMessages = Get-PendingMessages -Agent $agentName

            if ($pendingMessages.Count -eq 0) { continue }

            # RETROSPECTIVE BATCHING: If PM is in retrospective mode, batch messages instead of delivering
            if ($agentName -eq "pm") {
                $retroActive = Test-RetrospectiveActive
                if ($retroActive) {
                    # Batch PM messages during retrospective - don't deliver individually
                    Add-BatchedRetrospectiveMessage -AgentName $agentName -Messages $pendingMessages

                    # Acknowledge and remove from queue (they're now batched in prd.json.session.retro)
                    foreach ($msg in $pendingMessages) {
                        Invoke-AcknowledgeMessage -MessageId $msg.id -Agent $agentName | Out-Null
                    }
                    continue
                }
            }

            # AGENT STATUS CHECK: Verify agent's actual status from prd.json.agents (source of truth)
            # This prevents restarting an agent that just exited but hasn't updated watchdog's in-memory status yet
            # which could cause PRD updates to be incomplete or agent confusion
            #
            # EXCEPTION: Allow retrospective_complete through even when status is working_on_retrospective
            # This ensures PM can be woken up after all workers contribute to retrospective (pure event-driven)
            $agentStatusFromState = Get-AgentStatusFromState -AgentName $agentName
            if ($agentStatusFromState) {
                # Check if any pending message is retrospective_complete (event-driven wake-up signal)
                $hasRetrospectiveComplete = $pendingMessages | Where-Object { $_.type -eq "retrospective_complete" }

                # Don't deliver if agent is actively working, UNLESS it's the retrospective completion signal
                if ($agentStatusFromState -in @("working", "starting", "working_on_retrospective") -and -not $hasRetrospectiveComplete) {
                    Write-WatchdogLog "${agentName}: skipping delivery (status from state: ${agentStatusFromState})" -Color DarkGray
                    continue
                }

                # Log special case for retrospective completion
                if ($hasRetrospectiveComplete -and $agentStatusFromState -eq "working_on_retrospective") {
                    Write-WatchdogLog "${agentName}: delivering retrospective_complete (event-driven wake-up)" -Color Cyan
                }
            }

            Write-WatchdogLog "${agentName}: delivering $count message(s)" -Color Magenta

            # STARTUP MODE PROTECTION: Count PM restart attempts to prevent infinite loop
            if ($Script:StartupMode -and $agentName -eq "pm") {
                $Script:PMStartupAttempts++
                Write-WatchdogLog "PM startup attempt #$Script:PMStartupAttempts (max: $Script:MaxPMStartupAttempts)" -Color Yellow

                if ($Script:PMStartupAttempts -ge $Script:MaxPMStartupAttempts) {
                    Write-WatchdogLog "PM startup loop detected ($Script:PMStartupAttempts attempts) - forcing exit from startup mode" -Color Red
                    Write-WatchdogLog "This may indicate PM is not sending env_ready properly" -Color Yellow
                    Exit-StartupMode
                    $Script:PMStartupAttempts = 0  # Reset counter
                }
            }

            # Stop the current agent if running (but not working - we already checked above)
            if ($processActuallyRunning) {
                Stop-Agent -AgentName $agentName -Reason "message_delivery"
                Start-Sleep -Seconds 2
            }
            
            # Convert messages to simple format for agent
            $messageData = @()
            foreach ($msg in $pendingMessages) {
                $messageData += @{
                    id = $msg.id
                    from = $msg.from
                    type = $msg.type
                    priority = $msg.priority
                    payload = $msg.payload
                    timestamp = $msg.timestamp
                }
            }

            # Restart agent with the pending messages FIRST
            # Only acknowledge messages if agent starts successfully
            $agentStarted = Start-Agent -AgentName $agentName -PendingMessages $messageData

            if ($agentStarted) {
                # Agent started successfully - it will read and delete messages itself
                # DO NOT delete here - agent needs to read message files on startup
                # Agent will call Remove-AgentMessage after processing each message
                Write-WatchdogLog "Agent $agentName will process and delete $($pendingMessages.Count) message(s)" -Color Green

                # Track delivery time to enforce grace period
                $Script:Agents[$agentName].LastDeliveryTime = [DateTime]::UtcNow
            } else {
                Write-WatchdogLog "Failed to start $agentName - messages preserved in queue" -Color Red
                # Messages remain in queue for retry on next iteration
                continue
            }
            
            # Track the first/primary message being processed
            if ($messageData.Count -gt 0) {
                $Script:Agents[$agentName].CurrentMessage = $messageData[0]
            }
            
            $Script:TotalMessagesRouted += $count
            $Script:Agents[$agentName].LastActivity = [DateTime]::UtcNow
        }
    }
}

# ============================================================================
# STARTUP MODE
# ============================================================================

function Exit-StartupMode {
    <#
    .SYNOPSIS
    Exit startup mode and allow normal message delivery to all agents.
    Called when PM sends env_ready message, indicating consolidation is complete.
    #>
    if ($Script:StartupMode) {
        $Script:StartupMode = $false
        $duration = ([DateTime]::UtcNow - $Script:StartupModeStartTime).TotalSeconds
        Write-WatchdogLog "STARTUP MODE COMPLETE (after ${duration}s) - normal message delivery enabled" -Color Green
    }
}

# ============================================================================
# RETROSPECTIVE BATCHING
# ============================================================================

function Test-RetrospectiveActive {
    <#
    .SYNOPSIS
    Check if retrospective is active in prd.json.session.
    Used to determine if PM messages should be batched instead of delivered immediately.

    .RETURNS
    $true if retrospective is active, $false otherwise.
    #>
    $prdFile = $paths.PrdFile
    if (-not (Test-Path $prdFile)) { return $false }

    try {
        $prd = Get-Content $prdFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
        return $prd.session -and $prd.session.retro -and $prd.session.retro.active -eq $true
    } catch {
        return $false
    }
}

function Get-AgentStatusFromState {
    <#
    .SYNOPSIS
    Get agent's actual status from prd.json.agents (source of truth).
    This prevents delivering messages to agents that just exited but haven't updated watchdog's in-memory status yet.

    .PARAMETER AgentName
    The agent name to check.

    .RETURNS
    Agent status string, or $null if not found.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName
    )

    $prdFile = $paths.PrdFile
    if (-not (Test-Path $prdFile)) { return $null }

    try {
        $prd = Get-Content $prdFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
        if ($prd -and $prd.agents -and $prd.agents.$AgentName) {
            return $prd.agents.$AgentName.status
        }
    } catch {
        # Return null on error
    }
    return $null
}

function Sync-AgentStatusFromState {
    <#
    .SYNOPSIS
    Sync all agent statuses from prd.json.agents to in-memory $Script:Agents.
    This ensures dashboard shows current status even without status_update messages.

    prd.json.agents is the source of truth for agent status.

    CRITICAL FIX: Don't overwrite WorkStatus if agent is actively working.
    This prevents restart loop when agent hasn't updated prd.json yet.
    #>
    $prdFile = $paths.PrdFile
    if (-not (Test-Path $prdFile)) { return }

    try {
        $prd = Get-Content $prdFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
        if ($prd -and $prd.agents) {
            foreach ($agentName in @("pm", "developer", "qa", "gamedesigner", "techartist")) {
                if ($prd.agents.$agentName) {
                    $prdStatus = $prd.agents.$agentName.status
                    $prdCurrentTaskId = $prd.agents.$agentName.currentTaskId

                    # CRITICAL FIX: Don't overwrite WorkStatus if agent is actively working
                    # This prevents restart loop when agent hasn't updated prd.json yet
                    $agent = $Script:Agents[$agentName]
                    $shouldSkipSync = $false

                    # Skip if process is actually running
                    if ($agent.Process -and -not $agent.Process.HasExited) {
                        $shouldSkipSync = $true
                    }

                    # Skip if agent has recent activity (within 30 seconds)
                    $timeSinceActivity = ([DateTime]::UtcNow - $agent.LastActivity).TotalSeconds
                    if ($timeSinceActivity -lt 30) {
                        $shouldSkipSync = $true
                    }

                    # Update status only if not actively working
                    if (-not $shouldSkipSync -and $prdStatus) {
                        $Script:Agents[$agentName].WorkStatus = $prdStatus
                    }

                    # Always update currentTaskId if available (doesn't cause restart loops)
                    if ($prdCurrentTaskId) {
                        $Script:Agents[$agentName].CurrentTask = $prdCurrentTaskId
                    }
                }
            }
        }
    } catch {
        # Silently fail - status sync is best-effort
    }
}

function Add-BatchedRetrospectiveMessage {
    <#
    .SYNOPSIS
    Add PM messages to the batched messages array during retrospective.
    Messages are stored in prd.json.session.retro.batchedMessages and delivered when retrospective completes.

    .PARAMETER AgentName
    The agent name (should be "pm").

    .PARAMETER Messages
    Array of message objects to batch.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,

        [Parameter(Mandatory=$true)]
        [array]$Messages
    )

    $prdFile = $paths.PrdFile

    try {
        $prd = Get-Content $prdFile -Raw -ErrorAction Stop | ConvertFrom-Json

        # Ensure session.retro exists
        if (-not $prd.session) { $prd | Add-Member -NotePropertyName "session" -NotePropertyValue @{} -Force }
        if (-not $prd.session.retro) { $prd.session | Add-Member -NotePropertyName "retro" -NotePropertyValue @{} -Force }

        # Initialize batchedMessages array if needed
        if (-not $prd.session.retro.batchedMessages) {
            $prd.session.retro.batchedMessages = @()
        }

        # Add messages to batch
        foreach ($msg in $Messages) {
            $prd.session.retro.batchedMessages += @{
                id = $msg.id
                from = $msg.from
                type = $msg.type
                payload = $msg.payload
                timestamp = $msg.timestamp
            }
        }

        # Write back atomically
        $tempPath = $prdFile + ".tmp"
        $prd | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempPath -Encoding UTF8
        Move-Item -Path $tempPath -Destination $prdFile -Force

        Write-WatchdogLog "Batched $($Messages.Count) message(s) for PM during retrospective" -Color DarkGray
    } catch {
        Write-WatchdogLog "Failed to batch messages: $_" -Color Yellow
    }
}

function Send-RetrospectiveCompletionSignal {
    <#
    .SYNOPSIS
    Send a completion signal to PM's inbox when all retrospective contributions are received.
    This signals PM to wake up and process the batched messages.
    #>
    $completionMsg = @{
        id = (New-MessageId -RecipientAgent "pm")
        from = "watchdog"
        to = "pm"
        type = "retrospective_complete"
        priority = "high"
        payload = @{
            allContributionsReceived = $true
        }
        timestamp = [DateTime]::UtcNow.ToString("o")
        status = "pending"
    }

    # Write directly to PM's inbox
    $inbox = Join-Path $Script:SessionDir "messages\pm"
    $filePath = Join-Path $inbox "$($completionMsg.id).json"

    try {
        # Ensure inbox exists
        if (-not (Test-Path $inbox)) {
            New-Item -ItemType Directory -Path $inbox -Force | Out-Null
        }

        $completionMsg | ConvertTo-Json -Depth 10 | Out-File -FilePath $filePath -Encoding UTF8
        Write-WatchdogLog "Sent retrospective_complete signal to PM" -Color Green
    } catch {
        Write-WatchdogLog "Failed to send completion signal: $_" -Color Red
    }
}

function Invoke-HealthCheck {
    if (([DateTime]::UtcNow - $Script:LastHealthCheck).TotalMilliseconds -lt $HealthCheckIntervalMs) {
        return
    }
    
    $Script:LastHealthCheck = [DateTime]::UtcNow

    foreach ($agentName in @("pm", "developer", "qa", "gamedesigner", "techartist")) {
        $health = Test-AgentHealth -AgentName $agentName
        
        switch ($health) {
            "dead" {
                # Agent crashed - check if it has pending work
                $counts = Get-MessageCount
                if ($counts[$agentName] -gt 0) {
                    Write-WatchdogLog "$agentName crashed with pending messages - restarting" -Color Yellow
                    $null = Restart-Agent -AgentName $agentName -Reason "crashed_with_pending"
                }
                # Silent if no pending work
            }
            # REMOVED: "stale" case - idle agents should NOT be killed
            "healthy" {
                # Healthy is normal - don't log
            }
        }
    }
}

# ============================================================================
# AGENT STATE TIMEOUT MONITOR
# ============================================================================

function Test-AgentStateTimeout {
    <#
    .SYNOPSIS
    Check if agents are stuck in awaiting_* states and send timeout messages.
    This addresses P0-2: All awaiting_* states without timeout.

    Agents in event-driven mode may exit while waiting for responses.
    If they remain in awaiting_* status too long, watchdog detects and notifies PM.

    Includes cooldown mechanism to prevent spamming work_blocked messages.
    #>
    $prdFile = $paths.PrdFile
    if (-not (Test-Path $prdFile)) { return }

    try {
        $prd = Get-Content $prdFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
        if (-not $prd -or -not $prd.agents) { return }

        $now = [DateTime]::UtcNow

        foreach ($agentName in @("developer", "qa", "techartist", "gamedesigner")) {
            $agent = $prd.agents.$agentName
            if (-not $agent) { continue }

            # Check if agent is in an awaiting state
            $isAwaiting = $agent.status -like "awaiting_*" -or
                          $agent.status -eq "awaiting_pm" -or
                          $agent.status -eq "awaiting_gd" -or
                          $agent.status -eq "waiting"

            if ($isAwaiting) {
                # Calculate time since lastSeen
                $lastSeen = if ($agent.lastSeen) {
                    try { [DateTime]::Parse($agent.lastSeen) } catch { [DateTime]::MinValue }
                } else {
                    [DateTime]::MinValue
                }
                $elapsed = ($now - $lastSeen).TotalMinutes

                # Timeout threshold: 10 minutes (configurable via environment)
                $awaitingTimeout = if ($env:RALPH_AWAITING_TIMEOUT) {
                    [int]$env:RALPH_AWAITING_TIMEOUT
                } else {
                    10  # default 10 minutes
                }

                if ($elapsed -gt $awaitingTimeout) {
                    # COOLDOWN CHECK: Prevent spamming work_blocked messages
                    $lastSent = $Script:LastTimeoutSent[$agentName]
                    $cooldownElapsed = if ($lastSent) {
                        ($now - $lastSent).TotalMinutes
                    } else {
                        [double]::PositiveInfinity
                    }

                    if ($cooldownElapsed -lt $Script:TimeoutCooldownMinutes) {
                        # Skip - cooldown period not elapsed
                        $remaining = [math]::Round($Script:TimeoutCooldownMinutes - $cooldownElapsed, 1)
                        Write-WatchdogLog "$agentName timeout detected but cooldown active (${remaining}min remaining)" -Color DarkGray
                        continue
                    }

                    Write-WatchdogLog "$agentName timeout in $($agent.status) state for $([math]::Round($elapsed, 1))min - sending work_blocked to PM" -Color Yellow

                    # Send timeout message to PM (use work_blocked type, not agent_timeout)
                    $taskId = if ($agent.currentTaskId) { $agent.currentTaskId } else { "unknown" }

                    Send-AgentMessage -From "watchdog" -To "pm" -Type "work_blocked" -Payload @{
                        agent = $agentName
                        originalStatus = $agent.status
                        elapsedMinutes = [math]::Round($elapsed, 1)
                        taskId = $taskId
                        message = "$agentName has been waiting for $($agent.status) for $([math]::Round($elapsed, 1)) minutes"
                    } -Priority "high"

                    # Update cooldown timestamp
                    $Script:LastTimeoutSent[$agentName] = $now

                    # Reset agent status to idle so PM can reassign or take action
                    $prd.agents.$agentName.status = "idle"

                    # Write back atomically
                    $tempPath = $prdFile + ".tmp"
                    $prd | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempPath -Encoding UTF8
                    Move-Item -Path $tempPath -Destination $prdFile -Force
                }
            }
        }
    } catch {
        Write-WatchdogLog "Error in agent state timeout check: $_" -Color Yellow
    }
}

# ============================================================================
# RETROSPECTIVE FILE WATCHER
# ============================================================================

# Global file watcher state
$Script:RetrospectiveWatcher = $null
$Script:RetrospectiveContributions = @{
    developer = $false
    techartist = $false
    qa = $false
    gamedesigner = $false
}
$Script:RetrospectiveStartTime = $null

function Start-RetrospectiveWatcher {
    <#
    .SYNOPSIS
    Start monitoring retrospective.txt for changes. Wakes PM when all workers contributed.
    #>
    $retroFile = Join-Path $Script:SessionDir "retrospective.txt"

    if (-not (Test-Path $retroFile)) {
        Write-WatchdogLog "Retrospective file not found, cannot start watcher" -Color Yellow
        return
    }

    # Reset contributions tracking
    $Script:RetrospectiveContributions = @{
        developer = $false
        techartist = $false
        qa = $false
        gamedesigner = $false
    }
    $Script:RetrospectiveStartTime = [DateTime]::UtcNow

    try {
        # Create FileSystemWatcher
        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path = $Script:SessionDir
        $watcher.Filter = "retrospective.txt"
        $watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite
        $watcher.EnableRaisingEvents = $true

        # Register change event
        $action = {
            $retroFile = Join-Path $Event.MessageData "retrospective.txt"
            if (Test-Path $retroFile) {
                # Small delay to ensure file write is complete
                Start-Sleep -Milliseconds 100

                try {
                    $content = Get-Content $retroFile -Raw -ErrorAction SilentlyContinue
                    if ($content) {
                        # Check each agent's contribution
                        $Script:RetrospectiveContributions.developer = $content -match "### Developer Perspective" -and $content -notmatch "WAITING"
                        $Script:RetrospectiveContributions.techartist = $content -match "### Tech Artist Perspective" -and $content -notmatch "WAITING"
                        $Script:RetrospectiveContributions.qa = $content -match "### QA Perspective" -and $content -notmatch "WAITING"
                        $Script:RetrospectiveContributions.gamedesigner = $content -match "### Game Designer Perspective" -and $content -notmatch "WAITING"

                        # Check if playtest was received - read from prd.json.session
                        $prdFile = Join-Path (Split-Path $Event.MessageData -Parent) "prd.json"
                        $playtestReceived = $false
                        if (Test-Path $prdFile) {
                            $prd = Get-Content $prdFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
                            if ($prd -and $prd.session -and $prd.session.retro) {
                                $playtestReceived = $prd.session.retro.playtestReportReceived -eq $true
                            }
                        }

                        # Check if all complete
                        # Game Designer participation is optional - only required if section exists in file
                        # This allows retrospectives for bugfixes/config tasks without Game Designer contribution
                        $gamedesignerExpected = $content -match "### Game Designer Perspective"
                        $allRequiredContributions = $Script:RetrospectiveContributions.developer -and
                                                   $Script:RetrospectiveContributions.techartist -and
                                                   $Script:RetrospectiveContributions.qa
                        $gamedesignerComplete = -not $gamedesignerExpected -or $Script:RetrospectiveContributions.gamedesigner
                        $playtestComplete = -not $gamedesignerExpected -or $playtestReceived

                        if ($allRequiredContributions -and $gamedesignerComplete -and $playtestComplete) {

                            Write-WatchdogLog "All retrospective contributions received. Sending completion signal to PM..." -Color Green

                            # Stop watching
                            $watcher = $Event.SourceObject
                            $watcher.EnableRaisingEvents = $false

                            # Update prd.json.session: mark retrospective complete
                            $prdFile = Join-Path (Split-Path $Event.MessageData -Parent) "prd.json"
                            try {
                                $prd = Get-Content $prdFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
                                if ($prd -and $prd.session -and $prd.session.retro) {
                                    $prd.session.retro.active = $false
                                    $prd.session.retro.completedAt = [DateTime]::UtcNow.ToString("o")
                                    $tempPath = $prdFile + ".tmp"
                                    $prd | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempPath -Encoding UTF8
                                    Move-Item -Path $tempPath -Destination $prdFile -Force
                                }
                            } catch {
                                Write-WatchdogLog "Failed to update retrospective state: $_" -Color Yellow
                            }

                            # Send completion signal to PM (wakes PM with all batched messages)
                            Send-RetrospectiveCompletionSignal
                        }
                    }
                } catch {
                    Write-WatchdogLog "Error processing retrospective change: $_" -Color Yellow
                }
            }
        }

        # Register event with session dir as message data
        Register-ObjectEvent -InputObject $watcher -EventName "Changed" -Action $action -MessageData $Script:SessionDir | Out-Null

        $Script:RetrospectiveWatcher = $watcher
        Write-WatchdogLog "Started retrospective file watcher" -Color Cyan

    } catch {
        Write-WatchdogLog "Failed to start retrospective watcher: $_" -Color Red
    }
}

function Stop-RetrospectiveWatcher {
    <#
    .SYNOPSIS
    Stop monitoring retrospective.txt and clean up resources.
    #>
    if ($Script:RetrospectiveWatcher) {
        try {
            $Script:RetrospectiveWatcher.EnableRaisingEvents = $false
            $Script:RetrospectiveWatcher.Dispose()
        } catch {
            # Ignore disposal errors
        }
        $Script:RetrospectiveWatcher = $null
    }

    # Unregister event subscribers
    try {
        Get-EventSubscriber -ErrorAction SilentlyContinue |
            Where-Object { $_.SourceObject -and $_.SourceObject.Filter -eq "retrospective.txt" } |
            Unregister-Event -ErrorAction SilentlyContinue
    } catch {
        # Ignore unregistration errors
    }

    $Script:RetrospectiveContributions = @{
        developer = $false
        techartist = $false
        qa = $false
        gamedesigner = $false
    }
    $Script:RetrospectiveStartTime = $null

    Write-WatchdogLog "Stopped retrospective file watcher" -Color Cyan
}

function Test-RetrospectiveTimeout {
    <#
    .SYNOPSIS
    Check if retrospective has timed out and send reminders to idle agents.
    Called periodically from main loop.

    PHASE 1 (5 min): Send reminders to idle agents who haven't contributed
    PHASE 2 (15 min): Force skip retrospective and continue to next phase

    This addresses P0-1: PM retrospective_complete wait without timeout.
    #>
    if (-not $Script:RetrospectiveStartTime) {
        return
    }

    # Calculate elapsed time
    $elapsed = ([DateTime]::UtcNow - $Script:RetrospectiveStartTime).TotalMinutes

    # Force-skip threshold: 15 minutes (configurable via environment)
    $forceSkipMinutes = if ($env:RALPH_RETRO_FORCE_SKIP) {
        [int]$env:RALPH_RETRO_FORCE_SKIP
    } else {
        15  # default 15 minutes
    }

    # Phase 2: Force skip after timeout (prevents infinite wait)
    if ($elapsed -gt $forceSkipMinutes) {
        Write-WatchdogLog "Retrospective timeout ($([math]::Round($elapsed, 1))min > ${forceSkipMinutes}min) - force skipping to playtest phase" -Color Yellow

        try {
            $prdFile = $paths.PrdFile
            if (Test-Path $prdFile) {
                $prd = Get-Content $prdFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
                if ($prd -and $prd.session -and $prd.session.retro) {
                    # Mark retrospective as skipped
                    $prd.session.retro.active = $false
                    $prd.session.retro.skipped = $true
                    $prd.session.retro.skipReason = "timeout_after_${forceSkipMinutes}_minutes"
                    $prd.session.retro.skippedAt = [DateTime]::UtcNow.ToString("o")

                    # Move to next phase
                    if ($prd.session.currentTask) {
                        $prd.session.currentTask.status = "retrospective_synthesized"
                    }

                    # Write atomically
                    $tempPath = $prdFile + ".tmp"
                    $prd | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempPath -Encoding UTF8
                    Move-Item -Path $tempPath -Destination $prdFile -Force

                    # Wake up PM to continue to next phase
                    Send-RetrospectiveCompletionSignal
                    $Script:RetrospectiveStartTime = $null
                    return
                }
            }
        } catch {
            Write-WatchdogLog "Error in retrospective force-skip: $_" -Color Yellow
        }
    }

    # Phase 1: Send reminders at 5 minutes
    if ($elapsed -lt 5) {
        return
    }

    # Timeout reached - check who hasn't contributed and send reminder
    try {
        $prdFile = $paths.PrdFile
        if (-not (Test-Path $prdFile)) {
            return
        }

        $prd = Get-Content $prdFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
        if (-not $prd -or -not $prd.session -or $prd.session.currentTask.status -ne "in_retrospective") {
            return
        }

        $remindersSent = 0

        # Check each agent
        foreach ($agent in @("developer", "techartist", "qa", "gamedesigner")) {
            if (-not $Script:RetrospectiveContributions.$agent) {
                # Agent hasn't contributed - check if they're idle
                if ($prd.agents.$agent.status -ne "working_on_retrospective") {
                    Write-WatchdogLog "Sending retrospective reminder to idle agent: $agent" -Color Yellow

                    # Send reminder message
                    $retroFile = Join-Path $Script:SessionDir "retrospective.txt"
                    Send-AgentMessage -From "watchdog" -To $agent -Type "retrospective_initiate" -Payload @{
                        taskId = $prd.session.currentTask.id
                        retrospectiveFile = $retroFile
                        reminder = $true
                    } -Priority "normal"

                    $remindersSent++
                }
            }
        }

        if ($remindersSent -gt 0) {
            # Reset timer to avoid spamming (but still tracking total time for force-skip)
            # Don't reset RetrospectiveStartTime - we need it for force-skip detection
            Write-WatchdogLog "Reminders sent to $remindersSent agents. Total elapsed: $([math]::Round($elapsed, 1))min" -Color Cyan
        }

    } catch {
        Write-WatchdogLog "Error in retrospective timeout check: $_" -Color Yellow
    }
}

# ============================================================================
# RESOURCE MANAGEMENT
# ============================================================================

$Script:LastResourceCleanup = [DateTime]::MinValue

function Invoke-ResourceCleanup {
    <#
    .SYNOPSIS
    Periodic cleanup of archives, temp files, and stale resources.

    .PARAMETER Force
    Force cleanup even if recently done.
    #>
    param([switch]$Force)

    # Don't run more than once per 5 minutes unless forced
    if (-not $Force -and ([DateTime]::UtcNow - $Script:LastResourceCleanup).TotalMinutes -lt 5) {
        return
    }
    $Script:LastResourceCleanup = [DateTime]::UtcNow

    try {
        # Clean old message archives using state manager
        $removed = Clear-OldArchives
        if ($removed -gt 0) {
            Write-WatchdogLog "Cleaned $removed old archive files" -Color DarkGray
        }

        # Clean stale runner scripts from log directory
        Get-ChildItem -Path $Script:LogDir -Filter "*-runner.ps1" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTimeUtc -lt [DateTime]::UtcNow.AddHours(-1) } |
            ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }

        # Clean stale message files (format: msg-{agent}-{timestamp}-{seq}.json)
        Get-ChildItem -Path $Script:SessionDir -Filter "msg-*-*.json" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTimeUtc -lt [DateTime]::UtcNow.AddMinutes(-30) } |
            ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }

    } catch {
        # Resource cleanup failure is non-critical
        Write-WatchdogLog "Resource cleanup error: $_" -Color Yellow
    }
}

function Clear-OldArchives {
    <#
    .SYNOPSIS
    Clean up message files that have been processed.

    Uses the message state manager to determine which messages were already
    processed, and removes those message files from the queue.

    .RETURNS
    Number of message files removed.
    #>
    param()

    if (-not $Script:MessageQueueDir) {
        return 0
    }

    $removed = 0

    # Check each agent's inbox
    foreach ($agent in @("pm", "developer", "qa", "gamedesigner", "watchdog")) {
        $inbox = Join-Path $Script:MessageQueueDir $agent
        if (-not (Test-Path $inbox)) { continue }

        Get-ChildItem -Path $inbox -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
            $msgFile = $_

            try {
                # Read message to get its ID
                $content = Get-Content $msgFile.FullName -Raw -ErrorAction Stop | ConvertFrom-Json

                # Check if this message was already processed
                $wasProcessed = Test-MessageProcessed -MessageId $content.id
                if ($wasProcessed) {
                    # Message was processed - safe to delete
                    Remove-Item $msgFile.FullName -Force -ErrorAction SilentlyContinue
                    $removed++
                }
            } catch {
                # Corrupt or unreadable message file - quarantine it
                $quarantine = Join-Path $Script:MessageQueueDir "quarantine"
                if (-not (Test-Path $quarantine)) {
                    New-Item -ItemType Directory -Path $quarantine -Force | Out-Null
                }
                Move-Item -Path $msgFile.FullName -Destination (Join-Path $quarantine $msgFile.Name) -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # Also run state cleanup to remove old processed message entries (from memory)
    Invoke-StateCleanup -OlderThan (Get-Date).AddHours(-24) | Out-Null

    return $removed
}

# ============================================================================
# DASHBOARD
# ============================================================================

# Track if dashboard has been initialized
$Script:DashboardInitialized = $false
$Script:LastDashboardContent = @{}

function Write-LineAt {
    param(
        [int]$Row,
        [string]$Text,
        [ConsoleColor]$Color = [ConsoleColor]::White,
        [int]$Width = 80
    )
    
    $paddedText = $Text.PadRight($Width).Substring(0, $Width)
    
    # Only update if content changed
    $key = "row_$Row"
    $contentKey = "$paddedText|$Color"
    if ($Script:LastDashboardContent[$key] -eq $contentKey) {
        return
    }
    $Script:LastDashboardContent[$key] = $contentKey
    
    [Console]::SetCursorPosition(0, $Row)
    $oldColor = [Console]::ForegroundColor
    [Console]::ForegroundColor = $Color
    [Console]::Write($paddedText)
    [Console]::ForegroundColor = $oldColor
}

function Write-ColoredLineAt {
    param(
        [int]$Row,
        [array]$Segments,  # Array of @{Text="..."; Color="White"}
        [int]$Width = 80
    )
    
    # Build content key for change detection
    $contentKey = ($Segments | ForEach-Object { "$($_.Text)|$($_.Color)" }) -join ";"
    $key = "row_$Row"
    if ($Script:LastDashboardContent[$key] -eq $contentKey) {
        return
    }
    $Script:LastDashboardContent[$key] = $contentKey
    
    [Console]::SetCursorPosition(0, $Row)
    $totalLen = 0
    $oldColor = [Console]::ForegroundColor
    
    foreach ($seg in $Segments) {
        [Console]::ForegroundColor = [ConsoleColor]::$($seg.Color)
        [Console]::Write($seg.Text)
        $totalLen += $seg.Text.Length
    }
    
    # Pad remainder
    if ($totalLen -lt $Width) {
        [Console]::ForegroundColor = [ConsoleColor]::Black
        [Console]::Write(" " * ($Width - $totalLen))
    }
    
    [Console]::ForegroundColor = $oldColor
}

# ============================================================================
# DASHBOARD RENDERING HELPERS
# ============================================================================

function Initialize-DashboardScreen {
    <#
    .SYNOPSIS
    Initializes the dashboard screen (clears screen, hides cursor).
    Only runs once on first call.
    #>
    if (-not $Script:DashboardInitialized) {
        try {
            Clear-Host
            [Console]::CursorVisible = $false
        } catch {
            # Non-interactive mode - ignore console errors
        }
        $Script:DashboardInitialized = $true
        $Script:LastDashboardContent = @{}
    }
}

function Draw-DashboardHeader {
    <#
    .SYNOPSIS
    Draws the dashboard header with title and uptime info.

    .RETURNS
    The next row number to use.
    #>
    param(
        [int]$StartRow = 0,
        [int]$Width = 80
    )

    $border = "=" * $Width
    $separator = "  " + ("-" * ($Width - 4))
    $row = $StartRow

    $uptime = ([DateTime]::UtcNow - $Script:WatchdogStartTime)
    $uptimeStr = "{0:hh\:mm\:ss}" -f $uptime

    Write-LineAt -Row $row -Text $border -Color Cyan; $row++
    Write-LineAt -Row $row -Text "  RALPH WATCHDOG - Event-Driven Multi-Agent Mode" -Color Cyan; $row++
    Write-LineAt -Row $row -Text $border -Color Cyan; $row++
    Write-LineAt -Row $row -Text "" -Color White; $row++
    Write-LineAt -Row $row -Text "  Uptime: $uptimeStr  |  Routed: $Script:TotalMessagesRouted  |  Cycles: $Script:TotalIterations" -Color White; $row++

    # Show startup mode indicator
    if ($Script:StartupMode) {
        $elapsed = ([DateTime]::UtcNow - $Script:StartupModeStartTime).TotalSeconds
        Write-LineAt -Row $row -Text "  [STARTUP MODE: ${elapsed}s elapsed - Only PM active]" -Color Yellow; $row++
    }

    Write-LineAt -Row $row -Text "" -Color White; $row++

    return $row
}

function Draw-AgentStatusSection {
    <#
    .SYNOPSIS
    Draws the agent status section of the dashboard.

    .PARAMETER StartRow
    The starting row number.

    .RETURNS
    The next row number to use.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [int]$StartRow,

        [int]$Width = 80
    )

    $separator = "  " + ("-" * ($Width - 4))
    $row = $StartRow

    Write-LineAt -Row $row -Text "  AGENTS" -Color Yellow; $row++
    Write-LineAt -Row $row -Text $separator -Color White; $row++
    Write-LineAt -Row $row -Text ("  " + "Agent".PadRight(10) + "Status".PadRight(12) + "PID".PadRight(10) + "Pending".PadRight(10) + "Current Message") -Color DarkGray; $row++
    Write-LineAt -Row $row -Text $separator -Color White; $row++

    $counts = Get-MessageCount

    foreach ($agentName in @("pm", "developer", "qa", "gamedesigner", "techartist")) {
        $agent = $Script:Agents[$agentName]
        $pendingCount = $counts[$agentName]

        $processRunning = $agent.Process -and (-not $agent.Process.HasExited)
        $statusText = if ($processRunning) { $agent.WorkStatus.ToUpper() } else { "STOPPED" }

        # Use the Get-StatusColor function from Dashboard-Common if available
        if (Get-Command Get-StatusColor -ErrorAction SilentlyContinue) {
            $statusColor = Get-StatusColor -Status $agent.WorkStatus
            if (-not $processRunning) { $statusColor = "Red" }
        } else {
            $statusColor = switch ($true) {
                (-not $processRunning) { "Red" }
                ($agent.WorkStatus -eq "idle") { "Gray" }
                ($agent.WorkStatus -eq "working") { "Green" }
                ($agent.WorkStatus -eq "waiting") { "Yellow" }
                ($agent.WorkStatus -eq "ready") { "Cyan" }
                ($agent.WorkStatus -eq "starting") { "Magenta" }
                default { "White" }
            }
        }

        $pidText = if ($processRunning) { $agent.Process.Id.ToString() } else { "-" }
        $pendingColor = if ($pendingCount -gt 0) { "Yellow" } else { "Gray" }

        $currentMsgText = "-"
        if ($agent.CurrentMessage) {
            $msgType = $agent.CurrentMessage.type
            $msgFrom = $agent.CurrentMessage.from
            $currentMsgText = "$msgType from $msgFrom"
            if ($currentMsgText.Length -gt 28) {
                $currentMsgText = $currentMsgText.Substring(0, 25) + "..."
            }
        }
        $msgColor = if ($currentMsgText -ne "-") { "White" } else { "DarkGray" }

        Write-ColoredLineAt -Row $row -Segments @(
            @{Text="  "; Color="White"},
            @{Text=$agentName.PadRight(10); Color="Cyan"},
            @{Text=$statusText.PadRight(12); Color=$statusColor},
            @{Text=$pidText.PadRight(10); Color="White"},
            @{Text=$pendingCount.ToString().PadRight(10); Color=$pendingColor},
            @{Text=$currentMsgText.PadRight(28); Color=$msgColor}
        )
        $row++
    }

    Write-LineAt -Row $row -Text $separator -Color White; $row++
    Write-LineAt -Row $row -Text "" -Color White; $row++

    return $row
}

function Draw-MessageQueueSection {
    <#
    .SYNOPSIS
    Draws the message queue section of the dashboard.

    .PARAMETER StartRow
    The starting row number.

    .RETURNS
    The next row number to use.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [int]$StartRow,

        [int]$Width = 80
    )

    $separator = "  " + ("-" * ($Width - 4))
    $row = $StartRow

    Write-LineAt -Row $row -Text "  MESSAGE QUEUE" -Color Yellow; $row++
    Write-LineAt -Row $row -Text $separator -Color White; $row++

    $counts = Get-MessageCount
    $totalPending = ($counts.Values | Measure-Object -Sum).Sum

    foreach ($agentName in @("pm", "developer", "qa", "gamedesigner", "techartist")) {
        $count = $counts[$agentName]
        $countColor = if ($count -gt 0) { "Yellow" } else { "DarkGray" }
        Write-ColoredLineAt -Row $row -Segments @(
            @{Text="  "; Color="White"},
            @{Text=$agentName.PadRight(12); Color="Cyan"},
            @{Text="$count pending"; Color=$countColor}
        )
        $row++
    }

    Write-LineAt -Row $row -Text "" -Color White; $row++
    $totalColor = if ($totalPending -gt 0) { "Yellow" } else { "DarkGray" }
    Write-LineAt -Row $row -Text "  Total: $totalPending pending messages" -Color $totalColor; $row++
    Write-LineAt -Row $row -Text $separator -Color White; $row++
    Write-LineAt -Row $row -Text "" -Color White; $row++

    return $row
}

function Draw-ActivityLogSection {
    <#
    .SYNOPSIS
    Draws the activity log section of the dashboard.

    .PARAMETER StartRow
    The starting row number.

    .RETURNS
    The next row number to use.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [int]$StartRow
    )

    $separator = "  " + ("-" * 74)
    $row = $StartRow

    Write-LineAt -Row $row -Text "  ACTIVITY LOG" -Color Yellow; $row++
    Write-LineAt -Row $row -Text $separator -Color White; $row++

    for ($i = 0; $i -lt $Script:MaxActivityLogSize; $i++) {
        if ($i -lt $Script:ActivityLog.Count) {
            $logEntry = $Script:ActivityLog[$i]
            Write-LineAt -Row $row -Text "  $logEntry" -Color DarkGray
        } else {
            Write-LineAt -Row $row -Text "" -Color White
        }
        $row++
    }

    Write-LineAt -Row $row -Text $separator -Color White; $row++
    Write-LineAt -Row $row -Text "" -Color White; $row++

    return $row
}

function Draw-DashboardFooter {
    <#
    .SYNOPSIS
    Draws the dashboard footer.

    .PARAMETER StartRow
    The starting row number.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [int]$StartRow,

        [int]$Width = 80
    )

    $border = "=" * $Width
    $row = $StartRow

    Write-LineAt -Row $row -Text $border -Color Cyan; $row++
    Write-LineAt -Row $row -Text "  Press Ctrl+C to stop watchdog" -Color DarkGray; $row++
    Write-LineAt -Row $row -Text $border -Color Cyan; $row++
}

function Show-EventDashboard {
    <#
    .SYNOPSIS
    Main dashboard display function - orchestrates all dashboard sections.

    Uses helper functions for modular rendering:
    - Initialize-DashboardScreen: First-time setup
    - Draw-DashboardHeader: Title and uptime
    - Draw-AgentStatusSection: Agent status table
    - Draw-MessageQueueSection: Message counts
    - Draw-ActivityLogSection: Activity log entries
    - Draw-DashboardFooter: Footer with Ctrl+C prompt
    #>
    try {
        $width = 80

        # First time: clear screen and hide cursor
        Initialize-DashboardScreen

        # Header section
        $row = Draw-DashboardHeader -StartRow 0 -Width $width

        # Agent status section
        $row = Draw-AgentStatusSection -StartRow $row -Width $width

        # Message queue section
        $row = Draw-MessageQueueSection -StartRow $row -Width $width

        # Activity log section
        $row = Draw-ActivityLogSection -StartRow $row

        # Footer section
        Draw-DashboardFooter -StartRow $row -Width $width

    } catch {
        # Silently ignore dashboard errors
    }
}

# ============================================================================
# COMPLETION CHECK
# ============================================================================

function Test-SessionComplete {
    # Check for completion signal file
    $signalFile = Join-Path $Script:SessionDir "session-complete.flag"
    if (Test-Path $signalFile) {
        return $true
    }

    # Check for RALPH_COMPLETE in any agent log
    foreach ($agentName in @("pm", "developer", "qa", "gamedesigner", "techartist")) {
        $logFile = Join-Path $Script:LogDir "$agentName.log"
        if (Test-Path $logFile) {
            $content = Get-Content $logFile -Tail 50 -ErrorAction SilentlyContinue | Out-String
            if ($content -match '<promise>RALPH_COMPLETE</promise>') {
                return $true
            }
        }
    }

    # Note: Watchdog uses its own MaxIterationsLimit, not prd.json.session.maxIterations
    # The coordinator (PM agent) handles its own iteration counting in prd.json.session
    # This check is only for legacy compatibility

    return $false
}

# ============================================================================
# MAIN LOOP
# ============================================================================

function Start-EventWatchdog {
    # Check if another watchdog is already running
    if (Test-WatchdogAlreadyRunning) {
        Write-Host "[WATCHDOG] ERROR: Another watchdog instance is already running!" -ForegroundColor Red
        Write-Host "[WATCHDOG] Check $(Get-WatchdogPidFilePath -SessionDir $Script:SessionDir) for the existing process ID." -ForegroundColor Yellow
        exit 1
    }
    
    # Write PID file
    Write-WatchdogPidFile -SessionDir $Script:SessionDir
    
    # Register graceful shutdown handler for Ctrl+C and process exit
    $null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        Write-Host "`n[WATCHDOG] Received shutdown signal..." -ForegroundColor Yellow
        # Note: Stop-AllAgents will be called in the finally block
    }
    
    # Handle Ctrl+C gracefully (skip if no console handle)
    try {
        [Console]::TreatControlCAsInput = $false
    } catch {
        # Non-interactive mode - skip console property
    }
    $null = Register-ObjectEvent -InputObject ([Console]) -EventName CancelKeyPress -Action {
        $Script:SessionComplete = $true
        $EventArgs.Cancel = $true  # Prevent immediate termination
        Write-Host "`n[WATCHDOG] Ctrl+C received, shutting down gracefully..." -ForegroundColor Yellow
    } -ErrorAction SilentlyContinue
    
    # Initial startup messages (before dashboard takes over)
    if ($NoDashboard) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  RALPH WATCHDOG - Event-Driven Mode" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Project: $ProjectRoot"
        Write-Host "Log Dir: $Script:LogDir"
        Write-Host "PID: $PID"
        Write-Host ""
    }
    
    # Start agents and enter main monitoring loop (message queue mode)
    try {
        Start-AllAgents
        Invoke-MainLoop
    }
    finally {
        # Restore cursor visibility (ignore errors in non-interactive mode)
        try {
            [Console]::CursorVisible = $true
        } catch {
            # Non-interactive mode - ignore console errors
        }
        $Script:DashboardInitialized = $false
        
        Write-Host ""
        Write-Host "[WATCHDOG] Watchdog stopping..." -ForegroundColor Cyan
        
        # Stop all agents
        Stop-AllAgents -Graceful -Reason "watchdog_shutdown"
        
        # Final cleanup
        Invoke-ResourceCleanup -Force
        
        # Remove PID file
        Remove-WatchdogPidFile -SessionDir $Script:SessionDir
        
        # Write summary
        Write-EventSummary
    }
}

function Write-EventSummary {
    $summaryFile = Join-Path $Script:LogDir "watchdog-event-summary.log"
    $uptime = ([DateTime]::UtcNow - $Script:WatchdogStartTime)
    
    $summary = @"
================================================================================
RALPH WATCHDOG - EVENT-DRIVEN MODE - SESSION SUMMARY
================================================================================
Start Time:      $($Script:WatchdogStartTime.ToString('yyyy-MM-dd HH:mm:ss')) UTC
End Time:        $([DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) UTC
Total Uptime:    $("{0:hh\:mm\:ss}" -f $uptime)
Messages Routed: $Script:TotalMessagesRouted
Iterations:      $Script:TotalIterations
Session Complete: $Script:SessionComplete

--------------------------------------------------------------------------------
AGENT STATISTICS
--------------------------------------------------------------------------------
"@

    foreach ($agentName in @("pm", "developer", "qa", "gamedesigner", "techartist")) {
        $agent = $Script:Agents[$agentName]
        $summary += "`n  $agentName : Restarts=$($agent.RestartCount), ProcessState=$($agent.ProcessState), WorkStatus=$($agent.WorkStatus)"
    }
    
    $summary += @"


================================================================================
END OF SUMMARY
================================================================================
"@
    
    $summary | Out-File -FilePath $summaryFile -Encoding UTF8
    
    Write-Host ""
    Write-Host "[WATCHDOG] Summary written to: $summaryFile" -ForegroundColor Cyan
}

# ============================================================================
# ENTRY POINT
# ============================================================================

try {
    Start-EventWatchdog
} catch {
    Write-Host "[WATCHDOG] Fatal error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    exit 1
}
