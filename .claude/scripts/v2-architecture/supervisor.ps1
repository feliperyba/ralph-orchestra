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
    [string]$SessionDir
    [string]$Name
    [datetime]$StartedAt
    [int]$TotalRestarts

    # Constructor
    ActorSupervisor([string]$SessionDir, [string]$Name = "main") {
        $this.Actors = [System.Collections.Generic.Dictionary[string,object]]::new()
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
        if ($this.Actors.ContainsKey($AgentName)) {
            Write-Host "[SUP] Actor $AgentName already running" -ForegroundColor Yellow
            return
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
        # Determine the command to run
        $command = switch ($AgentName) {
            "pm" { "/ralph-coordinator-event" }
            "prd-starter" { "/ralph-prd-starter" }
            default { "/ralph-worker-event --agent $AgentName" }
        }

        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = "claude"
        $psi.Arguments = $command
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        # Run in a new window so we can see agent activity
        # $psi.CreateNoWindow = $false  # Set to $false for debugging

        $process = [System.Diagnostics.Process]::Start($psi)
        return $process
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

        # Check for graceful shutdown (0 = normal, 42 = our graceful shutdown code)
        if ($exitCode -eq 0 -or $exitCode -eq 42) {
            Write-Host "[SUP] Actor $agentName exited gracefully (code: $exitCode)" -ForegroundColor Green
            $this.Actors.Remove($agentName)
            return
        }

        # Crash - apply restart strategy based on RestartType
        if ($Actor.RestartType -eq "permanent") {
            $this.RestartActor($Actor, $exitCode)
        } elseif ($Actor.RestartType -eq "transient") {
            # Only restart if abnormal exit (not normal, shutdown, or {shutdown,_})
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

        # Exponential backoff delay
        $delay = [Math]::Min(5 * [Math]::Pow(2, $Actor.RestartCount), 60)
        Write-Host "[SUP] Waiting ${delay}s before restarting $agentName..." -ForegroundColor Yellow
        Start-Sleep -Seconds $delay

        # Remove old actor entry
        $this.Actors.Remove($agentName)

        # Clean up old pipe if it exists
        if ($Actor.Pipe) {
            Close-Pipe -AgentName $agentName
        }

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

        # Stop in reverse order of start (dependencies)
        $reversedActors = @($this.Actors.Keys)
        [Array]::Reverse($reversedActors) | ForEach-Object {
            $this.StopActor($_)
        }

        Write-Host "[SUP] All actors stopped" -ForegroundColor Green
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
