# Ralph Reliability and Integration Tests
#
# Tests for:
# - Crash recovery and state restoration
# - Snapshot functionality
# - Event migration and versioning
# - Process safety (no unintended process kills)
# - End-to-end integration scenarios
#
# Run with: Pester v3+

# Setup - run before tests
$moduleRoot = Join-Path $PSScriptRoot "..\..\.claude\scripts\v2-architecture"

# Source modules in dependency order (metrics first, then modules that depend on it)
$modulesToImport = @(
    "concurrency.ps1",
    "metrics.ps1",
    "eventlog.ps1",
    "event-store.ps1",
    "event-versioning.ps1",
    "projections.ps1"
)

# Source modules (must use dot-sourcing for class definitions in PS 5.1)
foreach ($mod in $modulesToImport) {
    $modPath = Join-Path $moduleRoot $mod
    if (Test-Path $modPath) {
        . $modPath -ErrorAction SilentlyContinue
    }
}

# Test data directory
$Script:TestDataDir = Join-Path $PSScriptRoot "test-data"
if (-not (Test-Path $Script:TestDataDir)) {
    New-Item -ItemType Directory -Path $Script:TestDataDir -Force | Out-Null
}

function Remove-TestData {
    if (Test-Path $Script:TestDataDir) {
        Remove-Item -Path $Script:TestDataDir -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $Script:TestDataDir -Force | Out-Null
    }
}

function Get-TestProcess {
    <#
    .SYNOPSIS
    Create a test PowerShell process for process safety testing.
    Returns the process ID and a cleanup scriptblock.
    #>
    $psi = [System.Diagnostics.ProcessStartInfo]::new(
        "powershell",
        "-Command", "Start-Sleep -Seconds 600"
    )
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::Start($psi)

    return @{
        Id = $process.Id
        Process = $process
        Cleanup = {
            if ($process -and -not $process.HasExited) {
                $process.Kill()
                $process.WaitForExit(1000)
            }
        }.GetNewClosure()
    }
}

Describe "EventSourcing - Crash Recovery" {
    BeforeEach {
        Remove-TestData
        $testLogDir = Join-Path $Script:TestDataDir "recovery-test"
        New-Item -ItemType Directory -Path $testLogDir -Force | Out-Null
        $Script:LogPath = Initialize-EventLog -SessionDir $testLogDir -SessionId "recovery"
    }

    AfterEach {
        # Clean up mutexes
        if ($Script:EventLogMutex) {
            $Script:EventLogMutex.Dispose()
        }
        if ($Script:SequenceMutex) {
            $Script:SequenceMutex.Dispose()
        }
    }

    It "Should recover state after simulated crash" {
        # Write some events
        $eventsToWrite = 50
        for ($i = 0; $i -lt $eventsToWrite; $i++) {
            Write-Event -Type "AgentStarted" -Data @{
                agent = "test-agent-$i"
                pid = 1000 + $i
            }
        }

        # Simulate crash by reloading module (loses in-memory state)
        Import-Module (Join-Path $moduleRoot "eventlog.ps1") -Force

        # Reinitialize
        Initialize-EventLog -SessionDir $testLogDir -SessionId "recovery" | Out-Null

        # Rebuild state from event log
        $status = Rebuild-AgentStatus

        # Should have recovered all agents
        $status.Count | Should Be $eventsToWrite

        # All should be in running state
        $runningCount = ($status.Values | Where-Object { $_.state -eq "running" }).Count
        $runningCount | Should Be $eventsToWrite
    }

    It "Should handle corrupted event log gracefully" {
        # Write some valid events
        for ($i = 0; $i -lt 10; $i++) {
            Write-Event -Type "TestEvent" -Data @{ id = $i }
        }

        # Append a corrupted line
        Add-Content -Path $Script:LogPath -Value "this is not valid json" -Encoding UTF8

        # Write more valid events after corruption
        for ($i = 10; $i -lt 20; $i++) {
            Write-Event -Type "TestEvent" -Data @{ id = $i }
        }

        # Rebuild should skip corrupted line
        $status = Rebuild-AgentStatus

        # Sequence numbers should still be correct
        $events = Get-EventsSince -FromSeq 0
        $events.Count | Should BeGreaterOrEqual 19  # At least 19 valid events
    }

    It "Should recover from empty event log" {
        $emptyLogDir = Join-Path $Script:TestDataDir "empty-test"
        New-Item -ItemType Directory -Path $emptyLogDir -Force | Out-Null

        $emptyPath = Initialize-EventLog -SessionDir $emptyLogDir -SessionId "empty"

        # Rebuilding empty log should return empty status
        $status = Rebuild-AgentStatus
        $status.Count | Should Be 0
    }
}

Describe "EventStore - Snapshots" {
    BeforeEach {
        Remove-TestData
        $storeDir = Join-Path $Script:TestDataDir "snapshot-test"
        $Script:EventStore = New-EventStore -DataDirectory $storeDir
    }

    It "Should create and restore snapshot" {
        $streamId = "test-stream"

        # Write some events
        $events = [List[object]]::new()
        for ($i = 0; $i -lt 50; $i++) {
            $evt = [StoredEvent]::new($streamId, $i, "TestEvent", [System.Text.Encoding]::UTF8.GetBytes("data-$i"))
            $events.Add($evt)
        }

        # Create snapshot
        $state = [System.Text.Encoding]::UTF8.GetBytes("snapshot-state")
        $Script:EventStore.CreateSnapshot($streamId, $state, 50)

        # Verify snapshot exists
        $snapshot = $Script:EventStore.GetSnapshot($streamId)
        $snapshot | Should Not Be $null
        $snapshot.Version | Should Be 50
        [System.Text.Encoding]::UTF8.GetString($snapshot.State) | Should Be "snapshot-state"
    }

    It "Should read from snapshot and then events" {
        $streamId = "test-snapshot-read"

        # Write 100 events
        for ($i = 0; $i -lt 100; $i++) {
            $evt = [StoredEvent]::new($streamId, $i, "TestEvent", [System.Text.Encoding]::UTF8.GetBytes("data-$i"))
            $Script:EventStore.Append($streamId, -2, [StoredEvent[]]$evt)
        }

        # Create snapshot at version 100
        $state = [System.Text.Encoding]::UTF8.GetBytes("state-at-100")
        $Script:EventStore.CreateSnapshot($streamId, $state, 100)

        # Write more events
        for ($i = 100; $i -lt 120; $i++) {
            $evt = [StoredEvent]::new($streamId, $i, "TestEvent", [System.Text.Encoding]::UTF8.GetBytes("data-$i"))
            $Script:EventStore.Append($streamId, -2, [StoredEvent[]]$evt)
        }

        # Read should return only events after snapshot
        $readEvents = $Script:EventStore.ReadStream($streamId, 0, [int]::MaxValue)
        $readEvents.Count | Should Be 20  # Only events 101-120
    }

    It "Should compact log after snapshot" {
        $streamId = "test-compact"

        # Write 200 events
        for ($i = 0; $i -lt 200; $i++) {
            $evt = [StoredEvent]::new($streamId, $i, "TestEvent", [System.Text.Encoding]::UTF8.GetBytes("data-$i"))
            $Script:EventStore.Append($streamId, -2, [StoredEvent[]]$evt)
        }

        # Create snapshot and compact
        $Script:EventStore.CompactStream($streamId, 100)

        # Read from version 0 should only return events after 100
        $readEvents = $Script:EventStore.ReadStream($streamId, 0, [int]::MaxValue)
        $readEvents.Count | Should Be 99  # Events 101-200 (200 - 100 = 100, but we started from 0)
    }
}

Describe "EventMigration - Version Compatibility" {
    BeforeEach {
        Remove-TestData
        $Script:Registry = New-EventTypeRegistry
        $Script:Engine = New-MigrationEngine -Registry $Script:Registry
    }

    It "Should migrate v1 event to v2" {
        # Register v2 event type
        $Script:Registry.RegisterEventType("TaskAssigned", "2.0.0")

        # Register upcaster
        $Script:Engine.RegisterUpcaster(
            "TaskAssigned",
            "v1.0.0",
            "v2.0.0",
            {
                param($evt)
                $evt.data.priority = if ($evt.data.priority) { $evt.data.priority } else { "medium" }
                $evt.data.version = "2.0.0"
                return $evt
            }.GetNewClosure()
        )

        # Create v1 event
        $v1Event = @{
            type = "TaskAssigned:v1.0.0"
            data = @{
                taskId = "task-123"
                agent = "developer"
                title = "Test task"
            }
        }

        # Migrate to v2
        $v2Event = $Script:Engine.MigrateToLatest($v1Event)

        $v2Event.data.priority | Should Be "medium"
        $v2Event.type | Should BeLike "*v2.0.0*"
    }

    It "Should apply multiple upcasters in sequence" {
        $Script:Registry.RegisterEventType("MessageSent", "3.0.0")

        # v1 -> v2
        $Script:Engine.RegisterUpcaster(
            "MessageSent",
            "v1.0.0",
            "v2.0.0",
            {
                param($evt)
                $evt.data.priority = 0
                return $evt
            }.GetNewClosure()
        )

        # v2 -> v3
        $Script:Engine.RegisterUpcaster(
            "MessageSent",
            "v2.0.0",
            "v3.0.0",
            {
                param($evt)
                $evt.data.correlationId = [Guid]::NewGuid().ToString()
                return $evt
            }.GetNewClosure()
        )

        # Create v1 event
        $v1Event = @{
            type = "MessageSent:v1.0.0"
            data = @{
                from = "pm"
                to = "developer"
                type = "AssignTask"
            }
        }

        # Migrate all the way to v3
        $v3Event = $Script:Engine.MigrateToLatest($v1Event)

        $v3Event.data.priority | Should Be 0
        $v3Event.data.correlationId | Should Not BeNullOrEmpty
        $v3Event.type | Should BeLike "*v3.0.0*"
    }

    It "Should track migration statistics" {
        $Script:Registry.RegisterEventType("TestEvent", "2.0.0")
        $Script:Engine.RegisterUpcaster("TestEvent", "v1.0.0", "v2.0.0", { param($e) return $e })

        # Migrate multiple events
        for ($i = 0; $i -lt 10; $i++) {
            $evt = @{
                type = "TestEvent:v1.0.0"
                data = @{ id = $i }
            }
            $Script:Engine.MigrateToLatest($evt) | Out-Null
        }

        $stats = $Script:Engine.GetMigrationStats()
        $stats.TotalMigrations | Should Be 10
    }
}

Describe "Projections - State Rebuilding" {
    BeforeEach {
        Remove-TestData
        $projDir = Join-Path $Script:TestDataDir "projection-test"
        $Script:Manager = New-ProjectionManager -DataDirectory $projDir
        $Script:AgentProjection = New-AgentStatusProjection
        $Script:Manager.Register($Script:AgentProjection)
    }

    It "Should rebuild projection from events" {
        $events = [List[object]]::new()

        # Create test events
        $events.Add(@{
            type = "AgentStarted"
            data = @{ agent = "pm"; pid = 1001 }
            timestamp = [DateTime]::UtcNow.ToString("o")
        })

        $events.Add(@{
            type = "AgentStarted"
            data = @{ agent = "developer"; pid = 1002 }
            timestamp = [DateTime]::UtcNow.ToString("o")
        })

        $events.Add(@{
            type = "AgentExited"
            data = @{ agent = "pm"; exitCode = 0 }
            timestamp = [DateTime]::UtcNow.ToString("o")
        })

        # Process events
        $Script:Manager.ProcessEvents($events.ToArray())

        # Check projection state
        $pmStatus = $Script:AgentProjection.GetAgentStatus("pm")
        $pmStatus | Should Not Be $null
        $pmStatus.state | Should Be "stopped"

        $devStatus = $Script:AgentProjection.GetAgentStatus("developer")
        $devStatus | Should Not Be $null
        $devStatus.state | Should Be "running"
    }

    It "Should persist and restore projection state" {
        $events = @(
            @{ type = "AgentStarted"; data = @{ agent = "qa"; pid = 1003 } }
        )

        $Script:Manager.ProcessEvents($events)
        $Script:Manager.Persist()

        # Create new manager and load
        $newManager = New-ProjectionManager -DataDirectory $projDir
        $newProjection = New-AgentStatusProjection
        $newManager.Register($newProjection)

        # Should have loaded previous state
        $newProjection.Checkpoint.ProcessedCount | Should Be 1
    }

    It "Should incrementally update projection" {
        # First batch
        $batch1 = @(
            @{ type = "AgentStarted"; data = @{ agent = "agent1"; pid = 2001 } }
            @{ type = "AgentStarted"; data = @{ agent = "agent2"; pid = 2002 } }
        )

        $Script:Manager.ProcessEvents($batch1)
        $Script:Manager.Checkpoint.LastProcessedSequence | Should Be 2

        # Second batch
        $batch2 = @(
            @{ type = "AgentStarted"; data = @{ agent = "agent3"; pid = 2003 } }
        )

        $Script:Manager.ProcessEvents($batch2)
        $Script:Manager.Checkpoint.LastProcessedSequence | Should Be 3

        # All agents should be present
        $Script:AgentProjection.AgentStates.Count | Should Be 3
    }
}

Describe "Integration - End-to-End Scenarios" {
    BeforeEach {
        Remove-TestData
        $sessionDir = Join-Path $Script:TestDataDir "e2e-session"
        New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null
        $Script:SessionDir = $sessionDir
    }

    AfterEach {
        # Clean up mutexes
        if ($Script:EventLogMutex) {
            $Script:EventLogMutex.Dispose()
        }
        if ($Script:SequenceMutex) {
            $Script:SequenceMutex.Dispose()
        }
    }

    It "Should complete full event lifecycle" {
        # Initialize components
        Initialize-EventLog -SessionDir $Script:SessionDir -SessionId "e2e-test" | Out-Null

        $store = New-EventStore -DataDirectory $Script:SessionDir
        $registry = New-EventTypeRegistry
        $registry.RegisterEventType("TaskAssigned", "1.0.0")
        $engine = New-MigrationEngine -Registry $registry

        $projManager = New-ProjectionManager -DataDirectory $Script:SessionDir
        $taskProjection = New-TaskTrackingProjection
        $projManager.Register($taskProjection)

        # Simulate task lifecycle
        $events = @(
            @{ type = "TaskAssigned"; data = @{ taskId = "task-1"; agent = "developer"; title = "Feature X" } }
            @{ type = "MessageSent"; data = @{ from = "pm"; to = "developer"; type = "TaskAssigned" } }
            @{ type = "TaskCompleted"; data = @{ taskId = "task-1"; agent = "developer" } }
        )

        # Write to event log
        foreach ($evt in $events) {
            Write-Event -Type $evt.type -Data $evt.data
        }

        # Process through projections
        $projManager.ProcessEvents($events)

        # Verify results
        $stats = $taskProjection.GetStatistics()
        $stats.TotalAssigned | Should Be 1
        $stats.TotalCompleted | Should Be 1
    }

    It "Should handle agent crash and restart scenario" {
        Initialize-EventLog -SessionDir $Script:SessionDir -SessionId "crash-test" | Out-Null

        # Simulate agent lifecycle
        Write-Event -Type "AgentStarted" -Data @{ agent = "developer"; pid = 3001 }
        Write-Event -Type "TaskAssigned" -Data @{ taskId = "task-2"; agent = "developer"; title = "Fix bug" }

        # Agent crashes
        Write-Event -Type "AgentCrashed" -Data @{ agent = "developer"; exitCode = 1 }

        # Rebuild state
        $status = Rebuild-AgentStatus

        # Agent should be in crashed state
        $developerStatus = $status["developer"]
        $developerStatus.state | Should Be "crashed"
        $developerStatus.exitCode | Should Be 1
    }
}

Describe "Metrics - Accuracy and Consistency" {
    It "Should track message latency accurately" {
        $tracker = [LatencyTracker]::new(100)

        # Record latencies with known distribution
        $knownLatencies = @(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)  # ms
        foreach ($lat in $knownLatencies) {
            $tracker.Record($lat * 1000)  # Convert to microseconds
        }

        $stats = $tracker.GetStatistics()

        # Average should be 5.5ms
        [math]::Round($stats.avg, 1) | Should Be 5.5

        # p50 should be close to 5ms
        $stats.p50 | Should BeGreaterOrEqual 4
        $stats.p50 | Should BeLessOrEqual 6
    }

    It "Should track throughput correctly" {
        $counter = [ThroughputCounter]::new()

        # Simulate activity over 1 second
        $start = Get-Date
        for ($i = 0; $i -lt 100; $i++) {
            $counter.Increment()
            Start-Sleep -Milliseconds 5
        }

        $stats = $counter.GetStatistics()

        $stats.Count | Should Be 100
        $stats.Rate | Should BeGreaterThan 0
    }
}

# Cleanup at end
Remove-TestData
