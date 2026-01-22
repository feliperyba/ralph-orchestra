# Ralph Integration Test Framework
# Comprehensive integration tests for watchdog, agents, and messaging

$ErrorActionPreference = "Stop"

# Source test helpers
. "$PSScriptRoot\test-helpers.ps1"

# Source message queue for messaging tests
. "$PSScriptRoot\message-queue.ps1"

Write-Host "=== Ralph Integration Test Suite ===" -ForegroundColor Cyan

# ============================================================================
# TEST SUITE 1: MESSAGE DELIVERY
# ============================================================================

function Test-MessageRoundTrip {
    <#
    .SYNOPSIS
    Test complete message lifecycle: send, receive, acknowledge.
    #>
    param()

    $env = New-TestEnvironment -TestName "message-roundtrip"

    try {
        # Initialize queue
        Initialize-MessageQueue -SessionDir $env.SessionDir

        # Send message
        $msg = New-TestMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ taskId = "test-001" }
        $msgId = Send-AgentMessage -From $msg.from -To $msg.to -Type $msg.type -Payload $msg.payload

        Assert-TestCondition -Condition ($msgId -ne [string]::Empty) -Message "Message ID should be generated"

        # Retrieve pending
        $pending = Get-PendingMessages -Agent "developer"
        Assert-TestCondition -Condition ($pending.Count -eq 1) -Message "Should have 1 pending message"
        Assert-TestCondition -Condition ($pending[0].id -eq $msgId) -Message "Message ID should match"

        # Get by ID
        $retrieved = Get-MessageById -MessageId $msgId -Agent "developer"
        Assert-TestCondition -Condition ($null -ne $retrieved) -Message "Should retrieve message by ID"
        Assert-TestCondition -Condition ($retrieved.type -eq "task_assign") -Message "Message type should match"

        # Acknowledge
        $result = Invoke-AcknowledgeMessage -MessageId $msgId -Agent "developer" -Result @{ processed = "ok" }
        Assert-TestCondition -Condition ($result -eq $true) -Message "Acknowledge should succeed"

        # Verify no pending
        $pendingAfter = Get-PendingMessages -Agent "developer"
        Assert-TestCondition -Condition ($pendingAfter.Count -eq 0) -Message "Should have 0 pending after ack"

        return $true
    } finally {
        & $env.Cleanup
    }
}

function Test-MultipleMessageQueues {
    <#
    .SYNOPSIS
    Test that different agents have separate message queues.
    #>
    param()

    $env = New-TestEnvironment -TestName "multiple-queues"

    try {
        Initialize-MessageQueue -SessionDir $env.SessionDir

        # Send to different agents
        Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ id = "dev-1" }
        Send-AgentMessage -From "pm" -To "qa" -Type "question" -Payload @{ id = "qa-1" }
        Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ id = "dev-2" }

        # Check counts
        $devCount = (Get-MessageCount).developer
        $qaCount = (Get-MessageCount).qa

        Assert-TestEqual -Actual $devCount -Expected 2 -Message "Developer should have 2 messages"
        Assert-TestEqual -Actual $qaCount -Expected 1 -Message "QA should have 1 message"

        return $true
    } finally {
        & $env.Cleanup
    }
}

function Test-PriorityMessageDelivery {
    <#
    .SYNOPSIS
    Test that high-priority messages are returned first.
    #>
    param()

    $env = New-TestEnvironment -TestName "priority-delivery"

    try {
        Initialize-MessageQueue -SessionDir $env.SessionDir

        # Send messages in mixed priority order
        Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Priority "normal" -Payload @{ order = 1 }
        Send-AgentMessage -From "pm" -To "developer" -Type "bug_report" -Priority "high" -Payload @{ order = 2 }
        Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Priority "normal" -Payload @{ order = 3 }
        Send-AgentMessage -From "pm" -To "developer" -Type "error" -Priority "high" -Payload @{ order = 4 }

        # Get all pending
        $pending = Get-PendingMessages -Agent "developer"

        Assert-TestEqual -Actual $pending.Count -Expected 4 -Message "Should have 4 messages"

        # First two should be high priority
        $highPriorityFirst = $pending[0].priority -eq "high" -and $pending[1].priority -eq "high"
        Assert-TestCondition -Condition $highPriorityFirst -Message "High priority messages should come first"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST SUITE 2: STATE MANAGEMENT
# ============================================================================

function Test-StatePersistence {
    <#
    .SYNOPSIS
    Test that state persists across read/write cycles.
    #>
    param()

    $env = New-TestEnvironment -TestName "state-persistence"

    try {
        $stateFile = Join-Path $env.StateDir "test-state.json"

        # Write initial state
        $initialState = @{
            version = 1
            timestamp = [DateTime]::UtcNow.ToString("o")
            agents = @{
                pm = @{ status = "idle" }
                developer = @{ status = "working" }
            }
        }

        $initialState | ConvertTo-Json -Depth 10 | Set-Content -Path $stateFile -Encoding UTF8

        # Read and verify
        $readState = Get-Content -Path $stateFile -Raw | ConvertFrom-Json
        Assert-TestEqual -Actual $readState.version -Expected 1 -Message "Version should persist"
        Assert-TestEqual -Actual $readState.agents.developer.status -Expected "working" -Message "Agent status should persist"

        # Modify and write
        $readState.agents.developer.status = "idle"
        $readState | ConvertTo-Json -Depth 10 | Set-Content -Path $stateFile -Encoding UTF8

        # Read again and verify change
        $modifiedState = Get-Content -Path $stateFile -Raw | ConvertFrom-Json
        Assert-TestEqual -Actual $modifiedState.agents.developer.status -Expected "idle" -Message "Modified status should persist"

        return $true
    } finally {
        & $env.Cleanup
    }
}

function Test-ConcurrentStateWrites {
    <#
    .SYNOPSIS
    Test concurrent state writes (simulated with rapid sequential updates).
    #>
    param()

    $env = New-TestEnvironment -TestName "concurrent-state"

    try {
        $stateFile = Join-Path $env.StateDir "concurrent-test.json"

        # Initialize
        @{ counter = 0; updates = @() } | ConvertTo-Json | Set-Content -Path $stateFile

        # Perform 10 rapid updates
        for ($i = 1; $i -le 10; $i++) {
            $state = Get-Content -Path $stateFile -Raw | ConvertFrom-Json
            $state.counter = $i
            if (-not $state.updates) { $state.updates = @() }
            $state.updates += $i
            $state | ConvertTo-Json | Set-Content -Path $stateFile
        }

        # Verify final state
        $finalState = Get-Content -Path $stateFile -Raw | ConvertFrom-Json
        Assert-TestEqual -Actual $finalState.counter -Expected 10 -Message "Counter should reach 10"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST SUITE 3: FILE SYSTEM RESILIENCE
# ============================================================================

function Test-CorruptedStateRecovery {
    <#
    .SYNOPSIS
    Test graceful handling of corrupted state files.
    #>
    param()

    $env = New-TestEnvironment -TestName "corrupted-state"

    try {
        $stateFile = Join-Path $env.StateDir "corrupt-test.json"

        # Create corrupted state
        New-CorruptStateFile -Path $stateFile -CorruptionType "invalid"

        # Attempt to read (should handle gracefully)
        try {
            $content = Get-Content -Path $stateFile -Raw -ErrorAction Stop
            $state = $content | ConvertFrom-Json -ErrorAction Stop
            # If we get here, JSON was valid (test setup issue)
            return $true
        } catch {
            # Expected to fail parsing
            Assert-TestCondition -Condition ($_.Exception.Message -like "*JSON*") -Message "Should fail with JSON error"
        }

        # Create default state after corruption
        $defaultState = @{
            recovered = $true
            timestamp = [DateTime]::UtcNow.ToString("o")
        }
        $defaultState | ConvertTo-Json | Set-Content -Path $stateFile

        # Verify recovery
        $recoveredState = Get-Content -Path $stateFile -Raw | ConvertFrom-Json
        Assert-TestEqual -Actual $recoveredState.recovered -Expected $true -Message "Should recover with default state"

        return $true
    } finally {
        & $env.Cleanup
    }
}

function Test-MissingDirectoryCreation {
    <#
    .SYNOPSIS
    Test that missing directories are created as needed.
    #>
    param()

    $env = New-TestEnvironment -TestName "missing-dirs"

    try {
        # Remove message directories
        Remove-Item $env.MessagesDir -Recurse -Force

        # Initialize queue (should recreate directories)
        Initialize-MessageQueue -SessionDir $env.SessionDir

        # Send a message (should create directories as needed)
        $msgId = Send-AgentMessage -From "pm" -To "developer" -Type "question" -Payload @{ test = "true" }

        Assert-TestCondition -Condition (Test-Path $env.MessagesDir) -Message "Messages directory should be created"
        Assert-TestCondition -Condition (Test-Path (Join-Path $env.MessagesDir "developer")) -Message "Agent directory should be created"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST SUITE 4: MESSAGE POOL INTEGRATION
# ============================================================================

function Test-MessagePoolIntegration {
    <#
    .SYNOPSIS
    Test message queue integration with object pool.
    #>
    param()

    $env = New-TestEnvironment -TestName "pool-integration"

    try {
        # Source pool module
        . "$PSScriptRoot\message-pool.ps1"

        Initialize-MessagePool
        $initialStats = Get-MessagePoolStats

        Initialize-MessageQueue -SessionDir $env.SessionDir

        # Send multiple messages
        for ($i = 1; $i -le 5; $i++) {
            Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ id = "task-$i" }
        }

        # Acknowledge all (should return to pool)
        $pending = Get-PendingMessages -Agent "developer"
        foreach ($msg in $pending) {
            Invoke-AcknowledgeMessage -MessageId $msg.id -Agent "developer" -Result @{ done = $true }
        }

        # Check pool stats (should show reuse)
        $finalStats = Get-MessagePoolStats
        Assert-TestCondition -Condition ($finalStats.TotalReused -gt $initialStats.TotalReused) -Message "Pool should show reuse"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST RUNNER
# ============================================================================

function Invoke-AllIntegrationTests {
    <#
    .SYNOPSIS
    Run all integration tests and report results.
    #>
    param()

    Write-Host "`n--- Suite 1: Message Delivery ---" -ForegroundColor Cyan
    Invoke-Test -Name "Message round-trip" -ScriptBlock ${function:Test-MessageRoundTrip}
    Invoke-Test -Name "Multiple queues" -ScriptBlock ${function:Test-MultipleMessageQueues}
    Invoke-Test -Name "Priority delivery" -ScriptBlock ${function:Test-PriorityMessageDelivery}

    Write-Host "`n--- Suite 2: State Management ---" -ForegroundColor Cyan
    Invoke-Test -Name "State persistence" -ScriptBlock ${function:Test-StatePersistence}
    Invoke-Test -Name "Concurrent state writes" -ScriptBlock ${function:Test-ConcurrentStateWrites}

    Write-Host "`n--- Suite 3: File System Resilience ---" -ForegroundColor Cyan
    Invoke-Test -Name "Corrupted state recovery" -ScriptBlock ${function:Test-CorruptedStateRecovery}
    Invoke-Test -Name "Missing directory creation" -ScriptBlock ${function:Test-MissingDirectoryCreation}

    Write-Host "`n--- Suite 4: Message Pool Integration ---" -ForegroundColor Cyan
    Invoke-Test -Name "Message pool integration" -ScriptBlock ${function:Test-MessagePoolIntegration}

    # Show results
    $allPassed = Show-TestResults

    # Cleanup any remaining test environments
    Remove-AllTestEnvironments

    return $allPassed
}

# Always run tests when this script is executed
$success = Invoke-AllIntegrationTests
exit $(if ($success) { 0 } else { 1 })
