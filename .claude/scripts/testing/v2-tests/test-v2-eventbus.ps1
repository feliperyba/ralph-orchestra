# Ralph V2 Event Bus Tests
# Tests for the event bus (event-bus.ps1)
#
# These tests verify:
# - Initialize-EventBus creates pipes directory
# - Write-Undelivered creates queue entries
# - Get-UndeliveredMessages retrieves entries
# - Retry-AllUndelivered processes queue
# - Get-PipeStatus returns correct info
# - Close-Pipe cleanup
# - Get-ConnectedAgents filtering

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
. "$ProjectRoot\.claude\scripts\v2-architecture\event-bus.ps1"

Write-Host "=== Ralph V2 Event Bus Tests ===" -ForegroundColor Cyan
Write-Host ""

# Helper to reset event bus state between tests
function Reset-EventBusState {
    # Close all pipes
    foreach ($agentName in @($Script:EventBusPipes.Keys)) {
        try {
            Close-Pipe -AgentName $agentName
        } catch {
            # Ignore errors during cleanup
        }
    }
    # Clear the pipes hashtable
    $Script:EventBusPipes.Clear()
}

$testsPassed = 0
$testsFailed = 0

# ============================================================================
# TEST: Initialize-EventBus creates pipes directory
# ============================================================================

Invoke-Test -Name "Initialize-EventBus creates pipes directory" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventbus-init"
    try {
        $result = Initialize-EventBus -SessionDir $env.SessionDir

        $pipesDir = Join-Path $env.SessionDir "pipes"
        Assert-TestCondition -Condition (Test-Path $pipesDir) -Message "Pipes directory should exist"
        Assert-TestCondition -Condition $result -Message "Initialize-EventBus should return true"

        return $true
    } finally {
        Reset-EventBusState
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: New-BidirectionalPipe creates pipe context
# ============================================================================

Invoke-Test -Name "New-BidirectionalPipe creates pipe context" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventbus-pipe-create"
    try {
        Initialize-EventBus -SessionDir $env.SessionDir | Out-Null

        $ctx = New-BidirectionalPipe -AgentName "test-agent"

        Assert-TestCondition -Condition ($ctx -ne $null) -Message "Pipe context should be created"
        Assert-TestCondition -Condition ($ctx.Name -eq "ralph-test-agent-main") -Message "Pipe name should be correct"
        Assert-TestCondition -Condition ($ctx.AgentName -eq "test-agent") -Message "Agent name should be set"
        Assert-TestCondition -Condition (-not $ctx.Connected) -Message "Pipe should not be connected initially"
        Assert-TestEqual -Actual $ctx.MessagesSent -Expected 0 -Message "Messages sent should be 0"
        Assert-TestEqual -Actual $ctx.MessagesReceived -Expected 0 -Message "Messages received should be 0"

        return $true
    } finally {
        Reset-EventBusState
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Write-Undelivered creates queue entry
# ============================================================================

Invoke-Test -Name "Write-Undelivered creates queue entry" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventbus-undelivered"
    try {
        Initialize-EventBus -SessionDir $env.SessionDir | Out-Null

        $testMsg = @{ type = "Test"; data = "test data" }
        Write-Undelivered -AgentName "pm" -Message $testMsg

        $undeliveredFile = Join-Path $env.SessionDir "undelivered.jsonl"
        Assert-TestCondition -Condition (Test-Path $undeliveredFile) -Message "Undelivered file should exist"

        $content = Get-Content $undeliveredFile -Raw
        Assert-TestCondition -Condition ($content -match "pm") -Message "Content should contain agent name"
        Assert-TestCondition -Condition ($content -match "Test") -Message "Content should contain message type"

        return $true
    } finally {
        Reset-EventBusState
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Get-UndeliveredMessages retrieves entries
# ============================================================================

Invoke-Test -Name "Get-UndeliveredMessages retrieves entries" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventbus-get-undelivered"
    try {
        Initialize-EventBus -SessionDir $env.SessionDir | Out-Null

        Write-Undelivered -AgentName "pm" -Message @{ type = "Msg1" }
        Write-Undelivered -AgentName "developer" -Message @{ type = "Msg2" }
        Write-Undelivered -AgentName "pm" -Message @{ type = "Msg3" }

        $allMsgs = Get-UndeliveredMessages
        $pmMsgs = Get-UndeliveredMessages -AgentName "pm"

        Assert-TestEqual -Actual $allMsgs.Count -Expected 3 -Message "Should get all 3 undelivered messages"
        Assert-TestEqual -Actual $pmMsgs.Count -Expected 2 -Message "Should get 2 messages for pm"

        return $true
    } finally {
        Reset-EventBusState
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Send-MessageToAgent queues when pipe not connected
# ============================================================================

Invoke-Test -Name "Send-MessageToAgent queues when disconnected" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventbus-send-disconnected"
    try {
        Initialize-EventBus -SessionDir $env.SessionDir | Out-Null
        # Don't create/connect the pipe - should queue

        $testMsg = @{ type = "TestMessage"; content = "hello" }
        $result = Send-MessageToAgent -AgentName "nonexistent" -Message $testMsg

        Assert-TestCondition -Condition (-not $result) -Message "Send should return false when pipe doesn't exist"

        $undelivered = Get-UndeliveredMessages -AgentName "nonexistent"
        Assert-TestCondition -Condition ($undelivered.Count -gt 0) -Message "Message should be queued"

        return $true
    } finally {
        Reset-EventBusState
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Get-PipeStatus returns correct info
# ============================================================================

Invoke-Test -Name "Get-PipeStatus returns pipe information" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventbus-status"
    try {
        Initialize-EventBus -SessionDir $env.SessionDir | Out-Null

        New-BidirectionalPipe -AgentName "agent1" | Out-Null
        New-BidirectionalPipe -AgentName "agent2" | Out-Null

        $status = Get-PipeStatus

        Assert-TestCondition -Condition ($status.ContainsKey("agent1")) -Message "Status should contain agent1"
        Assert-TestCondition -Condition ($status.ContainsKey("agent2")) -Message "Status should contain agent2"
        Assert-TestCondition -Condition (-not $status.agent1.Connected) -Message "agent1 should not be connected"
        Assert-TestEqual -Actual $status.agent1.MessagesSent -Expected 0 -Message "Messages sent should be 0"

        return $true
    } finally {
        Reset-EventBusState
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Get-ConnectedAgents filters correctly
# ============================================================================

Invoke-Test -Name "Get-ConnectedAgents filters connected pipes" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventbus-connected"
    try {
        Initialize-EventBus -SessionDir $env.SessionDir | Out-Null

        New-BidirectionalPipe -AgentName "agent1" | Out-Null
        New-BidirectionalPipe -AgentName "agent2" | Out-Null

        $connected = Get-ConnectedAgents

        # No pipes are actually connected (no WaitForConnection called)
        Assert-TestEqual -Actual $connected.Count -Expected 0 -Message "Should have 0 connected agents"

        return $true
    } finally {
        Reset-EventBusState
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Close-Pipe cleanup
# ============================================================================

Invoke-Test -Name "Close-Pipe cleans up pipe resources" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventbus-close"
    try {
        Initialize-EventBus -SessionDir $env.SessionDir | Out-Null

        $ctx = New-BidirectionalPipe -AgentName "test-agent"
        # Mark as connected to test cleanup
        $ctx.Connected = $true

        Close-Pipe -AgentName "test-agent"

        $status = Get-PipeStatus
        Assert-TestCondition -Condition (-not $status["test-agent"].Connected) -Message "Pipe should be marked as disconnected after Close-Pipe"

        return $true
    } finally {
        Reset-EventBusState
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Remove-Pipe removes from bus
# ============================================================================

Invoke-Test -Name "Remove-Pipe removes pipe from bus" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventbus-remove"
    try {
        Initialize-EventBus -SessionDir $env.SessionDir | Out-Null

        New-BidirectionalPipe -AgentName "test-agent" | Out-Null

        $statusBefore = Get-PipeStatus
        Assert-TestCondition -Condition ($statusBefore.ContainsKey("test-agent")) -Message "Pipe should exist before removal"

        Remove-Pipe -AgentName "test-agent"

        $statusAfter = Get-PipeStatus
        Assert-TestCondition -Condition (-not $statusAfter.ContainsKey("test-agent")) -Message "Pipe should not exist after removal"

        return $true
    } finally {
        Reset-EventBusState
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Close-AllPipes closes all pipes
# ============================================================================

Invoke-Test -Name "Close-AllPipes closes all pipe connections" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventbus-close-all"
    try {
        Initialize-EventBus -SessionDir $env.SessionDir | Out-Null

        New-BidirectionalPipe -AgentName "agent1" | Out-Null
        New-BidirectionalPipe -AgentName "agent2" | Out-Null
        New-BidirectionalPipe -AgentName "agent3" | Out-Null

        # Manually mark as connected for testing
        $Script:EventBusPipes["agent1"].Connected = $true
        $Script:EventBusPipes["agent2"].Connected = $true
        $Script:EventBusPipes["agent3"].Connected = $true

        Close-AllPipes

        $status = Get-PipeStatus
        foreach ($agentName in @("agent1", "agent2", "agent3")) {
            Assert-TestCondition -Condition (-not $status[$agentName].Connected) -Message "$agentName should be disconnected"
        }

        return $true
    } finally {
        Reset-EventBusState
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Send-MessageToAgents sends to multiple agents
# ============================================================================

Invoke-Test -Name "Send-MessageToAgents sends to multiple recipients" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventbus-multicast"
    try {
        Initialize-EventBus -SessionDir $env.SessionDir | Out-Null

        $testMsg = @{ type = "Broadcast"; content = "hello all" }
        $agents = @("agent1", "agent2", "agent3")

        $sent = Send-MessageToAgents -AgentNames $agents -Message $testMsg

        Assert-TestEqual -Actual $sent -Expected 0 -Message "Should send 0 messages (no pipes connected)"

        # All should be queued as undelivered
        $totalUndelivered = (Get-UndeliveredMessages).Count
        Assert-TestEqual -Actual $totalUndelivered -Expected 3 -Message "Should have 3 undelivered messages"

        return $true
    } finally {
        Reset-EventBusState
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Broadcast-Message sends to all except excluded
# ============================================================================

Invoke-Test -Name "Broadcast-Message excludes specified agent" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventbus-broadcast"
    try {
        Initialize-EventBus -SessionDir $env.SessionDir | Out-Null

        New-BidirectionalPipe -AgentName "agent1" | Out-Null
        New-BidirectionalPipe -AgentName "agent2" | Out-Null
        New-BidirectionalPipe -AgentName "agent3" | Out-Null

        $testMsg = @{ type = "Broadcast"; content = "hello" }
        $sent = Broadcast-Message -Message $testMsg -ExcludeAgent "agent2"

        Assert-TestEqual -Actual $sent -Expected 0 -Message "Should send 0 messages (no pipes connected)"

        # Should have 2 undelivered (agent1 and agent3, not agent2)
        $undelivered = Get-UndeliveredMessages
        Assert-TestCondition -Condition ($undelivered.Count -ge 2) -Message "Should have at least 2 undelivered messages"

        return $true
    } finally {
        Reset-EventBusState
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Receive-MessageFromAgent returns null when not connected
# ============================================================================

Invoke-Test -Name "Receive-MessageFromAgent returns null when not connected" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventbus-receive-null"
    try {
        Initialize-EventBus -SessionDir $env.SessionDir | Out-Null

        $msg = Receive-MessageFromAgent -AgentName "nonexistent"

        Assert-TestCondition -Condition ($msg -eq $null) -Message "Should return null for nonexistent pipe"

        return $true
    } finally {
        Reset-EventBusState
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Receive-MessageFromAnyAgent returns null when no messages
# ============================================================================

Invoke-Test -Name "Receive-MessageFromAnyAgent returns null when no messages" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventbus-receive-any-null"
    try {
        Initialize-EventBus -SessionDir $env.SessionDir | Out-Null

        New-BidirectionalPipe -AgentName "agent1" | Out-Null

        $result = Receive-MessageFromAnyAgent

        Assert-TestCondition -Condition ($result -eq $null) -Message "Should return null when no messages available"

        return $true
    } finally {
        Reset-EventBusState
        & $env.Cleanup
    }
}

# ============================================================================
# TEST: Get-UndeliveredFilePath returns correct path
# ============================================================================

Invoke-Test -Name "Get-UndeliveredFilePath returns correct path" -ScriptBlock {
    $env = New-TestEnvironment -TestName "eventbus-undelivered-path"
    try {
        Initialize-EventBus -SessionDir $env.SessionDir | Out-Null

        $path = Get-UndeliveredFilePath
        $expectedPath = Join-Path $env.SessionDir "undelivered.jsonl"

        Assert-TestEqual -Actual $path -Expected $expectedPath -Message "Path should match expected"

        return $true
    } finally {
        Reset-EventBusState
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
