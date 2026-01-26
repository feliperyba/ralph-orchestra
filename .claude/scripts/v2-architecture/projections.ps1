# Ralph Projections Module - CQRS Read Models
#
# Design Patterns Applied:
# - CQRS: Separate read models from write models
# - Projections: Transform event stream into queryable state
# - Materialized Views: Pre-computed views for fast queries
# - Event Replay: Rebuild projections from event history
#
# Features:
# - Multiple independent projections from same event stream
# - Incremental updates (only new events processed)
# - Snapshot support for fast recovery
# - Checkpoint tracking for resume capability
# - Projection versioning for schema evolution
#
# References:
# - https://martinfowler.com/bliki/EventSourcing.html
# - https://docs.microsoft.com/en-us/azure/architecture/patterns/cqrs

# ============================================================================
# PROJECTION BASE CLASS
# ============================================================================

enum ProjectionState {
    Building
    Active
    Failed
    Stopped
}

class ProjectionCheckpoint {
    [long]$LastProcessedSequence
    [DateTime]$LastProcessedTime
    [int]$ProcessedCount
    [string]$ProjectionVersion

    ProjectionCheckpoint() {
        $this.LastProcessedSequence = 0
        $this.LastProcessedTime = [DateTime]::UtcNow
        $this.ProcessedCount = 0
        $this.ProjectionVersion = "1.0.0"
    }

    [string] ToJson() {
        return $this | ConvertTo-Json -Compress -Depth 10
    }

    static [ProjectionCheckpoint] FromJson([string]$json) {
        $props = $json | ConvertFrom-Json
        $cp = [ProjectionCheckpoint]::new()
        $cp.LastProcessedSequence = $props.LastProcessedSequence
        $cp.LastProcessedTime = [DateTime]::Parse($props.LastProcessedTime)
        $cp.ProcessedCount = $props.ProcessedCount
        $cp.ProjectionVersion = $props.ProjectionVersion
        return $cp
    }
}

abstract class Projection {
    [string]$Name
    [string]$Version
    [ProjectionState]$State
    [ProjectionCheckpoint]$Checkpoint
    [DateTime]$LastUpdated

    Projection([string]$name, [string]$version) {
        $this.Name = $name
        $this.Version = $version
        $this.State = [ProjectionState]::Building
        $this.Checkpoint = [ProjectionCheckpoint]::new()
        $this.Checkpoint.ProjectionVersion = $version
        $this.LastUpdated = [DateTime]::UtcNow
    }

    # Abstract method to be implemented by derived classes
    abstract [void] Apply([object]$event)

    # Hook for derived classes to validate they can handle the event
    [bool] CanProcess([object]$event) {
        return $true
    }

    # Called before processing an event
    [void] OnBeforeApply([object]$event) {}

    # Called after processing an event
    [void] OnAfterApply([object]$event) {}

    # Called on error during processing
    [void] OnError([object]$event, [Exception]$ex) {
        Write-Warning "Projection '$($this.Name)' error processing event: $($ex.Message)"
        $this.State = [ProjectionState]::Failed
    }

    # Get the current projection state as a dictionary
    [hashtable] GetState() {
        return @{
            Name = $this.Name
            Version = $this.Version
            State = $this.State.ToString()
            LastUpdated = $this.LastUpdated.ToString("o")
            Checkpoint = $this.Checkpoint.ToJson()
        }
    }

    # Persist projection state to file
    [void] Persist([string]$directory) {
        if (-not (Test-Path $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }

        $statePath = Join-Path $directory "$($this.Name)-state.json"
        $checkPath = Join-Path $directory "$($this.Name)-checkpoint.json"

        $this.GetState() | Out-File -FilePath $statePath -Encoding UTF8
        $this.Checkpoint.ToJson() | Out-File -FilePath $checkPath -Encoding UTF8
    }

    # Load projection state from file
    [bool] Load([string]$directory) {
        $checkPath = Join-Path $directory "$($this.Name)-checkpoint.json"

        if (Test-Path $checkPath) {
            try {
                $content = Get-Content $checkPath -Raw -ErrorAction SilentlyContinue
                if ($content) {
                    $this.Checkpoint = [ProjectionCheckpoint]::FromJson($content)
                    return $true
                }
            } catch {
                # Failed to load, start fresh
            }
        }

        return $false
    }
}

# ============================================================================
# SPECIFIC PROJECTIONS
# ============================================================================

# Agent Status Projection - Tracks current state of all agents
class AgentStatusProjection : Projection {
    [System.Collections.Generic.Dictionary[string, object]]$AgentStates
    [System.Collections.Generic.List[hashtable]]$RecentActivity

    AgentStatusProjection() : base("AgentStatus", "1.0.0") {
        $this.AgentStates = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.RecentActivity = [System.Collections.Generic.List[hashtable]]::new()
    }

    [void] Apply([object]$event) {
        if (-not $this.CanProcess($event)) { return }

        $this.OnBeforeApply($event)

        try {
            $eventType = if ($event.type) { $event.type } else { $event.EventType }

            switch -regex ($eventType) {
                "^AgentStarted" {
                    $this.ApplyAgentStarted($event)
                }
                "^Agent(Exited|Stopped)" {
                    $this.ApplyAgentStopped($event)
                }
                "^AgentCrashed" {
                    $this.ApplyAgentCrashed($event)
                }
                "^MessageSent" {
                    $this.ApplyMessageSent($event)
                }
            }

            $this.LastUpdated = [DateTime]::UtcNow
            $this.OnAfterApply($event)
        } catch {
            $this.OnError($event, $_.Exception)
        }
    }

    hidden [void] ApplyAgentStarted([object]$event) {
        $data = if ($event.data) { $event.data } else { $event.Data }

        $this.AgentStates[$data.agent] = @{
            state = "running"
            pid = $data.pid
            startTime = if ($data.startTime) { $data.startTime } else { [DateTime]::UtcNow.ToString("o") }
            lastSeen = [DateTime]::UtcNow.ToString("o")
            messagesProcessed = 0
        }

        $this.RecordActivity("agent_started", $data.agent)
    }

    hidden [void] ApplyAgentStopped([object]$event) {
        $data = if ($event.data) { $event.data } else { $event.Data }

        if ($this.AgentStates.ContainsKey($data.agent)) {
            $this.AgentStates[$data.agent].state = "stopped"
            $this.AgentStates[$data.agent].lastSeen = [DateTime]::UtcNow.ToString("o")
        }

        $this.RecordActivity("agent_stopped", $data.agent)
    }

    hidden [void] ApplyAgentCrashed([object]$event) {
        $data = if ($event.data) { $event.data } else { $event.Data }

        $this.AgentStates[$data.agent] = @{
            state = "crashed"
            exitCode = $data.exitCode
            crashedAt = [DateTime]::UtcNow.ToString("o")
            lastSeen = [DateTime]::UtcNow.ToString("o")
        }

        $this.RecordActivity("agent_crashed", $data.agent)
    }

    hidden [void] ApplyMessageSent([object]$event) {
        $data = if ($event.data) { $event.data } else { $event.Data }

        if ($this.AgentStates.ContainsKey($data.from)) {
            $current = $this.AgentStates[$data.from]
            $current.messagesProcessed = ($current.messagesProcessed ?? 0) + 1
            $current.lastSeen = [DateTime]::UtcNow.ToString("o")
        }

        $this.RecordActivity("message_sent", $data.from, $data.to)
    }

    hidden [void] RecordActivity([string]$type, [string]$agent, [string]$target) {
        $activity = @{
            type = $type
            agent = $agent
            timestamp = [DateTime]::UtcNow.ToString("o")
        }

        if ($target) {
            $activity.target = $target
        }

        $this.RecentActivity.Add($activity)

        # Keep only last 100 activities
        if ($this.RecentActivity.Count -gt 100) {
            $this.RecentActivity.RemoveAt(0)
        }
    }

    [hashtable[]] GetActiveAgents() {
        return $this.AgentStates.Values |
            Where-Object { $_.state -eq "running" } |
            ForEach-Object { $_ }
    }

    [hashtable[]] GetInactiveAgents() {
        return $this.AgentStates.Values |
            Where-Object { $_.state -ne "running" } |
            ForEach-Object { $_ }
    }

    [object] GetAgentStatus([string]$agentName) {
        if ($this.AgentStates.ContainsKey($agentName)) {
            return $this.AgentStates[$agentName]
        }
        return $null
    }
}

# Task Tracking Projection - Tracks task assignments and completions
class TaskTrackingProjection : Projection {
    [System.Collections.Generic.Dictionary[string, object]]$Tasks
    [System.Collections.Generic.Dictionary[string, int]]$AgentTaskCounts
    [int]$TotalTasksAssigned
    [int]$TotalTasksCompleted
    [int]$TotalTasksAbandoned

    TaskTrackingProjection() : base("TaskTracking", "1.0.0") {
        $this.Tasks = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.AgentTaskCounts = [System.Collections.Generic.Dictionary[string, int]]::new()
        $this.TotalTasksAssigned = 0
        $this.TotalTasksCompleted = 0
        $this.TotalTasksAbandoned = 0
    }

    [void] Apply([object]$event) {
        if (-not $this.CanProcess($event)) { return }

        $this.OnBeforeApply($event)

        try {
            $eventType = if ($event.type) { $event.type } else { $event.EventType }

            switch -regex ($eventType) {
                "^TaskAssigned" {
                    $this.ApplyTaskAssigned($event)
                }
                "^TaskCompleted" {
                    $this.ApplyTaskCompleted($event)
                }
                "^TaskAbandoned" {
                    $this.ApplyTaskAbandoned($event)
                }
            }

            $this.LastUpdated = [DateTime]::UtcNow
            $this.OnAfterApply($event)
        } catch {
            $this.OnError($event, $_.Exception)
        }
    }

    hidden [void] ApplyTaskAssigned([object]$event) {
        $data = if ($event.data) { $event.data } else { $event.Data }

        $taskId = if ($data.taskId) { $data.taskId } else { $data.id }
        $agent = $data.agent

        $this.Tasks[$taskId] = @{
            id = $taskId
            agent = $agent
            status = "assigned"
            assignedAt = if ($data.timestamp) { $data.timestamp } else { [DateTime]::UtcNow.ToString("o") }
            title = $data.title
            priority = $data.priority
        }

        if (-not $this.AgentTaskCounts.ContainsKey($agent)) {
            $this.AgentTaskCounts[$agent] = 0
        }
        $this.AgentTaskCounts[$agent]++
        $this.TotalTasksAssigned++
    }

    hidden [void] ApplyTaskCompleted([object]$event) {
        $data = if ($event.data) { $event.data } else { $event.Data }

        $taskId = if ($data.taskId) { $data.taskId } else { $data.id }

        if ($this.Tasks.ContainsKey($taskId)) {
            $task = $this.Tasks[$taskId]
            $task.status = "completed"
            $task.completedAt = [DateTime]::UtcNow.ToString("o")
        }

        $this.TotalTasksCompleted++
    }

    hidden [void] ApplyTaskAbandoned([object]$event) {
        $data = if ($event.data) { $event.data } else { $event.Data }

        $taskId = if ($data.taskId) { $data.taskId } else { $data.id }

        if ($this.Tasks.ContainsKey($taskId)) {
            $task = $this.Tasks[$taskId]
            $task.status = "abandoned"
            $task.abandonedAt = [DateTime]::UtcNow.ToString("o")
        }

        $this.TotalTasksAbandoned++
    }

    [hashtable[]] GetPendingTasks() {
        return $this.Tasks.Values |
            Where-Object { $_.status -eq "assigned" } |
            ForEach-Object { $_ }
    }

    [hashtable[]] GetTasksByAgent([string]$agentName) {
        return $this.Tasks.Values |
            Where-Object { $_.agent -eq $agentName } |
            ForEach-Object { $_ }
    }

    [hashtable] GetStatistics() {
        return @{
            TotalAssigned = $this.TotalTasksAssigned
            TotalCompleted = $this.TotalTasksCompleted
            TotalAbandoned = $this.TotalTasksAbandoned
            Pending = $this.TotalTasksAssigned - $this.TotalTasksCompleted - $this.TotalTasksAbandoned
            CompletionRate = if ($this.TotalTasksAssigned -gt 0) {
                [math]::Round($this.TotalTasksCompleted / $this.TotalTasksAssigned * 100, 2)
            } else { 0 }
        }
    }
}

# Message Statistics Projection - Tracks message patterns and delivery
class MessageStatsProjection : Projection {
    [System.Collections.Generic.Dictionary[string, int]]$MessagesSent
    [System.Collections.Generic.Dictionary[string, int]]$MessagesReceived
    [System.Collections.Generic.Dictionary[string, int]]$MessageTypes
    [System.Collections.Generic.Dictionary[string, System.Collections.Generic.Dictionary[string, int]]]$AgentInteractions

    MessageStatsProjection() : base("MessageStats", "1.0.0") {
        $this.MessagesSent = [System.Collections.Generic.Dictionary[string, int]]::new()
        $this.MessagesReceived = [System.Collections.Generic.Dictionary[string, int]]::new()
        $this.MessageTypes = [System.Collections.Generic.Dictionary[string, int]]::new()
        $this.AgentInteractions = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.Dictionary[string, int]]]::new()
    }

    [void] Apply([object]$event) {
        if (-not $this.CanProcess($event)) { return }

        $this.OnBeforeApply($event)

        try {
            $eventType = if ($event.type) { $event.type } else { $event.EventType }

            switch -regex ($eventType) {
                "^Message(Sent|Delivered)" {
                    $this.ApplyMessageEvent($event)
                }
            }

            $this.LastUpdated = [DateTime]::UtcNow
            $this.OnAfterApply($event)
        } catch {
            $this.OnError($event, $_.Exception)
        }
    }

    hidden [void] ApplyMessageEvent([object]$event) {
        $data = if ($event.data) { $event.data } else { $event.Data }

        $from = $data.from
        $to = $data.to
        $msgType = $data.messageType ?? $data.type ?? "unknown"

        # Track sent by
        if (-not $this.MessagesSent.ContainsKey($from)) {
            $this.MessagesSent[$from] = 0
        }
        $this.MessagesSent[$from]++

        # Track received by
        if (-not $this.MessagesReceived.ContainsKey($to)) {
            $this.MessagesReceived[$to] = 0
        }
        $this.MessagesReceived[$to]++

        # Track message types
        if (-not $this.MessageTypes.ContainsKey($msgType)) {
            $this.MessageTypes[$msgType] = 0
        }
        $this.MessageTypes[$msgType]++

        # Track agent interactions
        if (-not $this.AgentInteractions.ContainsKey($from)) {
            $this.AgentInteractions[$from] = [System.Collections.Generic.Dictionary[string, int]]::new()
        }
        if (-not $this.AgentInteractions[$from].ContainsKey($to)) {
            $this.AgentInteractions[$from][$to] = 0
        }
        $this.AgentInteractions[$from][$to]++
    }

    [hashtable] GetMessageStats() {
        return @{
            TotalSent = ($this.MessagesSent.Values | Measure-Object -Sum).Sum
            TotalReceived = ($this.MessagesReceived.Values | Measure-Object -Sum).Sum
            BySender = $this.MessagesSent
            ByReceiver = $this.MessagesReceived
            ByType = $this.MessageTypes
        }
    }

    [string[]] GetMostActiveAgents([int]$topN) {
        $allAgents = [System.Collections.Generic.Dictionary[string, int]]::new()

        foreach ($kvp in $this.MessagesSent.GetEnumerator()) {
            if (-not $allAgents.ContainsKey($kvp.Key)) {
                $allAgents[$kvp.Key] = 0
            }
            $allAgents[$kvp.Key] += $kvp.Value
        }

        foreach ($kvp in $this.MessagesReceived.GetEnumerator()) {
            if (-not $allAgents.ContainsKey($kvp.Key)) {
                $allAgents[$kvp.Key] = 0
            }
            $allAgents[$kvp.Key] += $kvp.Value
        }

        return $allAgents.GetEnumerator() |
            Sort-Object -Property Value -Descending |
            Select-Object -First $topN |
            ForEach-Object { $_.Key }
    }
}

# Session Timeline Projection - Chronological event log
class SessionTimelineProjection : Projection {
    [System.Collections.Generic.List[hashtable]]$Timeline
    [int]$MaxEvents

    SessionTimelineProjection() : base("SessionTimeline", "1.0.0") {
        $this.Timeline = [System.Collections.Generic.List[hashtable]]::new()
        $this.MaxEvents = 1000
    }

    [void] Apply([object]$event) {
        if (-not $this.CanProcess($event)) { return }

        $this.OnBeforeApply($event)

        try {
            $entry = @{
                sequence = if ($event.seq) { $event.seq } else { $event.SequenceNumber }
                type = if ($event.type) { $event.type } else { $event.EventType }
                timestamp = if ($event.timestamp) { $event.timestamp } else {
                    if ($event.Timestamp) { $event.Timestamp.ToString("o") } else { [DateTime]::UtcNow.ToString("o") }
                }
                data = if ($event.data) { $event.data } else { $event.Data }
            }

            $this.Timeline.Add($entry)

            # Trim if needed
            if ($this.Timeline.Count -gt $this.MaxEvents) {
                $this.Timeline.RemoveAt(0)
            }

            $this.LastUpdated = [DateTime]::UtcNow
            $this.OnAfterApply($event)
        } catch {
            $this.OnError($event, $_.Exception)
        }
    }

    [hashtable[]] GetEvents([DateTime]$since) {
        return $this.Timeline |
            Where-Object {
                $ts = [DateTime]::Parse($_.timestamp)
                $ts -gt $since
            } |
            ForEach-Object { $_ }
    }

    [hashtable[]] GetEventsByType([string]$eventType) {
        return $this.Timeline |
            Where-Object { $_.type -like "*$eventType*" } |
            ForEach-Object { $_ }
    }
}

# ============================================================================
# PROJECTION MANAGER
# ============================================================================

class ProjectionManager {
    [string]$DataDirectory
    [System.Collections.Generic.List[Projection]]$Projections
    [hidden LatencyTracker]$UpdateLatency

    ProjectionManager([string]$dataDirectory) {
        $this.DataDirectory = $dataDirectory
        $this.Projections = [System.Collections.Generic.List[Projection]]::new()
        $this.UpdateLatency = [LatencyTracker]::new(1000)

        # Ensure directory exists
        if (-not (Test-Path $dataDirectory)) {
            New-Item -ItemType Directory -Path $dataDirectory -Force | Out-Null
        }
    }

    [void] Register([Projection]$projection) {
        # Try to load existing checkpoint
        $projection.Load($this.DataDirectory)
        $this.Projections.Add($projection)
    }

    [void] ProcessEvents([object[]]$events) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        foreach ($evt in $events) {
            $seq = if ($evt.seq) { $evt.seq } else { $evt.SequenceNumber }

            foreach ($proj in $this.Projections) {
                # Skip if projection already processed this event
                if ($seq -le $proj.Checkpoint.LastProcessedSequence) {
                    continue
                }

                if ($proj.CanProcess($evt)) {
                    $proj.Apply($evt)
                    $proj.Checkpoint.LastProcessedSequence = $seq
                    $proj.Checkpoint.LastProcessedTime = [DateTime]::UtcNow
                    $proj.Checkpoint.ProcessedCount++
                }
            }
        }

        # Persist all projections
        $this.Persist()

        $sw.Stop()
        $this.UpdateLatency.Record($sw.ElapsedMicroseconds)
    }

    [void] Persist() {
        foreach ($proj in $this.Projections) {
            try {
                $proj.Persist($this.DataDirectory)
            } catch {
                Write-Warning "Failed to persist projection '$($proj.Name)': $_"
            }
        }
    }

    [void] Rebuild([object[]]$allEvents) {
        foreach ($proj in $this.Projections) {
            $proj.Checkpoint = [ProjectionCheckpoint]::new()
            $proj.Checkpoint.ProjectionVersion = $proj.Version
        }

        $this.ProcessEvents($allEvents)
    }

    [hashtable] GetAllStates() {
        $states = [ordered]@{}

        foreach ($proj in $this.Projections) {
            $states[$proj.Name] = $proj.GetState()
        }

        return $states
    }

    [T] GetProjection([string]$name) {
        return $this.Projections | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    }

    [hashtable] GetMetrics() {
        return @{
            TotalProjections = $this.Projections.Count
            ProjectionStates = $this.Projections | ForEach-Object {
                @{
                    Name = $_.Name
                    State = $_.State.ToString()
                    ProcessedCount = $_.Checkpoint.ProcessedCount
                }
            }
            UpdateLatency = $this.UpdateLatency.GetStatistics()
        }
    }
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function New-ProjectionManager {
    <#
    .SYNOPSIS
    Create a new projection manager.

    .PARAMETER DataDirectory
    Directory for storing projection state.

    .RETURNS
    ProjectionManager instance.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$DataDirectory
    )

    return [ProjectionManager]::new($DataDirectory)
}

function New-AgentStatusProjection {
    <#
    .SYNOPSIS
    Create a new agent status projection.

    .RETURNS
    AgentStatusProjection instance.
    #>
    return [AgentStatusProjection]::new()
}

function New-TaskTrackingProjection {
    <#
    .SYNOPSIS
    Create a new task tracking projection.

    .RETURNS
    TaskTrackingProjection instance.
    #>
    return [TaskTrackingProjection]::new()
}

function New-MessageStatsProjection {
    <#
    .SYNOPSIS
    Create a new message statistics projection.

    .RETURNS
    MessageStatsProjection instance.
    #>
    return [MessageStatsProjection]::new()
}

function New-SessionTimelineProjection {
    <#
    .SYNOPSIS
    Create a new session timeline projection.

    .PARAMETER MaxEvents
    Maximum number of events to keep in timeline.

    .RETURNS
    SessionTimelineProjection instance.
    #>
    param(
        [Parameter(Mandatory=$false)]
        [int]$MaxEvents = 1000
    )

    $proj = [SessionTimelineProjection]::new()
    $proj.MaxEvents = $MaxEvents
    return $proj
}

function Update-Projections {
    <#
    .SYNOPSIS
    Update projections with new events.

    .PARAMETER Manager
    The ProjectionManager instance.

    .PARAMETER Events
    Array of events to process.

    .EXAMPLE
    $manager = New-ProjectionManager -DataDirectory ".\.claude\session\projections"
    $manager.Register((New-AgentStatusProjection))
    Update-Projections -Manager $manager -Events $newEvents
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ProjectionManager]$Manager,

        [Parameter(Mandatory=$true)]
        [object[]]$Events
    )

    $Manager.ProcessEvents($Events)
}

function Read-ProjectionState {
    <#
    .SYNOPSIS
    Read the state of a specific projection.

    .PARAMETER Manager
    The ProjectionManager instance.

    .PARAMETER ProjectionName
    Name of the projection to read.

    .RETURNS
    Projection state object or null if not found.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ProjectionManager]$Manager,

        [Parameter(Mandatory=$true)]
        [string]$ProjectionName
    )

    $proj = $Manager.GetProjection($ProjectionName)
    if ($proj) {
        return $proj.GetState()
    }
    return $null
}

# ============================================================================
# EXPORTS
# ============================================================================

try {
    Export-ModuleMember -Function @(
        # Managers
        'New-ProjectionManager',
        'Update-Projections',
        'Read-ProjectionState',

        # Projections
        'New-AgentStatusProjection',
        'New-TaskTrackingProjection',
        'New-MessageStatsProjection',
        'New-SessionTimelineProjection',

        # Enums
        'ProjectionState'
    )
} catch {
    # Not running as a module
}
