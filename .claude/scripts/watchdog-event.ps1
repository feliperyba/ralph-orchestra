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
    [int]$MaxIterations = 0,  # 0 = use config default
    [string]$Provider = ""    # CLI provider to use (claude, opencode)
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

# Initialize CLI provider
$Script:CliProvider = Initialize-RalphProvider -ProviderName $Provider -ProjectRoot $ProjectRoot
if ($Debug) {
    Write-Host "[WATCHDOG] Using CLI provider: $($Script:CliProvider.Name)" -ForegroundColor Cyan
    Write-Host "[WATCHDOG] Executable: $($Script:CliProvider.Executable)" -ForegroundColor DarkGray
}

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

    # Check if agent is already running (e.g. recovering from watchdog restart)
    if ($Script:Agents[$AgentName].ProcessState -eq "running" -and $Script:Agents[$AgentName].Process -and -not $Script:Agents[$AgentName].Process.HasExited) {
        Write-WatchdogLog "$AgentName is already running (PID: $($Script:Agents[$AgentName].Process.Id)). Skipping startup." -Color Yellow
        
        # If we had pending messages, we ensure the pending file exists so the running agent can (hopefully) pick them up
        if ($PendingMessages.Count -gt 0) {
            $pendingFile = Join-Path $Script:SessionDir "pending-messages-$AgentName.json"
            $pendingData = @{
                agent = $AgentName
                messageCount = $PendingMessages.Count
                messages = $PendingMessages
                timestamp = [DateTime]::UtcNow.ToString("o")
            }
            $pendingData | ConvertTo-Json -Depth 10 | Out-File -FilePath $pendingFile -Encoding UTF8
            Write-WatchdogLog "  Updated pending messages file for running agent $AgentName" -Color Magenta
        }
        
        return $true
    }
    
    # CLEANUP: If there is a lingering process object (dead/stopped), dispose it before starting new one
    if ($Script:Agents[$AgentName].Process) {
        try { $Script:Agents[$AgentName].Process.Dispose() } catch {}
        $Script:Agents[$AgentName].Process = $null
    }
    
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
    
    # Create inbox path for this agent
    $inboxPath = Join-Path $paths.SessionDir "messages/$AgentName"
    
    # Write pending messages to a context file for agent to read on startup (FALLBACK)
    # Primary delivery is via --message CLI argument
    $pendingFile = Join-Path $Script:SessionDir "pending-messages-$AgentName.json"
    $pendingFileForScript = $pendingFile  # Same path, used in script generation
    $messageJsonArg = ""
    if ($PendingMessages.Count -gt 0) {
        # Build --message argument (primary delivery path)
        # Pass only the messages array as compact JSON
        $messageJsonArg = $PendingMessages | ConvertTo-Json -Depth 10 -Compress
        
        # Keep pending file as fallback for safety (until fully validated)
        $pendingData = @{
            agent = $AgentName
            messageCount = $PendingMessages.Count
            messages = $PendingMessages
            timestamp = [DateTime]::UtcNow.ToString("o")
        }
        $pendingData | ConvertTo-Json -Depth 10 | Out-File -FilePath $pendingFile -Encoding UTF8
        Write-WatchdogLog "Delivered $($PendingMessages.Count) messages to $AgentName (via --message + fallback file)" -Color Magenta
    } else {
        # If no new messages provided, CHECK if there is an existing pending file.
        # If so, we are likely restarting a crashed/stale agent effectively in "Recovery Mode" implicitly.
        # We should PRESERVE the file so the agent can find it.
        if (Test-Path $pendingFile) {
             try {
                $existingContent = Get-Content $pendingFile -Raw | ConvertFrom-Json
                 $existingMessages = @($existingContent.messages)
                 if ($existingMessages.Count -gt 0) {
                     # Found existing work. Load it for the CLI argument!
                     $messageJsonArg = $existingMessages | ConvertTo-Json -Depth 10 -Compress
                     Write-WatchdogLog "Resumed $AgentName with existing pending file ($($existingMessages.Count) messages)" -Color DarkYellow
                }
             } catch {
                 # File corrupt? Then we can delete it.
                 Remove-Item $pendingFile -Force
             }
        }
    }
    
    # Create runner script with sanitized values to prevent command injection
    $safeProjectRoot = Get-SafeScriptString $ProjectRoot
    $safePendingFile = Get-SafeScriptString $pendingFileForScript
    $safeLogFile = Get-SafeScriptString $logFile
    $safeSessionDir = Get-SafeScriptString $paths.SessionDir
    # Note: $slashCommand is from a trusted switch statement, not user input
    
    # Build script logic for message handling
    # Use Here-String for JSON to avoid complex escaping issues
    $messageHandlingScript = ""
    if ($messageJsonArg) {
        # Check against pure literal '@ to prevent here-string breakout (unlikely in JSON)
        $safeJson = $messageJsonArg -replace "'@", "' @ " 
        
        $messageHandlingScript = @"
`$jsonPayload = @'
$safeJson
'@
# Escape double quotes for Windows CMD/Batch compatibility
# This prevents CMD from consuming the quotes when passing args to claude.cmd
`$safePayload = `$jsonPayload -replace '"', '\"'
`$messageArg = " --message '`$safePayload'"
"@
    } else {
        $messageHandlingScript = "`$messageArg = `"`""
    }
    
    # Get provider-specific MCP config args
    $mcpArgs = $Script:CliProvider.GetMcpConfigArgs($AgentName, $ProjectRoot)
    $mcpArg = if ($mcpArgs.Count -gt 0) { " " + ($mcpArgs -join " ") } else { "" }

    # Prepare display string for generated script (cleanly checks variable)
    $scriptMcpCheck = ""
    if ($mcpArg -ne "") {
       $safeDisplayArgs = ($mcpArg.Trim() -replace '"', '`"') -replace '\$', '`$'
       $scriptMcpCheck = "Write-Host ""MCP Config: $safeDisplayArgs"" -ForegroundColor DarkGray`n"
    }

    # Get provider info for script generation
    $cliExecutable = $Script:CliProvider.Executable
    $cliDefaultArgs = $Script:CliProvider.DefaultArgs -join " "
    $cliDisplayName = $Script:CliProvider.GetDisplayName()

    $scriptContent = @"
`$Host.UI.RawUI.WindowTitle = "$windowTitle"
Set-Location "$safeProjectRoot"

Write-Host "========================================"  -ForegroundColor Cyan
Write-Host "  RALPH EVENT-DRIVEN: $AgentName" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Mode: EVENT-DRIVEN MULTI-AGENT"
Write-Host "Working Dir: $safeProjectRoot"
Write-Host "CLI Provider: $cliDisplayName" -ForegroundColor DarkGray
$scriptMcpCheck
Write-Host ""

# Check for pending messages delivered by watchdog (FALLBACK - primary is --message)
`$pendingFile = "$safePendingFile"
if (Test-Path `$pendingFile) {
    Write-Host "PENDING MESSAGES AVAILABLE (fallback file):" -ForegroundColor Yellow
    Get-Content `$pendingFile | Write-Host -ForegroundColor DarkYellow
    Write-Host ""
}

# Prepare JSON payload securely
    $messageHandlingScript

    Write-Host "Starting $cliDisplayName..." -ForegroundColor Yellow
    Write-Host ""
    
    # Run CLI with message argument (primary delivery) + file fallback
    `$exitCode = 0
    try {
        # Build the prompt with slash command and message
        `$prompt = "$slashCommand" + `$messageArg
        
        # Debug output
        # Write-Host "DEBUG Prompt: `$prompt" -ForegroundColor DarkGray
        
        $cliExecutable$mcpArg $cliDefaultArgs "`$prompt"
        `$exitCode = `$LASTEXITCODE
    } catch {
        Write-Host "ERROR: `$_" -ForegroundColor Red
        `$exitCode = 1
    }

    Write-Host ""
    Write-Host "========================================"  -ForegroundColor Yellow
    Write-Host "  Agent session ended (exit code: `$exitCode)" -ForegroundColor Yellow
    Write-Host "========================================"  -ForegroundColor Yellow
    
    # PROCESS EXIT HANDLER (Telemetry only)
    # IMPORTANT: Process exit does NOT mean message batch completion.
    # Completion is authoritative only when watchdog receives explicit status_update
    # with an unlock state (idle|waiting|ready).
    
    if (`$exitCode -eq 0) {
        Write-Host "Agent process exited cleanly. Waiting for explicit watchdog status updates to unlock queue." -ForegroundColor Green
    } else {
        Write-Host "Task failed (Exit Code `$exitCode). Preserving pending file for recovery." -ForegroundColor Red
    }

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
        
        # Write PID file for process tracking (persistence across watchdog restarts)
        $agentPidFile = Join-Path $paths.SessionDir "$AgentName.pid"
        try {
            $process.Id | Out-File -FilePath $agentPidFile -Encoding utf8 -Force
        } catch {
            Write-WatchdogLog "Warning: Failed to write PID file for $AgentName" -Color Yellow
        }

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
        # always dispose
                 # Always dispose the process object to release handles
        if ($agent.Process) {
            try { $agent.Process.Dispose() } catch {}
        }
    }
    
    # Remove PID file
    $agentPidFile = Join-Path $paths.SessionDir "$AgentName.pid"
    if (Test-Path $agentPidFile) {
        Remove-Item $agentPidFile -Force -ErrorAction SilentlyContinue
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

function Restore-AgentState {
    Write-WatchdogLog "Checking for running agents from previous session..." -Color Cyan
    
    foreach ($agentName in $Script:Agents.Keys) {
        $pidFile = Join-Path $paths.SessionDir "$agentName.pid"
        
        if (Test-Path $pidFile) {
            try {
                $agentPid = Get-Content $pidFile -ErrorAction SilentlyContinue
                if ($agentPid) {
                    $proc = Get-Process -Id $agentPid -ErrorAction SilentlyContinue
                    
                    if ($proc -and -not $proc.HasExited) {
                        Write-WatchdogLog "  Found running agent: $agentName (PID: $agentPid)" -Color Green
                        
                        $Script:Agents[$agentName].Process = $proc
                        $Script:Agents[$agentName].ProcessState = "running"
                        $Script:Agents[$agentName].StartTime = $proc.StartTime
                        $Script:Agents[$agentName].LastActivity = [DateTime]::UtcNow
                        
                        # Check for pending transactional file
                        $pendingFile = Join-Path $paths.SessionDir "pending-messages-$agentName.json"
                        if (Test-Path $pendingFile) {
                             $Script:Agents[$agentName].WorkStatus = "working"
                             Write-WatchdogLog "  - Agent has pending task - marking as working" -Color DarkYellow
                        } else {
                             # Agent running but no pending file. 
                             # It might have finished and is waiting, or is idle.
                             # We'll mark it idle so it can receive new messages.
                             $Script:Agents[$agentName].WorkStatus = "idle"
                             Write-WatchdogLog "  - Agent has no pending task - marking as idle" -Color DarkGreen
                        }
                    } else {
                        Write-WatchdogLog "  Found stale PID ($agentPid) for $agentName. Cleaning up." -Color DarkGray
                        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
                    }
                }
            } catch {
                Write-WatchdogLog "  Error checking PID for $agentName : $_" -Color Red
            }
        }
    }
}

function Start-AllAgents {
    # Attempt to restore state from previous session first
    Restore-AgentState

    Write-WatchdogLog "Starting agents in PM-first initialization mode..." -Color Cyan

    # PM-FIRST MODE: Always start PM agent first
    # PM will assess state, clear stale messages, and send activation messages to workers as needed
    # This eliminates wasteful idle agent startup - workers only run when they have work
    Write-WatchdogLog "Starting PM agent to assess session state and activate workers..." -Color Green
    $null = Start-Agent -AgentName "pm"

    # Note: Workers will be started by watchdog when:
    # 1. PM sends task_assign → Developer starts
    # 2. PM sends test_plan_request → QA starts
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

        # 4. Resource Cleanup (Garbage Collection)
        # Prevents deadlocks from stale pending files (older than 30m)
        Invoke-ResourceCleanup

        # 5. Check for session completion
        if (Test-SessionComplete) {
            Write-WatchdogLog "Session complete - shutting down agents" -Color Green
            $Script:SessionComplete = $true
            break
        }

        # 5. Update dashboard
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

    foreach ($agentName in @("pm", "developer", "qa", "gamedesigner", "techartist")) {
        Stop-Agent -AgentName $agentName -Graceful:$Graceful -Reason $Reason
    }
}

# ============================================================================
# MESSAGE ROUTING
# ============================================================================

function Get-PendingBatchData {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,

        [Parameter(Mandatory=$true)]
        [string]$PendingFilePath
    )

    if (-not (Test-Path $PendingFilePath)) {
        return $null
    }

    try {
        $raw = Get-Content $PendingFilePath -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $null
        }

        $pendingData = $raw | ConvertFrom-Json -ErrorAction Stop
        if (-not $pendingData.messages) {
            return $null
        }

        return $pendingData
    } catch {
        Write-WatchdogLog "Failed reading pending batch for $AgentName: $_" -Color Red
        return $null
    }
}

function Get-StatusAckMessageIds {
    param(
        [Parameter(Mandatory=$true)]
        [object]$StatusPayload,

        [object[]]$PendingMessages = @(),

        [object]$CurrentMessage = $null
    )

    $ackMap = @{}
    $pendingIds = @($PendingMessages | ForEach-Object { [string]$_.id } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    if ($StatusPayload -and $StatusPayload.PSObject.Properties["processedMessageIds"]) {
        foreach ($id in @($StatusPayload.processedMessageIds)) {
            $idStr = [string]$id
            if (-not [string]::IsNullOrWhiteSpace($idStr)) {
                $ackMap[$idStr] = $true
            }
        }
    }

    if ($StatusPayload -and $StatusPayload.PSObject.Properties["processedMessageId"]) {
        $singleId = [string]$StatusPayload.processedMessageId
        if (-not [string]::IsNullOrWhiteSpace($singleId)) {
            $ackMap[$singleId] = $true
        }
    }

    if ($ackMap.Count -eq 0 -and $StatusPayload -and $StatusPayload.PSObject.Properties["processedMessageCount"]) {
        $processedCount = [int]$StatusPayload.processedMessageCount
        if ($processedCount -ge $pendingIds.Count -and $pendingIds.Count -gt 0) {
            foreach ($id in $pendingIds) {
                $ackMap[$id] = $true
            }
        }
    }

    # Backward compatibility for legacy single-message status updates.
    if ($ackMap.Count -eq 0 -and $pendingIds.Count -eq 1 -and $CurrentMessage -and $CurrentMessage.id) {
        $ackMap[[string]$CurrentMessage.id] = $true
    }

    return @($ackMap.Keys)
}

function Invoke-ProcessWatchdogMessages {
    # Process messages sent to watchdog (status updates, etc.)
    $messages = Get-PendingMessages -Agent "watchdog" -TimeoutMs $config.MessageProcessingTimeoutMs -ReadAll
    
    foreach ($msg in $messages) {
        switch ($msg.type) {
            "agent_ready" {
                Write-WatchdogLog "Agent ready: $($msg.from)" -Color Green
            }
            "status_update" {
                $agentName = $msg.from
                $Script:Agents[$agentName].LastActivity = [DateTime]::UtcNow
                $Script:Agents[$agentName].WorkStatus = $msg.payload.status  # Update WorkStatus, not ProcessState
                $Script:Agents[$agentName].CurrentTask = $msg.payload.currentTask
                
                # CRITICAL: Unlock only after explicit message-level acknowledgement.
                if ($msg.payload.status -in @("idle", "waiting", "ready", "awaiting_pm", "awaiting_gd")) {
                    $pendingFile = Join-Path $paths.SessionDir "pending-messages-$agentName.json"

                    if (Test-Path $pendingFile) {
                        $pendingData = Get-PendingBatchData -AgentName $agentName -PendingFilePath $pendingFile

                        if ($pendingData -and $pendingData.messages) {
                            $pendingMessages = @($pendingData.messages)
                            if ($pendingMessages.Count -eq 0) {
                                Write-WatchdogLog "Pending file for $agentName has no messages; preserving for recovery." -Color Yellow
                                continue
                            }

                            $pendingIds = @($pendingMessages | ForEach-Object { [string]$_.id } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                            $ackIdsFromStatus = Get-StatusAckMessageIds -StatusPayload $msg.payload -PendingMessages $pendingMessages -CurrentMessage $Script:Agents[$agentName].CurrentMessage
                            $ackSet = @{}
                            foreach ($id in $ackIdsFromStatus) { $ackSet[[string]$id] = $true }

                            $ackableIds = @($pendingIds | Where-Object { $ackSet.ContainsKey($_) })
                            if ($ackableIds.Count -eq 0) {
                                Write-WatchdogLog "Agent $agentName signaled '$($msg.payload.status)' without explicit processed IDs/count. Preserving pending batch." -Color Yellow
                            }

                            foreach ($processedId in $ackableIds) {
                                $null = Invoke-AcknowledgeMessageSafe -MessageId $processedId -Agent $agentName -Result @{
                                    acknowledgedByStatusMessageId = $msg.id
                                    unlockedStatus = $msg.payload.status
                                    acknowledgedAt = [DateTime]::UtcNow.ToString("o")
                                }
                            }

                            $remainingMessages = @($pendingMessages | Where-Object {
                                $msgId = [string]$_.id
                                -not $ackSet.ContainsKey($msgId)
                            })

                            if ($remainingMessages.Count -eq 0) {
                                Remove-Item $pendingFile -Force -ErrorAction SilentlyContinue
                                Write-WatchdogLog "Agent $agentName acknowledged complete batch ($($pendingIds.Count) message(s)). Cleared pending file." -Color Green
                                $Script:Agents[$agentName].CurrentMessage = $null
                            } else {
                                $ackedHistory = @()
                                if ($pendingData.PSObject.Properties["ackedMessageIds"] -and $pendingData.ackedMessageIds) {
                                    $ackedHistory = @($pendingData.ackedMessageIds)
                                }

                                $ackedMap = @{}
                                foreach ($id in $ackedHistory) {
                                    $idStr = [string]$id
                                    if (-not [string]::IsNullOrWhiteSpace($idStr)) { $ackedMap[$idStr] = $true }
                                }
                                foreach ($id in $ackableIds) {
                                    $idStr = [string]$id
                                    if (-not [string]::IsNullOrWhiteSpace($idStr)) { $ackedMap[$idStr] = $true }
                                }

                                $pendingData.messages = @($remainingMessages)
                                $pendingData.messageCount = $remainingMessages.Count
                                $pendingData.ackedMessageIds = @($ackedMap.Keys)
                                $pendingData.lastAckAt = [DateTime]::UtcNow.ToString("o")
                                $pendingData | ConvertTo-Json -Depth 12 | Out-File -FilePath $pendingFile -Encoding UTF8

                                $Script:Agents[$agentName].CurrentMessage = if ($remainingMessages.Count -gt 0) { $remainingMessages[0] } else { $null }
                                Write-WatchdogLog "Agent $agentName acknowledged $($ackableIds.Count)/$($pendingIds.Count). Preserved $($remainingMessages.Count) pending message(s)." -Color Yellow
                            }
                        } else {
                            Write-WatchdogLog "Pending file for $agentName is unreadable or empty; preserving for recovery." -Color Yellow
                        }
                    } else {
                        $Script:Agents[$agentName].CurrentMessage = $null
                    }
                }
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
            $agent = $Script:Agents[$agentName]
            
            # Check if agent is currently working or starting - don't interrupt!
            $processIsRunning = $agent.Process -and (-not $agent.Process.HasExited)
            $isWorking = $agent.WorkStatus -in @("working", "starting")
            
            # Only deliver messages if agent is NOT actively working or booting
            # Deliver if: agent stopped, idle, ready, or waiting for input
            if ($processIsRunning -and $isWorking) {
                continue  # Don't interrupt working/starting agents - let them finish booting
            }
            
            # DELIVERY BLOCKER CHECK:
            # If the pending-messages file exists, it means the agent hasn't finished the PREVIOUS batch.
            $pendingFile = Join-Path $paths.SessionDir "pending-messages-$agentName.json"
            $isRecovery = $false
            
            if (Test-Path $pendingFile) {
                 # Check if agent is actually dead/crashed, in which case we might need to restart with the SAME file
                 $health = Test-AgentHealth -AgentName $agentName
                 if ($health -eq "dead") {
                     Write-WatchdogLog "$agentName is dead but has pending file. Restarting in RECOVERY mode." -Color Yellow
                     $isRecovery = $true
                 } else {
                     # Agent is alive and file exists -> It is processing. Do not disturb.
                     continue 
                 }
            }

            # GRACE PERIOD CHECK (Skip if Recovery)
            if (-not $isRecovery) {
                $timeSinceLastDelivery = ([DateTime]::UtcNow - $agent.LastDeliveryTime).TotalSeconds
                if ($timeSinceLastDelivery -lt $Script:DeliveryGraceSeconds) {
                    continue
                }
            }
            
            # Get pending messages (from INBOX)
            $pendingMessages = Get-PendingMessages -Agent $agentName -TimeoutMs $config.MessageProcessingTimeoutMs -ReadAll
            
            # If NOT in recovery mode, we need items in inbox to proceed
            if (-not $isRecovery -and $pendingMessages.Count -eq 0) { continue }
            
            # If we are in RECOVERY mode, $pendingMessages from inbox might be empty, and that's OK.
            # We will rely on the file.
            
            if ($pendingMessages.Count -gt 0) {
               Write-WatchdogLog "${agentName}: delivering $($pendingMessages.Count) new message(s)" -Color Magenta
            }
            
            # Stop the current agent if running (but not working - we already checked above)
            # In recovery mode, process is dead, so this is skipped mostly, but good for cleanup
            if ($processIsRunning) {
                Write-WatchdogLog "Interrupting $agentName to deliver new priority messages" -Color Yellow
                Stop-Agent -AgentName $agentName -Reason "message_delivery"
                
                # Update the pending list if any processing messages were reverted (unlikely in this flow)
                $pendingMessages = Get-PendingMessages -Agent $agentName -TimeoutMs $config.MessageProcessingTimeoutMs -ReadAll
                Start-Sleep -Seconds 2
            }
            
            # Convert messages to simple format for agent
            $messageData = @()
            foreach ($msg in $pendingMessages) {
                # Ensure we don't pass the _filePath internal property
                $payload = if ($msg.psobject.Properties["payload"]) { $msg.payload } else { $null }
                
                $messageData += @{
                    id = $msg.id
                    from = $msg.from
                    type = $msg.type
                    priority = $msg.priority
                    payload = $payload
                    timestamp = $msg.timestamp
                }
            }

            # Restart agent with the pending messages FIRST
            
            # Setup mode variables
            $mode = "new"
            if ($isRecovery) { $mode = "recovery" }
            
            if ($mode -eq "recovery") {
                 # Recovery mode: Pending file exists.
                 # We must read from it because $pendingMessages (from inbox) is likely empty.
                 try {
                    $recoveryJson = Get-Content $pendingFile -Raw
                    if ([string]::IsNullOrWhiteSpace($recoveryJson)) { throw "Empty file" }
                    
                    $recoveryData = $recoveryJson | ConvertFrom-Json
                    
                    # INFINITE LOOP PROTECTION
                    # Check retry count in the file metadata
                    if ($recoveryData.retryCount -ge 3) {
                         Write-WatchdogLog "Agent $agentName stuck in restart loop (3 retries). Quarantining task." -Color Red
                         
                         $quarantineFile = Join-Path $paths.SessionDir "messages/quarantine/stuck-$agentName-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
                         if (-not (Test-Path (Split-Path $quarantineFile))) { New-Item -ItemType Directory -Path (Split-Path $quarantineFile) -Force }
                         
                         Move-Item $pendingFile -Destination $quarantineFile -Force
                         
                         # Clear status and continue
                         $Script:Agents[$agentName].WorkStatus = "crashed"
                         continue
                    }
                    
                    # Increment retry count
                    if (-not $recoveryData.PSObject.Properties["retryCount"]) {
                        $recoveryData | Add-Member -NotePropertyName "retryCount" -NotePropertyValue 0
                    }
                    $recoveryData.retryCount++
                    $recoveryData | ConvertTo-Json -Depth 10 | Out-File -FilePath $pendingFile -Encoding UTF8
                    
                    if ($recoveryData.messages) {
                        $messageData = @($recoveryData.messages)
                         Write-WatchdogLog "  Loaded $($messageData.Count) messages from recovery file (Retry #$($recoveryData.retryCount))" -Color DarkYellow
                    }
                } catch {
                     Write-WatchdogLog "Failed to read pending file for recovery: $_" -Color Red
                     # If file is corrupt, we can't recover. Delete it to unblock.
                     Remove-Item $pendingFile -Force -ErrorAction SilentlyContinue
                     continue
                }
            } else {
                # New delivery mode: Write inbox snapshot to pending file.
                # Inbox files are acknowledged/deleted only after explicit completion proof.
                $batchId = "batch-$agentName-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$([guid]::NewGuid().ToString().Substring(0,8))"
                $messageIds = @($messageData | ForEach-Object { $_.id })
                 $pendingData = @{
                    batchId = $batchId
                    agent = $agentName
                    messageCount = $messageData.Count
                    messageIds = $messageIds
                    ackedMessageIds = @()
                    messages = $messageData
                    timestamp = [DateTime]::UtcNow.ToString("o")
                }
                $pendingData | ConvertTo-Json -Depth 10 | Out-File -FilePath $pendingFile -Encoding UTF8
            }

            $agentStarted = Start-Agent -AgentName $agentName -PendingMessages $messageData

            if ($agentStarted) {
                # Track delivery time to enforce grace period
                $Script:Agents[$agentName].LastDeliveryTime = [DateTime]::UtcNow
            } else {
                Write-WatchdogLog "Failed to start $agentName" -Color Red
                # NOTE: We do NOT delete the pending file. It stays there for next retry.
                continue
            }
            
            # Track the first/primary message being processed
            if ($messageData.Count -gt 0) {
                $Script:Agents[$agentName].CurrentMessage = $messageData[0]
            }
            
            $Script:Agents[$agentName].LastActivity = [DateTime]::UtcNow
        }
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
                 # Agent process ended (Process.HasExited = True).
                 # This might be normal (one-off script finished) or crash.
                 
                $pendingFile = Join-Path $paths.SessionDir "pending-messages-$agentName.json"
                if (Test-Path $pendingFile) {
                    # Agent died but pending file still exists -> CRASH / INCOMPLETE
                    # We must restart the agent to re-process this file.
                    Write-WatchdogLog "$agentName process ended but pending file remains. Restarting recovery." -Color Red
                    
                    # We call Stop-Agent just to clean up handles, then triggering DeliverPendingMessages
                    # by resetting WorkStatus will catch it in next tick (via Recovery Mode)
                    Stop-Agent -AgentName $agentName 
                    $Script:Agents[$agentName].WorkStatus = "crashed" # Signal to loop
                } else {
                    # Agent died and pending file is GONE -> SUCCESS
                    # Status update cleared it. Normal shutdown.
                    if ($Script:Agents[$agentName].WorkStatus -ne "idle") {
                         $Script:Agents[$agentName].WorkStatus = "idle"
                    }
                }
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

        # Detect stale pending-messages files (NO AUTO-DELETE)
        # We never delete pending batches here to avoid silent message loss.
        Get-ChildItem -Path $Script:SessionDir -Filter "pending-messages-*.json" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTimeUtc -lt [DateTime]::UtcNow.AddMinutes(-30) } |
            ForEach-Object {
                $file = $_
                Write-WatchdogLog "STALE PENDING DETECTED: $($file.Name). Preserving for recovery and retry." -Color Yellow
            }

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

    # Check coordinator-state.json for max iterations reached
    # Note: Use watchdog's own MaxIterationsLimit, not coordinator state
    # The coordinator handles its own iteration counting
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
