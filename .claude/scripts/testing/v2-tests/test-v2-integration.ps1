# Ralph V2 Integration Tests
# End-to-end tests for the V2 architecture
#
# These tests verify:
# - Full system initialization (eventlog + eventbus + supervisor)
# - Event persistence across component boundaries
# - Agent status tracking end-to-end
# - Message protocol integration
# - State recovery after simulated crashes

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

# Import all V2 modules
. "$ProjectRoot\.claude\scripts\v2-architecture\eventlog.ps1"
. "$ProjectRoot\.claude\scripts\v2-architecture\event-bus.ps1"
. "$ProjectRoot\.claude\scripts\v2-architecture\supervisor.ps1"
. "$ProjectRoot\.claude\scripts\v2-architecture\message-protocol.ps1"

Write-Host "=== Ralph V2 Integration Tests ===" -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

# ============================================================================
# TEST: Full system initialization
# ============================================================================

Invoke-Test -Name "Full V2 system initializes correctly" -ScriptBlock {
    $env = New-TestEnvironment -TestName "integration-init"
    try {
        # Initialize event log
        $eventLogPath = Initialize-EventLog -SessionDir $env.SessionDir

        # Initialize event bus
        $eventBusInit = Initialize-EventBus -SessionDir $env.SessionDir

        # Create supervisor
        $sup = New-ActorSupervisor -SessionDir $env.SessionDir -Name "integration-test"

        Assert-TestCondition -Condition (Test-Path $eventLogPath) -Message "Event log should exist"
        Assert-TestCondition -Condition $eventBusInit -Message "Event bus should initialize"
        Assert-TestCondition -Condition ($sup -ne $null) -Message "Supervisor should be created"

        # Verify directory structure
        $pipesDir = Join-Path $env.SessionDir "pipes"
        Assert-TestCondition -Condition (Test-Path $pipesDir) -Message "Pipes directory should exist"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Event log and agent status integration
# ============================================================================

Invoke-Test -Name "Agent lifecycle events produce correct status" -ScriptBlock {
    $env = New-TestEnvironment -TestName "integration-lifecycle"
    try {
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null

        # Simulate complete agent lifecycle
        $seq1 = Write-AgentStartedEvent -AgentName "lifecycle-agent" -AgentPid 5000
        $seq2 = Write-AgentExitedEvent -AgentName "lifecycle-agent" -ExitCode 0

        # Rebuild status from events
        $status = Rebuild-AgentStatus

        Assert-TestCondition -Condition $status.ContainsKey("lifecycle-agent") -Message "Should have agent in status"
        Assert-TestEqual -Actual $status."lifecycle-agent".state -Expected "stopped" -Message "Agent should be stopped"
        Assert-TestEqual -Actual $status."lifecycle-agent".'pid' -Expected 5000 -Message "PID should be recorded"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Message protocol creates valid messages
# ============================================================================

Invoke-Test -Name "Message protocol integration" -ScriptBlock {
    $env = New-TestEnvironment -TestName "integration-messages"
    try {
        # Create various message types using the protocol
        $workMsg = New-WorkAssignMessage -From "pm" -To "developer" -TaskId "task-001" -WorkType "implementation" -Title "Test task"
        $queryMsg = New-QueryMessage -From "developer" -To "pm" -Question "How do I implement this?"
        $responseMsg = New-ResponseMessage -From "pm" -To "developer" -Answer "Use the standard pattern" -InReplyTo $queryMsg.id

        # Validate messages
        Assert-TestCondition -Condition (Test-Message -Message $workMsg) -Message "Work message should be valid"
        Assert-TestCondition -Condition (Test-Message -Message $queryMsg) -Message "Query message should be valid"
        Assert-TestCondition -Condition (Test-Message -Message $responseMsg) -Message "Response message should be valid"

        # Test message serialization
        $json = $workMsg | ConvertTo-Json -Depth 10
        $restored = $json | ConvertFrom-Json

        Assert-TestEqual -Actual $restored.id -Expected $workMsg.id -Message "ID should survive round-trip"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Event statistics integration
# ============================================================================

Invoke-Test -Name "Event statistics across components" -ScriptBlock {
    $env = New-TestEnvironment -TestName "integration-stats"
    try {
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null

        # Write various event types
        Write-AgentStartedEvent -AgentName "agent1" -AgentPid 1001 | Out-Null
        Write-AgentStartedEvent -AgentName "agent2" -AgentPid 1002 | Out-Null
        Write-MessageSentEvent -MessageId "msg-001" -From "pm" -To "agent1" -MessageType "WorkAssign" | Out-Null
        Write-AgentExitedEvent -AgentName "agent1" -ExitCode 0 | Out-Null

        $stats = Get-EventStatistics

        Assert-TestEqual -Actual $stats.TotalEvents -Expected 4 -Message "Should have 4 total events"
        Assert-TestEqual -Actual $stats.LastSequence -Expected 4 -Message "Last sequence should be 4"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Materialized view export and import
# ============================================================================

Invoke-Test -Name "Materialized view round-trip" -ScriptBlock {
    $env = New-TestEnvironment -TestName "integration-materialized"
    try {
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null

        # Create some events
        Write-AgentStartedEvent -AgentName "test-agent" -AgentPid 7777 | Out-Null

        # Export to materialized view
        $statusPath = Join-Path $env.SessionDir "agent-status.json"
        Export-AgentStatus -OutputPath $statusPath

        # Read back and verify
        $content = Get-Content $statusPath -Raw | ConvertFrom-Json

        Assert-TestCondition -Condition ($content.PSObject.Properties.Name -contains "test-agent") -Message "Export should contain test-agent"

        # Verify cached read works
        $cached = Get-AgentStatusCached
        Assert-TestCondition -Condition $cached.ContainsKey("test-agent") -Message "Cached status should contain agent"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Event log backup functionality
# ============================================================================

Invoke-Test -Name "Event log backup integration" -ScriptBlock {
    $env = New-TestEnvironment -TestName "integration-backup"
    try {
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null

        # Add some events
        Write-Event -Type "TestEvent" -Data @{ value = 1 } | Out-Null
        Write-Event -Type "TestEvent" -Data @{ value = 2 } | Out-Null

        # Create backup
        $backupPath = Backup-EventLog

        Assert-TestCondition -Condition (Test-Path $backupPath) -Message "Backup file should exist"
        Assert-TestCondition -Condition $backupPath.EndsWith(".bak") -Message "Backup should have .bak extension"

        # Verify backup contains events
        $backupContent = Get-Content $backupPath
        Assert-TestEqual -Actual $backupContent.Count -Expected 2 -Message "Backup should contain 2 events"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Multiple agent coordination tracking
# ============================================================================

Invoke-Test -Name "Multiple agent coordination in event log" -ScriptBlock {
    $env = New-TestEnvironment -TestName "integration-multi-agent"
    try {
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null

        # Simulate multi-agent workflow
        Write-AgentStartedEvent -AgentName "pm" -AgentPid 2001 | Out-Null
        Write-AgentStartedEvent -AgentName "developer" -AgentPid 2002 | Out-Null
        Write-AgentStartedEvent -AgentName "qa" -AgentPid 2003 | Out-Null

        Write-MessageSentEvent -MessageId "msg-001" -From "pm" -To "developer" -MessageType "WorkAssign" | Out-Null
        Write-MessageSentEvent -MessageId "msg-002" -From "developer" -To "qa" -MessageType "ValidationRequest" | Out-Null

        # Get events by agent
        $pmEvents = Get-EventsByAgent -AgentName "pm"
        $devEvents = Get-EventsByAgent -AgentName "developer"
        $qaEvents = Get-EventsByAgent -AgentName "qa"

        Assert-TestCondition -Condition ($pmEvents.Count -ge 2) -Message "PM should have at least 2 events"
        Assert-TestCondition -Condition ($devEvents.Count -ge 2) -Message "Developer should have at least 2 events"
        Assert-TestCondition -Condition ($qaEvents.Count -ge 1) -Message "QA should have at least 1 event"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: State recovery after crash simulation
# ============================================================================

Invoke-Test -Name "State recovery from event log" -ScriptBlock {
    $env = New-TestEnvironment -TestName "integration-recovery"
    try {
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null

        # Create initial state
        Write-AgentStartedEvent -AgentName "recovery-agent" -AgentPid 3000 | Out-Null
        Write-AgentExitedEvent -AgentName "recovery-agent" -ExitCode 1 | Out-Null

        # Simulate crash recovery by creating new supervisor instance
        # (In real scenario, watchdog restart would read existing event log)
        $status = Rebuild-AgentStatus

        Assert-TestCondition -Condition $status.ContainsKey("recovery-agent") -Message "Agent should be in rebuilt status"
        Assert-TestEqual -Actual $status."recovery-agent".state -Expected "crashed" -Message "Agent should be marked as crashed"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Empty event log handling
# ============================================================================

Invoke-Test -Name "Empty event log integration" -ScriptBlock {
    $env = New-TestEnvironment -TestName "integration-empty"
    try {
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null

        # Don't write any events
        $events = Get-EventsSince -FromSeq 0
        $status = Rebuild-AgentStatus
        $stats = Get-EventStatistics

        Assert-TestEqual -Actual $events.Count -Expected 0 -Message "Should have no events"
        Assert-TestEqual -Actual $status.Count -Expected 0 -Message "Should have empty status"
        Assert-TestEqual -Actual $stats.TotalEvents -Expected 0 -Message "Statistics should show 0 events"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Legacy message type conversion
# ============================================================================

Invoke-Test -Name "Legacy message type conversion" -ScriptBlock {
    $env = New-TestEnvironment -TestName "integration-legacy"
    try {
        # Test that legacy types map correctly
        $mappings = @{
            "task_assign" = "WorkAssign"
            "task_complete" = "WorkComplete"
            "bug_report" = "ProblemReport"
            "question" = "Query"
            "answer" = "Response"
            "gdd_ready" = "DesignUpdate"
            "prd_reorganized" = "PlanUpdate"
        }

        foreach ($legacy in $mappings.Keys) {
            $expected = $mappings[$legacy]
            $actual = Convert-LegacyMessageType -LegacyType $legacy
            Assert-TestEqual -Actual $actual -Expected $expected -Message "$legacy should map to $expected"
        }

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: All 12 core message types are valid
# ============================================================================

Invoke-Test -Name "All 12 core message types are valid" -ScriptBlock {
    $env = New-TestEnvironment -TestName "integration-message-types"
    try {
        $validTypes = @(
            "AgentStatus", "WorkAssign", "WorkComplete", "WorkAbandoned", "WorkBlocked",
            "ProblemReport", "Query", "Response", "ValidationRequest", "ValidationResult",
            "DesignUpdate", "Retrospective", "PlanUpdate", "ResearchUpdate", "System", "Playtest"
        )

        foreach ($type in $validTypes) {
            $msg = New-Message -Type $type -From "pm" -To "developer" -Payload @{ test = "data" }
            $isValid = Test-Message -Message $msg
            Assert-TestCondition -Condition $isValid -Message "$type should create valid message"
        }

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Event sequence numbering consistency
# ============================================================================

Invoke-Test -Name "Event sequence numbering is consistent" -ScriptBlock {
    $env = New-TestEnvironment -TestName "integration-sequence"
    try {
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null

        # Write multiple events and verify sequence
        $seq1 = Write-Event -Type "Event1" -Data @{ x = 1 }
        $seq2 = Write-Event -Type "Event2" -Data @{ x = 2 }
        $seq3 = Write-Event -Type "Event3" -Data @{ x = 3 }

        Assert-TestEqual -Actual $seq1 -Expected 1 -Message "First sequence should be 1"
        Assert-TestEqual -Actual $seq2 -Expected 2 -Message "Second sequence should be 2"
        Assert-TestEqual -Actual $seq3 -Expected 3 -Message "Third sequence should be 3"

        # Verify events have correct sequence numbers
        $events = Get-EventsSince -FromSeq 0
        Assert-TestEqual -Actual $events[0].seq -Expected 1 -Message "Event 1 seq should be 1"
        Assert-TestEqual -Actual $events[1].seq -Expected 2 -Message "Event 2 seq should be 2"
        Assert-TestEqual -Actual $events[2].seq -Expected 3 -Message "Event 3 seq should be 3"

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
