# Ralph Event Log Module - Event Sourcing Foundation
# Single source of truth for all system events
#
# Design Patterns Applied:
# - Event Sourcing: All state changes stored as sequence of events
# - CQRS: Write model (event log) separate from read model (materialized views)
# - At-Least-Once Delivery: Events persisted before acknowledgment
#
# References:
# - https://martinfowler.com/eaaDev/EventSourcing.html
# - https://docs.microsoft.com/en-us/azure/architecture/patterns/cqrs

$Script:EventLogFile = $null
$Script:EventLogSessionDir = $null

# ============================================================================
# CONCURRENCY PROTECTION
# ============================================================================

# Import or initialize mutex for event log protection
$Script:EventLogMutex = $null
$Script:SequenceMutex = $null
$Script:SessionId = $null

function Initialize-EventLogMutex {
    <#
    .SYNOPSIS
    Initialize mutexes for event log concurrent access protection.

    .DESCRIPTION
    Creates cross-process mutexes for:
    1. Sequence number allocation (prevents duplicates)
    2. File write operations (prevents corruption)

    .PARAMETER SessionId
    Optional session ID for mutex names (enables isolation).
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$SessionId = ""
    )

    $Script:SessionId = $SessionId

    if ($SessionId) {
        $seqMutexName = "Global\Ralph_${SessionId}_EventSeq"
        $writeMutexName = "Global\Ralph_${SessionId}_EventWrite"
    } else {
        $seqMutexName = "Global\RalphEventSeq"
        $writeMutexName = "Global\RalphEventWrite"
    }

    $Script:SequenceMutex = [System.Threading.Mutex]::new($false, $seqMutexName)
    $Script:EventLogMutex = [System.Threading.Mutex]::new($false, $writeMutexName)
}

function Get-SequenceMutex {
    if (-not $Script:SequenceMutex) {
        Initialize-EventLogMutex -SessionId $Script:SessionId
    }
    return $Script:SequenceMutex
}

function Get-EventLogMutexInternal {
    if (-not $Script:EventLogMutex) {
        Initialize-EventLogMutex -SessionId $Script:SessionId
    }
    return $Script:EventLogMutex
}

# ============================================================================
# INITIALIZATION
# ============================================================================

function Initialize-EventLog {
    <#
    .SYNOPSIS
    Initialize the event log for a Ralph session.

    .DESCRIPTION
    Creates or opens the append-only event log file (eventlog.jsonl).
    This file is the single source of truth for all system events.
    Also initializes mutexes for concurrent access protection.

    .PARAMETER SessionDir
    The session directory path.

    .PARAMETER SessionId
    Optional session ID for mutex isolation.

    .RETURNS
    The full path to the event log file.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$SessionDir,

        [Parameter(Mandatory=$false)]
        [string]$SessionId = ""
    )

    $Script:EventLogSessionDir = $SessionDir
    $Script:EventLogFile = Join-Path $SessionDir "eventlog.jsonl"
    $Script:SessionId = $SessionId

    # Initialize mutexes for concurrent access protection
    Initialize-EventLogMutex -SessionId $SessionId

    # Create log file if doesn't exist
    if (-not (Test-Path $Script:EventLogFile)) {
        # Ensure directory exists
        $logDir = Split-Path -Parent $Script:EventLogFile
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        # Create empty file with UTF-8 BOM for PowerShell compatibility
        [System.IO.File]::WriteAllLines($Script:EventLogFile, @())
    }

    return $Script:EventLogFile
}

function Get-EventLogPath {
    <#
    .SYNOPSIS
    Get the current event log file path.

    .RETURNS
    The full path to the event log file, or $null if not initialized.
    #>
    if ($Script:EventLogFile -and (Test-Path $Script:EventLogFile)) {
        return $Script:EventLogFile
    }
    return $null
}

# ============================================================================
# EVENT TYPES
# ============================================================================

# Core event types for the Ralph Orchestra system
# These represent all state changes in the system

$Script:EventTypes = @{
    # Lifecycle Events
    "AgentStarted" = "An agent process was started"
    "AgentExited" = "An agent process exited (graceful or crash)"
    "AgentCrashed" = "An agent crashed (unexpected exit)"

    # Message Events
    "MessageSent" = "A message was sent from one agent to another"
    "MessageDelivered" = "A message was successfully delivered to recipient"
    "MessageAcked" = "A message was acknowledged by recipient"

    # Work Events
    "TaskAssigned" = "A task was assigned to an agent"
    "TaskCompleted" = "A task was completed by an agent"
    "TaskAbandoned" = "A task was abandoned by an agent"

    # System Events
    "WatchdogStarted" = "The watchdog supervisor was started"
    "WatchdogStopped" = "The watchdog supervisor was stopped"
    "SessionInitialized" = "A new Ralph session was initialized"

    # CLI Process Events
    "CLIStarted" = "A CLI process was started for an agent"
    "CLICompleted" = "A CLI process completed"
    "CLITimeout" = "A CLI process timed out and was killed"
    "CLIFailed" = "A CLI process failed to start"
}

function Get-EventType {
    <#
    .SYNOPSIS
    Get description of an event type.

    .PARAMETER Type
    The event type name.

    .RETURNS
    Description string, or $null if unknown type.
    #>
    param([string]$Type)
    if ($Script:EventTypes.ContainsKey($Type)) {
        return $Script:EventTypes[$Type]
    }
    return $null
}

# ============================================================================
# WRITE OPERATIONS (CQRS Command Side)
# ============================================================================

function Write-Event {
    <#
    .SYNOPSIS
    Append a new event to the event log with mutex protection.

    .DESCRIPTION
    This is the primary write operation for the event log.
    All state changes must go through this function to ensure
    the single source of truth is maintained.

    CRITICAL FIX: Uses mutex protection for both sequence allocation
    and file writing to prevent:
    1. Duplicate sequence numbers (TOCTOU)
    2. File corruption from concurrent writes

    .PARAMETER Type
    The event type (e.g., "AgentStarted", "MessageSent").

    .PARAMETER Data
    A hashtable containing the event payload data.

    .PARAMETER Timestamp
    Optional timestamp. If not provided, uses current UTC time.

    .RETURNS
    The sequence number assigned to this event.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Type,

        [Parameter(Mandatory=$false)]
        [hashtable]$Data = @{},

        [Parameter(Mandatory=$false)]
        [DateTime]$Timestamp = [DateTime]::UtcNow
    )

    if (-not $Script:EventLogFile) {
        throw "Event log not initialized. Call Initialize-EventLog first."
    }

    $mutex = Get-EventLogMutexInternal

    # Acquire mutex for the entire write operation
    $acquired = $mutex.WaitOne(5000)
    if (-not $acquired) {
        throw "Failed to acquire event log write mutex within timeout"
    }

    try {
        # Get sequence number (still uses its own mutex for safety)
        $seq = Get-NextSequenceNumber

        $evtData = @{
            seq = $seq
            type = $Type
            timestamp = $Timestamp.ToString("o")  # ISO 8601 with timezone
            data = $Data
        }

        # Serialize and append atomically
        $json = $evtData | ConvertTo-Json -Compress -Depth 10

        # Atomic write: use FileStream with FileShare.None
        $stream = $null
        $writer = $null
        try {
            $stream = [System.IO.File]::Open(
                $Script:EventLogFile,
                [System.IO.FileMode]::Append,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::None
            )
            $writer = [System.IO.StreamWriter]::new($stream, [System.Text.Encoding]::UTF8)
            $writer.WriteLine($json)
        } finally {
            if ($writer -ne $null) { $writer.Dispose() }
            if ($stream -ne $null) { $stream.Dispose() }
        }

        return $seq
    } finally {
        $mutex.ReleaseMutex()
    }
}

function Write-AgentStartedEvent {
    <#
    .SYNOPSIS
    Record that an agent was started.

    .PARAMETER AgentName
    The name of the agent (pm, developer, qa, etc.).

    .PARAMETER AgentPid
    The process ID of the agent (renamed from Pid to avoid conflict with $PID automatic variable).

    .PARAMETER Timestamp
    Optional timestamp.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,

        [Parameter(Mandatory=$true)]
        [int]$AgentPid,

        [Parameter(Mandatory=$false)]
        [DateTime]$Timestamp = [DateTime]::UtcNow
    )

    return Write-Event -Type "AgentStarted" -Data @{
        agent = $AgentName
        pid = $AgentPid
    } -Timestamp $Timestamp
}

function Write-AgentExitedEvent {
    <#
    .SYNOPSIS
    Record that an agent exited.

    .PARAMETER AgentName
    The name of the agent.

    .PARAMETER ExitCode
    The exit code of the process.

    .PARAMETER Timestamp
    Optional timestamp.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,

        [Parameter(Mandatory=$true)]
        [int]$ExitCode,

        [Parameter(Mandatory=$false)]
        [DateTime]$Timestamp = [DateTime]::UtcNow
    )

    $eventType = if ($ExitCode -eq 0 -or $ExitCode -eq 42) {
        "AgentExited"
    } else {
        "AgentCrashed"
    }

    return Write-Event -Type $eventType -Data @{
        agent = $AgentName
        exitCode = $ExitCode
    } -Timestamp $Timestamp
}

function Write-MessageSentEvent {
    <#
    .SYNOPSIS
    Record that a message was sent between agents.

    .PARAMETER MessageId
    The unique message ID.

    .PARAMETER From
    The sender agent name.

    .PARAMETER To
    The recipient agent name.

    .PARAMETER MessageType
    The type of message.

    .PARAMETER Timestamp
    Optional timestamp.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$MessageId,

        [Parameter(Mandatory=$true)]
        [string]$From,

        [Parameter(Mandatory=$true)]
        [string]$To,

        [Parameter(Mandatory=$true)]
        [string]$MessageType,

        [Parameter(Mandatory=$false)]
        [DateTime]$Timestamp = [DateTime]::UtcNow
    )

    return Write-Event -Type "MessageSent" -Data @{
        messageId = $MessageId
        from = $From
        to = $To
        messageType = $MessageType
    } -Timestamp $Timestamp
}

# ============================================================================
# READ OPERATIONS (CQRS Query Side)
# ============================================================================

function Get-NextSequenceNumber {
    <#
    .SYNOPSIS
    Calculate the next sequence number for the event log with mutex protection.

    .DESCRIPTION
    CRITICAL FIX: This function uses mutex protection to prevent TOCTOU
    (Time-Of-Check-Time-Of-Use) race conditions. Without mutex protection,
    multiple processes could read the same last sequence number and
    generate duplicates, causing event log corruption.

    .RETURNS
    The next sequence number to use.
    #>
    $mutex = Get-SequenceMutex

    # Acquire mutex for the entire read-modify-write sequence
    $acquired = $mutex.WaitOne(5000)
    if (-not $acquired) {
        throw "Failed to acquire sequence mutex within timeout"
    }

    try {
        if (-not $Script:EventLogFile -or -not (Test-Path $Script:EventLogFile)) {
            return 1
        }

        try {
            $lastLine = Get-Content $Script:EventLogFile -Tail 1 -ErrorAction SilentlyContinue
            if ($lastLine -and $lastLine -match '\S') {
                $lastEvt = $lastLine | ConvertFrom-Json
                if ($lastEvt.seq) {
                    return $lastEvt.seq + 1
                }
            }
        } catch {
            # File might be empty or corrupted
        }

        return 1
    } finally {
        $mutex.ReleaseMutex()
    }
}

function Get-EventsSince {
    <#
    .SYNOPSIS
    Retrieve all events since a given sequence number.

    .DESCRIPTION
    This is the primary read operation for replaying events.
    Used for rebuilding state and creating materialized views.

    .PARAMETER FromSeq
    The sequence number to start from (exclusive).

    .PARAMETER IncludeTypes
    Optional array of event types to filter by.

    .RETURNS
    Array of event objects (always returns an array, even if empty or single item).
    #>
    param(
        [Parameter(Mandatory=$false)]
        [int64]$FromSeq = 0,

        [Parameter(Mandatory=$false)]
        [string[]]$IncludeTypes = $null
    )

    if (-not $Script:EventLogFile -or -not (Test-Path $Script:EventLogFile)) {
        return @()
    }

    $eventList = [System.Collections.Generic.List[object]]::new()
    try {
        Get-Content $Script:EventLogFile -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_ -match '\S') {
                try {
                    $evt = $_ | ConvertFrom-Json
                    if ($evt.seq -gt $FromSeq) {
                        if (-not $IncludeTypes -or $evt.type -in $IncludeTypes) {
                            [void]$eventList.Add($evt)
                        }
                    }
                } catch {
                    # Skip malformed lines
                }
            }
        }
    } catch {
        # Return empty on error
    }

    # Always return an array
    return ,@($eventList.ToArray())
}

function Get-EventsByType {
    <#
    .SYNOPSIS
    Retrieve all events of a specific type.

    .PARAMETER Type
    The event type to filter by.

    .RETURNS
    Array of event objects.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Type
    )

    return Get-EventsSince -FromSeq 0 -IncludeTypes @($Type)
}

function Get-EventsByAgent {
    <#
    .SYNOPSIS
    Retrieve all events related to a specific agent.

    .PARAMETER AgentName
    The agent name to filter by.

    .RETURNS
    Array of event objects.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName
    )

    $events = Get-EventsSince -FromSeq 0
    return $events | Where-Object {
        $_.data -and (
            $_.data.agent -eq $AgentName -or
            $_.data.from -eq $AgentName -or
            $_.data.to -eq $AgentName
        )
    }
}

# ============================================================================
# STATE REBUILDING (Materialized Views)
# ============================================================================

function Rebuild-AgentStatus {
    <#
    .SYNOPSIS
    Rebuild current agent status by replaying all events.

    .DESCRIPTION
    This is the CQRS read model builder. It replays all events
    from the event log to construct the current state of all agents.
    This is the canonical way to determine agent status.

    .RETURNS
    Hashtable mapping agent names to their current status.
    #>
    $events = Get-EventsSince -FromSeq 0
    $status = @{}

    foreach ($evt in $events) {
        # Skip events that don't have the expected event sourcing format
        # Event sourcing format has 'data' field, message protocol has 'from/to'
        if (-not $evt.data) {
            continue
        }

        switch ($evt.type) {
            "AgentStarted" {
                if ($evt.data.agent) {
                    $status[$evt.data.agent] = @{
                        state = "running"
                        pid = $evt.data.pid
                        lastEvent = $evt.seq
                        lastEventTime = $evt.timestamp
                    }
                }
            }
            "AgentExited" {
                if ($evt.data.agent -and $status[$evt.data.agent]) {
                    $status[$evt.data.agent].state = "stopped"
                    $status[$evt.data.agent].lastEvent = $evt.seq
                    $status[$evt.data.agent].lastEventTime = $evt.timestamp
                }
            }
            "AgentCrashed" {
                if ($evt.data.agent) {
                    $status[$evt.data.agent] = @{
                        state = "crashed"
                        exitCode = $evt.data.exitCode
                        lastEvent = $evt.seq
                        lastEventTime = $evt.timestamp
                    }
                }
            }
        }
    }

    return $status
}

function Export-AgentStatus {
    <#
    .SYNOPSIS
    Export agent status to a JSON file (materialized view).

    .DESCRIPTION
    Creates a materialized view of current agent state.
    This file can be queried without replaying the entire event log.

    .PARAMETER OutputPath
    The file path to write the status to.
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$OutputPath = ""
    )

    if (-not $OutputPath) {
        $OutputPath = Join-Path $Script:EventLogSessionDir "agent-status.json"
    }

    $status = Rebuild-AgentStatus
    $status | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8

    return $OutputPath
}

function Get-AgentStatus {
    <#
    .SYNOPSIS
    Get current status of all agents.

    .RETURNS
    Hashtable mapping agent names to their current status.
    #>
    return Rebuild-AgentStatus
}

function Get-AgentStatusCached {
    <#
    .SYNOPSIS
    Get agent status from cached materialized view if available.

    .DESCRIPTION
    Tries to read from agent-status.json for fast access.
    Falls back to rebuilding from event log if cache is missing.

    .RETURNS
    Hashtable mapping agent names to their current status.
    #>
    $cachedPath = Join-Path $Script:EventLogSessionDir "agent-status.json"

    if (Test-Path $cachedPath) {
        try {
            $cached = Get-Content $cachedPath -Raw | ConvertFrom-Json
            # Convert PSObject to hashtable
            $result = @{}
            foreach ($prop in $cached.PSObject.Properties) {
                $result[$prop.Name] = @{
                    state = $prop.Value.state
                    pid = $prop.Value.pid
                    lastEvent = $prop.Value.lastEvent
                    lastEventTime = $prop.Value.lastEventTime
                }
            }
            return $result
        } catch {
            # Cache corrupted, rebuild
        }
    }

    # Rebuild and cache
    Export-AgentStatus -OutputPath $cachedPath
    return Rebuild-AgentStatus
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Get-EventStatistics {
    <#
    .SYNOPSIS
    Get statistics about the event log.

    .RETURNS
    Hashtable with event statistics.
    #>
    $events = Get-EventsSince -FromSeq 0

    $stats = @{
        TotalEvents = $events.Count
        LastSequence = 0
        EventTypes = @{}
        FirstEventTime = $null
        LastEventTime = $null
    }

    foreach ($evt in $events) {
        if ($evt.seq -gt $stats.LastSequence) {
            $stats.LastSequence = $evt.seq
        }

        if (-not $stats.EventTypes.ContainsKey($evt.type)) {
            $stats.EventTypes[$evt.type] = 0
        }
        $stats.EventTypes[$evt.type]++

        if (-not $stats.FirstEventTime) {
            $stats.FirstEventTime = $evt.timestamp
        }
        $stats.LastEventTime = $evt.timestamp
    }

    return $stats
}

function Backup-EventLog {
    <#
    .SYNOPSIS
    Create a backup of the event log.

    .PARAMETER BackupPath
    Optional destination path. If not provided, uses timestamp-based name.
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$BackupPath = ""
    )

    if (-not $Script:EventLogFile -or -not (Test-Path $Script:EventLogFile)) {
        Write-Warning "Event log file not found, nothing to backup."
        return
    }

    if (-not $BackupPath) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $BackupPath = "$Script:EventLogFile.$timestamp.bak"
    }

    Copy-Item -Path $Script:EventLogFile -Destination $BackupPath
    Write-Host "Event log backed up to: $BackupPath" -ForegroundColor Green

    return $BackupPath
}

# ============================================================================
# EXPORTS
# ============================================================================

# Only export if running as a module (not when sourced directly)
# Use try-catch to gracefully handle non-module context
try {
    Export-ModuleMember -Function @(
        # Initialization
        'Initialize-EventLog',
        'Get-EventLogPath',

        # Write operations
        'Write-Event',
        'Write-AgentStartedEvent',
        'Write-AgentExitedEvent',
        'Write-MessageSentEvent',

        # Read operations
        'Get-EventsSince',
        'Get-EventsByType',
        'Get-EventsByAgent',

        # State rebuilding
        'Rebuild-AgentStatus',
        'Export-AgentStatus',
        'Get-AgentStatus',
        'Get-AgentStatusCached',

        # Utilities
        'Get-EventStatistics',
        'Backup-EventLog'
    )
} catch {
    # Not running as a module - ignore export error
}
