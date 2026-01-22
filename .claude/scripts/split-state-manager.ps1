# Ralph Split State Manager - Modular State Management
# Phase 2: Splits monolithic coordinator-state.json into separate files by concern
# Reduces write contention and improves performance
#
# Benefits:
# - Smaller files = faster I/O
# - Clearer ownership (each file has a primary writer)
# - Better crash recovery (corrupt one file doesn't lose everything)

# ============================================================================
# CONFIGURATION
# ============================================================================

$Script:StateDir = $null
$Script:StateCache = @{}  # Cache for state files

# State file definitions
$Script:StateFiles = @{
    "agents" = @{
        Path = "state/agents.json"
        Description = "Agent statuses and process states"
        PrimaryWriter = "watchdog"
        Schema = @{
            pm = @{ status = "idle"; ProcessState = "stopped"; pid = $null; LastSeen = $null }
            developer = @{ status = "idle"; ProcessState = "stopped"; pid = $null; LastSeen = $null }
            qa = @{ status = "idle"; ProcessState = "stopped"; pid = $null; LastSeen = $null }
            gamedesigner = @{ status = "idle"; ProcessState = "stopped"; pid = $null; LastSeen = $null }
            techartist = @{ status = "idle"; ProcessState = "stopped"; pid = $null; LastSeen = $null }
        }
    }
    "prd" = @{
        Path = "state/prd.json"
        Description = "PRD state and task progress"
        PrimaryWriter = "pm"
        Schema = @{
            version = "2.0"
            tasks = @{}
            currentTask = $null
        }
    }
    "current-task" = @{
        Path = "state/current-task.json"
        Description = "Current active task being worked on"
        PrimaryWriter = "shared"
        Schema = @{
            taskId = $null
            agent = $null
            status = "idle"
            startTime = $null
        }
    }
    "metrics" = @{
        Path = "state/metrics.json"
        Description = "Performance metrics and session statistics"
        PrimaryWriter = "watchdog"
        Schema = @{
            startTime = [DateTime]::UtcNow.ToString("o")
            totalMessagesRouted = 0
            totalIterations = 0
            uptimeSeconds = 0
        }
    }
}

# ============================================================================
# INITIALIZATION
# ============================================================================

function Initialize-SplitStateManager {
    <#
    .SYNOPSIS
    Initialize the split state manager.

    .PARAMETER SessionDir
    The session directory path.

    .RETURNS
    $true if initialized successfully, $false otherwise.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$SessionDir
    )

    $Script:StateDir = $SessionDir
    $statePath = Join-Path $SessionDir "state"

    # Create state directory
    if (-not (Test-Path $statePath)) {
        New-Item -ItemType Directory -Path $statePath -Force | Out-Null
    }

    # Initialize each state file with default schema if doesn't exist
    foreach ($key in $Script:StateFiles.Keys) {
        $stateFile = $Script:StateFiles[$key]
        $filePath = Join-Path $SessionDir $stateFile.Path

        if (-not (Test-Path $filePath)) {
            $defaultState = $stateFile.Schema
            $defaultState | ConvertTo-Json -Depth 10 | Out-File -FilePath $filePath -Encoding UTF8
        }

        # Cache initial state
        $Script:StateCache[$key] = Get-StateFile -Name $key
    }

    return $true
}

# ============================================================================
# STATE FILE OPERATIONS
# ============================================================================

function Get-StateFile {
    <#
    .SYNOPSIS
    Read a state file with caching.

    .PARAMETER Name
    The state file name (agents, prd, current-task, metrics).

    .PARAMETER NoCache
    Bypass cache and read from disk.

    .RETURNS
    The state object, or $null if file doesn't exist.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("agents", "prd", "current-task", "metrics")]
        [string]$Name,

        [switch]$NoCache
    )

    if (-not $Script:StateDir) {
        throw "Split state manager not initialized. Call Initialize-SplitStateManager first."
    }

    $stateFile = $Script:StateFiles[$Name]
    $filePath = Join-Path $Script:StateDir $stateFile.Path

    # Check cache first
    if (-not $NoCache -and $Script:StateCache[$Name]) {
        return $Script:StateCache[$Name]
    }

    # Read from disk
    try {
        $content = Get-Content $filePath -Raw -ErrorAction Stop | ConvertFrom-Json
        $Script:StateCache[$Name] = $content
        return $content
    } catch {
        # File doesn't exist or is corrupt - return default schema
        return $stateFile.Schema
    }
}

function Set-StateFile {
    <#
    .SYNOPSIS
    Write to a state file with atomic write pattern and locking.

    .PARAMETER Name
    The state file name (agents, prd, current-task, metrics).

    .PARAMETER Data
    The data to write (will be serialized to JSON).

    .PARAMETER AgentName
    The agent performing the write (for lock tracking).

    .PARAMETER UseLock
    Use file locking for write (default: true).

    .RETURNS
    $true if successful, $false otherwise.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("agents", "prd", "current-task", "metrics")]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [object]$Data,

        [string]$AgentName = "unknown",

        [switch]$UseLock
    )

    if (-not $Script:StateDir) {
        throw "Split state manager not initialized. Call Initialize-SplitStateManager first."
    }

    $stateFile = $Script:StateFiles[$Name]
    $filePath = Join-Path $Script:StateDir $stateFile.Path

    # Use file-lock.ps1 if available
    $lockModule = Join-Path $PSScriptRoot "file-lock.ps1"

    if ($UseLock -and (Test-Path $lockModule)) {
        . $lockModule

        try {
            Invoke-WithFileLock -FilePath $filePath -AgentName $AgentName -ScriptBlock {
                $Data | ConvertTo-Json -Depth 10 | Out-File -FilePath $filePath -Encoding UTF8 -Force
            }
        } catch {
            Write-Warning "[SplitStateManager] Failed to write $Name with lock: $_"
            return $false
        }
    } else {
        # Atomic write without lock
        $tempPath = "$filePath.tmp"
        try {
            $Data | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempPath -Encoding UTF8
            Move-Item -Path $tempPath -Destination $filePath -Force
        } catch {
            if (Test-Path $tempPath) { Remove-Item $tempPath -Force }
            throw
        }
    }

    # Update cache
    $Script:StateCache[$Name] = $Data

    return $true
}

function Update-StateFile {
    <#
    .SYNOPSIS
    Update a state file with a transform script block.

    .PARAMETER Name
    The state file name.

    .PARAMETER UpdateScript
    Script block that receives current state and returns updated state.

    .PARAMETER AgentName
    The agent performing the update.

    .EXAMPLE
    Update-StateFile -Name "agents" -AgentName "watchdog" -UpdateScript {
        param($state)
        $state.developer.status = "working"
        $state.developer.LastSeen = [DateTime]::UtcNow.ToString("o")
        return $state
    }
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("agents", "prd", "current-task", "metrics")]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [scriptblock]$UpdateScript,

        [string]$AgentName = "unknown"
    )

    $currentState = Get-StateFile -Name $Name
    $updatedState = & $UpdateScript $currentState

    if ($updatedState) {
        return Set-StateFile -Name $Name -Data $updatedState -AgentName $AgentName
    }

    return $false
}

# ============================================================================
# AGENT STATE HELPERS
# ============================================================================

function Get-AgentState {
    <#
    .SYNOPSIS
    Get state for a specific agent.

    .PARAMETER AgentName
    The agent name.

    .RETURNS
    The agent's state object, or $null if not found.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("pm", "developer", "qa", "gamedesigner", "techartist")]
        [string]$AgentName
    )

    $agentsState = Get-StateFile -Name "agents"
    return $agentsState.$AgentName
}

function Set-AgentState {
    <#
    .SYNOPSIS
    Update state for a specific agent.

    .PARAMETER AgentName
    The agent name.

    .PARAMETER Updates
    Hashtable of properties to update.

    .PARAMETER WriterAgent
    The agent performing the update.

    .EXAMPLE
    Set-AgentState -AgentName "developer" -Updates @{
        status = "working"
        currentTask = "feat-001"
    } -WriterAgent "watchdog"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("pm", "developer", "qa", "gamedesigner", "techartist")]
        [string]$AgentName,

        [Parameter(Mandatory=$true)]
        [hashtable]$Updates,

        [string]$WriterAgent = "watchdog"
    )

    return Update-StateFile -Name "agents" -AgentName $WriterAgent -UpdateScript {
        param($state)
        foreach ($key in $Updates.Keys) {
            $state.$AgentName.$key = $Updates[$key]
        }
        $state.$AgentName.LastSeen = [DateTime]::UtcNow.ToString("o")
        return $state
    }
}

# ============================================================================
# PRD STATE HELPERS
# ============================================================================

function Get-PRDState {
    <#
    .SYNOPSIS
    Get the PRD state.

    .RETURNS
    The PRD state object.
    #>
    param()

    return Get-StateFile -Name "prd"
}

function Set-PRDState {
    <#
    .SYNOPSIS
    Update the PRD state.

    .PARAMETER State
    The new PRD state object.

    .PARAMETER AgentName
    The agent performing the update (should be "pm").
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object]$State,

        [string]$AgentName = "pm"
    )

    return Set-StateFile -Name "prd" -Data $State -AgentName $AgentName
}

# ============================================================================
# CURRENT TASK HELPERS
# ============================================================================

function Get-CurrentTask {
    <#
    .SYNOPSIS
    Get the current active task.

    .RETURNS
    The current task object, or $null if no active task.
    #>
    param()

    return Get-StateFile -Name "current-task"
}

function Set-CurrentTask {
    <#
    .SYNOPSIS
    Set the current active task.

    .PARAMETER TaskId
    The task ID.

    .PARAMETER Agent
    The agent working on the task.

    .PARAMETER Status
    The task status.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskId,

        [Parameter(Mandatory=$true)]
        [ValidateSet("pm", "developer", "qa", "gamedesigner", "techartist")]
        [string]$Agent,

        [string]$Status = "assigned"
    )

    $taskState = @{
        taskId = $TaskId
        agent = $Agent
        status = $Status
        startTime = [DateTime]::UtcNow.ToString("o")
    }

    return Set-StateFile -Name "current-task" -Data $taskState -AgentName $Agent
}

function Clear-CurrentTask {
    <#
    .SYNOPSIS
    Clear the current active task.

    .PARAMETER AgentName
    The agent clearing the task.
    #>
    param(
        [string]$AgentName = "watchdog"
    )

    $emptyState = @{
        taskId = $null
        agent = $null
        status = "idle"
        startTime = $null
    }

    return Set-StateFile -Name "current-task" -Data $emptyState -AgentName $AgentName
}

# ============================================================================
# METRICS HELPERS
# ============================================================================

function Get-Metrics {
    <#
    .SYNOPSIS
    Get the performance metrics.

    .RETURNS
    The metrics object.
    #>
    param()

    return Get-StateFile -Name "metrics"
}

function Update-Metrics {
    <#
    .SYNOPSIS
    Update specific metrics.

    .PARAMETER Updates
    Hashtable of metrics to update.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Updates
    )

    return Update-StateFile -Name "metrics" -AgentName "watchdog" -UpdateScript {
        param($metrics)
        foreach ($key in $Updates.Keys) {
            $metrics.$key = $Updates[$key]
        }

        # Auto-update uptime
        if ($metrics.startTime) {
            $startTime = [DateTime]::Parse($metrics.startTime)
            $metrics.uptimeSeconds = ([DateTime]::UtcNow - $startTime).TotalSeconds
        }

        return $metrics
    }
}

# ============================================================================
# DIAGNOSTICS
# ============================================================================

function Get-SplitStateReport {
    <#
    .SYNOPSIS
    Get a diagnostic report of all state files.

    .RETURNS
    Hashtable with file statistics.
    #>
    param()

    if (-not $Script:StateDir) {
        throw "Split state manager not initialized."
    }

    $report = @{}

    foreach ($key in $Script:StateFiles.Keys) {
        $stateFile = $Script:StateFiles[$key]
        $filePath = Join-Path $Script:StateDir $stateFile.Path

        $fileInfo = $null
        if (Test-Path $filePath) {
            $fileInfo = Get-Item $filePath
        }

        $report[$key] = @{
            Path = $stateFile.Path
            Exists = (Test-Path $filePath)
            SizeBytes = if ($fileInfo) { $fileInfo.Length } else { 0 }
            PrimaryWriter = $stateFile.PrimaryWriter
            Description = $stateFile.Description
            Cached = ($null -ne $Script:StateCache[$key])
        }
    }

    return $report
}

function Show-SplitStateReport {
    <#
    .SYNOPSIS
    Display the split state report to console.
    #>
    param()

    $report = Get-SplitStateReport

    Write-Host "=== Split State Report ===" -ForegroundColor Cyan
    foreach ($key in $report.Keys) {
        $info = $report[$key]
        $status = if ($info.Exists) { "OK" } else { "MISSING" }
        $statusColor = if ($info.Exists) { "Green" } else { "Red" }

        Write-Host "[$key] " -NoNewline -ForegroundColor Cyan
        Write-Host "$status " -NoNewline -ForegroundColor $statusColor
        Write-Host "($($info.SizeBytes) bytes, writer: $($info.PrimaryWriter))"
        Write-Host "  Path: $($info.Path)" -ForegroundColor DarkGray
        Write-Host "  $($info.Description)" -ForegroundColor DarkGray
    }
    Write-Host "========================" -ForegroundColor Cyan
}

# ============================================================================
# EXPORT
# ============================================================================

# Module is dot-sourced, functions become available
