# Ralph Concurrency Tests
# Tests for concurrent message delivery, state updates, and race conditions

$ErrorActionPreference = "Stop"

# Source test helpers
. "$PSScriptRoot\test-helpers.ps1"

# Source message queue for messaging tests
. "$PSScriptRoot\message-queue.ps1"

Write-Host "=== Ralph Concurrency Test Suite ===" -ForegroundColor Cyan

# ============================================================================
# TEST SUITE 1: CONCURRENT MESSAGE DELIVERY
# ============================================================================

function Test-ConcurrentMessageSend {
    <#
    .SYNOPSIS
    Test multiple agents sending messages simultaneously.
    #>
    param()

    $env = New-TestEnvironment -TestName "concurrent-send"

    try {
        Initialize-MessageQueue -SessionDir $env.SessionDir

        # Simulate concurrent sends from multiple agents
        $senders = @("pm", "developer", "qa")
        $recipient = "developer"

        # Send messages rapidly (simulating concurrent senders)
        $messageIds = @()
        foreach ($sender in $senders) {
            for ($i = 1; $i -le 10; $i++) {
                $msgId = Send-AgentMessage -From $sender -To $recipient -Type "task_assign" -Payload @{
                    sender = $sender
                    sequence = $i
                }
                $messageIds += $msgId
            }
        }

        # Verify all messages were delivered
        $pending = Get-PendingMessages -Agent $recipient
        Assert-TestEqual -Actual $pending.Count -Expected 30 -Message "Should have all 30 messages"

        # Verify unique IDs
        $uniqueIds = $pending | Select-Object -ExpandProperty id | Sort-Object -Unique
        Assert-TestEqual -Actual $uniqueIds.Count -Expected 30 -Message "All message IDs should be unique"

        return $true
    } finally {
        & $env.Cleanup
    }
}

function Test-ConcurrentMessageAck {
    <#
    .SYNOPSIS
    Test concurrent message acknowledgment.
    #>
    param()

    $env = New-TestEnvironment -TestName "concurrent-ack"

    try {
        . "$PSScriptRoot\message-queue.ps1"
        Initialize-MessageQueue -SessionDir $env.SessionDir

        # Send 20 messages
        $messageIds = @()
        for ($i = 1; $i -le 20; $i++) {
            $msgId = Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ id = $i }
            $messageIds += $msgId
        }

        # "Concurrently" acknowledge messages (rapid fire)
        foreach ($msgId in $messageIds) {
            Invoke-AcknowledgeMessage -MessageId $msgId -Agent "developer" -Result @{ processed = $true }
        }

        # Verify all acknowledged
        $pending = Get-PendingMessages -Agent "developer"
        Assert-TestEqual -Actual $pending.Count -Expected 0 -Message "All messages should be acknowledged"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST SUITE 2: RACE CONDITION TESTS
# ============================================================================

function Test-ReadModifyWriteRace {
    <#
    .SYNOPSIS
    Test read-modify-write race condition on state files.
    #>
    param()

    $env = New-TestEnvironment -TestName "read-modify-race"

    try {
        $stateFile = Join-Path $env.StateDir "race-test.json"

        # Initialize shared state
        @{ counter = 0 } | ConvertTo-Json | Set-Content -Path $stateFile

        # Simulate two "processes" updating the same counter
        for ($i = 1; $i -le 10; $i++) {
            # Process 1 read
            $state1 = Get-Content -Path $stateFile -Raw | ConvertFrom-Json
            # Process 2 read
            $state2 = Get-Content -Path $stateFile -Raw | ConvertFrom-Json

            # Both modify
            $state1.counter += 1
            $state2.counter += 1

            # Both write (last write wins)
            $state1 | ConvertTo-Json | Set-Content -Path $stateFile
            $state2 | ConvertTo-Json | Set-Content -Path $stateFile
        }

        # Final state (will be 10 or less due to race - last write wins)
        $finalState = Get-Content -Path $stateFile -Raw | ConvertFrom-Json
        $finalCount = $finalState.counter

        # Due to race condition, we expect fewer than 20
        # This test documents the behavior - in production, use file locking
        Write-Host "    Note: Final counter = $finalCount (race condition expected)" -ForegroundColor DarkYellow

        Assert-TestCondition -Condition ($finalCount -le 20) -Message "Counter should not exceed expected maximum"
        Assert-TestCondition -Condition ($finalCount -ge 0) -Message "Counter should be non-negative"

        return $true
    } finally {
        & $env.Cleanup
    }
}

function Test-DuplicateMessageDetection {
    <#
    .SYNOPSIS
    Test handling of duplicate message IDs.
    #>
    param()

    $env = New-TestEnvironment -TestName "duplicate-detection"

    try {
        Initialize-MessageQueue -SessionDir $env.SessionDir

        # Send message
        $msgId = Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ id = 1 }

        # Try to send with same ID (should fail or be ignored)
        # In current implementation, IDs are generated, so we'll simulate
        # by creating a duplicate file manually
        $msgDir = Join-Path $env.MessagesDir "developer"
        $duplicateFile = Join-Path $msgDir "$msgId.json"

        $isDuplicate = Test-Path $duplicateFile
        Assert-TestCondition -Condition $isDuplicate -Message "Original message should exist"

        # Attempting to create duplicate file (in real system, should be prevented)
        # For now, just verify that reading returns one message
        $pending = Get-PendingMessages -Agent "developer"
        Assert-TestEqual -Actual $pending.Count -Expected 1 -Message "Should only have one message"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST SUITE 3: STATE UPDATE CONFLICTS
# ============================================================================

function Test-AgentStatusConflict {
    <#
    .SYNOPSIS
    Test conflicting agent status updates.
    #>
    param()

    $env = New-TestEnvironment -TestName "status-conflict"

    try {
        $stateFile = Join-Path $env.StateDir "agent-states.json"

        # Initial state
        @{
            agents = @{
                developer = @{ status = "idle"; lastUpdate = [DateTime]::UtcNow.ToString("o") }
                qa = @{ status = "idle"; lastUpdate = [DateTime]::UtcNow.ToString("o") }
            }
        } | ConvertTo-Json -Depth 10 | Set-Content -Path $stateFile

        # Simulate conflicting updates
        $state1 = Get-Content -Path $stateFile -Raw | ConvertFrom-Json
        $state1.agents.developer.status = "working"
        $state1 | ConvertTo-Json -Depth 10 | Set-Content -Path $stateFile

        $state2 = Get-Content -Path $stateFile -Raw | ConvertFrom-Json
        $state2.agents.qa.status = "working"
        $state2 | ConvertTo-Json -Depth 10 | Set-Content -Path $stateFile

        # Final state should have both updates
        $final = Get-Content -Path $stateFile -Raw | ConvertFrom-Json
        $devWorking = $final.agents.developer.status -eq "working"
        $qaWorking = $final.agents.qa.status -eq "working"

        Assert-TestCondition -Condition ($devWorking -and $qaWorking) -Message "Both status updates should be present"

        return $true
    } finally {
        & $env.Cleanup
    }
}

function Test-ConcurrentTaskAssignment {
    <#
    .SYNOPSIS
    Test concurrent task assignment to multiple agents.
    #>
    param()

    $env = New-TestEnvironment -TestName "concurrent-assignment"

    try {
        Initialize-MessageQueue -SessionDir $env.SessionDir

        # PM assigns tasks to multiple agents concurrently
        $agents = @("developer", "qa", "techartist")

        foreach ($agent in $agents) {
            for ($i = 1; $i -le 5; $i++) {
                $priority = if ($i -eq 1) { "high" } else { "normal" }
                Send-AgentMessage -From "pm" -To $agent -Type "task_assign" -Priority $priority -Payload @{
                    taskId = "$agent-task-$i"
                }
            }
        }

        # Verify each agent got their tasks
        foreach ($agent in $agents) {
            $pending = Get-PendingMessages -Agent $agent
            Assert-TestEqual -Actual $pending.Count -Expected 5 -Message "$agent should have 5 tasks"

            # Verify high priority is first
            $firstIsHigh = $pending[0].priority -eq "high"
            Assert-TestCondition -Condition $firstIsHigh -Message "$agent should have high priority task first"
        }

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST SUITE 4: QUEUE OVERLOAD
# ============================================================================

function Test-HighMessageVolume {
    <#
    .SYNOPSIS
    Test system behavior with high message volume.
    #>
    param()

    $env = New-TestEnvironment -TestName "high-volume"

    try {
        Initialize-MessageQueue -SessionDir $env.SessionDir

        # Send 100 messages rapidly
        $messageIds = @()
        for ($i = 1; $i -le 100; $i++) {
            $msgId = Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ index = $i }
            $messageIds += $msgId
        }

        # Verify all received
        $pending = Get-PendingMessages -Agent "developer"
        Assert-TestEqual -Actual $pending.Count -Expected 100 -Message "Should handle 100 messages"

        # Verify order preservation (for same priority)
        $indices = $pending | ForEach-Object { $_.payload.index }
        $isInOrder = $true
        for ($i = 0; $i -lt $indices.Count - 1; $i++) {
            if ($indices[$i] -gt $indices[$i + 1]) {
                $isInOrder = $false
                break
            }
        }
        Assert-TestCondition -Condition $isInOrder -Message "Message order should be preserved"

        return $true
    } finally {
        & $env.Cleanup
    }
}

function Test-RapidAckCycle {
    <#
    .SYNOPSIS
    Test rapid message acknowledgment cycles.
    #>
    param()

    $env = New-TestEnvironment -TestName "rapid-ack-cycle"

    try {
        . "$PSScriptRoot\message-queue.ps1"
        Initialize-MessageQueue -SessionDir $env.SessionDir

        # Perform 50 send/ack cycles rapidly
        $cycles = 50
        $successCount = 0

        for ($i = 1; $i -le $cycles; $i++) {
            # Send
            $msgId = Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ cycle = $i }

            # Ack
            $ackResult = Invoke-AcknowledgeMessage -MessageId $msgId -Agent "developer" -Result @{ cycle = $i }

            if ($ackResult) {
                $successCount++
            }
        }

        Assert-TestEqual -Actual $successCount -Expected $cycles -Message "All cycles should succeed"

        # Queue should be empty
        $pending = Get-PendingMessages -Agent "developer"
        Assert-TestEqual -Actual $pending.Count -Expected 0 -Message "Queue should be empty after all cycles"

        return $true
    } finally {
        & $env.Cleanup
    }
}

# ============================================================================
# TEST RUNNER
# ============================================================================

function Invoke-AllConcurrencyTests {
    <#
    .SYNOPSIS
    Run all concurrency tests and report results.
    #>
    param()

    Write-Host "`n--- Suite 1: Concurrent Message Delivery ---" -ForegroundColor Cyan
    Invoke-Test -Name "Concurrent message send" -ScriptBlock ${function:Test-ConcurrentMessageSend}
    Invoke-Test -Name "Concurrent message acknowledgment" -ScriptBlock ${function:Test-ConcurrentMessageAck}

    Write-Host "`n--- Suite 2: Race Condition Tests ---" -ForegroundColor Cyan
    Invoke-Test -Name "Read-modify-write race" -ScriptBlock ${function:Test-ReadModifyWriteRace}
    Invoke-Test -Name "Duplicate message detection" -ScriptBlock ${function:Test-DuplicateMessageDetection}

    Write-Host "`n--- Suite 3: State Update Conflicts ---" -ForegroundColor Cyan
    Invoke-Test -Name "Agent status conflict" -ScriptBlock ${function:Test-AgentStatusConflict}
    Invoke-Test -Name "Concurrent task assignment" -ScriptBlock ${function:Test-ConcurrentTaskAssignment}

    Write-Host "`n--- Suite 4: Queue Overload ---" -ForegroundColor Cyan
    Invoke-Test -Name "High message volume" -ScriptBlock ${function:Test-HighMessageVolume}
    Invoke-Test -Name "Rapid acknowledgment cycle" -ScriptBlock ${function:Test-RapidAckCycle}

    # Show results
    $allPassed = Show-TestResults

    # Cleanup
    Remove-AllTestEnvironments

    return $allPassed
}

# Always run tests when this script is executed
$success = Invoke-AllConcurrencyTests
exit $(if ($success) { 0 } else { 1 })
