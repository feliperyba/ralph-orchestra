# Debug - investigate test failures specifically
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\test-helpers.ps1"
. "$PSScriptRoot\message-queue.ps1"

Write-Host "=== Investigating Test Failures ===" -ForegroundColor Cyan

# Test 1: Message round-trip
Write-Host "`n1. Message Round-Trip Test" -ForegroundColor Yellow
$env = New-TestEnvironment -TestName "roundtrip-investigate"
Initialize-MessageQueue -SessionDir $env.SessionDir

$msg = New-TestMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ taskId = "test-001" }
Write-Host "   New-TestMessage: from=$($msg.from), to=$($msg.to), type=$($msg.type)" -ForegroundColor Gray

$msgId = Send-AgentMessage -From $msg.from -To $msg.to -Type $msg.type -Payload $msg.payload
Write-Host "   Message ID: $msgId" -ForegroundColor Gray

$inbox = Join-Path $Script:MessageQueueDir "developer"
Write-Host "   Inbox: $inbox" -ForegroundColor Gray
Write-Host "   Files exist: $(Get-ChildItem $inbox -File -ErrorAction SilentlyContinue | Measure-Object).Count" -ForegroundColor Gray

# Call Get-PendingMessages and inspect result
$pending = Get-PendingMessages -Agent "developer"
Write-Host "   Pending type: $($pending.GetType().FullName)" -ForegroundColor Gray
Write-Host "   Pending count: $($pending.Count)" -ForegroundColor $(if ($pending.Count -eq 1) { "Green" } else { "Red" })

# Check if it's an array or single object
if ($pending -is [array]) {
    Write-Host "   Is array: YES" -ForegroundColor Gray
} else {
    Write-Host "   Is array: NO (single object)" -ForegroundColor Yellow
    Write-Host "   Has Count property: $($null -ne $pending.Count)" -ForegroundColor Gray
}

& $env.Cleanup

# Test 2: Duplicate message detection
Write-Host "`n2. Duplicate Message Detection Test" -ForegroundColor Yellow
$env = New-TestEnvironment -TestName "duplicate-investigate"
Initialize-MessageQueue -SessionDir $env.SessionDir

$msgId = Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ id = 1 }
Write-Host "   Message ID: $msgId" -ForegroundColor Gray

$pending = Get-PendingMessages -Agent "developer"
Write-Host "   Pending: $($pending.Count) messages" -ForegroundColor $(if ($pending.Count -eq 1) { "Green" } else { "Red" })

if ($null -eq $pending.Count) {
    Write-Host "   ERROR: Count is null!" -ForegroundColor Red
    Write-Host "   Pending is null: $($null -eq $pending)" -ForegroundColor Red
    Write-Host "   Pending type: $($pending.GetType().FullName)" -ForegroundColor Red
}

& $env.Cleanup

# Test 3: Priority order
Write-Host "`n3. Concurrent Task Assignment (Priority Order)" -ForegroundColor Yellow
$env = New-TestEnvironment -TestName "priority-investigate"
Initialize-MessageQueue -SessionDir $env.SessionDir

# Send normal then high priority
Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Priority "normal" -Payload @{ order = 1 } | Out-Null
Send-AgentMessage -From "pm" -To "developer" -Type "bug_report" -Priority "high" -Payload @{ order = 2 } | Out-Null

$pending = Get-PendingMessages -Agent "developer"
Write-Host "   Pending: $($pending.Count) messages" -ForegroundColor Gray
if ($pending.Count -gt 0) {
    Write-Host "   First message priority: $($pending[0].priority)" -ForegroundColor Gray
    Write-Host "   Expected: high, Got: $($pending[0].priority)" -ForegroundColor $(if ($pending[0].priority -eq "high") { "Green" } else { "Red" })
}

& $env.Cleanup

Write-Host "`n=== Investigation Complete ===" -ForegroundColor Cyan
