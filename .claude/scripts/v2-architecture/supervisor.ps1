# Ralph Supervisor Module - Actor Lifecycle Management
# Implements Erlang/OTP-style supervision trees
#
# Design Patterns Applied:
# - Actor Model with Supervision Trees (Erlang/OTP)
# - Let-it-crash philosophy
# - Restart strategies: one_for_one, one_for_all, rest_for_one
#
# References:
# - https://www.erlang.org/doc/design_principles/sup_princ

# Source required modules
$Script:SupervisorModuleDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import event log for event sourcing
$eventLogModule = Join-Path $Script:SupervisorModuleDir "eventlog.ps1"
if (Test-Path $eventLogModule) {
    . $eventLogModule
} else {
    Write-Warning "[Supervisor] eventlog.ps1 not found at $eventLogModule"
}

# Import event bus for pipe management
$eventBusModule = Join-Path $Script:SupervisorModuleDir "event-bus.ps1"
if (Test-Path $eventBusModule) {
    . $eventBusModule
} else {
    Write-Warning "[Supervisor] event-bus.ps1 not found at $eventBusModule"
}

# ============================================================================
# SUPERVISOR CLASS
# ============================================================================

class ActorSupervisor {
    [System.Collections.Generic.Dictionary[string,object]]$Actors
    [System.Collections.Generic.Dictionary[string,object]]$CLIProcesses
    [string]$SessionDir
    [string]$Name
    [datetime]$StartedAt
    [int]$TotalRestarts

    # Constructor
    ActorSupervisor([string]$SessionDir, [string]$Name = "main") {
        $this.Actors = [System.Collections.Generic.Dictionary[string,object]]::new()
        $this.CLIProcesses = [System.Collections.Generic.Dictionary[string,object]]::new()
        $this.SessionDir = $SessionDir
        $this.Name = $Name
        $this.StartedAt = [DateTime]::UtcNow
        $this.TotalRestarts = 0

        # Initialize event log
        $logPath = Initialize-EventLog -SessionDir $SessionDir

        # Initialize event bus
        Initialize-EventBus -SessionDir $SessionDir

        # Rebuild state from event log (recovery from crash)
        $this.RebuildState()
    }

    # Start an actor (agent)
    [void] StartActor([string]$AgentName) {
        $this.StartActor($AgentName, "permanent", 3, "one-for-one")
    }

    [void] StartActor([string]$AgentName, [string]$RestartType, [int]$MaxRestarts, [string]$RestartStrategy) {
        # Check if actor is already running
        if ($this.Actors.ContainsKey($AgentName)) {
            Write-Host "[SUP] Actor $AgentName already running" -ForegroundColor Yellow
            return
        }

        # Check if actor is currently being disposed (prevents race condition)
        $disposingKey = "__disposing__$AgentName"
        if ($this.Actors.ContainsKey($disposingKey)) {
            Write-Host "[SUP] Actor $AgentName is currently being disposed, retrying..." -ForegroundColor Yellow
            Start-Sleep -Milliseconds 500
            # Retry once after disposal completes
            if ($this.Actors.ContainsKey($AgentName)) {
                Write-Host "[SUP] Actor $AgentName already running (after disposal)" -ForegroundColor Yellow
                return
            }
        }

        Write-Host "[SUP] Starting actor: $AgentName" -ForegroundColor Cyan

        # Create pipe for this agent (event bus)
        $pipe = New-BidirectionalPipe -AgentName $AgentName

        # Start agent process
        $process = $this.StartAgentProcess($AgentName)

        # Wait for pipe connection
        $connected = Wait-PipeConnection -AgentName $AgentName -TimeoutMs 30000
        if (-not $connected) {
            throw "Failed to connect to $AgentName pipe after 30 seconds"
        }

        # Create actor record
        $actor = @{
            Name = $AgentName
            Process = $process
            Pipe = $pipe
            RestartStrategy = $RestartStrategy
            RestartType = $RestartType
            RestartCount = 0
            MaxRestarts = $MaxRestarts
            LastRestart = $null
            StartedAt = [DateTime]::UtcNow
        }

        $this.Actors[$AgentName] = $actor

        # Log the event
        Write-AgentStartedEvent -AgentName $AgentName -AgentPid $process.Id
        Write-Host "[SUP] Actor $AgentName started (PID: $($process.Id))" -ForegroundColor Green
    }

    # Internal method to start an agent process
    [System.Diagnostics.Process] StartAgentProcess([string]$AgentName) {
        # V2: Start PowerShell bridge process directly (not via CLI slash commands)
        # The bridge connects to the pipe and stays alive for message delivery
        # When work arrives, watchdog restarts the actual CLI agent with context

        # Derive project root from SessionDir (SessionDir is .claude\session, project root is 2 levels up)
        $sessionDirItem = Get-Item $this.SessionDir
        $projectRoot = $sessionDirItem.Parent.Parent.FullName

        # Path to agent runtime script
        $runtimeScript = Join-Path $projectRoot ".claude\scripts\v2-architecture\agent-runtime.ps1"

        if (-not (Test-Path $runtimeScript)) {
            throw "Agent runtime script not found: $runtimeScript"
        }

        # Start PowerShell bridge process
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { . '$runtimeScript'; Start-AgentLoop -AgentName '$AgentName' }`""

        # Process settings
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        # Log the command being run for diagnostics
        Write-Host "[SUP] Starting: $($psi.FileName) $($psi.Arguments)" -ForegroundColor DarkGray

        try {
            $process = [System.Diagnostics.Process]::Start($psi)
            return $process
        } catch {
            throw "Failed to start agent bridge: $_`n  FileName: $($psi.FileName)`n  Arguments: $($psi.Arguments)"
        }
    }

    # Main supervision loop - check all actors
    [void] Supervise() {
        foreach ($agentName in $this.Actors.Keys) {
            $actor = $this.Actors[$agentName]

            # Check if process has exited
            if ($actor.Process.HasExited) {
                $this.HandleActorExit($actor)
            }
        }
    }

    # Handle actor exit
    [void] HandleActorExit([object]$Actor) {
        $agentName = $Actor.Name
        $exitCode = $Actor.Process.ExitCode

        # Log the exit
        Write-AgentExitedEvent -AgentName $agentName -ExitCode $exitCode

        # Check for graceful shutdown (42 = our intentional shutdown code)
        if ($exitCode -eq 42) {
            Write-Host "[SUP] Actor $agentName shut down intentionally (code: 42)" -ForegroundColor Green
            $this.Actors.Remove($agentName)
            return
        }

        # For V2 architecture, "permanent" agents are always restarted
        # Exit code 0 just means the agent completed its current task, not that it should stop
        if ($Actor.RestartType -eq "permanent") {
            if ($exitCode -eq 0) {
                Write-Host "[SUP] Actor $agentName completed task (code: 0), restarting..." -ForegroundColor Cyan
            }
            $this.RestartActor($Actor, $exitCode)
        } elseif ($Actor.RestartType -eq "transient") {
            # Only restart if abnormal exit (not normal)
            if ($exitCode -ne 0) {
                $this.RestartActor($Actor, $exitCode)
            } else {
                $this.Actors.Remove($agentName)
            }
        } else {
            # temporary - never restart
            Write-Host "[SUP] Actor $agentName is temporary, not restarting" -ForegroundColor Yellow
            $this.Actors.Remove($agentName)
        }
    }

    # Restart an actor after crash
    [void] RestartActor([object]$Actor, [int]$ExitCode) {
        $agentName = $Actor.Name

        # Check restart limit
        if ($Actor.RestartCount -ge $Actor.MaxRestarts) {
            Write-Host "[SUP] Actor $agentName exceeded max restarts ($($Actor.MaxRestarts))" -ForegroundColor Red
            $this.Actors.Remove($agentName)
            return
        }

        # Exponential backoff delay - but NOT for successful task completion (exit code 0)
        if ($ExitCode -ne 0) {
            $delay = [Math]::Min(5 * [Math]::Pow(2, $Actor.RestartCount), 60)
            Write-Host "[SUP] Waiting ${delay}s before restarting $agentName..." -ForegroundColor Yellow
            Start-Sleep -Seconds $delay
        } else {
            # Immediate restart for successful task completion
            Start-Sleep -Milliseconds 100  # Brief pause to let resources free up
        }

        # CRITICAL FIX: Mark actor as disposing BEFORE removal to prevent race condition
        # If we remove first, another StartActor call could create a new pipe
        # while we're still disposing the old one, causing the old disposal to close the new pipe
        $disposingKey = "__disposing__$agentName"
        $this.Actors[$disposingKey] = $true

        try {
            # FIRST: Dispose all resources while still tracked
            if ($Actor.Pipe) {
                try {
                    if ($Actor.Pipe.Pipe -and -not $Actor.Pipe.Pipe.IsDisposed) {
                        # Disconnect if connected
                        if ($Actor.Pipe.Pipe.IsConnected) {
                            try {
                                $Actor.Pipe.Pipe.Disconnect()
                            } catch {
                                # Ignore disconnect errors
                            }
                        }
                        # Dispose to release pipe handle
                        $Actor.Pipe.Pipe.Dispose()
                        Write-Host "[SUP] Disposed pipe for $agentName" -ForegroundColor DarkGray
                    }
                } catch {
                    # Ignore dispose errors
                }
            }

            # Also call Close-Pipe to clean up event bus state
            Close-Pipe -AgentName $agentName

            # Extra delay to let OS release the pipe
            Start-Sleep -Milliseconds 200

            # SECOND: Now safe to remove from dictionary
            $this.Actors.Remove($agentName)

            try {
                # Restart with same configuration
                $this.StartActor(
                    $agentName,
                    $Actor.RestartType,
                    $Actor.MaxRestarts,
                    $Actor.RestartStrategy
                )

                # Increment restart count
                $this.Actors[$agentName].RestartCount = $Actor.RestartCount + 1
                $this.TotalRestarts++

                Write-Host "[SUP] Restarted $agentName (restart #$($Actor.RestartCount + 1))" -ForegroundColor Yellow
            } catch {
                Write-Warning "[SUP] Failed to restart $agentName`: $_"
            }
        } finally {
            # Clean up disposing marker
            $this.Actors.Remove($disposingKey)
        }
    }

    # Stop an actor gracefully
    [void] StopActor([string]$AgentName) {
        if (-not $this.Actors.ContainsKey($AgentName)) {
            Write-Host "[SUP] Actor $AgentName not running" -ForegroundColor Yellow
            return
        }

        $actor = $this.Actors[$AgentName]

        Write-Host "[SUP] Stopping actor $AgentName..." -ForegroundColor Yellow

        # Try to send shutdown message first
        if ($actor.Pipe.Connected) {
            Send-MessageToAgent -AgentName $AgentName -Message @{
                type = "Shutdown"
                timestamp = [DateTime]::UtcNow.ToString("o")
            } -ErrorAction SilentlyContinue
        }

        # Wait for graceful exit (up to 30 seconds)
        $exited = $actor.Process.WaitForExit(30000)

        if (-not $exited -or -not $actor.Process.HasExited) {
            Write-Warning "[SUP] $AgentName did not exit gracefully, forcing termination"
            try {
                $actor.Process.Kill()
            } catch {
                # Already exited
            }
        }

        # Clean up
        Close-Pipe -AgentName $AgentName
        $this.Actors.Remove($AgentName)

        Write-Host "[SUP] Actor $AgentName stopped" -ForegroundColor Green
    }

    # Stop all actors
    [void] StopAll() {
        Write-Host "[SUP] Stopping all actors..." -ForegroundColor Yellow

        # First, clean up any CLI processes
        foreach ($kv in $this.CLIProcesses.GetEnumerator()) {
            $cliInfo = $kv.Value
            try {
                if (-not $cliInfo.Process.HasExited) {
                    Write-Host "[SUP] Stopping CLI process: $($kv.Key)" -ForegroundColor Yellow
                    $cliInfo.Process.Kill()
                }
            } catch {
                # Already exited
            }
        }
        $this.CLIProcesses.Clear()

        # Stop in reverse order of start (dependencies)
        $reversedActors = @($this.Actors.Keys)
        [Array]::Reverse($reversedActors) | ForEach-Object {
            $this.StopActor($_)
        }

        Write-Host "[SUP] All actors stopped" -ForegroundColor Green
    }

    # Spawn a CLI process for an agent (VISIBLE WINDOW)
    [string] SpawnCLIProcess([string]$AgentName, [string]$MessageFile, [string]$ResponseFile) {
        $invokeId = "cli-$AgentName-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$(Get-Random -Minimum 1000 -Maximum 9999)"

        Write-Host "[SUP] Spawning CLI for $AgentName (ID: $invokeId)" -ForegroundColor Cyan

        # Determine CLI command based on agent
        $cliCommand = if ($AgentName -eq "pm") {
            "/ralph-coordinator-event"
        } else {
            "/ralph-worker-event --agent $AgentName"
        }

        # Start CLI process with VISIBLE WINDOW
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = "claude"
        $psi.Arguments = $cliCommand
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $false  # CRITICAL: Visible window

        try {
            $process = [System.Diagnostics.Process]::Start($psi)

            # Track this CLI process
            $cliInfo = @{
                Id = $invokeId
                Process = $process
                AgentName = $AgentName
                MessageFile = $MessageFile
                ResponseFile = $ResponseFile
                StartedAt = [DateTime]::UtcNow
                TimeoutMs = 300000  # 5 minute timeout
                Notified = $false
            }

            $this.CLIProcesses[$invokeId] = $cliInfo

            # Log the event
            Write-Event -Type "CLIStarted" -Data @{
                invokeId = $invokeId
                agent = $AgentName
                pid = $process.Id
            }

            Write-Host "[SUP] CLI spawned (PID: $($process.Id))" -ForegroundColor Green
            return $invokeId
        } catch {
            Write-Warning "[SUP] Failed to spawn CLI: $_"
            return $null
        }
    }

    # Check and clean up completed CLI processes
    [void] SuperviseCLIProcesses() {
        $completed = @()
        $now = [DateTime]::UtcNow

        foreach ($kv in $this.CLIProcesses.GetEnumerator()) {
            $invokeId = $kv.Key
            $cliInfo = $kv.Value
            $process = $cliInfo.Process

            # Check if process has exited
            if ($process.HasExited) {
                $exitCode = $process.ExitCode
                $success = ($exitCode -eq 0)

                Write-Host "[SUP] CLI completed: $invokeId (exit: $exitCode)" -ForegroundColor Green

                # Send CLIComplete message to the agent
                $this.NotifyCLIComplete($cliInfo.AgentName, $invokeId, $success, $exitCode)

                # Log the event
                Write-Event -Type "CLICompleted" -Data @{
                    invokeId = $invokeId
                    agent = $cliInfo.AgentName
                    exitCode = $exitCode
                    durationMs = ($now - $cliInfo.StartedAt).TotalMilliseconds
                }

                $completed += $invokeId
            } else {
                # Check for timeout
                $elapsedMs = ($now - $cliInfo.StartedAt).TotalMilliseconds
                if ($elapsedMs -gt $cliInfo.TimeoutMs) {
                    Write-Warning "[SUP] CLI timeout: $invokeId (${elapsedMs}ms)"

                    # Kill the process
                    try {
                        $process.Kill()
                        Write-Warning "[SUP] Killed timed out CLI: $invokeId"
                    } catch {
                        Write-Warning "[SUP] Failed to kill timed out CLI: $_"
                    }

                    # Send failure notification
                    $this.NotifyCLIComplete($cliInfo.AgentName, $invokeId, $false, -1, "CLI timeout after $($cliInfo.TimeoutMs)ms")

                    # Log the event
                    Write-Event -Type "CLITimeout" -Data @{
                        invokeId = $invokeId
                        agent = $cliInfo.AgentName
                        timeoutMs = $cliInfo.TimeoutMs
                    }

                    $completed += $invokeId
                }
            }
        }

        # Remove completed CLI processes from tracking
        foreach ($invokeId in $completed) {
            $this.CLIProcesses.Remove($invokeId)
        }
    }

    # Notify an agent that CLI has completed
    [void] NotifyCLIComplete([string]$AgentName, [string]$InvokeId, [bool]$Success, [int]$ExitCode, [string]$Error = "") {
        # Import message protocol for creating messages
        $messageProtocolPath = Join-Path $Script:SupervisorModuleDir "message-protocol.ps1"
        if (Test-Path $messageProtocolPath) {
            . $messageProtocolPath

            $msg = New-CLICompleteMessage -To $AgentName -AgentName $AgentName -ExitCode $ExitCode -Success $Success -Error $Error

            # Send to agent via pipe
            Send-MessageToAgent -AgentName $AgentName -Message $msg
        }
    }

    # Get status of all active CLI processes
    [hashtable] GetCLIProcessStatus() {
        $status = @{}

        foreach ($kv in $this.CLIProcesses.GetEnumerator()) {
            $cliInfo = $kv.Value
            $elapsed = ([DateTime]::UtcNow - $cliInfo.StartedAt).TotalMilliseconds

            $status[$kv.Key] = @{
                agentName = $cliInfo.AgentName
                pid = $cliInfo.Process.Id
                hasExited = $cliInfo.Process.HasExited
                elapsedMs = $elapsed
                timeoutMs = $cliInfo.TimeoutMs
                messageFile = $cliInfo.MessageFile
            }
        }

        return $status
    }

    # Get status of all actors
    [hashtable] GetStatus() {
        $status = @{}

        foreach ($kv in $this.Actors.GetEnumerator()) {
            $actor = $kv.Value

            $pipeStatus = if ($actor.Pipe) {
                @{
                    Connected = $actor.Pipe.Connected
                    MessagesSent = $actor.Pipe.MessagesSent
                    MessagesReceived = $actor.Pipe.MessagesReceived
                }
            } else {
                @{ Connected = $false; MessagesSent = 0; MessagesReceived = 0 }
            }

            $status[$kv.Key] = @{
                pid = $actor.Process.Id
                hasExited = $actor.Process.HasExited
                restartCount = $actor.RestartCount
                maxRestarts = $actor.MaxRestarts
                startedAt = $actor.StartedAt
                restartStrategy = $actor.RestartStrategy
                restartType = $actor.RestartType
                pipe = $pipeStatus
            }
        }

        return $status
    }

    # Rebuild state from event log (crash recovery)
    [void] RebuildState() {
        Write-Host "[SUP] Rebuilding state from event log..." -ForegroundColor Cyan

        # Get current agent status from event log
        $agentStatus = Rebuild-AgentStatus

        # Mark running actors as crashed (they will be restarted)
        foreach ($agentName in $agentStatus.Keys) {
            if ($agentStatus[$agentName].state -eq "running") {
                Write-Host "[SUP] Detected stale running state for $agentName" -ForegroundColor Yellow
                # Update to crashed state
                Write-Event -Type "AgentCrashed" -Data @{
                    agent = $agentName
                    exitCode = -1  # Indicates watchdog restart
                    reason = "Supervisor recovered from crash"
                }
            }
        }

        Write-Host "[SUP] State rebuild complete" -ForegroundColor Green
    }

    # Check if supervisor should stop
    [bool] ShouldStop() {
        # Stop if no more actors and we've been running for a while
        if ($this.Actors.Count -eq 0) {
            # Could add logic here to determine if work is complete
            return $false  # For now, keep running
        }
        return $false
    }

    # Get summary of supervisor state
    [string] GetSummary() {
        $actorCount = $this.Actors.Count
        $uptime = [DateTime]::UtcNow - $this.StartedAt

        return "Supervisor '$($this.Name)': $actorCount actors, uptime: $($uptime.ToString('hh\:mm\:ss')), total restarts: $($this.TotalRestarts)"
    }
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function New-ActorSupervisor {
    <#
    .SYNOPSIS
    Create a new ActorSupervisor instance.

    .PARAMETER SessionDir
    The session directory path.

    .PARAMETER Name
    Optional name for the supervisor (default: "main").

    .RETURNS
    ActorSupervisor instance.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$SessionDir,

        [Parameter(Mandatory=$false)]
        [string]$Name = "main"
    )

    return [ActorSupervisor]::new($SessionDir, $Name)
}

function Test-SupervisorHealth {
    <#
    .SYNOPSIS
    Check health of a supervisor and its actors.

    .PARAMETER Supervisor
    The ActorSupervisor instance to check.

    .RETURNS
    Hashtable with health status.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ActorSupervisor]$Supervisor
    )

    $status = $Supervisor.GetStatus()
    $health = @{
        Healthy = $true
        Issues = @()
    }

    foreach ($kv in $status.GetEnumerator()) {
        $actorStatus = $kv.Value

        # Check for issues
        if ($actorStatus.hasExited) {
            $health.Healthy = $false
            $health.Issues += "$($kv.Key) has exited"
        }

        if ($actorStatus.restartCount -ge $actorStatus.maxRestarts) {
            $health.Healthy = $false
            $health.Issues += "$($kv.Key) has exceeded max restarts"
        }

        if (-not $actorStatus.pipe.Connected) {
            $health.Healthy = $false
            $health.Issues += "$($kv.Key) pipe is disconnected"
        }
    }

    return $health
}

# ============================================================================
# EXPORTS
# ============================================================================

# Only export if running as a module (not when sourced directly)
try {
    Export-ModuleMember -Function @(
        'New-ActorSupervisor',
        'Test-SupervisorHealth'
    )
} catch {
    # Not running as a module - ignore export error
}
