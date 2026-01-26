Describe "Scope Test" {
    It "Should initialize event log" {
        $PSScriptRoot = "."
        . ".\.claude\scripts\v2-architecture\eventlog.ps1"

        $testDataDir = Join-Path $PSScriptRoot "test-data-scope"
        New-Item -ItemType Directory -Path $testDataDir -Force | Out-Null

        $logPath = Initialize-EventLog -SessionDir $testDataDir -SessionId "scope-test"

        # Try to write an event
        Write-Event -Type "TestEvent" -Data @{ test = "value" } | Out-Null

        # Verify it was written
        $events = Get-EventsSince -FromSeq 0
        $events.Count | Should Be 1
    }
}
