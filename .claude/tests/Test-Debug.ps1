Describe "Debug Test" {
    It "Should debug event log" {
        $PSScriptRoot = "."
        . ".\.claude\scripts\v2-architecture\eventlog.ps1"

        $testDataDir = Join-Path $PSScriptRoot "test-data-debug"
        New-Item -ItemType Directory -Path $testDataDir -Force | Out-Null

        $logPath = Initialize-EventLog -SessionDir $testDataDir -SessionId "debug-test"
        Write-Host "LogPath: $logPath"
        Write-Host "EventLogFile: $Script:EventLogFile"
        Write-Host "File exists: $(Test-Path $Script:EventLogFile)"

        # Check Get-EventLogMutexInternal
        $mutex = Get-EventLogMutexInternal
        Write-Host "Mutex: $mutex"

        # Check Get-NextSequenceNumber
        try {
            $seq = Get-NextSequenceNumber
            Write-Host "Sequence: $seq"
        } catch {
            Write-Host "Failed to get sequence: $_"
        }
    }
}
