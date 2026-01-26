# Ralph V2 Message Protocol Tests
# Tests for the message protocol (message-protocol.ps1)
#
# These tests verify:
# - New-Message creates valid message
# - Test-Message validates required fields
# - Convert-LegacyMessageType maps correctly
# - All 12 message types are valid
# - Creation helpers (New-WorkAssignMessage, etc.)
# - inReplyTo field handling

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
. "$ProjectRoot\.claude\scripts\v2-architecture\message-protocol.ps1"

Write-Host "=== Ralph V2 Message Protocol Tests ===" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# TEST: New-Message creates valid message structure
# ============================================================================

Invoke-Test -Name "New-Message creates valid message" -ScriptBlock {
    $msg = New-Message -Type "WorkAssign" -From "pm" -To "developer" -Payload @{ taskId = "test-001" }

    Assert-TestCondition -Condition ($msg.id -match "^msg-\d{8}-\d{6}-\d{4}$") -Message "Message ID should have correct format"
    Assert-TestEqual -Actual $msg.type -Expected "WorkAssign" -Message "Type should be WorkAssign"
    Assert-TestEqual -Actual $msg.from -Expected "pm" -Message "From should be pm"
    Assert-TestEqual -Actual $msg.to -Expected "developer" -Message "To should be developer"
    Assert-TestCondition -Condition ($msg.timestamp -match "^\d{4}-\d{2}-\d{2}T") -Message "Timestamp should be ISO 8601"
    Assert-TestEqual -Actual $msg.payload.taskId -Expected "test-001" -Message "Payload should contain taskId"

    return $true
}

# ============================================================================
# TEST: New-Message with inReplyTo
# ============================================================================

Invoke-Test -Name "New-Message with inReplyTo parameter" -ScriptBlock {
    $originalMsg = New-Message -Type "Query" -From "developer" -To "pm" -Payload @{ question = "help?" }
    $replyMsg = New-Message -Type "Response" -From "pm" -To "developer" -Payload @{ answer = "ok" } -InReplyTo $originalMsg.id

    Assert-TestEqual -Actual $replyMsg.inReplyTo -Expected $originalMsg.id -Message "inReplyTo should reference original message"

    return $true
}

# ============================================================================
# TEST: Test-Message validates required fields
# ============================================================================

Invoke-Test -Name "Test-Message validates all required fields" -ScriptBlock {
    $validMsg = New-Message -Type "WorkAssign" -From "pm" -To "developer"

    $isValid = Test-Message -Message $validMsg

    Assert-TestCondition -Condition $isValid -Message "Valid message should pass validation"

    return $true
}

# ============================================================================
# TEST: Test-Message rejects invalid messages
# ============================================================================

Invoke-Test -Name "Test-Message rejects invalid messages" -ScriptBlock {
    # Missing 'from' field
    $invalidMsg1 = @{
        id = "msg-test"
        type = "WorkAssign"
        to = "developer"
        timestamp = [DateTime]::UtcNow.ToString("o")
        payload = @{}
    }

    $isValid1 = Test-Message -Message $invalidMsg1
    Assert-TestCondition -Condition (-not $isValid1) -Message "Message without 'from' should be invalid"

    # Missing 'id' field
    $invalidMsg2 = @{
        from = "pm"
        type = "WorkAssign"
        to = "developer"
        timestamp = [DateTime]::UtcNow.ToString("o")
        payload = @{}
    }

    $isValid2 = Test-Message -Message $invalidMsg2
    Assert-TestCondition -Condition (-not $isValid2) -Message "Message without 'id' should be invalid"

    return $true
}

# ============================================================================
# TEST: All 12 core message types are valid
# ============================================================================

Invoke-Test -Name "All 12 core message types are valid" -ScriptBlock {
    $validTypes = @(
        "AgentStatus", "WorkAssign", "WorkComplete", "WorkAbandoned", "WorkBlocked",
        "ProblemReport", "Query", "Response", "ValidationRequest", "ValidationResult",
        "DesignUpdate", "Retrospective", "PlanUpdate", "ResearchUpdate", "System", "Playtest"
    )

    foreach ($type in $validTypes) {
        $msg = New-Message -Type $type -From "pm" -To "developer"
        $isValid = Test-Message -Message $msg

        Assert-TestCondition -Condition $isValid -Message "$type should be a valid message type"
    }

    return $true
}

# ============================================================================
# TEST: Convert-LegacyMessageType maps correctly
# ============================================================================

Invoke-Test -Name "Convert-LegacyMessageType maps V1 to V2 types" -ScriptBlock {
    $mappings = @{
        "agent_ready" = "AgentStatus"
        "status_update" = "AgentStatus"
        "task_assign" = "WorkAssign"
        "asset_assign" = "WorkAssign"
        "task_complete" = "WorkComplete"
        "implementation_complete" = "WorkComplete"
        "bug_report" = "ProblemReport"
        "quality_concern" = "ProblemReport"
        "question" = "Query"
        "answer" = "Response"
        "gdd_ready" = "DesignUpdate"
        "prd_reorganized" = "PlanUpdate"
    }

    foreach ($legacyType in $mappings.Keys) {
        $expected = $mappings[$legacyType]
        $actual = Convert-LegacyMessageType -LegacyType $legacyType

        Assert-TestEqual -Actual $actual -Expected $expected -Message "$legacyType should map to $expected"
    }

    return $true
}

# ============================================================================
# TEST: Convert-LegacyMessageType passes through unknown types
# ============================================================================

Invoke-Test -Name "Convert-LegacyMessageType passes through V2 types" -ScriptBlock {
    $v2Types = @("WorkAssign", "Query", "Response", "System")

    foreach ($type in $v2Types) {
        $result = Convert-LegacyMessageType -LegacyType $type
        Assert-TestEqual -Actual $result -Expected $type -Message "V2 type should pass through unchanged"
    }

    return $true
}

# ============================================================================
# TEST: New-WorkAssignMessage creates correct message
# ============================================================================

Invoke-Test -Name "New-WorkAssignMessage creates valid work assignment" -ScriptBlock {
    $msg = New-WorkAssignMessage -From "pm" -To "developer" -TaskId "feat-001" -WorkType "implementation" -Title "Implement feature"

    Assert-TestEqual -Actual $msg.type -Expected "WorkAssign" -Message "Type should be WorkAssign"
    Assert-TestEqual -Actual $msg.from -Expected "pm" -Message "From should be pm"
    Assert-TestEqual -Actual $msg.to -Expected "developer" -Message "To should be developer"
    Assert-TestEqual -Actual $msg.payload.taskId -Expected "feat-001" -Message "Payload should contain taskId"
    Assert-TestEqual -Actual $msg.payload.workType -Expected "implementation" -Message "Payload should contain workType"
    Assert-TestEqual -Actual $msg.payload.title -Expected "Implement feature" -Message "Payload should contain title"

    return $true
}

# ============================================================================
# TEST: New-WorkCompleteMessage creates correct message
# ============================================================================

Invoke-Test -Name "New-WorkCompleteMessage creates valid completion message" -ScriptBlock {
    $msg = New-WorkCompleteMessage -From "developer" -To "pm" -TaskId "feat-001" -Result "success" -Notes "Done"

    Assert-TestEqual -Actual $msg.type -Expected "WorkComplete" -Message "Type should be WorkComplete"
    Assert-TestEqual -Actual $msg.payload.taskId -Expected "feat-001" -Message "Payload should contain taskId"
    Assert-TestEqual -Actual $msg.payload.result -Expected "success" -Message "Payload should contain result"
    Assert-TestEqual -Actual $msg.payload.notes -Expected "Done" -Message "Payload should contain notes"

    return $true
}

# ============================================================================
# TEST: New-QueryMessage creates correct message
# ============================================================================

Invoke-Test -Name "New-QueryMessage creates valid query" -ScriptBlock {
    $msg = New-QueryMessage -From "developer" -To "pm" -Question "How do I implement this?"

    Assert-TestEqual -Actual $msg.type -Expected "Query" -Message "Type should be Query"
    Assert-TestEqual -Actual $msg.payload.question -Expected "How do I implement this?" -Message "Payload should contain question"

    return $true
}

# ============================================================================
# TEST: New-ResponseMessage creates correct reply
# ============================================================================

Invoke-Test -Name "New-ResponseMessage creates valid response" -ScriptBlock {
    $originalId = "msg-20250125-120000-0001"
    $msg = New-ResponseMessage -From "pm" -To "developer" -Answer "Use the standard pattern" -InReplyTo $originalId

    Assert-TestEqual -Actual $msg.type -Expected "Response" -Message "Type should be Response"
    Assert-TestEqual -Actual $msg.payload.answer -Expected "Use the standard pattern" -Message "Payload should contain answer"
    Assert-TestEqual -Actual $msg.inReplyTo -Expected $originalId -Message "Should reference original message"

    return $true
}

# ============================================================================
# TEST: New-ProblemReportMessage creates correct report
# ============================================================================

Invoke-Test -Name "New-ProblemReportMessage creates valid problem report" -ScriptBlock {
    $msg = New-ProblemReportMessage -From "qa" -To "pm" -TaskId "feat-001" -ProblemType "bug" -Description "Critical failure" -Severity "critical"

    Assert-TestEqual -Actual $msg.type -Expected "ProblemReport" -Message "Type should be ProblemReport"
    Assert-TestEqual -Actual $msg.payload.taskId -Expected "feat-001" -Message "Payload should contain taskId"
    Assert-TestEqual -Actual $msg.payload.problemType -Expected "bug" -Message "Payload should contain problemType"
    Assert-TestEqual -Actual $msg.payload.severity -Expected "critical" -Message "Payload should contain severity"

    return $true
}

# ============================================================================
# TEST: New-ValidationRequestMessage creates correct request
# ============================================================================

Invoke-Test -Name "New-ValidationRequestMessage creates valid validation request" -ScriptBlock {
    $msg = New-ValidationRequestMessage -From "developer" -To "qa" -TaskId "feat-001" -ValidationType "full"

    Assert-TestEqual -Actual $msg.type -Expected "ValidationRequest" -Message "Type should be ValidationRequest"
    Assert-TestEqual -Actual $msg.payload.taskId -Expected "feat-001" -Message "Payload should contain taskId"
    Assert-TestEqual -Actual $msg.payload.validationType -Expected "full" -Message "Payload should contain validationType"

    return $true
}

# ============================================================================
# TEST: New-SystemMessage creates correct system message
# ============================================================================

Invoke-Test -Name "New-SystemMessage creates valid system message" -ScriptBlock {
    $msg = New-SystemMessage -From "watchdog" -To "*" -SystemEventType "shutdown" -Message "System shutting down"

    Assert-TestEqual -Actual $msg.type -Expected "System" -Message "Type should be System"
    Assert-TestEqual -Actual $msg.payload.systemEvent -Expected "shutdown" -Message "Payload should contain systemEvent"
    Assert-TestEqual -Actual $msg.payload.message -Expected "System shutting down" -Message "Payload should contain message"

    return $true
}

# ============================================================================
# TEST: Message ID format is consistent
# ============================================================================

Invoke-Test -Name "Message IDs have consistent format" -ScriptBlock {
    $ids = @()
    for ($i = 0; $i -lt 10; $i++) {
        $msg = New-Message -Type "WorkAssign" -From "pm" -To "developer"
        $ids += $msg.id
    }

    # All IDs should be unique
    $uniqueIds = $ids | Select-Object -Unique
    Assert-TestEqual -Actual $uniqueIds.Count -Expected $ids.Count -Message "All message IDs should be unique"

    # All IDs should match format: msg-YYYYMMDD-HHMMSS-XXXX
    foreach ($id in $ids) {
        Assert-TestCondition -Condition ($id -match "^msg-\d{8}-\d{6}-\d{4}$") -Message "ID format should be correct: $id"
    }

    return $true
}

# ============================================================================
# TEST: Payload can contain complex nested data
# ============================================================================

Invoke-Test -Name "Message payload can contain complex nested data" -ScriptBlock {
    $complexPayload = @{
        taskId = "feat-001"
        spec = @{
            requirements = @("req1", "req2", "req3")
            metadata = @{
                priority = "high"
                tags = @("frontend", "api")
            }
        }
    }

    $msg = New-Message -Type "WorkAssign" -From "pm" -To "developer" -Payload $complexPayload

    $isValid = Test-Message -Message $msg
    Assert-TestCondition -Condition $isValid -Message "Message with complex payload should be valid"

    # Verify payload structure is preserved
    Assert-TestEqual -Actual $msg.payload.spec.requirements.Count -Expected 3 -Message "Nested arrays should be preserved"
    Assert-TestEqual -Actual $msg.payload.spec.metadata.tags[1] -Expected "api" -Message "Deep nesting should be preserved"

    return $true
}

# ============================================================================
# TEST: Message serialization and deserialization
# ============================================================================

Invoke-Test -Name "Message survives JSON round-trip" -ScriptBlock {
    $original = New-Message -Type "WorkAssign" -From "pm" -To "developer" -Payload @{ taskId = "test-001" }

    # Serialize to JSON
    $json = $original | ConvertTo-Json -Depth 10

    # Deserialize back
    $restored = $json | ConvertFrom-Json

    Assert-TestEqual -Actual $restored.id -Expected $original.id -Message "ID should survive round-trip"
    Assert-TestEqual -Actual $restored.type -Expected $original.type -Message "Type should survive round-trip"
    Assert-TestEqual -Actual $restored.payload.taskId -Expected "test-001" -Message "Payload should survive round-trip"

    return $true
}

# ============================================================================
# TEST: AcceptanceCriteria in WorkAssign
# ============================================================================

Invoke-Test -Name "New-WorkAssignMessage with acceptance criteria" -ScriptBlock {
    $criteria = @(
        "Feature must be implemented",
        "Tests must pass",
        "Documentation updated"
    )

    $msg = New-WorkAssignMessage -From "pm" -To "developer" -TaskId "feat-001" -WorkType "implementation" -Title "New feature" -AcceptanceCriteria $criteria

    Assert-TestEqual -Actual $msg.payload.acceptanceCriteria.Count -Expected 3 -Message "Should have 3 acceptance criteria"
    Assert-TestEqual -Actual $msg.payload.acceptanceCriteria[0] -Expected "Feature must be implemented" -Message "First criterion should match"

    return $true
}

# ============================================================================
# RESULTS
# ============================================================================

Write-Host ""
$allPassed = Show-TestResults

# Clean up any orphaned test environments
Remove-AllTestEnvironments

exit $(if ($allPassed) { 0 } else { 1 })
