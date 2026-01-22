# Test script for message-queue.ps1 with pool integration

$ErrorActionPreference = "Stop"
$TestDir = Join-Path $env:TEMP "ralph-test-queue"

Write-Host "=== Message Queue Pool Integration Test ===" -ForegroundColor Cyan

# Clean up any previous test
if (Test-Path $TestDir) { Remove-Item $TestDir -Recurse -Force }
New-Item -ItemType Directory -Path $TestDir -Force | Out-Null

# Source the message queue module (will also source the pool)
. "$PSScriptRoot\message-queue.ps1"

# Initialize queue
Write-Host "`n1. Initializing message queue..." -ForegroundColor Gray
Initialize-MessageQueue -SessionDir $TestDir

# Check pool is loaded
Write-Host "   UseMessagePool: $Script:UseMessagePool" -ForegroundColor Green

# Send a test message
Write-Host "`n2. Sending test message..." -ForegroundColor Gray
$msgId = Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ taskId = "test-001"; title = "Test Task" }
Write-Host "   Message sent: $msgId" -ForegroundColor Green

# Get message count
Write-Host "`n3. Checking message count..." -ForegroundColor Gray
$counts = Get-MessageCount
Write-Host "   Pending messages: $($counts.developer)" -ForegroundColor Green

# Get pending messages
Write-Host "`n4. Retrieving pending messages..." -ForegroundColor Gray
$messages = Get-PendingMessages -Agent "developer"
Write-Host "   Retrieved: $($messages.Count) messages" -ForegroundColor Green
if ($messages.Count -gt 0) {
    Write-Host "   First message: $($messages[0].type) from $($messages[0].from)" -ForegroundColor Cyan

    # Check if message has _pooled flag (won't be present because it was read from JSON)
    Write-Host "   Has _pooled flag: $($messages[0]._pooled -eq $true)" -ForegroundColor Yellow
}

# Acknowledge message
Write-Host "`n5. Acknowledging message..." -ForegroundColor Gray
$result = Invoke-AcknowledgeMessage -MessageId $msgId -Agent "developer" -Result @{ processed = "ok" }
Write-Host "   Acknowledged: $result" -ForegroundColor Green

# Check pool stats
Write-Host "`n6. Pool stats after operations..." -ForegroundColor Gray
if (Get-Command Get-MessagePoolStats -ErrorAction SilentlyContinue) {
    Show-MessagePoolStats
}

# Cleanup
Remove-Item $TestDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n[OK] Queue integration test passed!" -ForegroundColor Green
