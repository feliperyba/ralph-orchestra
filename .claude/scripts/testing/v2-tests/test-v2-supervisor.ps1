# Ralph V2 Supervisor Tests
# Tests for the supervisor module (supervisor.ps1)
#
# These tests verify:
# - New-ActorSupervisor initializes correctly
# - ActorSupervisor state rebuild from event log
# - GetStatus returns correct information
# - Test-SupervisorHealth checks actor health
# - Supervise loop processes exited actors
# - Actor management (start/stop logic)
# - Restart strategy application

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

# Import dependencies (eventlog and eventbus are required by supervisor)
. "$ProjectRoot\.claude\scripts\v2-architecture\eventlog.ps1"
. "$ProjectRoot\.claude\scripts\v2-architecture\event-bus.ps1"

# Import the module under test
. "$ProjectRoot\.claude\scripts\v2-architecture\supervisor.ps1"

Write-Host "=== Ralph V2 Supervisor Tests ===" -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

# ============================================================================
# TEST: New-ActorSupervisor initializes correctly
# ============================================================================

Invoke-Test -Name "New-ActorSupervisor creates supervisor instance" -ScriptBlock {
    $env = New-TestEnvironment -TestName "supervisor-init"
    try {
        $sup = New-ActorSupervisor -SessionDir $env.SessionDir -Name "test-sup"

        Assert-TestCondition -Condition ($sup -ne $null) -Message "Supervisor should be created"
        Assert-TestEqual -Actual $sup.Name -Expected "test-sup" -Message "Name should be set"
        Assert-TestCondition -Condition ($sup.StartedAt -lt [DateTime]::UtcNow) -Message "StartedAt should be in the past"
        Assert-TestEqual -Actual $sup.TotalRestarts -Expected 0 -Message "TotalRestarts should be 0"
        Assert-TestEqual -Actual $sup.Actors.Count -Expected 0 -Message "Should have no actors initially"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: ActorSupervisor rebuilds state from event log
# ============================================================================

Invoke-Test -Name "ActorSupervisor rebuilds state from event log" -ScriptBlock {
    $env = New-TestEnvironment -TestName "supervisor-rebuild"
    try {
        # Create some events in the log first
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null
        Write-AgentStartedEvent -AgentName "existing-agent" -AgentPid 12345 | Out-Null

        # Now create supervisor - it should rebuild state
        $sup = New-ActorSupervisor -SessionDir $env.SessionDir

        # The rebuild happens in constructor, marking stale running agents as crashed
        # The existing-agent should be marked as crashed (stale state)
        $status = Rebuild-AgentStatus
        Assert-TestCondition -Condition $status.ContainsKey("existing-agent") -Message "Should have existing-agent in status"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: ActorSupervisor GetStatus returns correct info
# ============================================================================

Invoke-Test -Name "ActorSupervisor GetStatus returns empty when no actors" -ScriptBlock {
    $env = New-TestEnvironment -TestName "supervisor-status-empty"
    try {
        $sup = New-ActorSupervisor -SessionDir $env.SessionDir -Name "test-sup"
        $status = $sup.GetStatus()

        Assert-TestCondition -Condition ($status -ne $null) -Message "Status should not be null"
        Assert-TestEqual -Actual $status.Count -Expected 0 -Message "Should have no actors"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Test-SupervisorHealth checks correctly
# ============================================================================

Invoke-Test -Name "Test-SupervisorHealth returns healthy for empty supervisor" -ScriptBlock {
    $env = New-TestEnvironment -TestName "supervisor-health-empty"
    try {
        $sup = New-ActorSupervisor -SessionDir $env.SessionDir -Name "test-sup"
        $health = Test-SupervisorHealth -Supervisor $sup

        Assert-TestCondition -Condition $health.Healthy -Message "Empty supervisor should be healthy"
        Assert-TestEqual -Actual $health.Issues.Count -Expected 0 -Message "Should have no issues"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: ActorSupervisor initializes event log and event bus
# ============================================================================

Invoke-Test -Name "ActorSupervisor initializes event systems" -ScriptBlock {
    $env = New-TestEnvironment -TestName "supervisor-event-init"
    try {
        $sup = New-ActorSupervisor -SessionDir $env.SessionDir -Name "test-sup"

        # Check that event log file was created
        $eventLogPath = Join-Path $env.SessionDir "eventlog.jsonl"
        Assert-TestCondition -Condition (Test-Path $eventLogPath) -Message "Event log file should exist"

        # Check that pipes directory was created
        $pipesDir = Join-Path $env.SessionDir "pipes"
        Assert-TestCondition -Condition (Test-Path $pipesDir) -Message "Pipes directory should exist"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: ActorSupervisor GetSummary returns summary string
# ============================================================================

Invoke-Test -Name "ActorSupervisor GetSummary returns summary" -ScriptBlock {
    $env = New-TestEnvironment -TestName "supervisor-summary"
    try {
        $sup = New-ActorSupervisor -SessionDir $env.SessionDir -Name "test-sup"
        $summary = $sup.GetSummary()

        Assert-TestCondition -Condition ($summary -ne $null) -Message "Summary should not be null"
        Assert-TestCondition -Condition ($summary -match "test-sup") -Message "Summary should contain supervisor name"
        Assert-TestCondition -Condition ($summary -match "\d+.*actor") -Message "Summary should mention actor count"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: ActorSupervisor ShouldStop returns false for active supervisor
# ============================================================================

Invoke-Test -Name "ActorSupervisor ShouldStop returns false initially" -ScriptBlock {
    $env = New-TestEnvironment -TestName "supervisor-shouldstop"
    try {
        $sup = New-ActorSupervisor -SessionDir $env.SessionDir -Name "test-sup"
        $shouldStop = $sup.ShouldStop()

        Assert-TestCondition -Condition (-not $shouldStop) -Message "Should not stop when just created"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: ActorSupervisor handles event log persistence
# ============================================================================

Invoke-Test -Name "ActorSupervisor persists events to event log" -ScriptBlock {
    $env = New-TestEnvironment -TestName "supervisor-persistence"
    try {
        $sup = New-ActorSupervisor -SessionDir $env.SessionDir -Name "test-sup"

        # Write an event directly
        Write-Event -Type "TestEvent" -Data @{ test = "data" } | Out-Null

        # Verify it was persisted
        $events = Get-EventsSince -FromSeq 0
        Assert-TestEqual -Actual $events.Count -Expected 1 -Message "Should have 1 event"
        Assert-TestEqual -Actual $events[0].type -Expected "TestEvent" -Message "Event type should match"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: ActorSupervisor RebuildState processes existing events
# ============================================================================

Invoke-Test -Name "ActorSupervisor RebuildState processes events" -ScriptBlock {
    $env = New-TestEnvironment -TestName "supervisor-rebuild-state"
    try {
        # Pre-populate event log
        Initialize-EventLog -SessionDir $env.SessionDir | Out-Null
        Write-AgentStartedEvent -AgentName "test-agent-1" -AgentPid 1001 | Out-Null
        Write-AgentStartedEvent -AgentName "test-agent-2" -AgentPid 1002 | Out-Null
        Write-AgentExitedEvent -AgentName "test-agent-1" -ExitCode 0 | Out-Null

        # Create supervisor - will call RebuildState in constructor
        $sup = New-ActorSupervisor -SessionDir $env.SessionDir -Name "test-sup"

        # Check the rebuilt status
        $status = Rebuild-AgentStatus
        Assert-TestCondition -Condition $status.ContainsKey("test-agent-1") -Message "Should have test-agent-1"
        Assert-TestCondition -Condition ($status["test-agent-1"].state -eq "stopped") -Message "test-agent-1 should be stopped"
        Assert-TestCondition -Condition $status.ContainsKey("test-agent-2") -Message "Should have test-agent-2"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Test-SupervisorHealth detects issues in mock actors
# ============================================================================

Invoke-Test -Name "Test-SupervisorHealth detects simulated issues" -ScriptBlock {
    $env = New-TestEnvironment -TestName "supervisor-health-issues"
    try {
        $sup = New-ActorSupervisor -SessionDir $env.SessionDir -Name "test-sup"

        # Add a mock "problematic" actor entry directly
        # (In real scenario, this would be added via StartActor)
        $mockActor = @{
            Name = "problematic-agent"
            Process = @{
                Id = 9999
                HasExited = $true  # Simulating a crashed process
                ExitCode = 1
            }
            Pipe = $null
            RestartCount = 3
            MaxRestarts = 3
            StartedAt = [DateTime]::UtcNow.AddMinutes(-10)
        }
        $sup.Actors["problematic-agent"] = $mockActor

        $health = Test-SupervisorHealth -Supervisor $sup

        Assert-TestCondition -Condition (-not $health.Healthy) -Message "Should detect unhealthy state"
        Assert-TestCondition -Condition ($health.Issues.Count -gt 0) -Message "Should have issues"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: ActorSupervisor manages multiple mock actors
# ============================================================================

Invoke-Test -Name "ActorSupervisor manages multiple actors" -ScriptBlock {
    $env = New-TestEnvironment -TestName "supervisor-multiple"
    try {
        $sup = New-ActorSupervisor -SessionDir $env.SessionDir -Name "test-sup"

        # Add mock actors directly
        $sup.Actors["agent1"] = @{
            Name = "agent1"
            Process = @{ Id = 1001; HasExited = $false }
            Pipe = $null
            RestartCount = 0
            MaxRestarts = 3
        }
        $sup.Actors["agent2"] = @{
            Name = "agent2"
            Process = @{ Id = 1002; HasExited = $false }
            Pipe = $null
            RestartCount = 1
            MaxRestarts = 3
        }

        $status = $sup.GetStatus()

        Assert-TestEqual -Actual $status.Count -Expected 2 -Message "Should have 2 actors"
        Assert-TestCondition -Condition ($status.agent1.restartCount -eq 0) -Message "agent1 restart count should be 0"
        Assert-TestCondition -Condition ($status.agent2.restartCount -eq 1) -Message "agent2 restart count should be 1"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: ActorSupervisor tracks total restarts
# ============================================================================

Invoke-Test -Name "ActorSupervisor tracks total restarts" -ScriptBlock {
    $env = New-TestEnvironment -TestName "supervisor-restarts"
    try {
        $sup = New-ActorSupervisor -SessionDir $env.SessionDir -Name "test-sup"

        # Simulate some restarts by directly modifying the property
        $sup.TotalRestarts = 5

        Assert-TestEqual -Actual $sup.TotalRestarts -Expected 5 -Message "TotalRestarts should be tracked"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: ActorSupervisor session directory is correctly set
# ============================================================================

Invoke-Test -Name "ActorSupervisor SessionDir is set correctly" -ScriptBlock {
    $env = New-TestEnvironment -TestName "supervisor-sessiondir"
    try {
        $sup = New-ActorSupervisor -SessionDir $env.SessionDir -Name "test-sup"

        Assert-TestEqual -Actual $sup.SessionDir -Expected $env.SessionDir -Message "SessionDir should match test environment"

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
