# Ralph Metrics Collector (PowerShell)
# Structured metrics collection for task tracking and observability
#
# Usage:
#   . "$PSScriptRoot\metrics.ps1"
#   Record-TaskStart -TaskId "feat-001" -AgentName "developer"
#   Record-TaskComplete -TaskId "feat-001" -AgentName "developer"

# Source configuration if not already loaded
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Get-Command "Get-RalphConfig" -ErrorAction SilentlyContinue)) {
    . "$scriptDir\ralph-config.ps1"
}

# ============================================================================
# METRICS FILE MANAGEMENT
# ============================================================================

function Get-MetricsFilePath {
    param([string]$ProjectRoot = (Get-Location).Path)
    $paths = Get-RalphPaths -ProjectRoot $ProjectRoot
    return $paths.MetricsFile
}

function Get-EventsLogPath {
    param([string]$ProjectRoot = (Get-Location).Path)
    $paths = Get-RalphPaths -ProjectRoot $ProjectRoot
    return $paths.EventsLog
}

function Initialize-Metrics {
    <#
    .SYNOPSIS
    Initializes the metrics file with default structure.
    #>
    param([string]$ProjectRoot = (Get-Location).Path)
    
    $metricsPath = Get-MetricsFilePath -ProjectRoot $ProjectRoot
    
    if (Test-Path $metricsPath) {
        return Get-Content $metricsPath -Raw | ConvertFrom-Json
    }
    
    $metrics = @{
        sessionId = "ralph-" + (Get-Date).ToString("yyyyMMdd-HHmmss")
        startedAt = Get-Timestamp
        taskMetrics = @()
        aggregates = @{
            totalTasks = 0
            completedTasks = 0
            failedTasks = 0
            totalIterations = 0
            totalResets = 0
            avgTaskTimeSeconds = 0
            validationPassRate = 0
        }
        agentMetrics = @{
            pm = @{ iterations = 0; activeTime = 0; idleTime = 0 }
            developer = @{ iterations = 0; commits = 0; linesChanged = 0 }
            qa = @{ iterations = 0; validations = 0; bugsFound = 0 }
        }
    }
    
    $metrics | ConvertTo-Json -Depth 10 | Out-File -FilePath $metricsPath -Encoding utf8
    
    return $metrics
}

function Get-Metrics {
    <#
    .SYNOPSIS
    Reads current metrics from file.
    #>
    param([string]$ProjectRoot = (Get-Location).Path)
    
    $metricsPath = Get-MetricsFilePath -ProjectRoot $ProjectRoot
    
    if (-not (Test-Path $metricsPath)) {
        return Initialize-Metrics -ProjectRoot $ProjectRoot
    }
    
    try {
        return Get-Content $metricsPath -Raw | ConvertFrom-Json
    } catch {
        return Initialize-Metrics -ProjectRoot $ProjectRoot
    }
}

function Save-Metrics {
    <#
    .SYNOPSIS
    Saves metrics to file atomically.
    #>
    param(
        [Parameter(Mandatory=$true)]
        $Metrics,
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $metricsPath = Get-MetricsFilePath -ProjectRoot $ProjectRoot
    $tempPath = "$metricsPath.tmp"
    
    $Metrics.lastUpdated = Get-Timestamp
    
    try {
        $Metrics | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempPath -Encoding utf8
        Move-Item -Path $tempPath -Destination $metricsPath -Force
        return $true
    } catch {
        if (Test-Path $tempPath) { Remove-Item $tempPath -Force }
        return $false
    }
}

# ============================================================================
# TASK METRICS
# ============================================================================

function Record-TaskStart {
    <#
    .SYNOPSIS
    Records when a task starts.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskId,
        [Parameter(Mandatory=$true)]
        [string]$AgentName,
        [string]$TaskTitle = "",
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $metrics = Get-Metrics -ProjectRoot $ProjectRoot
    
    # Check if task already exists
    $existingTask = $metrics.taskMetrics | Where-Object { $_.taskId -eq $TaskId }
    
    if ($existingTask) {
        # Update existing task (retry)
        $existingTask.retryCount = ($existingTask.retryCount ?? 0) + 1
        $existingTask.lastStartedAt = Get-Timestamp
    } else {
        # Add new task
        $taskMetric = @{
            taskId = $TaskId
            title = $TaskTitle
            assignedTo = $AgentName
            startedAt = Get-Timestamp
            completedAt = $null
            status = "in_progress"
            durationSeconds = 0
            validationAttempts = 0
            retryCount = 0
            commits = 0
        }
        $metrics.taskMetrics += $taskMetric
        $metrics.aggregates.totalTasks++
    }
    
    Save-Metrics -Metrics $metrics -ProjectRoot $ProjectRoot
    
    # Also log event
    Write-Event -Type "task_start" -Data @{
        taskId = $TaskId
        agent = $AgentName
    } -ProjectRoot $ProjectRoot
}

function Record-TaskComplete {
    <#
    .SYNOPSIS
    Records when a task completes successfully.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskId,
        [Parameter(Mandatory=$true)]
        [string]$AgentName,
        [string]$CommitHash = "",
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $metrics = Get-Metrics -ProjectRoot $ProjectRoot
    
    $task = $metrics.taskMetrics | Where-Object { $_.taskId -eq $TaskId }
    
    if ($task) {
        $task.completedAt = Get-Timestamp
        $task.status = "completed"
        
        if ($task.startedAt) {
            try {
                $start = [DateTime]::Parse($task.startedAt)
                $end = [DateTime]::Parse($task.completedAt)
                $task.durationSeconds = [int]($end - $start).TotalSeconds
            } catch {}
        }
        
        if ($CommitHash) {
            $task.commits++
            $task.lastCommit = $CommitHash
        }
        
        $metrics.aggregates.completedTasks++
        
        # Update average task time
        $completedTasks = $metrics.taskMetrics | Where-Object { $_.status -eq "completed" }
        if ($completedTasks.Count -gt 0) {
            $totalTime = ($completedTasks | Measure-Object -Property durationSeconds -Sum).Sum
            $metrics.aggregates.avgTaskTimeSeconds = [int]($totalTime / $completedTasks.Count)
        }
    }
    
    Save-Metrics -Metrics $metrics -ProjectRoot $ProjectRoot
    
    Write-Event -Type "task_complete" -Data @{
        taskId = $TaskId
        agent = $AgentName
        commit = $CommitHash
    } -ProjectRoot $ProjectRoot
}

function Record-TaskFailed {
    <#
    .SYNOPSIS
    Records when a task fails validation.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskId,
        [string]$Reason = "",
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $metrics = Get-Metrics -ProjectRoot $ProjectRoot
    
    $task = $metrics.taskMetrics | Where-Object { $_.taskId -eq $TaskId }
    
    if ($task) {
        $task.validationAttempts++
        $task.lastFailedAt = Get-Timestamp
        $task.lastFailReason = $Reason
        
        # After 3 failures, mark as failed
        if ($task.validationAttempts -ge 3) {
            $task.status = "failed"
            $metrics.aggregates.failedTasks++
        } else {
            $task.status = "needs_fixes"
        }
    }
    
    Save-Metrics -Metrics $metrics -ProjectRoot $ProjectRoot
    
    Write-Event -Type "task_failed" -Data @{
        taskId = $TaskId
        reason = $Reason
        attempts = $task.validationAttempts
    } -ProjectRoot $ProjectRoot
}

function Record-ValidationPass {
    <#
    .SYNOPSIS
    Records a successful QA validation.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskId,
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $metrics = Get-Metrics -ProjectRoot $ProjectRoot
    
    $task = $metrics.taskMetrics | Where-Object { $_.taskId -eq $TaskId }
    
    if ($task) {
        $task.status = "passed"
        $task.passedAt = Get-Timestamp
    }
    
    # Update pass rate
    $validatedTasks = $metrics.taskMetrics | Where-Object { $_.status -in @("passed", "failed") }
    if ($validatedTasks.Count -gt 0) {
        $passedCount = ($validatedTasks | Where-Object { $_.status -eq "passed" }).Count
        $metrics.aggregates.validationPassRate = [math]::Round($passedCount / $validatedTasks.Count, 2)
    }
    
    $metrics.agentMetrics.qa.validations++
    
    Save-Metrics -Metrics $metrics -ProjectRoot $ProjectRoot
    
    Write-Event -Type "validation_pass" -Data @{
        taskId = $TaskId
    } -ProjectRoot $ProjectRoot
}

# ============================================================================
# AGENT METRICS
# ============================================================================

function Record-AgentIteration {
    <#
    .SYNOPSIS
    Records an iteration for an agent.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $metrics = Get-Metrics -ProjectRoot $ProjectRoot
    
    if ($metrics.agentMetrics.$AgentName) {
        $metrics.agentMetrics.$AgentName.iterations++
    }
    
    $metrics.aggregates.totalIterations++
    
    Save-Metrics -Metrics $metrics -ProjectRoot $ProjectRoot
}

function Record-ContextResetMetric {
    <#
    .SYNOPSIS
    Records a context reset in metrics.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,
        [string]$Reason = "",
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $metrics = Get-Metrics -ProjectRoot $ProjectRoot
    
    $metrics.aggregates.totalResets++
    
    Save-Metrics -Metrics $metrics -ProjectRoot $ProjectRoot
    
    Write-Event -Type "context_reset" -Data @{
        agent = $AgentName
        reason = $Reason
    } -ProjectRoot $ProjectRoot
}

function Record-Commit {
    <#
    .SYNOPSIS
    Records a git commit.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,
        [string]$CommitHash = "",
        [int]$LinesAdded = 0,
        [int]$LinesRemoved = 0,
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $metrics = Get-Metrics -ProjectRoot $ProjectRoot
    
    if ($AgentName -eq "developer" -and $metrics.agentMetrics.developer) {
        $metrics.agentMetrics.developer.commits++
        $metrics.agentMetrics.developer.linesChanged += ($LinesAdded + $LinesRemoved)
    }
    
    Save-Metrics -Metrics $metrics -ProjectRoot $ProjectRoot
    
    Write-Event -Type "commit" -Data @{
        agent = $AgentName
        hash = $CommitHash
        linesAdded = $LinesAdded
        linesRemoved = $LinesRemoved
    } -ProjectRoot $ProjectRoot
}

# ============================================================================
# STRUCTURED EVENT LOG (JSONL)
# ============================================================================

function Write-Event {
    <#
    .SYNOPSIS
    Writes a structured event to the JSONL log.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Type,
        [hashtable]$Data = @{},
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $eventsPath = Get-EventsLogPath -ProjectRoot $ProjectRoot
    
    $event = @{
        timestamp = Get-Timestamp
        type = $Type
        data = $Data
    }
    
    $eventJson = $event | ConvertTo-Json -Compress
    
    try {
        Add-Content -Path $eventsPath -Value $eventJson -Encoding utf8
    } catch {
        # Ignore event logging failures
    }
}

function Get-RecentEvents {
    <#
    .SYNOPSIS
    Reads recent events from the log.
    #>
    param(
        [int]$Count = 50,
        [string]$Type = "",
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $eventsPath = Get-EventsLogPath -ProjectRoot $ProjectRoot
    
    if (-not (Test-Path $eventsPath)) {
        return @()
    }
    
    $events = Get-Content $eventsPath -Tail $Count | ForEach-Object {
        try {
            $_ | ConvertFrom-Json
        } catch {}
    }
    
    if ($Type) {
        $events = $events | Where-Object { $_.type -eq $Type }
    }
    
    return $events
}

# ============================================================================
# METRICS SUMMARY
# ============================================================================

function Get-MetricsSummary {
    <#
    .SYNOPSIS
    Gets a human-readable summary of current metrics.
    #>
    param([string]$ProjectRoot = (Get-Location).Path)
    
    $metrics = Get-Metrics -ProjectRoot $ProjectRoot
    
    $summary = @"
=== Ralph Session Metrics ===
Session: $($metrics.sessionId)
Started: $($metrics.startedAt)

TASKS:
  Total: $($metrics.aggregates.totalTasks)
  Completed: $($metrics.aggregates.completedTasks)
  Failed: $($metrics.aggregates.failedTasks)
  Avg Time: $($metrics.aggregates.avgTaskTimeSeconds)s
  Pass Rate: $([math]::Round($metrics.aggregates.validationPassRate * 100, 1))%

ITERATIONS:
  Total: $($metrics.aggregates.totalIterations)
  Context Resets: $($metrics.aggregates.totalResets)

AGENTS:
  PM: $($metrics.agentMetrics.pm.iterations) iterations
  Developer: $($metrics.agentMetrics.developer.iterations) iterations, $($metrics.agentMetrics.developer.commits) commits
  QA: $($metrics.agentMetrics.qa.iterations) iterations, $($metrics.agentMetrics.qa.validations) validations
"@
    
    return $summary
}
