# Debug EventLog scope issue
. .\.claude\scripts\v2-architecture\eventlog.ps1

Write-Host 'After sourcing eventlog.ps1:'
Write-Host "  EventLogFile exists: $(Test-Path variable:Script:EventLogFile)"
Write-Host "  EventLogMutex exists: $(Test-Path variable:Script:EventLogMutex)"
Write-Host "  SessionId exists: $(Test-Path variable:Script:SessionId)"

# Initialize
Write-Host 'Calling Initialize-EventLog...'
$testDir = '.claude/tests/test-data-debug2'
New-Item -ItemType Directory -Path $testDir -Force | Out-Null
Initialize-EventLog -SessionDir $testDir -SessionId 'debug-test'

Write-Host 'After Initialize-EventLog:'
Write-Host "  EventLogFile: $Script:EventLogFile"
Write-Host "  EventLogMutex: $Script:EventLogMutex"
Write-Host "  SessionId: $Script:SessionId"

# Try to get mutex
Write-Host 'Calling Get-EventLogMutexInternal...'
$mutex = Get-EventLogMutexInternal
Write-Host "  Mutex from Get-EventLogMutexInternal: $mutex"
Write-Host "  Mutex is null: $($mutex -eq $null)"

# Get sequence number
Write-Host 'Calling Get-NextSequenceNumber...'
try {
    $seq = Get-NextSequenceNumber
    Write-Host "  Sequence: $seq"
} catch {
    Write-Host "  Error getting sequence: $_"
    Write-Host "  Error at: $($_.InvocationInfo.ScriptLineNumber)"
}

# Try to write event - manual debugging
Write-Host 'Manual Write-Event steps...'

Write-Host '1. Check EventLogFile variable:'
Write-Host "   Script:EventLogFile exists: $(Test-Path variable:Script:EventLogFile)"
Write-Host "   Script:EventLogFile value: $Script:EventLogFile"

Write-Host '2. Get mutex via Get-EventLogMutexInternal:'
$testMutex = Get-EventLogMutexInternal
Write-Host "   Mutex: $testMutex"
Write-Host "   Mutex is null: $($testMutex -eq $null)"

Write-Host '3. Try WaitOne on mutex:'
$acquired = $testMutex.WaitOne(5000)
Write-Host "   Acquired: $acquired"

try {
    Write-Host '4. Get sequence number:'
    $seq = Get-NextSequenceNumber
    Write-Host "   Sequence: $seq"

    Write-Host '5. Create event data and JSON:'
    $evtData = @{
        seq = $seq
        type = "TestEvent"
        timestamp = [DateTime]::UtcNow.ToString("o")
        data = @{ test = "value" }
    }
    $json = $evtData | ConvertTo-Json -Compress -Depth 10
    Write-Host "   JSON: $json"

    Write-Host '6. Write to file:'
    $stream = $null
    $writer = $null
    try {
        $stream = [System.IO.File]::Open(
            $Script:EventLogFile,
            [System.IO.FileMode]::Append,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None
        )
        Write-Host "   Stream opened: $stream"
        $writer = [System.IO.StreamWriter]::new($stream, [System.Text.Encoding]::UTF8)
        Write-Host "   Writer created: $writer"
        $writer.WriteLine($json)
        Write-Host "   Line written"
    } finally {
        Write-Host "   Disposing writer and stream..."
        if ($writer -ne $null) { $writer.Dispose() }
        if ($stream -ne $null) { $stream.Dispose() }
    }

    Write-Host "7. Release mutex:"
    $testMutex.ReleaseMutex()
    Write-Host "   Mutex released"

    Write-Host "SUCCESS! Sequence: $seq"
} catch {
    Write-Host "ERROR in manual Write-Event: $_"
    Write-Host "   at: $($_.InvocationInfo.ScriptLineNumber)"
} finally {
    if ($acquired) {
        try {
            $testMutex.ReleaseMutex()
        } catch {
            Write-Host "   (mutex already released or error releasing)"
        }
    }
}
