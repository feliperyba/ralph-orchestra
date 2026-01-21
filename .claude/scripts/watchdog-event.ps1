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
}

# Delivery grace period - don't re-deliver messages to an agent within this window
# Reduced from 10 to 5 seconds for faster response when agents are ready
$Script:DeliveryGraceSeconds = 5

# ============================================================================
# AGENT MANAGEMENT
# ============================================================================

# Message Preamble Generator - consolidates messages into initial prompt
function Get-AgentStartupPreamble {
    <#
    .SYNOPSIS
    Generate a startup preamble with pending messages for the agent.
    This embeds messages into the initial prompt instead of requiring a file read.

    .PARAMETER AgentName
    The agent receiving the messages.

    .PARAMETER PendingMessages
    Array of message objects to include in preamble.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,

        [Parameter(Mandatory=$true)]
        [array]$PendingMessages
    )

    if ($PendingMessages.Count -eq 0) { return "" }

    $preamble = @"

# ═══════════════════════════════════════════════════════════════
# PENDING MESSAGES FOR $AgentName
# You have $($PendingMessages.Count) message(s) to process:
# ═══════════════════════════════════════════════════════════════
"@

    foreach ($msg in $PendingMessages) {
        $preamble += "`n## [$($msg.priority.ToUpper())] $($msg.type) from $($msg.from)"
        $preamble += "`nMessage ID: $($msg.id)"
        $preamble += "`nPayload: $($msg.payload | ConvertTo-Json -Compress)"
        $preamble += "`n"
    }

    $preamble += @"
# ═══════════════════════════════════════════════════════════════
# IMPORTANT: After processing ALL messages above:
# 1. Send any response messages to the appropriate inboxes
# 2. Delete the pending file: Remove-Item ".claude\session\pending-messages-$AgentName.json" -Force
# 3. Send status_update with status="ready" to watchdog when done
# ═══════════════════════════════════════════════════════════════
"@

    return $preamble
}

# Cleanup Verification - checks if agent deleted pending file
function Test-AgentPendingFileStale {
    <#
    .SYNOPSIS
    Check if agent's pending file is stale (agent may have crashed).

    .PARAMETER AgentName
    The agent to check.

    .RETURNS
    $true if file is stale (>5 min old), $false if deleted or recent.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName
    )

    $pendingFile = Join-Path $Script:SessionDir "pending-messages-$AgentName.json"

    # No file = agent cleaned up properly
    if (-not (Test-Path $pendingFile)) { return $false }

    # File exists - check age
    $fileAge = ([DateTime]::UtcNow - (Get-Item $pendingFile).LastWriteTimeUtc).TotalMinutes

    if ($fileAge -gt 5) {
        Write-WatchdogLog "WARNING: Stale pending file for $AgentName (${fileAge}min old)" -Color Yellow
        return $true  # Stale - agent may have crashed
    }

    # Recent file - agent still processing
    return $false
}

# Security: Escape strings for safe embedding in generated scripts
function Get-SafeScriptString {
    param([string]$Value)
    # Escape backticks first, then double quotes, then dollar signs
    return $Value -replace '`', '``' -replace '"', '`"' -replace '\$', '`$'
}

function Start-Agent {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("pm", "developer", "qa")]
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
    }
    
    $windowTitle = "Ralph Event: $AgentName"
    $scriptFile = Join-Path $Script:LogDir "$AgentName-runner.ps1"
    
    # Write pending messages to a context file for agent to read on startup
    # The preamble is embedded in the file content for token-efficient single-read
    $pendingFile = Join-Path $Script:SessionDir "pending-messages-$AgentName.json"
    $pendingFileForScript = $pendingFile  # Same path, used in script generation
    if ($PendingMessages.Count -gt 0) {
        # Generate preamble with messages embedded
        $preamble = Get-AgentStartupPreamble -AgentName $AgentName -PendingMessages $PendingMessages

        # Create structured data file with preamble as readable content
        # This allows single file read to get both formatted preamble and structured data
        $pendingContent = @"

$preamble

# RAW DATA (for reference):
$($PendingMessages | ConvertTo-Json -Depth 10)

# Use the formatted messages above - they are already in your context.
# After processing, delete this file: Remove-Item "$pendingFile" -Force
"@

        $pendingContent | Out-File -FilePath $pendingFile -Encoding UTF8
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
Write-Host "Mode: EVENT-DRIVEN MULTI-AGENT"
Write-Host "Working Dir: $safeProjectRoot"
Write-Host ""

# Check for pending messages delivered by watchdog
`$pendingFile = "$safePendingFile"
if (Test-Path `$pendingFile) {
    Write-Host "PENDING MESSAGES AVAILABLE:" -ForegroundColor Yellow
    Write-Host "See file content above - messages embedded in initial prompt" -ForegroundColor DarkYellow
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

# Recursive Process Tree Cleanup - terminates all descendant processes
function Stop-ProcessTree {
    <#
    .SYNOPSIS
    Recursively terminate a process and all its descendants.

    .PARAMETER ParentPid
    The root process ID to terminate.

    .PARAMETER Reason
    Reason for termination (for logging).
    #>
    param(
        [Parameter(Mandatory=$true)]
        [int]$ParentPid,

        [string]$Reason = "cleanup"
    )

    # Build complete process tree using BFS
    $allProcesses = @()
    $queue = @($ParentPid)
    $visited = @{}

    while ($queue.Count -gt 0) {
        $currentPid = $queue[0]
        $queue = $queue[1..($queue.Count - 1)]

        if ($visited.ContainsKey($currentPid)) { continue }
        $visited[$currentPid] = $true
        $allProcesses += $currentPid

        # Find direct children of current process
        try {
            $children = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
                Where-Object { $_.ParentProcessId -eq $currentPid } |
                Select-Object -ExpandProperty ProcessId

            $queue += @($children)
        } catch {
            # Query may fail if process already exited
        }
    }

    # Kill in reverse order (leaves first, then parents)
    [Array]::Reverse($allProcesses)
    $terminated = 0
    foreach ($procId in $allProcesses) {
        try {
            $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
            if ($proc -and -not $proc.HasExited) {
                Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
                $proc.WaitForExit(1000) | Out-Null
                $terminated++
            }
        } catch {
            # Process may have already exited - that's fine
        }
    }

    if ($terminated -gt 0) {
        Write-WatchdogLog "Terminated $terminated process(es) for PID $ParentPid ($Reason)" -Color DarkGray
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
    if (-not $agent.Process) { return }
    
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
            # Use recursive process tree cleanup for complete termination
            Stop-ProcessTree -ParentPid $agent.Process.Id -Reason $Reason

            # Ensure main process is terminated
            if (-not $agent.Process.HasExited) {
                $agent.Process.Kill()
                $agent.Process.WaitForExit(5000) | Out-Null
            }
        }
    } catch {
        # Log but continue cleanup
        Write-WatchdogLog "Error stopping $AgentName process: $_" -Color Yellow
    } finally {
        # Always dispose the process object to release handles
        if ($agent.Process) {
            try { $agent.Process.Dispose() } catch {}
        }
    }
    
    $Script:Agents[$AgentName].Process = $null
    $Script:Agents[$AgentName].ProcessState = "stopped"
    $Script:Agents[$AgentName].WorkStatus = "idle"
    $Script:Agents[$AgentName].CurrentMessage = $null
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
    <#
    .SYNOPSIS
    Start all agents with consolidation mode support.

    If consolidation is required (startup with pending messages):
    1. Start only PM first
    2. Wait for PM to consolidate and signal complete
    3. Then start workers
    #>
    Write-WatchdogLog "Starting all agents..." -Color Cyan

    # Check if consolidation is required
    $consolidationRequired = Test-ConsolidationRequired

    if ($consolidationRequired) {
        Write-WatchdogLog "CONSOLIDATION MODE: Pending messages detected, starting PM first..." -Color Yellow

        # Start only PM first
        $success = Start-Agent -AgentName "pm"
        if (-not $success) {
            Write-WatchdogLog "Failed to start PM" -Color Red
            # Fallback to normal startup
            $consolidationRequired = $false
        } else {
            # Wait for PM to consolidate
            Write-WatchdogLog "Waiting for PM to consolidate pending messages..." -Color Yellow

            $maxWaitSeconds = $config.ConsolidationTimeoutSeconds
            $startTime = [DateTime]::UtcNow
            $consolidationComplete = $false
            $waitIterations = 0  # For spinner animation

            # Initialize dashboard for the first time if not already done
            if (-not $Script:DashboardInitialized -and -not $NoDashboard) {
                Clear-Host
                [Console]::CursorVisible = $false
                $Script:DashboardInitialized = $true
            }

            while (([DateTime]::UtcNow - $startTime).TotalSeconds -lt $maxWaitSeconds) {
                # Update dashboard to show we're waiting (with spinner animation)
                $waitIterations++
                if (-not $NoDashboard) {
                    # Temporarily use wait iterations for spinner
                    $savedIterations = $Script:TotalIterations
                    $Script:TotalIterations = $waitIterations
                    Show-EventDashboard
                    $Script:TotalIterations = $savedIterations
                }

                Start-Sleep -Milliseconds 500

                $mode = Get-ConsolidationMode
                if ($mode -and $mode.mode -eq "normal") {
                    $consolidationComplete = $true
                    Write-WatchdogLog "PM consolidation complete! Starting workers..." -Color Green
                    break
                }

                # Check if PM is still running
                $pmProcess = $Script:Agents["pm"].Process
                if (-not $pmProcess -or $pmProcess.HasExited) {
                    Write-WatchdogLog "PM exited during consolidation" -Color Red
                    break
                }
            }

            if (-not $consolidationComplete) {
                Write-WatchdogLog "Consolidation timeout or failed - starting workers anyway" -Color Yellow
            }
        }
    }

    # Start workers (if not in consolidation mode, or after consolidation complete)
    foreach ($agentName in @("developer", "qa")) {
        # Skip if we're still waiting for consolidation
        if ($consolidationRequired -and -not $consolidationComplete) {
            # Will be started after consolidation in main loop
            continue
        }

        $success = Start-Agent -AgentName $agentName
        if (-not $success) {
            Write-WatchdogLog "Failed to start $agentName" -Color Red
        }
        Start-Sleep -Milliseconds 500
    }

    return $consolidationRequired
}

function Stop-AllAgents {
    param(
        [switch]$Graceful = $false,
        [string]$Reason = "shutdown"
    )
    
    Write-WatchdogLog "Stopping all agents..." -Color Cyan
    
    foreach ($agentName in @("pm", "developer", "qa")) {
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
                Write-WatchdogLog "Agent ready: $($msg.from)" -Color Green
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
        }
        
        # Acknowledge message
        $null = Invoke-AcknowledgeMessage -MessageId $msg.id -Agent "watchdog"
    }
}

function Invoke-StartWorkersAfterConsolidation {
    <#
    .SYNOPSIS
    Start worker agents after PM consolidation is complete.
    This is called from the main loop when consolidation mode transitions to normal.
    #>
    param()

    foreach ($agentName in @("developer", "qa")) {
        $agent = $Script:Agents[$agentName]

        # Skip if already running
        if ($agent.Process -and (-not $agent.Process.HasExited)) {
            continue
        }

        $success = Start-Agent -AgentName $agentName
        if ($success) {
            Write-WatchdogLog "$agentName started after consolidation" -Color Green
        } else {
            Write-WatchdogLog "Failed to start $agentName after consolidation" -Color Red
        }
        Start-Sleep -Milliseconds 500
    }
}

function Invoke-DeliverPendingMessages {
    <#
    .SYNOPSIS
    Check if agents have pending messages and deliver them by restarting agent with context
    This is the key mechanism - agents don't poll, watchdog delivers messages by restart

    Consolidation Mode: If consolidation is pending, only deliver to PM.
    Workers (developer, qa) will not receive messages until PM consolidates.
    #>

    $counts = Get-MessageCount

    # Check if consolidation is required
    $consolidationRequired = Test-ConsolidationRequired

    foreach ($agentName in @("pm", "developer", "qa")) {
        $count = $counts[$agentName]
        if ($count -gt 0) {
            $agent = $Script:Agents[$agentName]

            # CONSOLIDATION MODE CHECK: Skip workers if consolidation is pending
            # Only PM receives messages during consolidation
            if ($consolidationRequired -and $agentName -ne "pm") {
                # Workers don't get messages until PM consolidates
                continue
            }

            # Check if agent is currently working or starting - don't interrupt!
            $processIsRunning = $agent.Process -and (-not $agent.Process.HasExited)
            $isWorking = $agent.WorkStatus -in @("working", "starting")
            
            # Only deliver messages if agent is NOT actively working or booting
            # Deliver if: agent stopped, idle, ready, or waiting for input
            if ($processIsRunning -and $isWorking) {
                continue  # Don't interrupt working/starting agents - let them finish booting
            }
            
            # GRACE PERIOD CHECK: Don't re-deliver to an agent that just received messages
            # This prevents restart loops when acknowledgment or status updates are slow
            # EXCEPTION: If agent explicitly signals "ready", bypass grace period
            $timeSinceLastDelivery = ([DateTime]::UtcNow - $agent.LastDeliveryTime).TotalSeconds
            if ($agent.WorkStatus -ne "ready" -and $timeSinceLastDelivery -lt $Script:DeliveryGraceSeconds) {
                # Agent is working and still within grace period - skip
                continue
            }
            # If WorkStatus == "ready", deliver immediately regardless of grace period

            # CLEANUP VERIFICATION: Check if previous pending file is stale
            # If agent crashed without processing, we want to know before delivering more
            $isStale = Test-AgentPendingFileStale -AgentName $agentName
            if ($isStale) {
                Write-WatchdogLog "$agentName has stale pending file - may have crashed" -Color Yellow
                # Continue with delivery - new messages will replace old file
            }

            # Get the pending messages
            $pendingMessages = Get-PendingMessages -Agent $agentName
            
            if ($pendingMessages.Count -eq 0) { continue }
            
            Write-WatchdogLog "${agentName}: delivering $count message(s)" -Color Magenta
            
            # Stop the current agent if running (but not working - we already checked above)
            if ($processIsRunning) {
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
                
                # Acknowledge the message since we're delivering it
                $null = Invoke-AcknowledgeMessage -MessageId $msg.id -Agent $agentName
            }
            
            # Restart agent with the pending messages
            $null = Start-Agent -AgentName $agentName -PendingMessages $messageData
            
            # Track delivery time to enforce grace period
            $Script:Agents[$agentName].LastDeliveryTime = [DateTime]::UtcNow
            
            # Track the first/primary message being processed
            if ($messageData.Count -gt 0) {
                $Script:Agents[$agentName].CurrentMessage = $messageData[0]
            }
            
            $Script:TotalMessagesRouted += $count
            $Script:Agents[$agentName].LastActivity = [DateTime]::UtcNow
        }
    }
}

function Invoke-HealthCheck {
    if (([DateTime]::UtcNow - $Script:LastHealthCheck).TotalMilliseconds -lt $HealthCheckIntervalMs) {
        return
    }
    
    $Script:LastHealthCheck = [DateTime]::UtcNow
    
    foreach ($agentName in @("pm", "developer", "qa")) {
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
            "stale" {
                Write-WatchdogLog "$agentName appears stale" -Color Yellow
                # Could restart here if needed, but PM handles priority
            }
            "healthy" {
                # Healthy is normal - don't log
            }
        }
    }
}

# ============================================================================
# RESOURCE MANAGEMENT
# ============================================================================

$Script:LastResourceCleanup = [DateTime]::MinValue

function Invoke-ResourceCleanup {
    <#
    .SYNOPSIS
    Periodic cleanup of temp files and stale resources.

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
        # Clean stale runner scripts from log directory
        Get-ChildItem -Path $Script:LogDir -Filter "*-runner.ps1" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTimeUtc -lt [DateTime]::UtcNow.AddHours(-1) } |
            ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
        
        # Clean stale pending-messages files
        Get-ChildItem -Path $Script:SessionDir -Filter "pending-messages-*.json" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTimeUtc -lt [DateTime]::UtcNow.AddMinutes(-30) } |
            ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
            
    } catch {
        # Resource cleanup failure is non-critical
        Write-WatchdogLog "Resource cleanup error: $_" -Color Yellow
    }
}

# ============================================================================
# PID FILE MANAGEMENT
# ============================================================================

function Get-PidFilePath {
    return Join-Path $Script:SessionDir "watchdog.pid"
}

function Test-WatchdogAlreadyRunning {
    <#
    .SYNOPSIS
    Check if another watchdog instance is already running.
    Returns $true if conflict detected.
    #>
    $pidFile = Get-PidFilePath
    
    if (-not (Test-Path $pidFile)) { return $false }
    
    try {
        $existingPid = [int](Get-Content $pidFile -Raw -ErrorAction Stop)
        $existingProcess = Get-Process -Id $existingPid -ErrorAction SilentlyContinue
        
        if ($existingProcess) {
            # Process exists - check if it's actually a PowerShell/watchdog
            if ($existingProcess.ProcessName -match 'powershell|pwsh') {
                return $true
            }
        }
        
        # PID file is stale - remove it
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
        return $false
    } catch {
        # Can't parse PID file - remove it
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
        return $false
    }
}

function Write-PidFile {
    $pidFile = Get-PidFilePath
    try {
        $PID | Out-File -FilePath $pidFile -Encoding utf8 -Force
    } catch {
        Write-WatchdogLog "Failed to write PID file: $_" -Color Yellow
    }
}

function Remove-PidFile {
    $pidFile = Get-PidFilePath
    if (Test-Path $pidFile) {
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# DASHBOARD
# ============================================================================

# Track if dashboard has been initialized and content cache
$Script:DashboardInitialized = $false
$Script:LastDashboardContent = @{}
$Script:LastConsolidationMode = $null

function Write-LineAt {
    <#
    .SYNOPSIS
    Write a line of text at a specific console row with color.
    Uses change detection to reduce flicker.
    #>
    param(
        [int]$Row,
        [string]$Text,
        [ConsoleColor]$Color = [ConsoleColor]::White,
        [int]$Width = 80
    )

    # Truncate or pad to width
    if ($Text.Length -gt $Width) {
        $paddedText = $Text.Substring(0, $Width)
    } else {
        $paddedText = $Text.PadRight($Width)
    }

    # Only update if content changed (reduces flicker)
    $key = "row_$Row"
    $contentKey = "$paddedText|$Color"
    if ($Script:LastDashboardContent[$key] -eq $contentKey) {
        return
    }
    $Script:LastDashboardContent[$key] = $contentKey

    try {
        [Console]::SetCursorPosition(0, $Row)
        $oldColor = [Console]::ForegroundColor
        [Console]::ForegroundColor = $Color
        [Console]::Write($paddedText)
        [Console]::ForegroundColor = $oldColor
    } catch {
        # Silently ignore console errors
    }
}

function Write-ColoredLineAt {
    <#
    .SYNOPSIS
    Write a line with multiple colored segments at a specific console row.
    Uses change detection to reduce flicker.
    #>
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

    try {
        [Console]::SetCursorPosition(0, $Row)
        $totalLen = 0
        $oldColor = [Console]::ForegroundColor

        foreach ($seg in $Segments) {
            [Console]::ForegroundColor = [ConsoleColor]::$($seg.Color)
            [Console]::Write($seg.Text)
            $totalLen += $seg.Text.Length
        }

        # Pad remainder with background color
        if ($totalLen -lt $Width) {
            [Console]::ForegroundColor = [ConsoleColor]::Black
            [Console]::Write(" " * ($Width - $totalLen))
        }

        [Console]::ForegroundColor = $oldColor
    } catch {
        # Silently ignore console errors
    }
}

function Show-EventDashboard {
    <#
    .SYNOPSIS
    Display real-time dashboard using SetCursorPosition for updates.
    Uses change detection via Write-LineAt/Write-ColoredLineAt to reduce flicker.
    #>
    try {
        $width = 80
        $border = "=" * $width
        $separator = "  " + ("-" * 74)

        # First time: clear screen and hide cursor
        if (-not $Script:DashboardInitialized) {
            Clear-Host
            [Console]::CursorVisible = $false
            $Script:DashboardInitialized = $true
        }

        $row = 0

        # Header
        Write-LineAt -Row $row -Text $border -Color Cyan
        $row++
        Write-LineAt -Row $row -Text "  RALPH WATCHDOG - Event-Driven Multi-Agent Mode" -Color Cyan
        $row++
        Write-LineAt -Row $row -Text $border -Color Cyan
        $row++
        Write-LineAt -Row $row -Text "" -Color White
        $row++

        # Uptime with spinner (visual feedback that updates are working)
        $uptime = ([DateTime]::UtcNow - $Script:WatchdogStartTime)
        $uptimeStr = "{0:hh\:mm\:ss}" -f $uptime
        $spinner = @('|', '/', '-', '\')[$($Script:TotalIterations % 4)]
        Write-LineAt -Row $row -Text "  Uptime: $uptimeStr  |  Routed: $Script:TotalMessagesRouted  |  Cycles: $Script:TotalIterations $spinner" -Color White
        $row++
        Write-LineAt -Row $row -Text "" -Color White
        $row++

        # Consolidation mode status (fixed 2-3 rows)
        $consolidationMode = Get-ConsolidationMode
        $currentMode = if ($consolidationMode) { $consolidationMode.mode } else { "normal" }
        $isConsolidating = ($currentMode -eq "pending_consolidation")

        # Track mode changes for cache clearing
        if ($Script:LastConsolidationMode -ne $currentMode) {
            $Script:LastDashboardContent = @{}
            $Script:LastConsolidationMode = $currentMode
        }

        if ($isConsolidating) {
            Write-LineAt -Row $row -Text "  *** CONSOLIDATION MODE ACTIVE ***" -Color Yellow
            $row++
            $reasonText = if ($consolidationMode.reason) { $consolidationMode.reason.ToUpper() } else { "PENDING" }
            Write-LineAt -Row $row -Text "  PM is reviewing pending messages... (Reason: $reasonText)" -Color DarkYellow
            $row++
        } else {
            Write-LineAt -Row $row -Text "  Mode: NORMAL" -Color DarkGray
            $row++
            Write-LineAt -Row $row -Text "  All agents operational" -Color DarkGray
            $row++
        }
        Write-LineAt -Row $row -Text "" -Color White
        $row++

        # Agent section header
        Write-LineAt -Row $row -Text "  AGENTS" -Color Yellow
        $row++
        Write-LineAt -Row $row -Text $separator -Color White
        $row++
        Write-LineAt -Row $row -Text ("  " + "Agent".PadRight(10) + "Status".PadRight(12) + "PID".PadRight(10) + "Pending".PadRight(10) + "Current Message") -Color DarkGray
        $row++
        Write-LineAt -Row $row -Text $separator -Color White
        $row++

        # Get message counts once
        $counts = Get-MessageCount

        foreach ($agentName in @("pm", "developer", "qa")) {
            $agent = $Script:Agents[$agentName]
            $pendingCount = $counts[$agentName]
            $processRunning = $agent.Process -and (-not $agent.Process.HasExited)

            # Determine status - show waiting for consolidation
            if (-not $processRunning -and $isConsolidating -and $agentName -ne "pm") {
                $statusText = "WAITING (PM CONSO)"
                $statusColor = "Yellow"
            } elseif ($processRunning) {
                $statusText = $agent.WorkStatus.ToUpper()
                $statusColor = switch ($agent.WorkStatus) {
                    "idle" { "Gray" }
                    "working" { "Green" }
                    "waiting" { "Yellow" }
                    "ready" { "Cyan" }
                    "starting" { "Magenta" }
                    default { "White" }
                }
            } else {
                $statusText = "STOPPED"
                $statusColor = "Red"
            }

            $pidText = if ($processRunning) { $agent.Process.Id.ToString() } else { "-" }
            $pendingColor = if ($pendingCount -gt 0) { "Yellow" } else { "Gray" }

            $currentMsgText = "-"
            if ($agent.CurrentMessage) {
                $currentMsgText = "$($agent.CurrentMessage.type) from $($agent.CurrentMessage.from)"
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

        Write-LineAt -Row $row -Text $separator -Color White
        $row++
        Write-LineAt -Row $row -Text "" -Color White
        $row++

        # Message queue section
        Write-LineAt -Row $row -Text "  MESSAGE QUEUE" -Color Yellow
        $row++
        Write-LineAt -Row $row -Text $separator -Color White
        $row++

        $totalPending = ($counts.Values | Measure-Object -Sum).Sum

        foreach ($agentName in @("pm", "developer", "qa")) {
            $count = $counts[$agentName]
            $countColor = if ($count -gt 0) { "Yellow" } else { "DarkGray" }
            Write-ColoredLineAt -Row $row -Segments @(
                @{Text="  "; Color="White"},
                @{Text=$agentName.PadRight(12); Color="Cyan"},
                @{Text="$count pending"; Color=$countColor}
            )
            $row++
        }

        Write-LineAt -Row $row -Text "" -Color White
        $row++
        $totalColor = if ($totalPending -gt 0) { "Yellow" } else { "DarkGray" }
        Write-LineAt -Row $row -Text "  Total: $totalPending pending messages" -Color $totalColor
        $row++
        Write-LineAt -Row $row -Text $separator -Color White
        $row++
        Write-LineAt -Row $row -Text "" -Color White
        $row++

        # Activity Log section
        Write-LineAt -Row $row -Text "  ACTIVITY LOG" -Color Yellow
        $row++
        Write-LineAt -Row $row -Text $separator -Color White
        $row++

        # Show last N activity entries
        for ($i = 0; $i -lt $Script:MaxActivityLogSize; $i++) {
            if ($i -lt $Script:ActivityLog.Count) {
                Write-LineAt -Row $row -Text "  $($Script:ActivityLog[$i])" -Color DarkGray
            } else {
                Write-LineAt -Row $row -Text "" -Color White
            }
            $row++
        }

        Write-LineAt -Row $row -Text $separator -Color White
        $row++
        Write-LineAt -Row $row -Text "" -Color White
        $row++

        # Footer
        Write-LineAt -Row $row -Text $border -Color Cyan
        $row++
        if ($isConsolidating) {
            Write-LineAt -Row $row -Text "  *** WAITING FOR PM CONSOLIDATION *** Workers start after PM review" -Color Yellow
        } else {
            Write-LineAt -Row $row -Text "  Press Ctrl+C to stop watchdog" -Color DarkGray
        }
        $row++
        Write-LineAt -Row $row -Text $border -Color Cyan

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
    foreach ($agentName in @("pm", "developer", "qa")) {
        $logFile = Join-Path $Script:LogDir "$agentName.log"
        if (Test-Path $logFile) {
            $content = Get-Content $logFile -Tail 50 -ErrorAction SilentlyContinue | Out-String
            if ($content -match '<promise>RALPH_COMPLETE</promise>') {
                return $true
            }
        }
    }

    # Check coordinator-state.json for max iterations reached
    $stateFile = Join-Path $Script:SessionDir "coordinator-state.json"
    if (Test-Path $stateFile) {
        try {
            $state = Get-Content $stateFile -Raw | ConvertFrom-Json
            if ($state -and $state.iteration -ge $state.maxIterations) {
                Write-WatchdogLog "Max iterations reached: $($state.iteration)/$($state.maxIterations)" -Color Yellow
                # Update status
                $state.status = "max_iterations_reached"
                $state | ConvertTo-Json -Depth 10 | Out-File -FilePath $stateFile -Encoding UTF8
                return $true
            }
        } catch {
            # Ignore parsing errors
        }
    }

    return $false
}

# ============================================================================
# MAIN LOOP
# ============================================================================

function Start-EventWatchdog {
    # Check if another watchdog is already running
    if (Test-WatchdogAlreadyRunning) {
        Write-Host "[WATCHDOG] ERROR: Another watchdog instance is already running!" -ForegroundColor Red
        Write-Host "[WATCHDOG] Check $(Get-PidFilePath) for the existing process ID." -ForegroundColor Yellow
        exit 1
    }
    
    # Write PID file
    Write-PidFile
    
    # Register graceful shutdown handler for Ctrl+C and process exit
    $null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        Write-Host "`n[WATCHDOG] Received shutdown signal..." -ForegroundColor Yellow
        # Note: Stop-AllAgents will be called in the finally block
    }
    
    # Handle Ctrl+C gracefully
    [Console]::TreatControlCAsInput = $false
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
    
    # Initialize consolidation mode on startup
    $consolidationWasRequired = Initialize-ConsolidationForStartup
    if ($consolidationWasRequired) {
        Write-WatchdogLog "Startup consolidation mode initialized" -Color Yellow
    }

    # Start all agents (will handle consolidation mode)
    $consolidationWasRequired = Start-AllAgents

    # Track consolidation state for transition detection
    $Script:LastConsolidationMode = if ($consolidationWasRequired) { "pending_consolidation" } else { "normal" }

    # Main monitoring loop
    try {
        while (-not $Script:SessionComplete) {
            $Script:TotalIterations++

            # Process watchdog's own messages
            Invoke-ProcessWatchdogMessages

            # CHECK CONSOLIDATION TRANSITION: If we were in consolidation mode and now we're not
            $currentConsolidationMode = Get-ConsolidationMode
            $currentMode = if ($currentConsolidationMode) { $currentConsolidationMode.mode } else { "normal" }

            if ($Script:LastConsolidationMode -eq "pending_consolidation" -and $currentMode -eq "normal") {
                # Consolidation just completed - start workers if not already running
                try {
                    Write-WatchdogLog "Consolidation transition detected - starting workers" -Color Green
                    # Clear dashboard cache for fresh display after consolidation
                    $Script:LastDashboardContent = @{}
                    Invoke-StartWorkersAfterConsolidation
                } catch {
                    Write-WatchdogLog "ERROR starting workers after consolidation: $_" -Color Red
                    # Continue main loop even if worker startup fails
                }
            }

            $Script:LastConsolidationMode = $currentMode

            # Deliver pending messages to agents (stops and restarts agent with context)
            # This function now respects consolidation mode - won't deliver to workers if pending
            Invoke-DeliverPendingMessages

            # Periodic health check
            Invoke-HealthCheck

            # Periodic resource cleanup (every 100 iterations ~ 50 seconds at 500ms interval)
            if ($Script:TotalIterations % 100 -eq 0) {
                Invoke-ResourceCleanup
            }

            # Check for session completion
            if (Test-SessionComplete) {
                Write-WatchdogLog "Session complete detected!" -Color Green
                $Script:SessionComplete = $true
                break
            }

            # Update dashboard
            if (-not $NoDashboard) {
                Show-EventDashboard
            }

            # Heartbeat logging every ~10 seconds (20 iterations at 500ms interval)
            # This helps diagnose if the main loop stops running
            if ($Script:TotalIterations % 20 -eq 0) {
                $modeLabel = if ($currentMode -eq "pending_consolidation") { "CONSOLIDATION" } else { "NORMAL" }
                Write-WatchdogLog "Heartbeat: Iteration $Script:TotalIterations, Mode: $modeLabel" -Color DarkGray
            }

            Start-Sleep -Milliseconds $MessageCheckIntervalMs
        }
    }
    finally {
        # Restore cursor visibility
        [Console]::CursorVisible = $true
        $Script:DashboardInitialized = $false
        
        Write-Host ""
        Write-Host "[WATCHDOG] Watchdog stopping..." -ForegroundColor Cyan
        
        # Stop all agents
        Stop-AllAgents -Graceful -Reason "watchdog_shutdown"
        
        # Final cleanup
        Invoke-ResourceCleanup -Force
        
        # Remove PID file
        Remove-PidFile
        
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
    
    foreach ($agentName in @("pm", "developer", "qa")) {
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
