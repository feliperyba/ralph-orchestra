# Ralph Performance Benchmark Suite
# Automated performance benchmarks with threshold verification

$ErrorActionPreference = "Stop"

# Source test helpers
. "$PSScriptRoot\test-helpers.ps1"

# Source message queue for messaging benchmarks
. "$PSScriptRoot\message-queue.ps1"

Write-Host "=== Ralph Performance Benchmark Suite ===" -ForegroundColor Cyan

# ============================================================================
# BENCHMARK CONFIGURATION
# ============================================================================

$Script:BenchmarkThresholds = @{
    # Target thresholds based on Phase 2-3 improvements
    MessageDeliveryMs = 10          # Target: <10ms for message delivery
    StatePersistenceMs = 5          # Target: <5ms for state write
    MessageQueueScanMs = 5          # Target: <5ms for queue scan
    MemoryGrowthMBPerHour = 1.0     # Target: <1MB/hour
    CpuIdlePercent = 5.0            # Target: <5% CPU at idle
    MessageThroughputPerSec = 50    # Target: >50 messages/second
}

$Script:BenchmarkResults = @{}

# ============================================================================
# BENCHMARK 1: MESSAGE DELIVERY LATENCY
# ============================================================================

function Measure-MessageDeliveryLatency {
    <#
    .SYNOPSIS
    Measure time from Send-AgentMessage to message available in queue.

    .DESCRIPTION
    Measures the complete message delivery pipeline:
    - Message creation
    - File write
    - Queue enumeration
    - Message retrieval

    Target: <10ms
    #>
    param()

    $env = New-TestEnvironment -TestName "benchmark-delivery"

    try {
        Initialize-MessageQueue -SessionDir $env.SessionDir

        # Warm up
        for ($i = 1; $i -le 5; $i++) {
            $msgId = Send-AgentMessage -From "pm" -To "developer" -Type "status_update" -Payload @{ warmup = $true }
            Get-PendingMessages -Agent "developer" | Out-Null
            Invoke-AcknowledgeMessage -MessageId $msgId -Agent "developer" | Out-Null
        }

        # Measure 100 deliveries
        $samples = @()
        $iterations = 100

        for ($i = 1; $i -le $iterations; $i++) {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()

            # Send
            $msgId = Send-AgentMessage -From "pm" -To "developer" -Type "status_update" -Payload @{ index = $i }

            # Retrieve
            $pending = Get-PendingMessages -Agent "developer"
            $null = $pending | Where-Object { $_.id -eq $msgId }

            $sw.Stop()
            $samples += $sw.ElapsedMilliseconds

            # Clean up
            Invoke-AcknowledgeMessage -MessageId $msgId -Agent "developer" | Out-Null
        }

        # Calculate statistics
        $avg = ($samples | Measure-Object -Average).Average
        $min = ($samples | Measure-Object -Minimum).Minimum
        $max = ($samples | Measure-Object -Maximum).Maximum
        $p50 = ($samples | Sort-Object)[[math]::Floor($samples.Count * 0.5)]
        $p95 = ($samples | Sort-Object)[[math]::Floor($samples.Count * 0.95)]
        $p99 = ($samples | Sort-Object)[[math]::Floor($samples.Count * 0.99)]

        $result = @{
            Average = [math]::Round($avg, 2)
            Min = [math]::Round($min, 2)
            Max = [math]::Round($max, 2)
            P50 = [math]::Round($p50, 2)
            P95 = [math]::Round($p95, 2)
            P99 = [math]::Round($p99, 2)
            Target = $Script:BenchmarkThresholds.MessageDeliveryMs
            Pass = $avg -lt $Script:BenchmarkThresholds.MessageDeliveryMs
        }

        return $result
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# BENCHMARK 2: STATE PERSISTENCE
# ============================================================================

function Measure-StatePersistence {
    <#
    .SYNOPSIS
    Measure time to write state files to disk.

    .DESCRIPTION
    Measures state file write performance including:
    - JSON serialization
    - File write
    - Disk flush

    Target: <5ms
    #>
    param()

    $env = New-TestEnvironment -TestName "benchmark-state"

    try {
        $stateFile = Join-Path $env.StateDir "benchmark-state.json"

        # Create realistic state payload
        $testState = @{
            version = 1
            timestamp = [DateTime]::UtcNow.ToString("o")
            agents = @{
                pm = @{
                    status = "idle"
                    lastHeartbeat = [DateTime]::UtcNow.ToString("o")
                    pid = 1234
                    contextResets = 2
                    tasksCompleted = 5
                }
                developer = @{
                    status = "working"
                    lastHeartbeat = [DateTime]::UtcNow.ToString("o")
                    pid = 5678
                    contextResets = 1
                    tasksCompleted = 3
                }
                qa = @{
                    status = "idle"
                    lastHeartbeat = [DateTime]::UtcNow.ToString("o")
                    pid = 9012
                    contextResets = 0
                    tasksCompleted = 2
                }
            }
            currentTask = @{
                id = "task-001"
                title = "Benchmark task"
                status = "in_progress"
                agent = "developer"
                startTime = [DateTime]::UtcNow.ToString("o")
            }
            metrics = @{
                totalIterations = 10
                tasksCompleted = 8
                contextResets = 3
            }
        }

        # Warm up
        for ($i = 1; $i -le 5; $i++) {
            $testState | ConvertTo-Json -Depth 10 | Set-Content -Path $stateFile -Encoding UTF8
        }

        # Measure 100 writes
        $samples = @()
        $iterations = 100

        for ($i = 1; $i -le $iterations; $i++) {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()

            # Write state
            $testState | ConvertTo-Json -Depth 10 | Set-Content -Path $stateFile -Encoding UTF8

            $sw.Stop()
            $samples += $sw.ElapsedMilliseconds
        }

        $avg = ($samples | Measure-Object -Average).Average
        $min = ($samples | Measure-Object -Minimum).Minimum
        $max = ($samples | Measure-Object -Maximum).Maximum

        $result = @{
            Average = [math]::Round($avg, 2)
            Min = [math]::Round($min, 2)
            Max = [math]::Round($max, 2)
            Target = $Script:BenchmarkThresholds.StatePersistenceMs
            Pass = $avg -lt $Script:BenchmarkThresholds.StatePersistenceMs
        }

        return $result
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# BENCHMARK 3: MESSAGE QUEUE SCAN
# ============================================================================

function Measure-MessageQueueScan {
    <#
    .SYNOPSIS
    Measure time to scan message queue for pending messages.

    .DESCRIPTION
    Measures queue enumeration performance with various message counts.

    Target: <5ms
    #>
    param()

    $env = New-TestEnvironment -TestName "benchmark-queue-scan"

    try {
        Initialize-MessageQueue -SessionDir $env.SessionDir

        # Pre-populate queue with messages
        $messageCounts = @(10, 50, 100)
        $results = @{}

        foreach ($count in $messageCounts) {
            # Clear queue
            Get-ChildItem -Path (Join-Path $env.MessagesDir "developer") -File | Remove-Item -Force

            # Add messages
            for ($i = 1; $i -le $count; $i++) {
                Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ index = $i } | Out-Null
            }

            # Warm up
            for ($i = 1; $i -le 5; $i++) {
                Get-PendingMessages -Agent "developer" | Out-Null
            }

            # Measure 50 scans
            $samples = @()
            for ($i = 1; $i -le 50; $i++) {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $null = Get-PendingMessages -Agent "developer"
                $sw.Stop()
                $samples += $sw.ElapsedMilliseconds
            }

            $avg = ($samples | Measure-Object -Average).Average

            $results[$count] = @{
                Average = [math]::Round($avg, 3)
                Min = [math]::Round(($samples | Measure-Object -Minimum).Minimum, 3)
                Max = [math]::Round(($samples | Measure-Object -Maximum).Maximum, 3)
            }
        }

        $avg100 = $results[100].Average
        $result = @{
            ByMessageCount = $results
            At100Messages = $results[100].Average
            Target = $Script:BenchmarkThresholds.MessageQueueScanMs
            Pass = $avg100 -lt $Script:BenchmarkThresholds.MessageQueueScanMs
        }

        return $result
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# BENCHMARK 4: MEMORY GROWTH
# ============================================================================

function Measure-MemoryGrowth {
    <#
    .SYNOPSIS
    Measure memory growth over simulated workload.

    .DESCRIPTION
    Measures memory growth over time to detect memory leaks.
    Runs a workload and measures memory before/after.

    Target: <1MB/hour
    #>
    param()

    $env = New-TestEnvironment -TestName "benchmark-memory"

    try {
        Initialize-MessageQueue -SessionDir $env.SessionDir

        # Get initial memory
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        [GC]::Collect()
        $initialMemory = [GC]::GetTotalMemory($true)

        # Simulate workload: 1000 message cycles
        for ($i = 1; $i -le 1000; $i++) {
            $msgId = Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ index = $i }
            Get-PendingMessages -Agent "developer" | Out-Null
            Invoke-AcknowledgeMessage -MessageId $msgId -Agent "developer" | Out-Null

            # Periodic GC
            if ($i % 100 -eq 0) {
                [GC]::Collect()
            }
        }

        # Force final collection
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        [GC]::Collect()
        $finalMemory = [GC]::GetTotalMemory($true)

        # Calculate growth
        $growthBytes = $finalMemory - $initialMemory
        $growthKB = $growthBytes / 1KB
        $growthMB = $growthBytes / 1MB

        # Extrapolate to hourly rate (assuming 1000 messages takes ~1 minute in real use)
        # This is a simplified estimate
        $hourlyGrowthMB = $growthMB * 60  # Rough estimate

        $result = @{
            InitialMemoryKB = [math]::Round($initialMemory / 1KB, 2)
            FinalMemoryKB = [math]::Round($finalMemory / 1KB, 2)
            GrowthKB = [math]::Round($growthKB, 2)
            GrowthMB = [math]::Round($growthMB, 4)
            EstimatedHourlyGrowthMB = [math]::Round($hourlyGrowthMB, 4)
            Target = $Script:BenchmarkThresholds.MemoryGrowthMBPerHour
            Pass = $hourlyGrowthMB -lt $Script:BenchmarkThresholds.MemoryGrowthMBPerHour
        }

        return $result
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# BENCHMARK 5: MESSAGE THROUGHPUT
# ============================================================================

function Measure-MessageThroughput {
    <#
    .SYNOPSIS
    Measure maximum message throughput (messages per second).

    .DESCRIPTION
    Measures how many messages can be sent and acknowledged per second.

    Target: >50 messages/second
    #>
    param()

    $env = New-TestEnvironment -TestName "benchmark-throughput"

    try {
        Initialize-MessageQueue -SessionDir $env.SessionDir

        # Measure throughput over 1 second
        $durationSeconds = 1
        $endTime = [DateTime]::UtcNow.AddSeconds($durationSeconds)
        $messageCount = 0

        while ([DateTime]::UtcNow -lt $endTime) {
            $msgId = Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ index = $messageCount }
            Invoke-AcknowledgeMessage -MessageId $msgId -Agent "developer" | Out-Null
            $messageCount++
        }

        $throughput = $messageCount / $durationSeconds

        $result = @{
            MessagesSent = $messageCount
            DurationSeconds = $durationSeconds
            ThroughputPerSecond = [math]::Round($throughput, 2)
            Target = $Script:BenchmarkThresholds.MessageThroughputPerSec
            Pass = $throughput -gt $Script:BenchmarkThresholds.MessageThroughputPerSec
        }

        return $result
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# BENCHMARK 6: CACHED OPERATIONS
# ============================================================================

function Measure-CachedOperations {
    <#
    .SYNOPSIS
    Measure performance improvement from caching.

    .DESCRIPTION
    Compares cached vs uncached operations for:
    - Dashboard cell values
    - Directory enumeration
    #>
    param()

    $env = New-TestEnvironment -TestName "benchmark-cache"

    try {
        # Source cache module (dashboard cache from watchdog)
        $Script:DashboardCellCache = @{}
        $Script:CellCacheMaxAge = 1000  # 1 second TTL

        function Get-CachedDashboardCell {
            param([string]$CellId, [scriptblock]$Formatter)
            $now = [DateTime]::UtcNow
            if ($Script:DashboardCellCache.ContainsKey($CellId)) {
                $cached = $Script:DashboardCellCache[$CellId]
                if (($now - $cached.Time).TotalMilliseconds -lt $Script:CellCacheMaxAge) {
                    return $cached.Value
                }
            }
            $value = & $Formatter
            $Script:DashboardCellCache[$CellId] = @{ Time = $now; Value = $value }
            return $value
        }

        # Benchmark uncached (direct computation)
        $samplesUncached = @()
        $startTime = [DateTime]::UtcNow
        for ($i = 1; $i -le 1000; $i++) {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $result = "{0:hh\:mm\:ss}" -f ([DateTime]::UtcNow - $startTime)
            $sw.Stop()
            $samplesUncached += $sw.ElapsedTicks
        }
        $avgUncached = ($samplesUncached | Measure-Object -Average).Average

        # Benchmark cached
        $samplesCached = @()
        for ($i = 1; $i -le 1000; $i++) {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $result = Get-CachedDashboardCell -CellId "uptime" -Formatter {
                "{0:hh\:mm\:ss}" -f ([DateTime]::UtcNow - $startTime)
            }
            $sw.Stop()
            $samplesCached += $sw.ElapsedTicks
        }
        $avgCached = ($samplesCached | Measure-Object -Average).Average

        # Calculate improvement
        $improvement = if ($avgCached -gt 0) { $avgUncached / $avgCached } else { 1 }
        $percentImprovement = [math]::Round(($improvement - 1) * 100, 1)

        $result = @{
            AvgUncachedTicks = [math]::Round($avgUncached, 2)
            AvgCachedTicks = [math]::Round($avgCached, 2)
            SpeedupFactor = [math]::Round($improvement, 2)
            PercentImprovement = $percentImprovement
            Pass = $improvement -gt 1.1  # At least 10% improvement
        }

        return $result
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# RESULT FORMATTING
# ============================================================================

function Show-BenchmarkResult {
    <#
    .SYNOPSIS
    Display benchmark result with pass/fail indication.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        $Result,

        [string]$Unit = "ms"
    )

    $value = if ($Result.Average) { $Result.Average } elseif ($Result.ThroughputPerSecond) { $Result.ThroughputPerSecond } elseif ($Result.Throughput) { $Result.Throughput } elseif ($Result.EstimatedHourlyGrowthMB) { $Result.EstimatedHourlyGrowthMB } else { $Result }

    $target = $Result.Target
    $pass = if ($null -ne $Result.Pass) { $Result.Pass } else { $value -lt $target }

    $status = if ($pass) { "[PASS]" } else { "[FAIL]" }
    $statusColor = if ($pass) { "Green" } else { "Red" }

    Write-Host "  $Name " -NoNewline
    Write-Host $status -ForegroundColor $statusColor -NoNewline
    Write-Host ": " -NoNewline
    Write-Host "$value $Unit" -NoNewline -ForegroundColor Cyan
    Write-Host " (target: <$target $Unit)" -ForegroundColor Gray

    # Show additional stats if available
    if ($Result.Min -and $Result.Max) {
        Write-Host "    Range: $($Result.Min)-$($Result.Max) $Unit" -ForegroundColor DarkGray
    }
    if ($Result.P50 -and $Result.P95) {
        Write-Host "    Percentiles: p50=$($Result.P50), p95=$($Result.P95), p99=$($Result.P99) $Unit" -ForegroundColor DarkGray
    }
    if ($Result.SpeedupFactor) {
        Write-Host "    Cache speedup: $($Result.SpeedupFactor)x ($($Result.PercentImprovement)% improvement)" -ForegroundColor DarkGray
    }
}

# ============================================================================
# BENCHMARK RUNNER
# ============================================================================

function Invoke-BenchmarkWithTiming {
    <#
    .SYNOPSIS
    Run a benchmark function and return both the result and timing.

    .RETURNS
    The benchmark result (hashtable with Pass, Average, Target, etc.)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$BenchmarkName,

        [Parameter(Mandatory=$true)]
        [scriptblock]$BenchmarkScript
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $result = & $BenchmarkScript
    $sw.Stop()

    $color = if ($sw.ElapsedMilliseconds -lt 10000) { "Green" } elseif ($sw.ElapsedMilliseconds -lt 30000) { "Yellow" } else { "Red" }
    Write-Host "    Complete: " -NoNewline -ForegroundColor Gray
    Write-Host "$($sw.ElapsedMilliseconds) ms" -ForegroundColor $color

    return $result
}

function Invoke-AllBenchmarks {
    <#
    .SYNOPSIS
    Run all performance benchmarks and report results.
    #>
    param(
        [switch]$Verbose
    )

    Write-Host "`n=== Running Performance Benchmarks ===" -ForegroundColor Cyan
    Write-Host "This may take a minute..." -ForegroundColor Gray

    $overallPass = $true

    # Benchmark 1: Message Delivery
    Write-Host "`n--- Message Delivery Latency ---" -ForegroundColor Cyan
    $deliveryResult = Invoke-BenchmarkWithTiming -BenchmarkName "MessageDelivery" -BenchmarkScript ${function:Measure-MessageDeliveryLatency}
    $Script:BenchmarkResults.Delivery = $deliveryResult
    Show-BenchmarkResult -Name "Average" -Result $deliveryResult
    Show-BenchmarkResult -Name "P95" -Result @{ Average = $deliveryResult.P95; Target = $deliveryResult.Target }
    if (-not $deliveryResult.Pass) { $overallPass = $false }

    # Benchmark 2: State Persistence
    Write-Host "`n--- State Persistence ---" -ForegroundColor Cyan
    $stateResult = Invoke-BenchmarkWithTiming -BenchmarkName "StatePersistence" -BenchmarkScript ${function:Measure-StatePersistence}
    $Script:BenchmarkResults.StatePersistence = $stateResult
    Show-BenchmarkResult -Name "Write" -Result $stateResult
    if (-not $stateResult.Pass) { $overallPass = $false }

    # Benchmark 3: Queue Scan
    Write-Host "`n--- Message Queue Scan ---" -ForegroundColor Cyan
    $queueResult = Invoke-BenchmarkWithTiming -BenchmarkName "QueueScan" -BenchmarkScript ${function:Measure-MessageQueueScan}
    $Script:BenchmarkResults.QueueScan = $queueResult
    Write-Host "  At 10 messages: " -NoNewline -ForegroundColor Gray
    Write-Host "$($queueResult.ByMessageCount[10].Average) ms" -ForegroundColor Cyan
    Write-Host "  At 50 messages: " -NoNewline -ForegroundColor Gray
    Write-Host "$($queueResult.ByMessageCount[50].Average) ms" -ForegroundColor Cyan
    Write-Host "  At 100 messages: " -NoNewline -ForegroundColor Gray
    Write-Host "$($queueResult.At100Messages) ms" -ForegroundColor Cyan
    Write-Host "    (target: <$($queueResult.Target) ms)" -ForegroundColor DarkGray
    if (-not $queueResult.Pass) { $overallPass = $false }

    # Benchmark 4: Memory Growth
    Write-Host "`n--- Memory Growth ---" -ForegroundColor Cyan
    $memoryResult = Invoke-BenchmarkWithTiming -BenchmarkName "MemoryGrowth" -BenchmarkScript ${function:Measure-MemoryGrowth}
    $Script:BenchmarkResults.MemoryGrowth = $memoryResult
    Write-Host "  Initial: " -NoNewline -ForegroundColor Gray
    Write-Host "$($memoryResult.InitialMemoryKB) KB" -ForegroundColor Cyan
    Write-Host "  Final: " -NoNewline -ForegroundColor Gray
    Write-Host "$($memoryResult.FinalMemoryKB) KB" -ForegroundColor Cyan
    Write-Host "  Growth: " -NoNewline -ForegroundColor Gray
    Write-Host "$($memoryResult.GrowthMB) MB" -ForegroundColor Cyan
    Write-Host "  Estimated hourly: " -NoNewline -ForegroundColor Gray
    Write-Host "$($memoryResult.EstimatedHourlyGrowthMB) MB/hr (target: <$($memoryResult.Target) MB/hr)" -ForegroundColor $(if ($memoryResult.Pass) { "Green" } else { "Red" })
    if (-not $memoryResult.Pass) { $overallPass = $false }

    # Benchmark 5: Throughput
    Write-Host "`n--- Message Throughput ---" -ForegroundColor Cyan
    $throughputResult = Invoke-BenchmarkWithTiming -BenchmarkName "Throughput" -BenchmarkScript ${function:Measure-MessageThroughput}
    $Script:BenchmarkResults.Throughput = $throughputResult
    Show-BenchmarkResult -Name "Throughput" -Result $throughputResult -Unit "msg/sec"
    if (-not $throughputResult.Pass) { $overallPass = $false }

    # Benchmark 6: Cache Performance
    Write-Host "`n--- Cache Performance ---" -ForegroundColor Cyan
    $cacheResult = Invoke-BenchmarkWithTiming -BenchmarkName "CachePerformance" -BenchmarkScript ${function:Measure-CachedOperations}
    $Script:BenchmarkResults.Cache = $cacheResult
    Write-Host "  Uncached: " -NoNewline -ForegroundColor Gray
    Write-Host "$($cacheResult.AvgUncachedTicks) ticks" -ForegroundColor Cyan
    Write-Host "  Cached: " -NoNewline -ForegroundColor Gray
    Write-Host "$($cacheResult.AvgCachedTicks) ticks" -ForegroundColor Cyan
    Write-Host "  Speedup: " -NoNewline -ForegroundColor Gray
    Write-Host "$($cacheResult.SpeedupFactor)x ($($cacheResult.PercentImprovement)%)" -ForegroundColor Green

    # Summary
    Write-Host "`n=== Benchmark Summary ===" -ForegroundColor Cyan
    $passed = ($Script:BenchmarkResults.Values | Where-Object { $_.Pass -eq $true }).Count
    $total = ($Script:BenchmarkResults.Values | Where-Object { $_.Pass -is [bool] }).Count
    Write-Host "  Thresholds passed: $passed / $total" -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Yellow" })

    # Cleanup
    Remove-AllTestEnvironments

    return $overallPass
}

# Always run benchmarks when this script is executed
$success = Invoke-AllBenchmarks
exit $(if ($success) { 0 } else { 1 })
