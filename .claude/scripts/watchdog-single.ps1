# Ralph Watchdog - Single Active Agent Mode
# Only one agent runs at a time, watchdog orchestrates handoffs
# Run: .\.claude\scripts\watchdog-single.ps1
#
# Key Features:
# 1. NEVER EXITS on its own - runs until Ctrl+C or RALPH_COMPLETE
# 2. Only ONE agent active at any time (saves tokens)
# 3. Agents write to handoff-signal.json to request handoff
# 4. Watchdog detects handoff, gracefully stops current agent, starts next
# 5. Context is passed to next agent via pending-handoff.json + state files

param(
    [int]$GracefulShutdownSeconds = 30,    # Wait for agent to save state
    [int]$HandoffCheckIntervalMs = 1000,   # Check for handoff signals
    [int]$MaxRestarts = 3,                 # Retries before waiting longer
    [switch]$NoDashboard = $false,
    [switch]$Debug = $false,               # Enable verbose debug output
    [string]$ProjectRoot = "",
    [string]$InitialAgent = "pm",          # Which agent starts first
    [int]$MaxIterations = 0                # 0 = use config default
)

$ErrorActionPreference = "Stop"

# Determine project root
if (-not $ProjectRoot) {
    $ProjectRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
}

# Source configuration
. "$PSScriptRoot\ralph-config.ps1"

$config = Get-RalphConfig
$paths = Get-RalphPaths -ProjectRoot $ProjectRoot

# Directories
$Script:LogDir = Join-Path $paths.SessionDir "logs"
$Script:SessionDir = $paths.SessionDir
if (-not (Test-Path $Script:LogDir)) {
    New-Item -ItemType Directory -Path $Script:LogDir -Force | Out-Null
}

# ============================================================================
# STATE TRACKING
# ============================================================================

$Script:WatchdogStartTime = [DateTime]::UtcNow
$Script:TotalIterations = 0
$Script:TotalHandoffs = 0
$Script:ActiveAgent = $null
$Script:AgentProcess = $null
$Script:AgentStartTime = $null
$Script:AgentRestartCount = 0
$Script:HandoffLog = @()
$Script:PendingHandoff = $null
$Script:SessionComplete = $false

# Max iterations - use parameter or config default
$Script:MaxIterationsLimit = if ($MaxIterations -gt 0) { $MaxIterations } else { $config.MaxIterations }

# ============================================================================
# HANDOFF PROTOCOL
# ============================================================================

# Handoff phrase patterns:
# Format: "HANDOFF:agent_name:context_message"
# Example: "HANDOFF:developer:Implement feat-001 - Add user auth"
# Context is plain text (no encoding needed)
# Pattern is lenient to handle transcript formatting

$Script:HandoffPattern = 'HANDOFF\s*:\s*(pm|developer|qa)\s*:\s*(.+)'
$Script:CompletionPattern = '<promise>RALPH_COMPLETE</promise>'
$Script:GracefulExitPattern = 'AGENT_READY_FOR_HANDOFF'

function Test-HandoffRequest {
    param(
        [string]$AgentName,
        [switch]$Verbose = $false
    )
    
    # PRIMARY: Check for handoff signal file (most reliable method)
    $signalFile = Join-Path $Script:SessionDir "handoff-signal.json"
    
    if (Test-Path $signalFile) {
        try {
            $signalContent = Get-Content $signalFile -Raw | ConvertFrom-Json
            
            # Check if it's a completion signal
            if ($signalContent.type -eq "complete") {
                Write-Host "[WATCHDOG] Detected COMPLETE signal in handoff-signal.json" -ForegroundColor Green
                # Remove signal file after reading
                Remove-Item $signalFile -Force
                return @{
                    Type = "complete"
                    TargetAgent = $null
                    Context = "All tasks completed"
                }
            }
            
            # Check if it's a handoff signal
            if ($signalContent.targetAgent) {
                $targetAgent = $signalContent.targetAgent
                $context = $signalContent.context
                
                # Security: Validate target agent name
                $validAgents = @("pm", "developer", "qa")
                if ($targetAgent -notin $validAgents) {
                    Write-Host "[WATCHDOG] Invalid target agent in signal: $targetAgent" -ForegroundColor Red
                    Remove-Item $signalFile -Force
                    return $null
                }
                
                Write-Host "[WATCHDOG] Detected handoff signal: -> $targetAgent" -ForegroundColor Magenta
                Write-Host "[WATCHDOG] Context: $context" -ForegroundColor DarkMagenta
                
                # Remove signal file after reading
                Remove-Item $signalFile -Force
                
                return @{
                    Type = "handoff"
                    TargetAgent = $targetAgent
                    Context = $context
                }
            }
        } catch {
            Write-Host "[WATCHDOG] Error parsing handoff-signal.json: $_" -ForegroundColor Red
        }
    }
    
    # FALLBACK: Check log file for handoff patterns (less reliable but backup)
    $logFile = Join-Path $Script:LogDir "$AgentName.log"
    
    if (-not (Test-Path $logFile)) { 
        if ($Verbose) { Write-Host "[HANDOFF-CHECK] No log file yet: $logFile" -ForegroundColor DarkGray }
        return $null 
    }
    
    try {
        # Read last 100 lines to find handoff request
        $lines = Get-Content $logFile -Tail 100 -ErrorAction SilentlyContinue
        $content = $lines -join "`n"
        
        if ($Verbose) {
            Write-Host "[HANDOFF-CHECK] Read $($lines.Count) lines from log" -ForegroundColor DarkGray
        }
        
        # Check for completion first
        if ($content -match $Script:CompletionPattern) {
            return @{
                Type = "complete"
                TargetAgent = $null
                Context = "All tasks completed"
            }
        }
        
        # Check for handoff request in log output
        if ($content -match $Script:HandoffPattern) {
            $targetAgent = $Matches[1]
            $contextMessage = $Matches[2].Trim()
            
            Write-Host "[WATCHDOG] Detected handoff in log: $targetAgent" -ForegroundColor Magenta
            Write-Host "[WATCHDOG] Context: $contextMessage" -ForegroundColor DarkMagenta
            
            return @{
                Type = "handoff"
                TargetAgent = $targetAgent
                Context = $contextMessage
            }
        }
        
        # Check if we see AGENT_READY_FOR_HANDOFF but no handoff pattern (helpful debug)
        if ($content -match $Script:GracefulExitPattern) {
            Write-Host "[WATCHDOG] Agent signaled ready for handoff but no HANDOFF: line found!" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[WATCHDOG] Error reading log: $_" -ForegroundColor Red
    }
    
    return $null
}

function New-HandoffContext {
    param(
        [string]$FromAgent,
        [string]$ToAgent,
        [string]$Reason,
        [hashtable]$TaskInfo = @{}
    )
    
    $context = @{
        from = $FromAgent
        to = $ToAgent
        reason = $Reason
        timestamp = [DateTime]::UtcNow.ToString("o")
        task = $TaskInfo
    }
    
    $json = $context | ConvertTo-Json -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    return [System.Convert]::ToBase64String($bytes)
}

function Write-HandoffLog {
    param(
        [string]$FromAgent,
        [string]$ToAgent,
        [string]$Reason,
        [string]$Context
    )
    
    $entry = @{
        timestamp = [DateTime]::UtcNow.ToString("o")
        from = $FromAgent
        to = $ToAgent
        reason = $Reason
        context = $Context
    }
    
    $Script:HandoffLog += $entry
    $Script:TotalHandoffs++
    
    # Also write to handoff-log.json
    $logFile = Join-Path $Script:SessionDir "handoff-log.json"
    
    $logData = @{
        sessionId = "ralph-single-$($Script:WatchdogStartTime.ToString('yyyyMMdd-HHmmss'))"
        handoffs = $Script:HandoffLog
    }
    
    $logData | ConvertTo-Json -Depth 10 | Out-File -FilePath $logFile -Encoding UTF8
}

function Update-CoordinatorState {
    param(
        [string]$ActiveAgent,
        [string]$PendingHandoff = $null,
        [string]$HandoffContext = $null
    )
    
    $stateFile = Join-Path $Script:SessionDir "coordinator-state.json"
    
    $state = @{}
    if (Test-Path $stateFile) {
        try {
            $state = Get-Content $stateFile -Raw | ConvertFrom-Json -AsHashtable
        } catch {
            $state = @{}
        }
    }
    
    # Update fields
    $state.currentAgent = $ActiveAgent
    $state.lastUpdate = [DateTime]::UtcNow.ToString("o")
    $state.orchestrationMode = "single-agent"
    
    if ($PendingHandoff) {
        $state.pendingHandoff = @{
            targetAgent = $PendingHandoff
            context = $HandoffContext
            requestedAt = [DateTime]::UtcNow.ToString("o")
        }
    } else {
        $state.pendingHandoff = $null
    }
    
    $state | ConvertTo-Json -Depth 10 | Out-File -FilePath $stateFile -Encoding UTF8
}

# ============================================================================
# AGENT MANAGEMENT
# ============================================================================

# Security: Escape strings for safe embedding in generated scripts
function Get-SafeScriptString {
    param([string]$Value)
    # Escape backticks first, then double quotes, then dollar signs
    return $Value -replace '`', '``' -replace '"', '`"' -replace '\$', '`$'
}

function Start-SingleAgent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,
        [string]$HandoffContext = $null
    )
    
    $logFile = Join-Path $Script:LogDir "$AgentName.log"
    
    # Clear old log file
    if (Test-Path $logFile) {
        Remove-Item $logFile -Force
    }
    "" | Out-File -FilePath $logFile -Encoding utf8
    
    # Determine slash command - using single-agent versions
    # Format: /command-name for commands in .claude/commands/
    $slashCommand = switch ($AgentName) {
        "pm" { "/ralph-coordinator-single" }
        "developer" { "/ralph-worker-single --agent developer" }
        "qa" { "/ralph-worker-single --agent qa" }
    }
    
    Write-Host "[WATCHDOG] Starting $AgentName agent..." -ForegroundColor Cyan
    Write-Host "[WATCHDOG]   Command: claude `"$slashCommand`" --dangerously-skip-permissions" -ForegroundColor DarkGray
    
    # Build runner script with handoff context
    $windowTitle = "Ralph Single-Agent: $AgentName"
    $scriptFile = Join-Path $Script:LogDir "$AgentName-runner.ps1"
    
    # Write handoff context to a file that the agent will read on startup
    $handoffFile = Join-Path $Script:SessionDir "pending-handoff.json"
    if ($HandoffContext) {
        $handoffData = @{
            targetAgent = $AgentName
            context = $HandoffContext
            timestamp = [DateTime]::UtcNow.ToString("o")
        }
        $handoffData | ConvertTo-Json -Depth 10 | Out-File -FilePath $handoffFile -Encoding UTF8
        Write-Host "[WATCHDOG]   Handoff context written to: $handoffFile" -ForegroundColor DarkGray
    } else {
        # Clear any pending handoff
        if (Test-Path $handoffFile) {
            Remove-Item $handoffFile -Force
        }
    }
    
    # Create runner script with sanitized values to prevent command injection
    # Primary handoff detection is via handoff-signal.json file
    # Log file is secondary/backup
    $safeProjectRoot = Get-SafeScriptString $ProjectRoot
    $safeHandoffFile = Get-SafeScriptString $handoffFile
    $safeLogFile = Get-SafeScriptString $logFile
    # Note: $slashCommand is from a trusted switch statement, not user input
    
    $scriptContent = @"
`$Host.UI.RawUI.WindowTitle = "$windowTitle"
Set-Location "$safeProjectRoot"

Write-Host "========================================"  -ForegroundColor Cyan
Write-Host "  RALPH SINGLE-AGENT: $AgentName" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Mode: SINGLE-AGENT ORCHESTRATION"
Write-Host "Slash Command: $slashCommand"
Write-Host "Working Dir: $safeProjectRoot"
Write-Host ""

# Check for pending handoff context
`$handoffFile = "$safeHandoffFile"
if (Test-Path `$handoffFile) {
    Write-Host "Handoff Context Available" -ForegroundColor Yellow
    Get-Content `$handoffFile | Write-Host -ForegroundColor DarkGray
    Write-Host ""
}

Write-Host "IMPORTANT: When done, write to .claude/session/handoff-signal.json" -ForegroundColor Magenta
Write-Host ""
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

# Write exit status for watchdog
`$exitCode | Out-File -FilePath "$safeLogFile.exit" -Encoding utf8

# Keep window open briefly
Start-Sleep -Seconds 5
"@

    # Write script
    $scriptContent | Out-File -FilePath $scriptFile -Encoding utf8 -Force
    
    try {
        # Start in new window (no -NoExit so window closes when script ends)
        $process = Start-Process "powershell.exe" `
            -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptFile `
            -PassThru `
            -WindowStyle Normal
        
        $Script:ActiveAgent = $AgentName
        $Script:AgentProcess = $process
        $Script:AgentStartTime = [DateTime]::UtcNow
        
        # Update coordinator state
        Update-CoordinatorState -ActiveAgent $AgentName
        
        Write-Host "[WATCHDOG] $AgentName started (PID: $($process.Id))" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "[WATCHDOG] Failed to start $AgentName : $_" -ForegroundColor Red
        return $false
    }
}

function Stop-SingleAgent {
    param(
        [switch]$Graceful = $false,
        [string]$Reason = "unknown"
    )
    
    if (-not $Script:AgentProcess) { return }
    
    $agentName = $Script:ActiveAgent
    Write-Host "[WATCHDOG] Stopping $agentName (Reason: $Reason)..." -ForegroundColor Yellow
    
    if ($Graceful) {
        Write-Host "[WATCHDOG] Waiting ${GracefulShutdownSeconds}s for graceful shutdown..." -ForegroundColor DarkGray
        
        # Wait for agent to output AGENT_READY_FOR_HANDOFF or timeout
        $deadline = [DateTime]::UtcNow.AddSeconds($GracefulShutdownSeconds)
        $readyForHandoff = $false
        
        while ([DateTime]::UtcNow -lt $deadline) {
            $logFile = Join-Path $Script:LogDir "$agentName.log"
            if (Test-Path $logFile) {
                $content = Get-Content $logFile -Tail 20 -ErrorAction SilentlyContinue | Out-String
                if ($content -match $Script:GracefulExitPattern) {
                    $readyForHandoff = $true
                    Write-Host "[WATCHDOG] Agent signaled ready for handoff" -ForegroundColor Green
                    break
                }
            }
            Start-Sleep -Milliseconds 500
        }
        
        if (-not $readyForHandoff) {
            Write-Host "[WATCHDOG] Graceful timeout - forcing stop" -ForegroundColor Yellow
        }
    }
    
    try {
        if (-not $Script:AgentProcess.HasExited) {
            # Kill child processes first
            $parentPid = $Script:AgentProcess.Id
            Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | 
                Where-Object { $_.ParentProcessId -eq $parentPid } | 
                ForEach-Object {
                    try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
                }
            
            $Script:AgentProcess.Kill()
            $Script:AgentProcess.WaitForExit(5000) | Out-Null
        }
    } catch {}
    
    $Script:ActiveAgent = $null
    $Script:AgentProcess = $null
}

function Invoke-Handoff {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FromAgent,
        [Parameter(Mandatory=$true)]
        [string]$ToAgent,
        [string]$Context = ""
    )
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "  HANDOFF: $FromAgent -> $ToAgent" -ForegroundColor Magenta
    Write-Host "  Context: $Context" -ForegroundColor DarkMagenta
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host ""
    
    # Log handoff
    Write-HandoffLog -FromAgent $FromAgent -ToAgent $ToAgent -Reason "agent_request" -Context $Context
    
    # Gracefully stop current agent
    Stop-SingleAgent -Graceful -Reason "handoff_to_$ToAgent"
    Start-Sleep -Seconds 2
    
    # Create simple handoff message for next agent
    $handoffMessage = @"
## Handoff from $FromAgent

$Context

---
Read current-task.json and coordinator-state.json for full details.
"@
    
    # Start new agent with context
    $success = Start-SingleAgent -AgentName $ToAgent -HandoffContext $handoffMessage
    
    if (-not $success) {
        $Script:AgentRestartCount++
        Write-Host "[WATCHDOG] Failed to start agent (attempt $($Script:AgentRestartCount))" -ForegroundColor Yellow
        
        # Never give up - wait and retry
        if ($Script:AgentRestartCount -gt $MaxRestarts) {
            Write-Host "[WATCHDOG] Multiple failures - waiting 30s before retry..." -ForegroundColor Yellow
            Start-Sleep -Seconds 30
            $Script:AgentRestartCount = 0
        }
        
        # Keep trying
        Start-Sleep -Seconds 5
        return Start-SingleAgent -AgentName $ToAgent -HandoffContext $handoffMessage
    }
    
    return $success
}

# ============================================================================
# DASHBOARD
# ============================================================================

function Show-SingleAgentDashboard {
    try {
        $width = 80
        $border = "=" * $width
        
        Clear-Host
        Write-Host $border -ForegroundColor Cyan
    Write-Host "  RALPH WATCHDOG - Single Active Agent Mode" -ForegroundColor Cyan
    Write-Host $border -ForegroundColor Cyan
    Write-Host ""
    
    # Uptime
    $uptime = ([DateTime]::UtcNow - $Script:WatchdogStartTime)
    $uptimeStr = "{0:hh\:mm\:ss}" -f $uptime
    Write-Host "  Uptime: $uptimeStr  |  Handoffs: $Script:TotalHandoffs  |  Iterations: $Script:TotalIterations" -ForegroundColor White
    Write-Host ""
    
    # Current agent status
    Write-Host "  ACTIVE AGENT" -ForegroundColor Yellow
    Write-Host "  $("-" * 74)"
    
    if ($Script:ActiveAgent -and $Script:AgentProcess) {
        $agentName = $Script:ActiveAgent
        $agentPid = $Script:AgentProcess.Id
        $status = if ($Script:AgentProcess.HasExited) { "EXITED" } else { "RUNNING" }
        $statusColor = if ($Script:AgentProcess.HasExited) { "Red" } else { "Green" }
        
        $runTime = ([DateTime]::UtcNow - $Script:AgentStartTime)
        $runTimeStr = "{0:hh\:mm\:ss}" -f $runTime
        
        Write-Host "  Agent: " -NoNewline
        Write-Host "$agentName" -ForegroundColor Cyan -NoNewline
        Write-Host "  |  PID: $agentPid  |  Status: " -NoNewline
        Write-Host "$status" -ForegroundColor $statusColor -NoNewline
        Write-Host "  |  Runtime: $runTimeStr"
    } else {
        Write-Host "  No active agent" -ForegroundColor Gray
    }
    
    Write-Host "  $("-" * 74)"
    Write-Host ""
    
    # Recent handoffs
    if ($Script:HandoffLog.Count -gt 0) {
        Write-Host "  RECENT HANDOFFS (last 5)" -ForegroundColor Yellow
        Write-Host "  $("-" * 74)"
        
        $recentHandoffs = $Script:HandoffLog | Select-Object -Last 5
        foreach ($h in $recentHandoffs) {
            $time = ([DateTime]::Parse($h.timestamp)).ToString("HH:mm:ss")
            Write-Host "  $time  " -NoNewline -ForegroundColor DarkGray
            Write-Host "$($h.from)" -NoNewline -ForegroundColor Cyan
            Write-Host " -> " -NoNewline
            Write-Host "$($h.to)" -ForegroundColor Green -NoNewline
            Write-Host "  ($($h.reason))"
        }
        Write-Host "  $("-" * 74)"
        Write-Host ""
    }
    
    # Logs
    Write-Host "  LOGS" -ForegroundColor Yellow
    Write-Host "  $Script:LogDir"
    Write-Host ""
    
    Write-Host $border -ForegroundColor Cyan
    Write-Host "  Press Ctrl+C to stop watchdog" -ForegroundColor DarkGray
    Write-Host $border -ForegroundColor Cyan
    
    } catch {
        # Silently ignore dashboard errors - don't crash watchdog
        Write-Host "[WATCHDOG] Dashboard error (ignored): $_" -ForegroundColor DarkGray
    }
}

# ============================================================================
# MAIN LOOP
# ============================================================================

function Start-SingleAgentWatchdog {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  RALPH WATCHDOG - Single Agent Mode" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Project: $ProjectRoot"
    Write-Host "Initial Agent: $InitialAgent"
    Write-Host "Graceful Shutdown: ${GracefulShutdownSeconds}s"
    Write-Host "Log Dir: $Script:LogDir"
    Write-Host ""
    
    # Start initial agent
    $success = Start-SingleAgent -AgentName $InitialAgent
    if (-not $success) {
        Write-Host "[WATCHDOG] Failed to start initial agent. Exiting." -ForegroundColor Red
        return
    }
    
    Write-Host ""
    Write-Host "[WATCHDOG] Monitoring for handoff requests..." -ForegroundColor Green
    Write-Host ""
    
    # Main monitoring loop
    try {
        $lastLogCheck = [DateTime]::MinValue
        
        while (-not $Script:SessionComplete) {
            $Script:TotalIterations++
            
            # FIRST: Check for handoff request BEFORE checking if process exited
            # This prevents treating a graceful handoff as a crash
            $handoffRequest = $null
            if ($Script:ActiveAgent) {
                $handoffRequest = Test-HandoffRequest -AgentName $Script:ActiveAgent
                
                # Every 10 seconds, show we're alive and checking
                if (([DateTime]::UtcNow - $lastLogCheck).TotalSeconds -ge 10) {
                    $logFile = Join-Path $Script:LogDir "$($Script:ActiveAgent).log"
                    $logSize = 0
                    if (Test-Path $logFile) {
                        $logSize = (Get-Item $logFile).Length
                    }
                    Write-Host "[WATCHDOG] Checking $($Script:ActiveAgent) - Log size: $logSize bytes - Iteration: $($Script:TotalIterations)" -ForegroundColor DarkGray
                    $lastLogCheck = [DateTime]::UtcNow
                }
            }
            
            if ($handoffRequest) {
                switch ($handoffRequest.Type) {
                    "complete" {
                        Write-Host ""
                        Write-Host "[WATCHDOG] Session complete - all tasks finished!" -ForegroundColor Green
                        $Script:SessionComplete = $true
                        break
                    }
                    "handoff" {
                        # Execute handoff - this will stop current agent and start next
                        Invoke-Handoff `
                            -FromAgent $Script:ActiveAgent `
                            -ToAgent $handoffRequest.TargetAgent `
                            -Context $handoffRequest.Context

                        # Reset restart counter on successful handoff
                        $Script:AgentRestartCount = 0

                        # Skip the rest of this iteration - new agent is starting
                        Start-Sleep -Milliseconds $HandoffCheckIntervalMs
                        continue
                    }
                }
            }

            # Check for max iterations reached
            $stateFile = Join-Path $Script:SessionDir "coordinator-state.json"
            if (Test-Path $stateFile) {
                try {
                    $state = Get-Content $stateFile -Raw | ConvertFrom-Json
                    if ($state -and $state.iteration -ge $state.maxIterations) {
                        Write-Host ""
                        Write-Host "[WATCHDOG] Max iterations reached: $($state.iteration)/$($state.maxIterations)" -ForegroundColor Yellow
                        # Update status
                        $state.status = "max_iterations_reached"
                        $state | ConvertTo-Json -Depth 10 | Out-File -FilePath $stateFile -Encoding UTF8
                        $Script:SessionComplete = $true
                        break
                    }
                } catch {
                    # Ignore parsing errors
                }
            }
            
            # Only check for unexpected exit if no handoff was requested
            if ($Script:AgentProcess -and $Script:AgentProcess.HasExited) {
                # Check one more time if there was a handoff we missed
                $finalCheck = Test-HandoffRequest -AgentName $Script:ActiveAgent
                if ($finalCheck -and $finalCheck.Type -eq "handoff") {
                    # This was a graceful exit after handoff request
                    Invoke-Handoff `
                        -FromAgent $Script:ActiveAgent `
                        -ToAgent $finalCheck.TargetAgent `
                        -Context $finalCheck.Context
                    $Script:AgentRestartCount = 0
                    continue
                }
                
                Write-Host ""
                Write-Host "[WATCHDOG] Agent process exited without handoff!" -ForegroundColor Yellow
                
                # Show last few lines of log for debugging
                $logFile = Join-Path $Script:LogDir "$($Script:ActiveAgent).log"
                if (Test-Path $logFile) {
                    Write-Host "[WATCHDOG] Last 10 lines of agent log:" -ForegroundColor DarkYellow
                    Get-Content $logFile -Tail 10 | ForEach-Object {
                        Write-Host "  $_" -ForegroundColor DarkGray
                    }
                }
                Write-Host ""
                
                $Script:AgentRestartCount++
                
                # Never give up - just wait longer between retries
                if ($Script:AgentRestartCount -gt $MaxRestarts) {
                    Write-Host "[WATCHDOG] Multiple agent failures - waiting 30s before retry..." -ForegroundColor Yellow
                    Write-Host "[WATCHDOG] (Watchdog stays running - press Ctrl+C to stop)" -ForegroundColor DarkGray
                    Start-Sleep -Seconds 30
                    $Script:AgentRestartCount = 0
                }
                
                Write-Host "[WATCHDOG] Restarting agent (attempt $($Script:AgentRestartCount + 1))..." -ForegroundColor Yellow
                
                # Restart same agent
                Start-Sleep -Seconds 2
                Start-SingleAgent -AgentName $Script:ActiveAgent
            }
            
            # Update dashboard
            if (-not $NoDashboard) {
                Show-SingleAgentDashboard
            }
            
            Start-Sleep -Milliseconds $HandoffCheckIntervalMs
        }
    }
    finally {
        Write-Host ""
        Write-Host "[WATCHDOG] Watchdog stopping..." -ForegroundColor Cyan
        
        # Stop any running agent
        if ($Script:AgentProcess -and -not $Script:AgentProcess.HasExited) {
            Stop-SingleAgent -Graceful -Reason "watchdog_shutdown"
        }
        
        # Write summary
        Write-SingleAgentSummary
    }
}

function Write-SingleAgentSummary {
    $summaryFile = Join-Path $Script:LogDir "watchdog-summary.log"
    $uptime = ([DateTime]::UtcNow - $Script:WatchdogStartTime)
    
    $summary = @"
================================================================================
RALPH WATCHDOG - SINGLE AGENT MODE - SESSION SUMMARY
================================================================================
Start Time:    $($Script:WatchdogStartTime.ToString('yyyy-MM-dd HH:mm:ss')) UTC
End Time:      $([DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) UTC
Total Uptime:  $("{0:hh\:mm\:ss}" -f $uptime)
Total Handoffs: $Script:TotalHandoffs
Iterations:    $Script:TotalIterations
Session Complete: $Script:SessionComplete

--------------------------------------------------------------------------------
HANDOFF HISTORY
--------------------------------------------------------------------------------
"@
    
    foreach ($h in $Script:HandoffLog) {
        $summary += "`n  $($h.timestamp): $($h.from) -> $($h.to) ($($h.reason))"
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
    Start-SingleAgentWatchdog
} catch {
    Write-Host "[WATCHDOG] Fatal error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    exit 1
}
