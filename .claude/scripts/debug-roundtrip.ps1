# Debug test 11 - check message round-trip specifically
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\test-helpers.ps1"
. "$PSScriptRoot\message-queue.ps1"

Write-Host "=== Debug Message Round-Trip Test ===" -ForegroundColor Cyan

$env = New-TestEnvironment -TestName "roundtrip-debug"
Initialize-MessageQueue -SessionDir $env.SessionDir

# Send message
$msg = New-TestMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ taskId = "test-001" }
Write-Host "Test message created: type=$($msg.type), from=$($msg.from), to=$($msg.to)" -ForegroundColor Gray

$msgId = Send-AgentMessage -From $msg.from -To $msg.to -Type $msg.type -Payload $msg.payload
Write-Host "Message ID: $msgId" -ForegroundColor Green

# Check file exists
$inbox = Join-Path $Script:MessageQueueDir "developer"
$files = Get-ChildItem -Path $inbox -Filter "*.json"
Write-Host "Files in inbox: $($files.Count)" -ForegroundColor Gray

# Get pending messages
Write-Host "`nCalling Get-PendingMessages..." -ForegroundColor Gray
$pending = Get-PendingMessages -Agent "developer"
Write-Host "Pending count: $($pending.Count)" -ForegroundColor $(if ($pending.Count -gt 0) { "Green" } else { "Red" })

if ($pending.Count -gt 0) {
    Write-Host "First message:" -ForegroundColor Gray
    Write-Host "  id: $($pending[0].id)" -ForegroundColor DarkGray
    Write-Host "  type: $($pending[0].type)" -ForegroundColor DarkGray
    Write-Host "  from: $($pending[0].from)" -ForegroundColor DarkGray
    Write-Host "  to: $($pending[0].to)" -ForegroundColor DarkGray
    Write-Host "  status: $($pending[0].status)" -ForegroundColor DarkGray
    Write-Host "  payload: $($pending[0].payload)" -ForegroundColor DarkGray
} else {
    Write-Host "NO MESSAGES FOUND!" -ForegroundColor Red
}

# Get by ID
Write-Host "`nCalling Get-MessageById..." -ForegroundColor Gray
$retrieved = Get-MessageById -MessageId $msgId -Agent "developer"
if ($retrieved) {
    Write-Host "Retrieved message:" -ForegroundColor Green
    Write-Host "  id: $($retrieved.id)" -ForegroundColor DarkGray
    Write-Host "  type: $($retrieved.type)" -ForegroundColor DarkGray
} else {
    Write-Host "MESSAGE NOT FOUND BY ID!" -ForegroundColor Red
}

# Cleanup
& $env.Cleanup
Write-Host "`n[OK] Debug complete" -ForegroundColor Green
