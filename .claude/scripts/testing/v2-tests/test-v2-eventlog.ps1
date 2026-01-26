# Ralph V2 Event Log Tests
# Tests for the event sourcing foundation (eventlog.ps1)
#
# These tests verify:
# - Initialize-EventLog creates file
# - Write-Event increments sequence
# - Get-EventsSince filters correctly
# - Rebuild-AgentStatus produces correct state
# - Export-AgentStatus creates materialized view
# - Corrupted event log handling

$ErrorActionPreference = "Stop"

# Get the project root
$ProjectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
# Remove trailing .claude if present
if ($ProjectRoot.EndsWith('.claude')) {
    $ProjectRoot = Split-Path $ProjectRoot -Parent
}
Set-Location $ProjectRoot

# Import test helpers
. "$ProjectRoot\.claude\scripts\testing\test-helpers.ps1"

# Import the module under test
. "$ProjectRoot\.claude\scripts\v2-architecture\eventlog.ps1"

Write-Host "=== Ralph V2 Event Log Tests ===" -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

# ============================================================================
# TEST: Initialize-EventLog creates file
# ============================================================================

Invoke-Test -Name "Initialize-EventLog creates eventlog.jsonl" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventlog-init"
    try {
        $logPath = Initialize-EventLog -SessionDir $env.SessionDir

        Assert-TestCondition -Condition (Test-Path $logPath) -Message "Event log file should exist"
        Assert-TestEqual -Actual (Split-Path $logPath -Leaf) -Expected "eventlog.jsonl" -Message "File should be named eventlog.jsonl"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Write-Event increments sequence
# ============================================================================

Invoke-Test -Name "Write-Event increments sequence numbers" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventlog-sequence"
    try {
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null

        $seq1 = Write-Event -Type "TestEvent" -Data @{ test = "data1" }
        $seq2 = Write-Event -Type "TestEvent" -Data @{ test = "data2" }
        $seq3 = Write-Event -Type "TestEvent" -Data @{ test = "data3" }

        Assert-TestEqual -Actual $seq1 -Expected 1 -Message "First event sequence should be 1"
        Assert-TestEqual -Actual $seq2 -Expected 2 -Message "Second event sequence should be 2"
        Assert-TestEqual -Actual $seq3 -Expected 3 -Message "Third event sequence should be 3"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Get-EventsSince filters correctly
# ============================================================================

Invoke-Test -Name "Get-EventsSince filters by sequence number" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventlog-filter"
    try {
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null

        Write-Event -Type "TestEvent1" -Data @{ value = 1 } | Out-Null
        Write-Event -Type "TestEvent2" -Data @{ value = 2 } | Out-Null
        Write-Event -Type "TestEvent3" -Data @{ value = 3 } | Out-Null

        $eventsSince0 = Get-EventsSince -FromSeq 0
        $eventsSince1 = Get-EventsSince -FromSeq 1
        $eventsSince2 = Get-EventsSince -FromSeq 2

        Assert-TestCondition -Condition ($eventsSince0.Count -eq 3) -Message "Should get all 3 events from seq 0"
        Assert-TestCondition -Condition ($eventsSince1.Count -eq 2) -Message "Should get 2 events from seq 1"
        # FromSeq 2 means seq > 2, so only seq 3 is returned
        Assert-TestCondition -Condition ($eventsSince2.Count -eq 1) -Message "Should get 1 event from seq 2 (seq 3)"
        # Verify the returned event is seq 3
        if ($eventsSince2.Count -eq 1) {
            Assert-TestCondition -Condition ($eventsSince2[0].seq -eq 3) -Message "Event should be seq 3"
        }

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Get-EventsSince filters by type
# ============================================================================

Invoke-Test -Name "Get-EventsSince filters by event type" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventlog-type-filter"
    try {
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null

        Write-Event -Type "AgentStarted" -Data @{ agent = "pm" } | Out-Null
        Write-Event -Type "MessageSent" -Data @{ from = "pm" } | Out-Null
        Write-Event -Type "AgentStarted" -Data @{ agent = "dev" } | Out-Null

        $agentEvents = Get-EventsSince -FromSeq 0 -IncludeTypes @("AgentStarted")

        Assert-TestCondition -Condition ($agentEvents.Count -eq 2) -Message "Should get 2 AgentStarted events"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Rebuild-AgentStatus produces correct state
# ============================================================================

Invoke-Test -Name "Rebuild-AgentStatus builds agent state from events" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventlog-rebuild"
    try {
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null

        # Simulate agent lifecycle
        Write-AgentStartedEvent -AgentName "pm" -AgentPid 1001 | Out-Null
        Write-AgentStartedEvent -AgentName "developer" -AgentPid 1002 | Out-Null
        Write-AgentExitedEvent -AgentName "pm" -ExitCode 0 | Out-Null

        $status = Rebuild-AgentStatus

        Assert-TestCondition -Condition $status.ContainsKey("developer") -Message "Should have developer status"
        Assert-TestCondition -Condition ($status.developer.state -eq "running") -Message "Developer should be running"
        Assert-TestCondition -Condition ($status.pm.state -eq "stopped") -Message "PM should be stopped"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Export-AgentStatus creates materialized view
# ============================================================================

Invoke-Test -Name "Export-AgentStatus creates JSON file" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventlog-export"
    try {
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null

        Write-AgentStartedEvent -AgentName "test-agent" -AgentPid 9999 | Out-Null

        $statusPath = Join-Path $env.SessionDir "agent-status.json"
        Export-AgentStatus -OutputPath $statusPath

        Assert-TestCondition -Condition (Test-Path $statusPath) -Message "Status file should exist"

        $content = Get-Content $statusPath -Raw | ConvertFrom-Json
        # Check if the property exists using PSObject
        $hasTestAgent = $content.PSObject.Properties.Name -contains "test-agent"
        Assert-TestCondition -Condition $hasTestAgent -Message "Status should contain test-agent"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Corrupted event log handling
# ============================================================================

Invoke-Test -Name "Corrupted event log is handled gracefully" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventlog-corrupt"
    try {
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null

        # Write a valid event
        Write-Event -Type "ValidEvent" -Data @{ value = 1 } | Out-Null

        # Corrupt the file by appending invalid JSON
        $logPath = Get-EventLogPath
        Add-Content -Path $logPath -Value "{invalid json here" -Encoding UTF8

        # Write another valid event
        Write-Event -Type "ValidEvent2" -Data @{ value = 2 } | Out-Null

        # Should still be able to read valid events
        $events = Get-EventsSince -FromSeq 0

        Assert-TestCondition -Condition ($events.Count -ge 2) -Message "Should read at least 2 valid events"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Get-EventsByAgent filters by agent
# ============================================================================

Invoke-Test -Name "Get-EventsByAgent filters correctly" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventlog-agent-filter"
    try {
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null

        Write-AgentStartedEvent -AgentName "pm" -AgentPid 1001 | Out-Null
        Write-AgentStartedEvent -AgentName "developer" -AgentPid 1002 | Out-Null
        Write-MessageSentEvent -MessageId "msg-001" -From "pm" -To "developer" -MessageType "Query" | Out-Null

        $pmEvents = Get-EventsByAgent -AgentName "pm"

        Assert-TestCondition -Condition ($pmEvents.Count -ge 2) -Message "PM should have at least 2 events"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Get-EventStatistics returns correct stats
# ============================================================================

Invoke-Test -Name "Get-EventStatistics returns correct statistics" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventlog-stats"
    try {
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null

        Write-Event -Type "TypeA" -Data @{ x = 1 } | Out-Null
        Write-Event -Type "TypeA" -Data @{ x = 2 } | Out-Null
        Write-Event -Type "TypeB" -Data @{ y = 1 } | Out-Null

        $stats = Get-EventStatistics

        Assert-TestEqual -Actual $stats.TotalEvents -Expected 3 -Message "Should have 3 total events"
        Assert-TestEqual -Actual $stats.LastSequence -Expected 3 -Message "Last sequence should be 3"
        Assert-TestEqual -Actual $stats.EventTypes.TypeA -Expected 2 -Message "TypeA count should be 2"
        Assert-TestEqual -Actual $stats.EventTypes.TypeB -Expected 1 -Message "TypeB count should be 1"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Backup-EventLog creates backup
# ============================================================================

Invoke-Test -Name "Backup-EventLog creates backup file" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventlog-backup"
    try {
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null

        Write-Event -Type "TestEvent" -Data @{ value = 1 } | Out-Null

        $backupPath = Backup-EventLog

        Assert-TestCondition -Condition (Test-Path $backupPath) -Message "Backup file should exist"
        Assert-TestCondition -Condition $backupPath.EndsWith(".bak") -Message "Backup should have .bak extension"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Empty event log handling
# ============================================================================

Invoke-Test -Name "Empty event log is handled correctly" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventlog-empty"
    try {
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null

        $events = Get-EventsSince -FromSeq 0
        $status = Rebuild-AgentStatus

        Assert-TestEqual -Actual $events.Count -Expected 0 -Message "Empty log should have 0 events"
        Assert-TestEqual -Actual $status.Count -Expected 0 -Message "Empty log should have empty status"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Get-AgentStatusCached uses cache
# ============================================================================

Invoke-Test -Name "Get-AgentStatusCached uses materialized view" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventlog-cache"
    try {
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null

        Write-AgentStartedEvent -AgentName "cached-agent" -AgentPid 5555 | Out-Null

        # Export to create cache
        Export-AgentStatus

        # Get from cache (should be faster than rebuild)
        $status1 = Get-AgentStatusCached
        $status2 = Get-AgentStatusCached

        Assert-TestCondition -Condition $status1.ContainsKey("cached-agent") -Message "Cached status should contain agent"
        # Access pid property using string indexing to avoid $PID automatic variable conflict
        $agentStatus = $status1."cached-agent"
        Assert-TestEqual -Actual $agentStatus.'pid' -Expected 5555 -Message "PID should match"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: AgentCrashed vs AgentExited event types
# ============================================================================

Invoke-Test -Name "AgentCrashed event for non-zero exit codes" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventlog-crash"
    try {
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null

        # Exit code 0 = AgentExited
        Write-AgentExitedEvent -AgentName "agent1" -ExitCode 0 | Out-Null

        # Exit code 42 = AgentExited (graceful shutdown)
        Write-AgentExitedEvent -AgentName "agent2" -ExitCode 42 | Out-Null

        # Exit code 1 = AgentCrashed
        Write-AgentExitedEvent -AgentName "agent3" -ExitCode 1 | Out-Null

        $events = Get-EventsSince -FromSeq 0
        $exitedEvents = @($events | Where-Object { $_.type -eq "AgentExited" })
        $crashedEvents = @($events | Where-Object { $_.type -eq "AgentCrashed" })

        Assert-TestEqual -Actual $exitedEvents.Count -Expected 2 -Message "Should have 2 AgentExited events"
        Assert-TestEqual -Actual $crashedEvents.Count -Expected 1 -Message "Should have 1 AgentCrashed event"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# RESULTS
# ============================================================================

Write-Host ""
$allPassed = Show-TestResults

# Clean up any orphaned test environments
Remove-AllTestEnvironments

exit $(if ($allPassed) { 0 } else { 1 })
