# Ralph Metrics Module (PowerShell 5.1 Compatible)
# Performance tracking for <10ms latency verification
#
# Design Goals:
# - Track p50, p95, p99 latencies with minimal overhead
# - Thread-safe recording from multiple processes
# - Rolling window to prevent unbounded growth
# - Export to JSON for analysis
#
# PowerShell 5.1 Compatibility Notes:
# - Uses Monitor.Enter/Exit instead of lock() statement

# ============================================================================
# CLASSES
# ============================================================================

class LatencyTracker {
    # High-performance latency percentile tracker
    # Uses circular buffer for fixed memory footprint

    hidden [System.Collections.Generic.List[long]]$Samples
    hidden [int]$MaxSamples
    hidden [object]$Lock
    hidden [long]$TotalCount
    hidden [long]$Sum
    [string]$Name

    LatencyTracker([string]$name, [int]$maxSamples) {
        $this.Name = $name
        $this.Samples = [System.Collections.Generic.List[long]]::new()
        $this.MaxSamples = $maxSamples
        $this.Lock = [object]::new()
        $this.TotalCount = 0
        $this.Sum = 0
    }

    LatencyTracker([int]$maxSamples) {
        $this.Name = "Latency"
        $this.Samples = [System.Collections.Generic.List[long]]::new()
        $this.MaxSamples = $maxSamples
        $this.Lock = [object]::new()
        $this.TotalCount = 0
        $this.Sum = 0
    }

    [void] Record([long]$microseconds) {
        [System.Threading.Monitor]::Enter($this.Lock)
        try {
            $this.Samples.Add($microseconds)
            $this.Sum += $microseconds
            $this.TotalCount++

            if ($this.Samples.Count -gt $this.MaxSamples) {
                $removed = $this.Samples[0]
                $this.Samples.RemoveAt(0)
                $this.Sum -= $removed
            }
        } finally {
            [System.Threading.Monitor]::Exit($this.Lock)
        }
    }

    [void] Record([timespan]$duration) {
        $this.Record([long]($duration.TotalMilliseconds * 1000))
    }

    [void] RecordMs([double]$milliseconds) {
        $this.Record([long]($milliseconds * 1000))
    }

    [hashtable] GetStatistics() {
        [System.Threading.Monitor]::Enter($this.Lock)
        try {
            if ($this.Samples.Count -eq 0) {
                return @{
                    Name = $this.Name
                    Count = 0
                    p50 = 0.0
                    p75 = 0.0
                    p90 = 0.0
                    p95 = 0.0
                    p99 = 0.0
                    p999 = 0.0
                    avg = 0.0
                    min = 0.0
                    max = 0.0
                    sum = 0.0
                    unit = "ms"
                }
            }

            # Create sorted copy for percentiles
            $sorted = [long[]]::new($this.Samples.Count)
            $this.Samples.CopyTo($sorted)
            [Array]::Sort($sorted)

            $count = $sorted.Length

            return @{
                Name = $this.Name
                Count = $this.TotalCount
                p50 = $sorted[[math]::Floor($count * 0.50)] / 1000.0
                p75 = $sorted[[math]::Floor($count * 0.75)] / 1000.0
                p90 = $sorted[[math]::Floor($count * 0.90)] / 1000.0
                p95 = $sorted[[math]::Floor($count * 0.95)] / 1000.0
                p99 = $sorted[[math]::Floor($count * 0.99)] / 1000.0
                p999 = $sorted[[math]::Min($count - 1, [math]::Floor($count * 0.999))] / 1000.0
                avg = $this.Sum / [double]$this.Samples.Count / 1000.0
                min = $sorted[0] / 1000.0
                max = $sorted[$count - 1] / 1000.0
                sum = $this.Sum / 1000.0
                unit = "ms"
            }
        } finally {
            [System.Threading.Monitor]::Exit($this.Lock)
        }
    }

    [void] Reset() {
        [System.Threading.Monitor]::Enter($this.Lock)
        try {
            $this.Samples.Clear()
            $this.TotalCount = 0
            $this.Sum = 0
        } finally {
            [System.Threading.Monitor]::Exit($this.Lock)
        }
    }

    [int] GetSampleCount() {
        [System.Threading.Monitor]::Enter($this.Lock)
        try {
            return $this.Samples.Count
        } finally {
            [System.Threading.Monitor]::Exit($this.Lock)
        }
    }
}

class ThroughputCounter {
    # Tracks operations per second with sliding window

    hidden [System.Collections.Queue]$Timestamps
    hidden [int]$WindowSeconds
    hidden [object]$Lock
    [string]$Name

    ThroughputCounter() {
        $this.Name = "Throughput"
        $this.WindowSeconds = 60  # Default 60 second window
        $this.Timestamps = [System.Collections.Queue]::new()
        $this.Lock = [object]::new()
    }

    ThroughputCounter([string]$name, [int]$windowSeconds) {
        $this.Name = $name
        $this.WindowSeconds = $windowSeconds
        $this.Timestamps = [System.Collections.Queue]::new()
        $this.Lock = [object]::new()
    }

    ThroughputCounter([int]$windowSeconds) {
        $this.Name = "Throughput"
        $this.WindowSeconds = $windowSeconds
        $this.Timestamps = [System.Collections.Queue]::new()
        $this.Lock = [object]::new()
    }

    [void] Increment() {
        $now = [DateTime]::UtcNow
        [System.Threading.Monitor]::Enter($this.Lock)
        try {
            $this.Timestamps.Enqueue($now)
            $this.CleanupOldTimestamps($now)
        } finally {
            [System.Threading.Monitor]::Exit($this.Lock)
        }
    }

    [void] Increment([int]$count) {
        $now = [DateTime]::UtcNow
        [System.Threading.Monitor]::Enter($this.Lock)
        try {
            for ($i = 0; $i -lt $count; $i++) {
                $this.Timestamps.Enqueue($now)
            }
            $this.CleanupOldTimestamps($now)
        } finally {
            [System.Threading.Monitor]::Exit($this.Lock)
        }
    }

    hidden [void] CleanupOldTimestamps([DateTime]$now) {
        $cutoff = $now.AddSeconds(-$this.WindowSeconds)
        while ($this.Timestamps.Count -gt 0 -and $this.Timestamps.Peek() -lt $cutoff) {
            $this.Timestamps.Dequeue()
        }
    }

    [double] GetRate() {
        $now = [DateTime]::UtcNow
        [System.Threading.Monitor]::Enter($this.Lock)
        try {
            $this.CleanupOldTimestamps($now)
            return $this.Timestamps.Count / [double]$this.WindowSeconds
        } finally {
            [System.Threading.Monitor]::Exit($this.Lock)
        }
    }

    [hashtable] GetStatistics() {
        $now = [DateTime]::UtcNow
        [System.Threading.Monitor]::Enter($this.Lock)
        try {
            $this.CleanupOldTimestamps($now)
            return @{
                Name = $this.Name
                Count = $this.Timestamps.Count
                Rate = $this.Timestamps.Count / [double]$this.WindowSeconds
                WindowSeconds = $this.WindowSeconds
                Unit = "ops/sec"
            }
        } finally {
            [System.Threading.Monitor]::Exit($this.Lock)
        }
    }

    [void] Reset() {
        [System.Threading.Monitor]::Enter($this.Lock)
        try {
            $this.Timestamps.Clear()
        } finally {
            [System.Threading.Monitor]::Exit($this.Lock)
        }
    }

    [long] GetCount() {
        [System.Threading.Monitor]::Enter($this.Lock)
        try {
            return $this.Timestamps.Count
        } finally {
            [System.Threading.Monitor]::Exit($this.Lock)
        }
    }
}

class ErrorCounter {
    # Tracks error rates by type

    hidden [System.Collections.Generic.Dictionary[string,int]]$Errors
    hidden [System.Collections.Generic.Dictionary[string,System.Collections.Queue]]$ErrorTimestamps
    hidden [int]$WindowSeconds
    hidden [object]$Lock

    ErrorCounter([int]$windowSeconds) {
        $this.Errors = [System.Collections.Generic.Dictionary[string,int]]::new()
        $this.ErrorTimestamps = [System.Collections.Generic.Dictionary[string,System.Collections.Queue]]::new()
        $this.WindowSeconds = $windowSeconds
        $this.Lock = [object]::new()
    }

    [void] Record([string]$errorType) {
        $now = [DateTime]::UtcNow
        [System.Threading.Monitor]::Enter($this.Lock)
        try {
            if (-not $this.Errors.ContainsKey($errorType)) {
                $this.Errors[$errorType] = 0
                $this.ErrorTimestamps[$errorType] = [System.Collections.Queue]::new()
            }
            $this.Errors[$errorType]++
            $this.ErrorTimestamps[$errorType].Enqueue($now)

            # Cleanup old timestamps
            $cutoff = $now.AddSeconds(-$this.WindowSeconds)
            $timestamps = $this.ErrorTimestamps[$errorType]
            while ($timestamps.Count -gt 0 -and $timestamps.Peek() -lt $cutoff) {
                $timestamps.Dequeue()
            }
        } finally {
            [System.Threading.Monitor]::Exit($this.Lock)
        }
    }

    [hashtable] GetStatistics() {
        $now = [DateTime]::UtcNow
        [System.Threading.Monitor]::Enter($this.Lock)
        try {
            $result = [ordered]@{
                TotalErrors = 0
                ErrorRate = 0.0
                ByType = @{}
            }

            $recentErrors = 0

            foreach ($kvp in $this.Errors.GetEnumerator()) {
                $type = $kvp.Key
                $total = $kvp.Value

                # Count recent errors
                $timestamps = $this.ErrorTimestamps[$type]
                $cutoff = $now.AddSeconds(-$this.WindowSeconds)
                $recentCount = 0
                foreach ($ts in $timestamps) {
                    if ($ts -ge $cutoff) { $recentCount++ }
                }

                $result.ByType[$type] = @{
                    Total = $total
                    Recent = $recentCount
                    Rate = $recentCount / [double]$this.WindowSeconds
                }

                $result.TotalErrors += $total
                $recentErrors += $recentCount
            }

            $result.ErrorRate = $recentErrors / [double]$this.WindowSeconds
            return $result
        } finally {
            [System.Threading.Monitor]::Exit($this.Lock)
        }
    }

    [void] Reset() {
        [System.Threading.Monitor]::Enter($this.Lock)
        try {
            $this.Errors.Clear()
            $this.ErrorTimestamps.Clear()
        } finally {
            [System.Threading.Monitor]::Exit($this.Lock)
        }
    }
}

class OperationTimer {
    # Context manager for timing operations

    hidden [LatencyTracker]$Tracker
    hidden [System.Diagnostics.Stopwatch]$Stopwatch
    hidden [DateTime]$StartTime

    OperationTimer([LatencyTracker]$tracker) {
        $this.Tracker = $tracker
        $this.Stopwatch = [System.Diagnostics.Stopwatch]::new()
        $this.Start()
    }

    [void] Start() {
        $this.StartTime = [DateTime]::UtcNow
        $this.Stopwatch.Restart()
    }

    [void] Stop() {
        $this.Stopwatch.Stop()
        $this.Tracker.Record($this.Stopwatch.ElapsedTicks * 1000000 / [System.Diagnostics.Stopwatch]::Frequency)
    }

    [long] GetElapsedMicroseconds() {
        return $this.Stopwatch.ElapsedTicks * 1000000 / [System.Diagnostics.Stopwatch]::Frequency
    }

    [double] GetElapsedMilliseconds() {
        return $this.Stopwatch.ElapsedMilliseconds
    }

    [timespan] GetElapsed() {
        return $this.Stopwatch.Elapsed
    }

    [void] Dispose() {
        if ($this.Stopwatch.IsRunning) {
            $this.Stop()
        }
    }
}

class MetricsCollector {
    # Central metrics collection point

    hidden [System.Collections.Generic.Dictionary[string,LatencyTracker]]$LatencyTrackers
    hidden [System.Collections.Generic.Dictionary[string,ThroughputCounter]]$ThroughputCounters
    hidden [System.Collections.Generic.Dictionary[string,ErrorCounter]]$ErrorCounters
    hidden [DateTime]$StartedAt

    MetricsCollector() {
        $this.LatencyTrackers = [System.Collections.Generic.Dictionary[string,LatencyTracker]]::new()
        $this.ThroughputCounters = [System.Collections.Generic.Dictionary[string,ThroughputCounter]]::new()
        $this.ErrorCounters = [System.Collections.Generic.Dictionary[string,ErrorCounter]]::new()
        $this.StartedAt = [DateTime]::UtcNow
    }

    [LatencyTracker] GetLatencyTracker([string]$name, [int]$maxSamples) {
        if (-not $this.LatencyTrackers.ContainsKey($name)) {
            $this.LatencyTrackers[$name] = [LatencyTracker]::new($name, $maxSamples)
        }
        return $this.LatencyTrackers[$name]
    }

    [ThroughputCounter] GetThroughputCounter([string]$name, [int]$windowSeconds) {
        if (-not $this.ThroughputCounters.ContainsKey($name)) {
            $this.ThroughputCounters[$name] = [ThroughputCounter]::new($name, $windowSeconds)
        }
        return $this.ThroughputCounters[$name]
    }

    [ErrorCounter] GetErrorCounter([string]$name, [int]$windowSeconds) {
        if (-not $this.ErrorCounters.ContainsKey($name)) {
            $this.ErrorCounters[$name] = [ErrorCounter]::new($windowSeconds)
        }
        return $this.ErrorCounters[$name]
    }

    [void] RecordLatency([string]$operationName, [long]$microseconds) {
        $tracker = $this.GetLatencyTracker($operationName, 10000)
        $tracker.Record($microseconds)
    }

    [void] IncrementThroughput([string]$operationName) {
        $counter = $this.GetThroughputCounter($operationName, 60)
        $counter.Increment()
    }

    [void] RecordError([string]$operationName, [string]$errorType) {
        $counter = $this.GetErrorCounter($operationName, 60)
        $counter.Record($errorType)
    }

    [hashtable] GetAllMetrics() {
        $result = [ordered]@{
            Timestamp = [DateTime]::UtcNow.ToString("o")
            Uptime = ([DateTime]::UtcNow - $this.StartedAt).TotalSeconds
            Latency = @{}
            Throughput = @{}
            Errors = @{}
        }

        foreach ($kvp in $this.LatencyTrackers.GetEnumerator()) {
            $result.Latency[$kvp.Key] = $kvp.Value.GetStatistics()
        }

        foreach ($kvp in $this.ThroughputCounters.GetEnumerator()) {
            $result.Throughput[$kvp.Key] = $kvp.Value.GetStatistics()
        }

        foreach ($kvp in $this.ErrorCounters.GetEnumerator()) {
            $result.Errors[$kvp.Key] = $kvp.Value.GetStatistics()
        }

        return $result
    }

    [string] GetMetricsJson() {
        return $this.GetAllMetrics() | ConvertTo-Json -Depth 10
    }

    [void] ExportMetrics([string]$filePath) {
        $this.GetMetricsJson() | Out-File -FilePath $filePath -Encoding UTF8
    }

    [void] Reset() {
        foreach ($tracker in $this.LatencyTrackers.Values) {
            $tracker.Reset()
        }
        foreach ($counter in $this.ThroughputCounters.Values) {
            $counter.Reset()
        }
        foreach ($counter in $this.ErrorCounters.Values) {
            $counter.Reset()
        }
    }
}

# ============================================================================
# GLOBAL SINGLETON
# ============================================================================

$Script:MetricsCollector = $null
$Script:IsInitialized = $false

function Initialize-Metrics {
    <#
    .SYNOPSIS
    Initialize the global metrics collector.
    #>
    if ($Script:IsInitialized) {
        return
    }

    $Script:MetricsCollector = [MetricsCollector]::new()
    $Script:IsInitialized = $true
}

function Get-LatencyTracker {
    <#
    .SYNOPSIS
    Get or create a latency tracker.

    .PARAMETER Name
    Name of the tracker.

    .PARAMETER MaxSamples
    Maximum number of samples to retain. Default is 10000.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [int]$MaxSamples = 10000
    )

    if (-not $Script:IsInitialized) {
        Initialize-Metrics
    }

    return $Script:MetricsCollector.GetLatencyTracker($Name, $MaxSamples)
}

function Get-ThroughputCounter {
    <#
    .SYNOPSIS
    Get or create a throughput counter.

    .PARAMETER Name
    Name of the counter.

    .PARAMETER WindowSeconds
    Time window in seconds. Default is 60.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [int]$WindowSeconds = 60
    )

    if (-not $Script:IsInitialized) {
        Initialize-Metrics
    }

    return $Script:MetricsCollector.GetThroughputCounter($Name, $WindowSeconds)
}

function Get-ErrorCounter {
    <#
    .SYNOPSIS
    Get or create an error counter.

    .PARAMETER Name
    Name of the counter.

    .PARAMETER WindowSeconds
    Time window in seconds. Default is 60.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [int]$WindowSeconds = 60
    )

    if (-not $Script:IsInitialized) {
        Initialize-Metrics
    }

    return $Script:MetricsCollector.GetErrorCounter($Name, $WindowSeconds)
}

function Get-AllMetrics {
    <#
    .SYNOPSIS
    Get all collected metrics as a hashtable.
    #>
    if (-not $Script:IsInitialized) {
        Initialize-Metrics
    }

    return $Script:MetricsCollector.GetAllMetrics()
}

function Export-Metrics {
    <#
    .SYNOPSIS
    Export metrics to a JSON file.

    .PARAMETER Path
    Output file path.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    if (-not $Script:IsInitialized) {
        Initialize-Metrics
    }

    $Script:MetricsCollector.ExportMetrics($Path)
}

function Reset-Metrics {
    <#
    .SYNOPSIS
    Reset all metrics counters.
    #>
    if ($Script:IsInitialized) {
        $Script:MetricsCollector.Reset()
    }
}

# ============================================================================
# TIMING HELPERS
# ============================================================================

function Measure-Operation {
    <#
    .SYNOPSIS
    Measure and record operation latency.

    .PARAMETER TrackerName
    Name of the latency tracker.

    .PARAMETER ScriptBlock
    Operation to measure.

    .EXAMPLE
    $result = Measure-Operation "MessageSend" { SendMessage $msg }
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TrackerName,

        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory=$false)]
        [int]$MaxSamples = 10000
    )

    $tracker = Get-LatencyTracker -Name $TrackerName -MaxSamples $MaxSamples
    $timer = [OperationTimer]::new($tracker)

    try {
        return & $ScriptBlock
    } finally {
        $timer.Dispose()
    }
}

function Start-OperationTimer {
    <#
    .SYNOPSIS
    Start an operation timer for manual timing.

    .PARAMETER TrackerName
    Name of the latency tracker.

    .OUTPUTS
    OperationTimer that should be disposed when done.

    .EXAMPLE
    $timer = Start-OperationTimer "DatabaseQuery"
    # ... do work ...
    $timer.Dispose()
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TrackerName,

        [Parameter(Mandatory=$false)]
        [int]$MaxSamples = 10000
    )

    $tracker = Get-LatencyTracker -Name $TrackerName -MaxSamples $MaxSamples
    return [OperationTimer]::new($tracker)
}
