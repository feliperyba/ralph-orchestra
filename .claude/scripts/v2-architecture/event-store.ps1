# Ralph Event Store Module - Production Event Sourcing Implementation
#
# Design Patterns Applied:
# - Event Sourcing: All state changes stored as sequence of events
# - Snapshot/Restore: Periodic snapshots to reduce replay time
# - Log Compaction: Truncation of old events after snapshot
# - CQRS: Separate read/write models with projections
#
# Features:
# - Append-only event storage with optimistic concurrency
# - Automatic snapshot creation at configurable intervals
# - Log compaction to prevent unbounded growth
# - Multi-stream support (per-agent event streams)
# - Atomic batch writes
#
# References:
# - https://martinfowler.com/eaaDev/EventSourcing.html
# - https://eventstore.com/docs/event-sourcing/basics/

using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Text.Json

# ============================================================================
# DEPENDENCIES
# ============================================================================

# Import concurrency primitives if available
$DependencyPath = Join-Path $PSScriptRoot "concurrency.ps1"
if (Test-Path $DependencyPath) {
    . $DependencyPath
}

# Import serialization module if available
$SerializationPath = Join-Path $PSScriptRoot "serialization.ps1"
if (Test-Path $SerializationPath) {
    . $SerializationPath
}

# ============================================================================
# ENUMS
# ============================================================================

enum ExpectedVersion {
    Any         = -2      # No version check (create new or append)
    NoStream    = -1      # Stream must not exist
    EmptyStream = 0       # Stream must be empty
}

enum CompactionStrategy {
    None        = 0       # No compaction
    Snapshot    = 1       # Keep events after latest snapshot
    TimeWindow  = 2       # Keep events within time window
    CountWindow = 3       # Keep last N events
}

# ============================================================================
# EVENT DATA STRUCTURES
# ============================================================================

class StoredEvent {
    [long]$SequenceNumber
    [string]$StreamId
    [long]$StreamVersion
    [string]$EventType
    [byte[]]$Data
    [byte[]]$Metadata
    [DateTime]$Timestamp
    [string]$CorrelationId
    [string]$CausationId

    StoredEvent() {
        $this.Timestamp = [DateTime]::UtcNow
    }

    StoredEvent(
        [string]$streamId,
        [long]$streamVersion,
        [string]$eventType,
        [byte[]]$data
    ) {
        $this.StreamId = $streamId
        $this.StreamVersion = $streamVersion
        $this.EventType = $eventType
        $this.Data = $data
        $this.Timestamp = [DateTime]::UtcNow
        $this.SequenceNumber = -1  # Assigned on append
    }

    # Convert to JSON for file storage
    [string] ToJson() {
        $props = @{
            seq = $this.SequenceNumber
            streamId = $this.StreamId
            version = $this.StreamVersion
            type = $this.EventType
            data = $null
            metadata = $null
            timestamp = $this.Timestamp.ToString("o")
        }

        if ($this.Data) {
            $props.data = [System.Convert]::ToBase64String($this.Data)
        }
        if ($this.Metadata) {
            $props.metadata = [System.Convert]::ToBase64String($this.Metadata)
        }
        if ($this.CorrelationId) {
            $props.correlationId = $this.CorrelationId
        }
        if ($this.CausationId) {
            $props.causationId = $this.CausationId
        }

        return ($props | ConvertTo-Json -Compress -Depth 10)
    }

    # Parse from JSON file storage
    static [StoredEvent] FromJson([string]$json) {
        $props = $json | ConvertFrom-Json

        $evt = [StoredEvent]::new()
        $evt.SequenceNumber = $props.seq
        $evt.StreamId = $props.streamId
        $evt.StreamVersion = $props.version
        $evt.EventType = $props.type
        $evt.Timestamp = [DateTime]::Parse($props.timestamp)

        if ($props.data) {
            $evt.Data = [System.Convert]::FromBase64String($props.data)
        }
        if ($props.metadata) {
            $evt.Metadata = [System.Convert]::FromBase64String($props.metadata)
        }
        if ($props.correlationId) {
            $evt.CorrelationId = $props.correlationId
        }
        if ($props.causationId) {
            $evt.CausationId = $props.causationId
        }

        return $evt
    }
}

class Snapshot {
    [string]$StreamId
    [long]$Version
    [byte[]]$State
    [DateTime]$Timestamp
    [long]$EventSequenceNumber

    Snapshot() {}

    Snapshot([string]$streamId, [long]$version, [byte[]]$state) {
        $this.StreamId = $streamId
        $this.Version = $version
        $this.State = $state
        $this.Timestamp = [DateTime]::UtcNow
    }

    [string] ToJson() {
        $props = @{
            streamId = $this.StreamId
            version = $this.Version
            state = $null
            timestamp = $this.Timestamp.ToString("o")
            eventSeq = $this.EventSequenceNumber
        }

        if ($this.State) {
            $props.state = [System.Convert]::ToBase64String($this.State)
        }

        return ($props | ConvertTo-Json -Compress -Depth 10)
    }

    static [Snapshot] FromJson([string]$json) {
        $props = $json | ConvertFrom-Json

        $snap = [Snapshot]::new()
        $snap.StreamId = $props.streamId
        $snap.Version = $props.version
        $snap.Timestamp = [DateTime]::Parse($props.timestamp)
        $snap.EventSequenceNumber = $props.eventSeq

        if ($props.state) {
            $snap.State = [System.Convert]::FromBase64String($props.state)
        }

        return $snap
    }
}

# ============================================================================
# EVENT STORE CONFIGURATION
# ============================================================================

class EventStoreConfig {
    [string]$DataDirectory
    [int]$SnapshotInterval
    [CompactionStrategy]$CompactionStrategy
    [int]$CompactionThreshold
    [timespan]$CompactionRetention
    [int]$MaxBatchSize
    [bool]$EnableCompression

    EventStoreConfig([string]$dataDirectory) {
        $this.DataDirectory = $dataDirectory
        $this.SnapshotInterval = 100  # Snapshot every 100 events
        $this.CompactionStrategy = [CompactionStrategy]::Snapshot
        $this.CompactionThreshold = 1000  # Compact after 1000 events past snapshot
        $this.CompactionRetention = [timespan]::FromDays(7)  # Keep 7 days
        $this.MaxBatchSize = 100
        $this.EnableCompression = $false
    }
}

# ============================================================================
# EVENT STREAM - Per-stream event management
# ============================================================================

class EventStream {
    [string]$Id
    [string]$FilePath
    [long]$CurrentVersion
    [System.Threading.Mutex]$WriteMutex

    EventStream([string]$id, [string]$filePath) {
        $this.Id = $id
        $this.FilePath = $filePath
        $this.CurrentVersion = 0
        $this.WriteMutex = [System.Threading.Mutex]::new($false, "Global\Ralph_Stream_$id")
    }

    [void] Dispose() {
        $this.WriteMutex.Dispose()
    }
}

# ============================================================================
# EVENT STORE - Main event storage implementation
# ============================================================================

class EventStore {
    [EventStoreConfig]$Config
    [string]$GlobalEventFilePath
    [System.Threading.Mutex]$GlobalWriteMutex
    [AtomicCounter]$SequenceCounter
    [Dictionary[string,EventStream]]$Streams
    [Dictionary[string,Snapshot]]$Snapshots

    hidden [LatencyTracker]$AppendLatency
    hidden [LatencyTracker]$ReadLatency

    EventStore([EventStoreConfig]$config) {
        $this.Config = $config
        $this.Streams = [Dictionary[string,EventStream]]::new()
        $this.Snapshots = [Dictionary[string,Snapshot]]::new()

        # Ensure data directory exists
        if (-not (Test-Path $this.Config.DataDirectory)) {
            New-Item -ItemType Directory -Path $this.Config.DataDirectory -Force | Out-Null
        }

        # Global event log (all events from all streams)
        $this.GlobalEventFilePath = Join-Path $this.Config.DataDirectory "events.jsonl"

        # Initialize mutex and counter
        $this.GlobalWriteMutex = [System.Threading.Mutex]::new($false, "Global\RalphEventStore_Write")
        $this.SequenceCounter = [AtomicCounter]::new(0)

        # Initialize sequence from existing log
        $this.InitializeSequenceCounter()

        # Load existing snapshots
        $this.LoadSnapshots()

        # Metrics
        $this.AppendLatency = [LatencyTracker]::new(1000)
        $this.ReadLatency = [LatencyTracker]::new(1000)
    }

    # =========================================================================
    # INITIALIZATION
    # =========================================================================

    hidden [void] InitializeSequenceCounter() {
        if (-not (Test-Path $this.GlobalEventFilePath)) {
            return
        }

        try {
            $lastLine = Get-Content $this.GlobalEventFilePath -Tail 1 -ErrorAction SilentlyContinue
            if ($lastLine -and $lastLine -match '\S') {
                $lastEvt = [StoredEvent]::FromJson($lastLine)
                $this.SequenceCounter.Value = $lastEvt.SequenceNumber
            }
        } catch {
            # Start from 0 on error
        }
    }

    hidden [void] LoadSnapshots() {
        $snapshotDir = Join-Path $this.Config.DataDirectory "snapshots"
        if (-not (Test-Path $snapshotDir)) {
            return
        }

        Get-ChildItem -Path $snapshotDir -Filter "*.snapshot" | ForEach-Object {
            try {
                $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
                if ($content) {
                    $snap = [Snapshot]::FromJson($content)
                    $this.Snapshots[$snap.StreamId] = $snap
                }
            } catch {
                # Skip corrupted snapshots
            }
        }
    }

    # =========================================================================
    # STREAM MANAGEMENT
    # =========================================================================

    hidden [EventStream] GetOrCreateStream([string]$streamId) {
        if ($this.Streams.ContainsKey($streamId)) {
            return $this.Streams[$streamId]
        }

        $streamFilePath = Join-Path $this.Config.DataDirectory "$streamId.jsonl"
        $stream = [EventStream]::new($streamId, $streamFilePath)

        # Load current version from stream file
        if (Test-Path $streamFilePath) {
            try {
                $lastLine = Get-Content $streamFilePath -Tail 1 -ErrorAction SilentlyContinue
                if ($lastLine -and $lastLine -match '\S') {
                    $lastEvt = [StoredEvent]::FromJson($lastLine)
                    $stream.CurrentVersion = $lastEvt.StreamVersion
                }
            } catch {
                # Version stays 0
            }
        }

        $this.Streams[$streamId] = $stream
        return $stream
    }

    # =========================================================================
    # WRITE OPERATIONS (CQRS Command Side)
    # =========================================================================

    [void] Append(
        [string]$streamId,
        [long]$expectedVersion,
        [StoredEvent[]]$events
    ) {
        if ($null -eq $events -or $events.Count -eq 0) {
            return
        }

        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        # Acquire write mutex
        $acquired = $this.GlobalWriteMutex.WaitOne(5000)
        if (-not $acquired) {
            throw "Failed to acquire event store write mutex"
        }

        try {
            $stream = $this.GetOrCreateStream($streamId)

            # Verify expected version (optimistic concurrency)
            $actualVersion = $stream.CurrentVersion

            if ($expectedVersion -ne [ExpectedVersion]::Any) {
                if ($expectedVersion -eq [ExpectedVersion]::NoStream) {
                    if ($actualVersion -gt 0) {
                        throw "Stream '$streamId' already exists (version: $actualVersion)"
                    }
                } elseif ($expectedVersion -ne $actualVersion) {
                    throw "Concurrency violation for stream '$streamId': expected version $expectedVersion, actual version $actualVersion"
                }
            }

            # Assign sequence numbers and write events
            $startVersion = $actualVersion + 1
            for ($i = 0; $i -lt $events.Count; $i++) {
                $events[$i].SequenceNumber = $this.SequenceCounter.Increment()
                $events[$i].StreamId = $streamId
                $events[$i].StreamVersion = $startVersion + $i
            }

            # Write to global event log
            $this.WriteEventsToFile($this.GlobalEventFilePath, $events)

            # Write to stream-specific file
            $this.WriteEventsToFile($stream.FilePath, $events)

            # Update stream version
            $stream.CurrentVersion = $startVersion + $events.Count - 1

            # Check if snapshot needed
            if ($stream.CurrentVersion % $this.Config.SnapshotInterval -eq 0) {
                $this.CreateSnapshot($streamId)
            }

        } finally {
            $this.GlobalWriteMutex.ReleaseMutex()
        }

        $sw.Stop()
        $this.AppendLatency.Record($sw.ElapsedMicroseconds)
    }

    hidden [void] WriteEventsToFile([string]$filePath, [StoredEvent[]]$events) {
        # Ensure directory exists
        $dir = Split-Path -Parent $filePath
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        # Atomic write: append to file
        $stream = $null
        $writer = $null
        try {
            $stream = [System.IO.File]::Open(
                $filePath,
                [System.IO.FileMode]::Append,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::None
            )
            $writer = [System.IO.StreamWriter]::new($stream, [System.Text.Encoding]::UTF8)

            foreach ($evt in $events) {
                $writer.WriteLine($evt.ToJson())
            }
        } finally {
            if ($writer -ne $null) { $writer.Dispose() }
            if ($stream -ne $null) { $stream.Dispose() }
        }
    }

    # =========================================================================
    # READ OPERATIONS (CQRS Query Side)
    # =========================================================================

    [StoredEvent[]] ReadStream(
        [string]$streamId,
        [long]$fromVersion,
        [int]$maxCount
    ) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        $events = [List[StoredEvent]]::new()

        # Check if we can start from snapshot
        $snapshot = $null
        if ($fromVersion -eq 0 -and $this.Snapshots.ContainsKey($streamId)) {
            $snapshot = $this.Snapshots[$streamId]
            $fromVersion = $snapshot.Version + 1
        }

        $stream = $this.GetOrCreateStream($streamId)
        if (-not (Test-Path $stream.FilePath)) {
            $sw.Stop()
            return $events.ToArray()
        }

        try {
            Get-Content $stream.FilePath -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_ -match '\S') {
                    try {
                        $evt = [StoredEvent]::FromJson($_)
                        if ($evt.StreamVersion -gt $fromVersion) {
                            $events.Add($evt)
                            if ($maxCount -gt 0 -and $events.Count -ge $maxCount) {
                                break
                            }
                        }
                    } catch {
                        # Skip malformed events
                    }
                }
            }
        } catch {
            # Return partial results
        }

        $sw.Stop()
        $this.ReadLatency.Record($sw.ElapsedMicroseconds)

        return $events.ToArray()
    }

    [StoredEvent[]] ReadStreamForward(
        [string]$streamId,
        [long]$fromVersion,
        [int]$maxCount
    ) {
        return $this.ReadStream($streamId, $fromVersion, $maxCount)
    }

    [StoredEvent[]] ReadStreamBackward(
        [string]$streamId,
        [long]$fromVersion,
        [int]$maxCount
    ) {
        $events = [List[StoredEvent]]::new()

        $stream = $this.GetOrCreateStream($streamId)
        if (-not (Test-Path $stream.FilePath)) {
            return $events.ToArray()
        }

        try {
            $lines = Get-Content $stream.FilePath -ErrorAction SilentlyContinue
            [Array]::Reverse($lines)

            foreach ($line in $lines) {
                if ($line -match '\S') {
                    try {
                        $evt = [StoredEvent]::FromJson($line)
                        if ($fromVersion -eq -1 -or $evt.StreamVersion -le $fromVersion) {
                            $events.Add($evt)
                            if ($maxCount -gt 0 -and $events.Count -ge $maxCount) {
                                break
                            }
                        }
                    } catch {
                        # Skip malformed events
                    }
                }
            }
        } catch {
            # Return partial results
        }

        return $events.ToArray()
    }

    # =========================================================================
    # SNAPSHOT OPERATIONS
    # =========================================================================

    [void] CreateSnapshot(
        [string]$streamId,
        [byte[]]$state,
        [long]$version
    ) {
        $snapshot = [Snapshot]::new($streamId, $version, $state)

        # Get current event sequence for this version
        $events = $this.ReadStream($streamId, $version, 1)
        if ($events.Count -gt 0) {
            $snapshot.EventSequenceNumber = $events[0].SequenceNumber
        }

        $this.Snapshots[$streamId] = $snapshot

        # Write snapshot to file
        $snapshotDir = Join-Path $this.Config.DataDirectory "snapshots"
        if (-not (Test-Path $snapshotDir)) {
            New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
        }

        $snapshotPath = Join-Path $snapshotDir "$streamId.snapshot"
        $snapshot.ToJson() | Out-File -FilePath $snapshotPath -Encoding UTF8

        # Trigger compaction if configured
        if ($this.Config.CompactionStrategy -eq [CompactionStrategy]::Snapshot) {
            $this.CompactStream($streamId, $version)
        }
    }

    [void] CreateSnapshot([string]$streamId) {
        $events = $this.ReadStream($streamId, 0, [int]::MaxValue)
        if ($events.Count -eq 0) {
            return
        }

        $lastEvent = $events[-1]

        # Rebuild state (placeholder - actual state rebuilding would be projection-specific)
        $state = [System.Text.Encoding]::UTF8.GetBytes(($events | ConvertTo-Json -Compress -Depth 10))

        $this.CreateSnapshot($streamId, $state, $lastEvent.StreamVersion)
    }

    [Snapshot] GetSnapshot([string]$streamId) {
        if ($this.Snapshots.ContainsKey($streamId)) {
            return $this.Snapshots[$streamId]
        }
        return $null
    }

    [bool] HasSnapshot([string]$streamId) {
        return $this.Snapshots.ContainsKey($streamId)
    }

    # =========================================================================
    # COMPACTION
    # =========================================================================

    [void] CompactStream([string]$streamId, [long]$keepAfterVersion) {
        $stream = $this.GetOrCreateStream($streamId)
        if (-not (Test-Path $stream.FilePath)) {
            return
        }

        $tempFile = "$($stream.FilePath).tmp"
        $keptCount = 0

        try {
            Get-Content $stream.FilePath -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_ -match '\S') {
                    try {
                        $evt = [StoredEvent]::FromJson($_)
                        if ($evt.StreamVersion -gt $keepAfterVersion) {
                            $_ | Add-Content -Path $tempFile -Encoding UTF8
                            $keptCount++
                        }
                    } catch {
                        # Skip malformed events
                    }
                }
            }

            # Atomic replace
            if ($keptCount -gt 0) {
                Move-Item -Path $tempFile -Destination $stream.FilePath -Force
            } else {
                # All events compacted, keep at least one marker
                "[]" | Out-File -FilePath $stream.FilePath -Encoding UTF8
            }

        } catch {
            # Cleanup temp file on error
            if (Test-Path $tempFile) {
                Remove-Item $tempFile -Force
            }
        }
    }

    [void] CompactByTime([string]$streamId, [timespan]$retention) {
        $cutoffTime = [DateTime]::UtcNow.Subtract($retention)
        $stream = $this.GetOrCreateStream($streamId)

        if (-not (Test-Path $stream.FilePath)) {
            return
        }

        # Find latest event within retention window
        $latestVersion = 0
        Get-Content $stream.FilePath -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_ -match '\S') {
                try {
                    $evt = [StoredEvent]::FromJson($_)
                    if ($evt.Timestamp -gt $cutoffTime) {
                        $latestVersion = [math]::Max($latestVersion, $evt.StreamVersion)
                    }
                } catch {
                    # Skip malformed events
                }
            }
        }

        if ($latestVersion -gt 0) {
            $this.CompactStream($streamId, $latestVersion - 1)
        }
    }

    [void] CompactByCount([string]$streamId, [int]$keepCount) {
        $stream = $this.GetOrCreateStream($streamId)
        if (-not (Test-Path $stream.FilePath)) {
            return
        }

        # Find version to keep from
        $keepFromVersion = [math]::Max(0, $stream.CurrentVersion - $keepCount)
        $this.CompactStream($streamId, $keepFromVersion)
    }

    [void] CompactAll() {
        foreach ($streamId in $this.Streams.Keys) {
            switch ($this.Config.CompactionStrategy) {
                ([CompactionStrategy]::Snapshot) {
                    $snapshot = $this.GetSnapshot($streamId)
                    if ($snapshot) {
                        $this.CompactStream($streamId, $snapshot.Version)
                    }
                }
                ([CompactionStrategy]::TimeWindow) {
                    $this.CompactByTime($streamId, $this.Config.CompactionRetention)
                }
                ([CompactionStrategy]::CountWindow) {
                    $this.CompactByCount($streamId, $this.Config.CompactionThreshold)
                }
            }
        }
    }

    # =========================================================================
    # STREAM STATE QUERIES
    # =========================================================================

    [long] GetStreamVersion([string]$streamId) {
        $stream = $this.GetOrCreateStream($streamId)
        return $stream.CurrentVersion
    }

    [bool] StreamExists([string]$streamId) {
        $stream = $this.GetOrCreateStream($streamId)
        return $stream.CurrentVersion -gt 0
    }

    [string[]] GetStreams() {
        $streamList = [System.Collections.Generic.List[string]]::new()

        if (Test-Path $this.Config.DataDirectory) {
            Get-ChildItem -Path $this.Config.DataDirectory -Filter "*.jsonl" | ForEach-Object {
                $name = $_.Name.Replace(".jsonl", "")
                if ($name -ne "events") {
                    $streamList.Add($name)
                }
            }
        }

        return $streamList.ToArray()
    }

    # =========================================================================
    # GLOBAL EVENT QUERIES
    # =========================================================================

    [StoredEvent[]] ReadGlobal([long]$fromSequence, [int]$maxCount) {
        $events = [List[StoredEvent]]::new()

        if (-not (Test-Path $this.GlobalEventFilePath)) {
            return $events.ToArray()
        }

        try {
            Get-Content $this.GlobalEventFilePath -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_ -match '\S') {
                    try {
                        $evt = [StoredEvent]::FromJson($_)
                        if ($evt.SequenceNumber -gt $fromSequence) {
                            $events.Add($evt)
                            if ($maxCount -gt 0 -and $events.Count -ge $maxCount) {
                                break
                            }
                        }
                    } catch {
                        # Skip malformed events
                    }
                }
            }
        } catch {
            # Return partial results
        }

        return $events.ToArray()
    }

    [StoredEvent[]] ReadAllEvents() {
        return $this.ReadGlobal(0, [int]::MaxValue)
    }

    # =========================================================================
    # METRICS
    # =========================================================================

    [hashtable] GetMetrics() {
        return @{
            TotalStreams = $this.Streams.Count
            TotalSnapshots = $this.Snapshots.Count
            AppendLatency = $this.AppendLatency.GetStatistics()
            ReadLatency = $this.ReadLatency.GetStatistics()
            CurrentSequence = $this.SequenceCounter.Get()
        }
    }

    # =========================================================================
    # DISPOSE
    # =========================================================================

    [void] Dispose() {
        foreach ($stream in $this.Streams.Values) {
            $stream.Dispose()
        }
        $this.Streams.Clear()
        $this.GlobalWriteMutex.Dispose()
    }
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function New-EventStore {
    <#
    .SYNOPSIS
    Create a new EventStore instance.

    .PARAMETER DataDirectory
    Directory path for event storage.

    .PARAMETER SnapshotInterval
    Number of events between automatic snapshots.

    .PARAMETER CompactionStrategy
    Strategy for log compaction (None, Snapshot, TimeWindow, CountWindow).

    .RETURNS
    EventStore instance.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$DataDirectory,

        [Parameter(Mandatory=$false)]
        [int]$SnapshotInterval = 100,

        [Parameter(Mandatory=$false)]
        [CompactionStrategy]$CompactionStrategy = [CompactionStrategy]::Snapshot,

        [Parameter(Mandatory=$false)]
        [int]$CompactionThreshold = 1000
    )

    $config = [EventStoreConfig]::new($DataDirectory)
    $config.SnapshotInterval = $SnapshotInterval
    $config.CompactionStrategy = $CompactionStrategy
    $config.CompactionThreshold = $CompactionThreshold

    return [EventStore]::new($config)
}

function Write-StoredEvent {
    <#
    .SYNOPSIS
    Create a StoredEvent object with data.

    .PARAMETER StreamId
    Stream identifier.

    .PARAMETER EventType
    Event type name.

    .PARAMETER Data
    Event data as hashtable or JSON string.

    .PARAMETER Metadata
    Optional metadata.

    .RETURNS
    StoredEvent object.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$StreamId,

        [Parameter(Mandatory=$true)]
        [string]$EventType,

        [Parameter(Mandatory=$true)]
        [object]$Data,

        [Parameter(Mandatory=$false)]
        [hashtable]$Metadata = @{}
    )

    $jsonData = if ($Data -is [string]) {
        [System.Text.Encoding]::UTF8.GetBytes($Data)
    } else {
        [System.Text.Encoding]::UTF8.GetBytes(($Data | ConvertTo-Json -Compress -Depth 10))
    }

    $evt = [StoredEvent]::new($StreamId, 0, $EventType, $jsonData)

    if ($Metadata.Count -gt 0) {
        $evt.Metadata = [System.Text.Encoding]::UTF8.GetBytes(($Metadata | ConvertTo-Json -Compress))
    }

    return $evt
}

# ============================================================================
# EXPORTS
# ============================================================================

try {
    Export-ModuleMember -Function @(
        'New-EventStore',
        'Write-StoredEvent'
    )
} catch {
    # Not running as a module
}
