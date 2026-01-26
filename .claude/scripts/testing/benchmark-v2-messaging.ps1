# Ralph V2 Messaging Performance Benchmarks
# Measures the performance characteristics of the V2 architecture
#
# Benchmarks:
# - Event write throughput (events/second)
# - Event replay speed (time to rebuild from N events)
# - Message serialization/deserialization speed
# - Memory usage with large event logs

$ErrorActionPreference = "Stop"

# Get the project root
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $ProjectRoot

# Import V2 modules
. ".\.claude\scripts\eventlog.ps1"
. ".\.claude\scripts\event-bus.ps1"
. ".\.claude\scripts\message-protocol.ps1"

Write-Host "=== Ralph V2 Messaging Performance Benchmarks ===" -ForegroundColor Cyan
Write-Host ""

# Create temporary directory for benchmarks
$benchDir = Join-Path $env:TEMP "ralph-benchmark-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $benchDir -Force | Out-Null

Write-Host "Benchmark directory: $benchDir"
Write-Host ""

# ============================================================================
# BENCHMARK: Event Write Throughput
# ============================================================================

Write-Host "Benchmark: Event Write Throughput" -ForegroundColor Yellow

Initialize-EventLog -SessionDir $benchDir | Out-Null

$eventCount = 1000
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

for ($i = 0; $i -lt $eventCount; $i++) {
    Write-Event -Type "BenchmarkEvent" -Data @{
        iteration = $i
        timestamp = [DateTime]::UtcNow.ToString("o")
        data = "x" * 100  # 100 chars of data
    } | Out-Null
}

$stopwatch.Stop()
$eventsPerSecond = $eventCount / $stopwatch.Elapsed.TotalSeconds

Write-Host "  Wrote $eventCount events in $($stopwatch.ElapsedMilliseconds)ms"
Write-Host "  Throughput: $([math]::Round($eventsPerSecond)) events/second"
Write-Host ""

# ============================================================================
# BENCHMARK: Event Replay Speed
# ============================================================================

Write-Host "Benchmark: Event Replay Speed" -ForegroundColor Yellow

$stopwatch.Restart()
$status = Rebuild-AgentStatus
$stopwatch.Stop()

Write-Host "  Rebuilt agent status from $eventCount events in $($stopwatch.ElapsedMilliseconds)ms"
Write-Host "  Replay rate: $([math]::Round($eventCount / $stopwatch.Elapsed.TotalSeconds)) events/second"
Write-Host ""

# ============================================================================
# BENCHMARK: Get-EventsSince Performance
# ============================================================================

Write-Host "Benchmark: Get-EventsSince Performance" -ForegroundColor Yellow

# Test different filter scenarios
$scenarios = @{
    "FromSeq 0 (all events)" = 0
    "FromSeq 500 (half)" = 500
    "FromSeq 900 (last 100)" = 900
}

foreach ($scenarioName in $scenarios.Keys) {
    $fromSeq = $scenarios[$scenarioName]
    $stopwatch.Restart()
    $events = Get-EventsSince -FromSeq $fromSeq
    $stopwatch.Stop()

    Write-Host "  $scenarioName : $($stopwatch.ElapsedMilliseconds)ms ($($events.Count) events)"
}

Write-Host ""

# ============================================================================
# BENCHMARK: Message Serialization
# ============================================================================

Write-Host "Benchmark: Message Serialization" -ForegroundColor Yellow

$messageCount = 1000
$messages = @()

for ($i = 0; $i -lt $messageCount; $i++) {
    $messages += New-WorkAssignMessage -From "pm" -To "developer" -TaskId "task-$i" -WorkType "implementation" -Title "Task $i"
}

# Benchmark serialization
$stopwatch.Restart()
$serialized = $messages | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 10 }
$stopwatch.Stop()

Write-Host "  Serialized $messageCount messages in $($stopwatch.ElapsedMilliseconds)ms"
Write-Host "  Rate: $([math]::Round($messageCount / $stopwatch.Elapsed.TotalSeconds)) messages/second"
Write-Host ""

# ============================================================================
# BENCHMARK: Message Deserialization
# ============================================================================

Write-Host "Benchmark: Message Deserialization" -ForegroundColor Yellow

$stopwatch.Restart()
$deserialized = $serialized | ForEach-Object { $_ | ConvertFrom-Json }
$stopwatch.Stop()

Write-Host "  Deserialized $messageCount messages in $($stopwatch.ElapsedMilliseconds)ms"
Write-Host "  Rate: $([math]::Round($messageCount / $stopwatch.Elapsed.TotalSeconds)) messages/second"
Write-Host ""

# ============================================================================
# BENCHMARK: Event Statistics
# ============================================================================

Write-Host "Benchmark: Event Statistics Calculation" -ForegroundColor Yellow

$stopwatch.Restart()
$stats = Get-EventStatistics
$stopwatch.Stop()

Write-Host "  Calculated statistics from $eventCount events in $($stopwatch.ElapsedMilliseconds)ms"
Write-Host "  Result: $($stats.TotalEvents) total events, $($stats.LastSequence) last sequence"
Write-Host ""

# ============================================================================
# BENCHMARK: Export-AgentStatus
# ============================================================================

Write-Host "Benchmark: Materialized View Export" -ForegroundColor Yellow

$statusPath = Join-Path $benchDir "agent-status-benchmark.json"

$stopwatch.Restart()
Export-AgentStatus -OutputPath $statusPath
$stopwatch.Stop()

Write-Host "  Exported agent status in $($stopwatch.ElapsedMilliseconds)ms"

$fileSize = (Get-Item $statusPath).Length
Write-Host "  File size: $([math]::Round($fileSize / 1KB, 2)) KB"
Write-Host ""

# ============================================================================
# BENCHMARK: Memory Usage
# ============================================================================

Write-Host "Benchmark: Memory Usage" -ForegroundColor Yellow

# Get current process memory usage
$process = Get-Process -Id $PID
$memoryBefore = $process.WorkingSet64 / 1MB

Write-Host "  Process memory before large operations: $([math]::Round($memoryBefore, 2)) MB"

# Load all events into memory
$allEvents = Get-EventsSince -FromSeq 0

$process.Refresh()
$memoryAfter = $process.WorkingSet64 / 1MB

Write-Host "  Process memory after loading all events: $([math]::Round($memoryAfter, 2)) MB"
Write-Host "  Memory delta: $([math]::Round($memoryAfter - $memoryBefore, 2)) MB"
Write-Host ""

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host "=== Benchmark Summary ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target performance goals:"
Write-Host "  - Event write throughput: > 1000 events/sec"
Write-Host "  - Event replay speed: > 5000 events/sec"
Write-Host "  - Message serialization: > 10000 messages/sec"
Write-Host "  - Memory efficiency: < 100 MB for 10K events"
Write-Host ""

# Clean up
Remove-Item -Recurse -Force $benchDir -ErrorAction SilentlyContinue
Write-Host "Cleanup complete."
