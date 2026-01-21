# Ralph Message State Manager
# Single source of truth for message processing state and task completion
# Provides idempotency checks for all message operations
#
# Key Design:
# - Messages deleted immediately when processed (no grace period)
# - State persists across watchdog restarts (crash recovery)
# - coordinator-state.json holds longer-term state; this is for deduplication only

# ============================================================================
# CONFIGURATION
# ============================================================================

$Script:MessageStateFile = $null
$Script:MessageStateDir = $null

# In-memory cache for fast lookups
$Script:ProcessedMessagesCache = @{}
$Script:CompletedTasksCache = @{}
$Script:StateLoaded = $false

# ============================================================================
# INITIALIZATION
# ============================================================================

function Initialize-MessageStateManager {
    <#
    .SYNOPSIS
    Initialize the message state manager.

    .PARAMETER SessionDir
    The session directory path.

    .RETURNS
    $true if initialized successfully, $false otherwise.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$SessionDir
    )

    $Script:MessageStateDir = $SessionDir
    $Script:MessageStateFile = Join-Path $SessionDir "message-state.json"

    # Create state file if it doesn't exist
    if (-not (Test-Path $Script:MessageStateFile)) {
        $initialState = @{
            processedMessages = @{}
            completedTasks = @{}
            lastCleanup = [DateTime]::UtcNow.ToString("o")
            version = "1.0"
        }
        $initialState | ConvertTo-Json -Depth 10 | Out-File -FilePath $Script:MessageStateFile -Encoding UTF8
    }

    # Load state into cache
    return Read-MessageState
}

function Read-MessageState {
    <#
    .SYNOPSIS
    Load state from file into cache (idempotent).
    #>
    param()

    if (-not $Script:MessageStateFile) {
        return $false
    }

    try {
        $content = Get-Content $Script:MessageStateFile -Raw -ErrorAction Stop | ConvertFrom-Json

        # Rebuild hashtables from JSON
        $Script:ProcessedMessagesCache = @{}
        if ($content.processedMessages) {
            foreach ($prop in $content.processedMessages.PSObject.Properties) {
                $Script:ProcessedMessagesCache[$prop.Name] = $prop.Value
            }
        }

        $Script:CompletedTasksCache = @{}
        if ($content.completedTasks) {
            foreach ($prop in $content.completedTasks.PSObject.Properties) {
                $Script:CompletedTasksCache[$prop.Name] = $prop.Value
            }
        }

        $Script:StateLoaded = $true
        return $true
    } catch {
        # File doesn't exist or is corrupt - initialize empty state
        $Script:ProcessedMessagesCache = @{}
        $Script:CompletedTasksCache = @{}
        $Script:StateLoaded = $false
        return $false
    }
}

function Write-MessageState {
    <#
    .SYNOPSIS
    Write current cache state to file (atomic write pattern).
    #>
    param()

    if (-not $Script:MessageStateFile) {
        return $false
    }

    try {
        $state = @{
            processedMessages = $Script:ProcessedMessagesCache
            completedTasks = $Script:CompletedTasksCache
            lastCleanup = [DateTime]::UtcNow.ToString("o")
            version = "1.0"
        }

        # Atomic write: write to temp file, then rename
        $tempPath = $Script:MessageStateFile + ".tmp"
        $state | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempPath -Encoding UTF8

        # Atomic rename
        Move-Item -Path $tempPath -Destination $Script:MessageStateFile -Force
        return $true
    } catch {
        return $false
    }
}

# ============================================================================
# MESSAGE STATE TRACKING
# ============================================================================

function Test-MessageProcessed {
    <#
    .SYNOPSIS
    Check if a message was already processed.

    .PARAMETER MessageId
    The message ID to check.

    .RETURNS
    $true if the message was already processed, $false otherwise.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$MessageId
    )

    # Reload state if cache is empty (handles watchdog restart)
    if (-not $Script:StateLoaded -or $Script:ProcessedMessagesCache.Count -eq 0) {
        Read-MessageState
    }

    return $Script:ProcessedMessagesCache.ContainsKey($MessageId)
}

function Set-MessageProcessed {
    <#
    .SYNOPSIS
    Mark a message as processed (idempotent).

    .PARAMETER MessageId
    The message ID to mark as processed.

    .PARAMETER Result
    Optional result data to attach.

    .PARAMETER FromAgent
    The agent that processed this message.

    .RETURNS
    $true if marked successfully, $false if already existed.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$MessageId,

        [hashtable]$Result = @{},

        [string]$FromAgent = $null
    )

    # Check if already processed (idempotency)
    if (Test-MessageProcessed -MessageId $MessageId) {
        return $false
    }

    # Mark as processed
    $processData = @{
        processedAt = [DateTime]::UtcNow.ToString("o")
        message = $MessageId
    }

    if ($Result.Count -gt 0) {
        $processData.result = $Result
    }

    if ($FromAgent) {
        $processData.processedBy = $FromAgent
    }

    $Script:ProcessedMessagesCache[$MessageId] = $processData

    # Persist to disk
    Write-MessageState

    return $true
}

function Get-ProcessedMessage {
    <#
    .SYNOPSIS
    Get the processing record for a message.

    .PARAMETER MessageId
    The message ID to look up.

    .RETURNS
    The processing record, or $null if not found.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$MessageId
    )

    if (-not $Script:StateLoaded) {
        Read-MessageState
    }

    if ($Script:ProcessedMessagesCache.ContainsKey($MessageId)) {
        return $Script:ProcessedMessagesCache[$MessageId]
    }

    return $null
}

function Remove-ProcessedMessage {
    <#
    .SYNOPSIS
    Remove a message from processed state (for cleanup).

    .PARAMETER MessageId
    The message ID to remove.

    .PARAMETER OlderThan
    Only remove if processed before this time.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$MessageId,

        [DateTime]$OlderThan = $null
    )

    if (-not $Script:ProcessedMessagesCache.ContainsKey($MessageId)) {
        return $false
    }

    # Check age if filter specified
    if ($OlderThan) {
        $record = $Script:ProcessedMessagesCache[$MessageId]
        $processedAt = [DateTime]::Parse($record.processedAt)
        if ($processedAt -ge $OlderThan) {
            return $false  # Too recent, don't remove
        }
    }

    $Script:ProcessedMessagesCache.Remove($MessageId)
    Write-MessageState
    return $true
}

# ============================================================================
# TASK COMPLETION TRACKING
# ============================================================================

function Test-TaskCompleted {
    <#
    .SYNOPSIS
    Check if a task was already completed.

    .PARAMETER TaskId
    The task ID to check (e.g., "feat-001").

    .RETURNS
    $true if the task was completed, $false otherwise.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskId
    )

    # Reload state if cache is empty
    if (-not $Script:StateLoaded -or $Script:CompletedTasksCache.Count -eq 0) {
        Read-MessageState
    }

    return $Script:CompletedTasksCache.ContainsKey($TaskId)
}

function Set-TaskCompleted {
    <#
    .SYNOPSIS
    Mark a task as completed (idempotent).

    .PARAMETER TaskId
    The task ID to mark as completed.

    .PARAMETER Status
    The completion status (passed, needs_fixes, etc.).

    .PARAMETER Agent
    The agent that completed the task.

    .PARAMETER Summary
    Optional summary of completion.

    .RETURNS
    $true if marked successfully, $false if already existed with same status.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskId,

        [Parameter(Mandatory=$true)]
        [string]$Status,

        [string]$Agent = $null,

        [string]$Summary = $null
    )

    # Check if already completed with same status (idempotency)
    if ($Script:CompletedTasksCache.ContainsKey($TaskId)) {
        $existing = $Script:CompletedTasksCache[$TaskId]
        if ($existing.status -eq $Status) {
            return $false  # Already set
        }
    }

    $taskData = @{
        completedAt = [DateTime]::UtcNow.ToString("o")
        status = $Status
        task = $TaskId
    }

    if ($Agent) {
        $taskData.completedBy = $Agent
    }

    if ($Summary) {
        $taskData.summary = $Summary
    }

    $Script:CompletedTasksCache[$TaskId] = $taskData

    # Persist to disk
    Write-MessageState

    return $true
}

function Get-CompletedTask {
    <#
    .SYNOPSIS
    Get the completion record for a task.

    .PARAMETER TaskId
    The task ID to look up.

    .RETURNS
    The completion record, or $null if not found.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskId
    )

    if (-not $Script:StateLoaded) {
        Read-MessageState
    }

    if ($Script:CompletedTasksCache.ContainsKey($TaskId)) {
        return $Script:CompletedTasksCache[$TaskId]
    }

    return $null
}

# ============================================================================
# STATE CLEANUP
# ============================================================================

function Invoke-StateCleanup {
    <#
    .SYNOPSIS
    Clean up old state entries to prevent unbounded growth.

    .PARAMETER OlderThan
    Remove entries older than this time (default: 24 hours).

    .RETURNS
    Hashtable with count of removed entries.
    #>
    param(
        [DateTime]$OlderThan = (Get-Date).AddHours(-24)
    )

    # Ensure state is loaded
    if (-not $Script:StateLoaded) {
        Read-MessageState
    }

    $removedMessages = 0
    $removedTasks = 0

    # Clean old processed messages
    $messagesToRemove = @()
    foreach ($key in $Script:ProcessedMessagesCache.Keys) {
        $record = $Script:ProcessedMessagesCache[$key]
        try {
            $processedAt = [DateTime]::Parse($record.processedAt)
            if ($processedAt -lt $OlderThan) {
                $messagesToRemove += $key
            }
        } catch {
            # Invalid date - remove it
            $messagesToRemove += $key
        }
    }

    foreach ($key in $messagesToRemove) {
        $Script:ProcessedMessagesCache.Remove($key)
        $removedMessages++
    }

    # Note: Don't auto-remove completedTasks - those are longer-lived
    # They represent actual task completion and are used for deduplication

    # Persist changes
    if ($removedMessages -gt 0) {
        Write-MessageState
    }

    return @{
        processedMessagesRemoved = $removedMessages
        tasksRemoved = $removedTasks
        cleanupTime = [DateTime]::UtcNow.ToString("o")
    }
}

function Clear-MessageState {
    <#
    .SYNOPSIS
    Clear ALL state (useful for fresh start or testing).

    .RETURNS
    $true if cleared successfully.
    #>
    param()

    $Script:ProcessedMessagesCache = @{}
    $Script:CompletedTasksCache = @{}

    if ($Script:MessageStateFile -and (Test-Path $Script:MessageStateFile)) {
        Remove-Item $Script:MessageStateFile -Force
    }

    return $true
}

# ============================================================================
# DIAGNOSTICS
# ============================================================================

function Get-MessageStateReport {
    <#
    .SYNOPSIS
    Get a diagnostic report of current state.

    .RETURNS
    Hashtable with state statistics.
    #>
    param()

    if (-not $Script:StateLoaded) {
        Read-MessageState
    }

    # Calculate age statistics
    $now = [DateTime]::UtcNow
    $oldestMessage = $null
    $newestMessage = $null

    foreach ($record in $Script:ProcessedMessagesCache.Values) {
        try {
            $processedAt = [DateTime]::Parse($record.processedAt)
            if (-not $oldestMessage -or $processedAt -lt $oldestMessage) {
                $oldestMessage = $processedAt
            }
            if (-not $newestMessage -or $processedAt -gt $newestMessage) {
                $newestMessage = $processedAt
            }
        } catch {}
    }

    return @{
        totalProcessedMessages = $Script:ProcessedMessagesCache.Count
        totalCompletedTasks = $Script:CompletedTasksCache.Count
        oldestMessage = if ($oldestMessage) { $oldestMessage.ToString("o") } else { $null }
        newestMessage = if ($newestMessage) { $newestMessage.ToString("o") } else { $null }
        stateFile = $Script:MessageStateFile
        stateLoaded = $Script:StateLoaded
        cacheSizeBytes = if ($Script:MessageStateFile -and (Test-Path $Script:MessageStateFile)) {
            (Get-Item $Script:MessageStateFile).Length
        } else { 0 }
    }
}

function Show-MessageStateReport {
    <#
    .SYNOPSIS
    Display the state report to console.
    #>
    param()

    $report = Get-MessageStateReport

    Write-Host "=== Message State Report ===" -ForegroundColor Cyan
    Write-Host "Processed Messages: $($report.totalProcessedMessages)" -ForegroundColor White
    Write-Host "Completed Tasks: $($report.totalCompletedTasks)" -ForegroundColor White
    Write-Host "State File: $($report.stateFile)" -ForegroundColor Gray
    Write-Host "Cache Size: $($report.cacheSizeBytes) bytes" -ForegroundColor Gray
    if ($report.oldestMessage) {
        Write-Host "Oldest Message: $($report.oldestMessage)" -ForegroundColor Gray
    }
    if ($report.newestMessage) {
        Write-Host "Newest Message: $($report.newestMessage)" -ForegroundColor Gray
    }
    Write-Host "========================" -ForegroundColor Cyan
}

# ============================================================================
# EXPORT
# ============================================================================

# Module is dot-sourced, functions become available
