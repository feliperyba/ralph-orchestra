# Ralph Supervision Tree Implementation
# Erlang/OTP-style supervision with hierarchical restart strategies
#
# Design Patterns Applied:
# - Supervisor Pattern: Hierarchical fault tolerance
# - Let It Crash: Fault isolation through actor boundaries
# - Restart Intensity: Max restarts within time window
#
# References:
# - https://www.erlang.org/doc/design_principles/sup_princ.html
# - https://learnyousomeerlang.com/supervisors

using namespace System.Collections.Generic

# ============================================================================
# CHILD SPECIFICATION
# ============================================================================

class ChildSpec {
    # Unique identifier for this child
    [string]$Id

    # Actor name
    [string]$Name

    # Factory function to create the actor
    [scriptblock]$Factory

    # Restart strategy for this child
    [RestartType]$RestartType

    # Shutdown timeout (max time to wait for graceful stop)
    [timespan]$ShutdownTimeout

    # Actor reference (once started)
    [RalphActor]$Actor

    # When this child was started (relative to supervisor start order)
    [int]$StartOrder

    # Whether child is currently restarting
    [bool]$IsRestarting

    ChildSpec([string]$id, [string]$name, [scriptblock]$factory) {
        $this.Id = $id
        $this.Name = $name
        $this.Factory = $factory
        $this.RestartType = [RestartType]::Permanent
        $this.ShutdownTimeout = [timespan]::FromSeconds(5)
        $this.StartOrder = 0
        $this.IsRestarting = $false
    }

    ChildSpec([string]$id, [string]$name, [scriptblock]$factory, [RestartType]$restartType) {
        $this.Id = $id
        $this.Name = $name
        $this.Factory = $factory
        $this.RestartType = $restartType
        $this.ShutdownTimeout = [timespan]::FromSeconds(5)
        $this.StartOrder = 0
        $this.IsRestarting = $false
    }
}

# ============================================================================
# RESTART TRACKING
# ============================================================================

class RestartHistory {
    hidden [System.Collections.Generic.Queue[DateTime]]$RestartTimes
    [int]$MaxRestarts
    [timespan]$DurationWindow

    RestartHistory([int]$maxRestarts, [timespan]$durationWindow) {
        $this.RestartTimes = [System.Collections.Generic.Queue[DateTime]]::new()
        $this.MaxRestarts = $maxRestarts
        $this.DurationWindow = $durationWindow
    }

    # Record a restart occurrence
    [void] RecordRestart() {
        $this.RestartTimes.Enqueue([DateTime]::UtcNow)
        $this.CleanupOldRestarts()
    }

    # Remove restarts outside our time window
    hidden [void] CleanupOldRestarts() {
        $cutoff = [DateTime]::UtcNow - $this.DurationWindow

        while ($this.RestartTimes.Count -gt 0 -and $this.RestartTimes.Peek() -lt $cutoff) {
            $this.RestartTimes.Dequeue()
        }
    }

    # Check if restart limit has been exceeded
    [bool] IsExceeded() {
        $this.CleanupOldRestarts()
        return $this.RestartTimes.Count -ge $this.MaxRestarts
    }

    # Get current restart count within window
    [int] GetCount() {
        $this.CleanupOldRestarts()
        return $this.RestartTimes.Count
    }

    # Reset restart history
    [void] Reset() {
        $this.RestartTimes.Clear()
    }

    # Get time until oldest restart falls outside window
    [timespan] GetTimeUntilNextReset() {
        if ($this.RestartTimes.Count -eq 0) {
            return [timespan]::Zero
        }

        $oldest = $this.RestartTimes.Peek()
        $resetTime = $oldest + $this.DurationWindow
        $remaining = $resetTime - [DateTime]::UtcNow

        return [math]::Max([timespan]::Zero, $remaining)
    }
}

# ============================================================================
# SUPERVISOR SPEC
# ============================================================================

class SupervisorSpec {
    [string]$Name
    [RestartStrategy]$Strategy

    # Restart intensity configuration
    [int]$MaxRestarts
    [timespan]$MaxRestartsDuration

    # Child actors
    hidden [System.Collections.Generic.Dictionary[string,ChildSpec]]$Children

    # Child supervisors (for hierarchical supervision)
    hidden [System.Collections.Generic.Dictionary[string,ActorSupervisor]]$ChildSupervisors

    # Restart tracking
    hidden [RestartHistory]$RestartHistory

    # Start order counter
    hidden [int]$NextStartOrder

    # Supervisor state
    [bool]$IsRunning
    [DateTime]$StartedAt

    SupervisorSpec([string]$name, [RestartStrategy]$strategy) {
        $this.Name = $name
        $this.Strategy = $strategy
        $this.MaxRestarts = 5
        $this.MaxRestartsDuration = [timespan]::FromMinutes(1)
        $this.Children = [System.Collections.Generic.Dictionary[string,ChildSpec]]::new()
        $this.ChildSupervisors = [System.Collections.Generic.Dictionary[string,ActorSupervisor]]::new()
        $this.RestartHistory = [RestartHistory]::new($this.MaxRestarts, $this.MaxRestartsDuration)
        $this.NextStartOrder = 0
        $this.IsRunning = $false
    }

    SupervisorSpec([string]$name, [RestartStrategy]$strategy, [int]$maxRestarts, [timespan]$maxDuration) {
        $this.Name = $name
        $this.Strategy = $strategy
        $this.MaxRestarts = $maxRestarts
        $this.MaxRestartsDuration = $maxDuration
        $this.Children = [System.Collections.Generic.Dictionary[string,ChildSpec]]::new()
        $this.ChildSupervisors = [System.Collections.Generic.Dictionary[string,ActorSupervisor]]::new()
        $this.RestartHistory = [RestartHistory]::new($this.MaxRestarts, $this.MaxRestartsDuration)
        $this.NextStartOrder = 0
        $this.IsRunning = $false
    }
}

# ============================================================================
# ACTOR SUPERVISOR
# ============================================================================

class ActorSupervisor {
    [SupervisorSpec]$Spec
    [string]$Name
    hidden [object]$Lock

    # Event hooks
    [scriptblock]$OnChildCrashed
    [scriptblock]$OnChildRestarted
    [scriptblock]$OnChildTerminated
    [scriptblock]$OnSupervisorShutdown

    ActorSupervisor([string]$name, [RestartStrategy]$strategy) {
        $this.Name = $name
        $this.Spec = [SupervisorSpec]::new($name, $strategy)
        $this.Lock = [object]::new()
    }

    ActorSupervisor([string]$name, [RestartStrategy]$strategy, [int]$maxRestarts, [timespan]$maxDuration) {
        $this.Name = $name
        $this.Spec = [SupervisorSpec]::new($name, $strategy, $maxRestarts, $maxDuration)
        $this.Lock = [object]::new()
    }

    # ========================================================================
    # CHILD MANAGEMENT
    # ========================================================================

    # Add a child actor specification
    [void] AddChild([string]$id, [string]$name, [scriptblock]$factory) {
        lock($this.Lock) {
            $childSpec = [ChildSpec]::new($id, $name, $factory)
            $childSpec.StartOrder = $this.Spec.NextStartOrder++
            $this.Spec.Children[$id] = $childSpec
        }
    }

    # Add a child with restart type
    [void] AddChild([string]$id, [string]$name, [scriptblock]$factory, [RestartType]$restartType) {
        lock($this.Lock) {
            $childSpec = [ChildSpec]::new($id, $name, $factory, $restartType)
            $childSpec.StartOrder = $this.Spec.NextStartOrder++
            $this.Spec.Children[$id] = $childSpec
        }
    }

    # Add a child supervisor
    [void] AddChildSupervisor([ActorSupervisor]$childSupervisor) {
        lock($this.Lock) {
            $this.Spec.ChildSupervisors[$childSupervisor.Name] = $childSupervisor
        }
    }

    # Remove a child
    [void] RemoveChild([string]$id) {
        lock($this.Lock) {
            if ($this.Spec.Children.ContainsKey($id)) {
                $child = $this.Spec.Children[$id]

                # Stop actor if running
                if ($child.Actor -and $child.Actor.State -ne [ActorState]::Stopped) {
                    $child.Actor.Stop()
                }

                $this.Spec.Children.Remove($id)
            }
        }
    }

    # Get a child actor by ID
    [RalphActor] GetChild([string]$id) {
        lock($this.Lock) {
            if ($this.Spec.Children.ContainsKey($id)) {
                return $this.Spec.Children[$id].Actor
            }
            return $null
        }
    }

    # Get all child actors
    [RalphActor[]] GetChildren() {
        lock($this.Lock) {
            $children = [System.Collections.Generic.List[RalphActor]]::new()
            foreach ($child in $this.Spec.Children.Values) {
                if ($child.Actor) {
                    $children.Add($child.Actor)
                }
            }
            return $children.ToArray()
        }
    }

    # ========================================================================
    # STARTUP/SHUTDOWN
    # ========================================================================

    # Start all children
    [void] Start() {
        lock($this.Lock) {
            if ($this.Spec.IsRunning) {
                return
            }

            $this.Spec.IsRunning = $true
            $this.Spec.StartedAt = [DateTime]::UtcNow

            # Start all children in order
            foreach ($child in $this.Spec.Children.Values | Sort-Object { $_.StartOrder }) {
                $this.StartChild($child)
            }

            # Start all child supervisors
            foreach ($supervisor in $this.Spec.ChildSupervisors.Values) {
                $supervisor.Start()
            }
        }
    }

    # Start a specific child
    hidden [void] StartChild([ChildSpec]$child) {
        if ($null -eq $child) { return }

        try {
            # Create actor using factory
            $child.Actor = & $child.Factory

            # Start the actor
            $child.Actor.Start()

            Write-Host "[SUP-$($this.Name)] Started child: $($child.Name)" -ForegroundColor Green
        } catch {
            Write-Warning "[SUP-$($this.Name)] Failed to start child $($child.Name): $_"

            # Record failure for permanent children
            if ($child.RestartType -eq [RestartType]::Permanent) {
                $this.Spec.RestartHistory.RecordRestart()
            }
        }
    }

    # Stop all children
    [void] Stop() {
        lock($this.Lock) {
            if (-not $this.Spec.IsRunning) {
                return
            }

            # Stop in reverse start order
            $sortedChildren = $this.Spec.Children.Values | Sort-Object { -$_.StartOrder }

            foreach ($child in $sortedChildren) {
                if ($child.Actor -and $child.Actor.State -ne [ActorState]::Stopped) {
                    try {
                        $child.Actor.Stop()

                        # Wait for graceful shutdown
                        $child.Actor.ProcessingThread.Join($child.ShutdownTimeout.TotalMilliseconds)
                    } catch {
                        Write-Warning "[SUP-$($this.Name)] Error stopping child $($child.Name): $_"
                    }
                }
            }

            # Stop all child supervisors
            foreach ($supervisor in $this.Spec.ChildSupervisors.Values) {
                $supervisor.Stop()
            }

            $this.Spec.IsRunning = $false

            if ($this.OnSupervisorShutdown) {
                & $this.OnSupervisorShutdown $this
            }
        }
    }

    # ========================================================================
    # CRASH HANDLING
    # ========================================================================

    # Handle a child crash (called externally when child crashes)
    [void] HandleChildCrash([string]$childId, [Exception]$reason) {
        lock($this.Lock) {
            if (-not $this.Spec.Children.ContainsKey($childId)) {
                Write-Warning "[SUP-$($this.Name)] Unknown child crashed: $childId"
                return
            }

            $child = $this.Spec.Children[$childId]

            Write-Warning "[SUP-$($this.Name)] Child crashed: $($child.Name) - $reason"

            # Call hook
            if ($this.OnChildCrashed) {
                try {
                    & $this.OnChildCrashed $child $reason
                } catch {
                    Write-Warning "[SUP-$($this.Name)] OnChildCrashed hook error: $_"
                }
            }

            # Check if we should restart based on restart type
            $shouldRestart = $false

            switch ($child.RestartType) {
                ([RestartType]::Permanent) {
                    # Always restart
                    $shouldRestart = $true
                }
                ([RestartType]::Transient) {
                    # Restart only on abnormal exit (exception)
                    if ($null -ne $reason) {
                        $shouldRestart = $true
                    }
                }
                ([RestartType]::Temporary) {
                    # Never restart
                    $shouldRestart = $false
                }
            }

            if (-not $shouldRestart) {
                Write-Host "[SUP-$($this.Name)] Child $($child.Name) not restarting (RestartType: $($child.RestartType))" -ForegroundColor Yellow
                $this.Spec.Children.Remove($childId)

                if ($this.OnChildTerminated) {
                    & $this.OnChildTerminated $child
                }
                return
            }

            # Check restart intensity
            $this.Spec.RestartHistory.RecordRestart()

            if ($this.Spec.RestartHistory.IsExceeded()) {
                Write-Error "[SUP-$($this.Name)] Max restart intensity exceeded! Shutting down supervisor."

                # Shutdown entire supervisor
                $this.Stop()
                return
            }

            # Apply restart strategy
            $this.ApplyRestartStrategy($child)
        }
    }

    # Apply the configured restart strategy
    hidden [void] ApplyRestartStrategy([ChildSpec]$crashedChild) {
        switch ($this.Spec.Strategy) {
            ([RestartStrategy]::OneForOne) {
                $this.RestartChild($crashedChild)
            }

            ([RestartStrategy]::OneForAll) {
                $this.RestartAllChildren()
            }

            ([RestartStrategy]::RestForOne) {
                $this.RestartRestForOne($crashedChild)
            }
        }
    }

    # Restart only the crashed child (OneForOne)
    hidden [void] RestartChild([ChildSpec]$child) {
        if ($null -eq $child) { return }

        Write-Host "[SUP-$($this.Name)] Restarting child: $($child.Name)" -ForegroundColor Yellow

        # Stop the crashed actor
        try {
            if ($child.Actor) {
                $child.Actor.Stop()
            }
        } catch {
            # Ignore stop errors
        }

        # Exponential backoff based on restart count
        $restartCount = $this.Spec.RestartHistory.GetCount()
        $delayMs = [math]::Min(1000 * [math]::Pow(2, $restartCount), 30000)

        if ($delayMs -gt 0) {
            Write-Host "[SUP-$($this.Name)] Waiting ${delayMs}ms before restart..." -ForegroundColor DarkGray
            Start-Sleep -Milliseconds $delayMs
        }

        # Restart the child
        $child.IsRestarting = $true
        $this.StartChild($child)
        $child.IsRestarting = $false

        # Increment actor's restart count
        if ($child.Actor) {
            $child.Actor.RestartCount++
        }

        # Call hook
        if ($this.OnChildRestarted) {
            try {
                & $this.OnChildRestarted $child
            } catch {
                Write-Warning "[SUP-$($this.Name)] OnChildRestarted hook error: $_"
            }
        }
    }

    # Restart all children (OneForAll)
    hidden [void] RestartAllChildren() {
        Write-Host "[SUP-$($this.Name)] Restarting all children (OneForAll strategy)" -ForegroundColor Yellow

        # Stop all children
        foreach ($child in $this.Spec.Children.Values) {
            try {
                if ($child.Actor -and $child.Actor.State -ne [ActorState]::Stopped) {
                    $child.Actor.Stop()
                }
            } catch {
                # Ignore stop errors
            }
        }

        # Small delay before restarting
        Start-Sleep -Milliseconds 500

        # Restart all children in original order
        foreach ($child in $this.Spec.Children.Values | Sort-Object { $_.StartOrder }) {
            $this.StartChild($child)
            if ($child.Actor) {
                $child.Actor.RestartCount++
            }
        }
    }

    # Restart crashed child and all children started after it (RestForOne)
    hidden [void] RestartRestForOne([ChildSpec]$crashedChild) {
        Write-Host "[SUP-$($this.Name)] Restarting affected children (RestForOne strategy)" -ForegroundColor Yellow

        # Find the crash order and restart all children at or after that position
        $crashOrder = $crashedChild.StartOrder

        # Stop affected children
        foreach ($child in $this.Spec.Children.Values) {
            if ($child.StartOrder -ge $crashOrder) {
                try {
                    if ($child.Actor -and $child.Actor.State -ne [ActorState]::Stopped) {
                        $child.Actor.Stop()
                    }
                } catch {
                    # Ignore stop errors
                }
            }
        }

        # Small delay before restarting
        Start-Sleep -Milliseconds 500

        # Restart affected children in order
        foreach ($child in $this.Spec.Children.Values | Sort-Object { $_.StartOrder }) {
            if ($child.StartOrder -ge $crashOrder) {
                $this.StartChild($child)
                if ($child.Actor) {
                    $child.Actor.RestartCount++
                }
            }
        }
    }

    # ========================================================================
    # MONITORING
    # ========================================================================

    # Get supervisor statistics
    [hashtable] GetStats() {
        lock($this.Lock) {
            $childrenStats = @{}
            foreach ($kv in $this.Spec.Children) {
                $child = $kv.Value
                $childrenStats[$kv.Key] = @{
                    Name = $child.Name
                    State = if ($child.Actor) { $child.Actor.State.ToString() } else { "NotStarted" }
                    RestartCount = if ($child.Actor) { $child.Actor.RestartCount } else { 0 }
                    RestartType = $child.RestartType.ToString()
                    StartOrder = $child.StartOrder
                    IsRestarting = $child.IsRestarting
                }
            }

            $uptime = if ($this.Spec.StartedAt -gt [DateTime]::MinValue) {
                ([DateTime]::UtcNow - $this.Spec.StartedAt).TotalSeconds
            } else { 0 }

            return @{
                Name = $this.Name
                Strategy = $this.Spec.Strategy.ToString()
                IsRunning = $this.Spec.IsRunning
                UptimeSeconds = [math]::Round($uptime, 2)
                ChildCount = $this.Spec.Children.Count
                SupervisorCount = $this.Spec.ChildSupervisors.Count
                RestartCount = $this.Spec.RestartHistory.GetCount()
                MaxRestarts = $this.Spec.MaxRestarts
                TimeUntilReset = $this.Spec.RestartHistory.GetTimeUntilNextReset().TotalSeconds
                Children = $childrenStats
                StartedAt = if ($this.Spec.StartedAt -gt [DateTime]::MinValue) { $this.Spec.StartedAt.ToString("o") } else { $null }
            }
        }
    }

    # Check if supervisor is healthy
    [bool] IsHealthy() {
        lock($this.Lock) {
            if (-not $this.Spec.IsRunning) {
                return $false
            }

            # Check restart intensity
            if ($this.Spec.RestartHistory.IsExceeded()) {
                return $false
            }

            # Check all children are running
            foreach ($child in $this.Spec.Children.Values) {
                if ($child.RestartType -eq [RestartType]::Permanent) {
                    if ($null -eq $child.Actor -or
                        $child.Actor.State -eq [ActorState]::Crashed -or
                        $child.Actor.State -eq [ActorState]::Stopped) {
                        return $false
                    }
                }
            }

            return $true
        }
    }
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Create a new supervisor
function New-ActorSupervisor {
    <#
    .SYNOPSIS
    Create a new actor supervisor.

    .PARAMETER Name
    Unique name for the supervisor.

    .PARAMETER Strategy
    Restart strategy (OneForOne, OneForAll, RestForOne).

    .PARAMETER MaxRestarts
    Maximum number of restarts allowed within the time window.

    .PARAMETER MaxRestartsDuration
    Time window for restart intensity checking.

    .EXAMPLE
    $sup = New-ActorSupervisor "MainSupervisor" OneForOne
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [RestartStrategy]$Strategy = [RestartStrategy]::OneForOne,

        [Parameter(Mandatory=$false)]
        [int]$MaxRestarts = 5,

        [Parameter(Mandatory=$false)]
        [timespan]$MaxRestartsDuration = [timespan]::FromMinutes(1)
    )

    return [ActorSupervisor]::new($Name, $Strategy, $MaxRestarts, $MaxRestartsDuration)
}

# Add a child actor to supervisor
function Add-SupervisorChild {
    <#
    .SYNOPSIS
    Add a child actor to a supervisor.

    .PARAMETER Supervisor
    The ActorSupervisor to add the child to.

    .PARAMETER Id
    Unique identifier for the child.

    .PARAMETER Name
    Display name for the child.

    .PARAMETER Factory
    Scriptblock that creates the actor.

    .PARAMETER RestartType
    When to restart the child.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ActorSupervisor]$Supervisor,

        [Parameter(Mandatory=$true)]
        [string]$Id,

        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [scriptblock]$Factory,

        [Parameter(Mandatory=$false)]
        [RestartType]$RestartType = [RestartType]::Permanent
    )

    $Supervisor.AddChild($Id, $Name, $Factory, $RestartType)
}

# Start a supervisor
function Start-Supervisor {
    <#
    .SYNOPSIS
    Start a supervisor and all its children.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ActorSupervisor]$Supervisor
    )

    $Supervisor.Start()
}

# Stop a supervisor
function Stop-Supervisor {
    <#
    .SYNOPSIS
    Stop a supervisor and all its children.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ActorSupervisor]$Supervisor
    )

    $Supervisor.Stop()
}

# Get supervisor statistics
function Get-SupervisorStats {
    <#
    .SYNOPSIS
    Get statistics about a supervisor.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ActorSupervisor]$Supervisor
    )

    return $Supervisor.GetStats()
}

# ============================================================================
# EXPORTS
# ============================================================================

try {
    Export-ModuleMember -Function @(
        'New-ActorSupervisor',
        'Add-SupervisorChild',
        'Start-Supervisor',
        'Stop-Supervisor',
        'Get-SupervisorStats'
    )
} catch {
    # Not running as a module
}
