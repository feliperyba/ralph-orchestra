# Debug test to see what's happening with message queue
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\test-helpers.ps1"
. "$PSScriptRoot\message-queue.ps1"

Write-Host "=== Debug Message Queue Test ===" -ForegroundColor Cyan

$env = New-TestEnvironment -TestName "debug-queue"
Write-Host "SessionDir: $($env.SessionDir)" -ForegroundColor Gray
Write-Host "MessagesDir: $($env.MessagesDir)" -ForegroundColor Gray

# Initialize queue
Initialize-MessageQueue -SessionDir $env.SessionDir
Write-Host "MessageQueueDir: $Script:MessageQueueDir" -ForegroundColor Gray

# Check if developer inbox exists
$inbox = Join-Path $Script:MessageQueueDir "developer"
Write-Host "Inbox path: $inbox" -ForegroundColor Gray
Write-Host "Inbox exists: $(Test-Path $inbox)" -ForegroundColor Gray
Write-Host "Files in inbox: $(Get-ChildItem $inbox -ErrorAction SilentlyContinue | Measure-Object).Count" -ForegroundColor Gray

# Send a message
Write-Host "`nSending message..." -ForegroundColor Gray
$msgId = Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ test = "debug" }
Write-Host "Message ID: $msgId" -ForegroundColor Green

# Check files again
Write-Host "`nAfter send - Files in inbox: $(Get-ChildItem $inbox -ErrorAction SilentlyContinue | Measure-Object).Count" -ForegroundColor Gray
if (Test-Path $inbox) {
    Get-ChildItem $inbox -File | ForEach-Object {
        Write-Host "  File: $($_.Name)" -ForegroundColor DarkGray
    }
}

# Get pending
Write-Host "`nGetting pending messages..." -ForegroundColor Gray
$pending = Get-PendingMessages -Agent "developer"
Write-Host "Pending count: $($pending.Count)" -ForegroundColor $(if ($pending.Count -gt 0) { "Green" } else { "Red" })

# Cleanup
& $env.Cleanup
Write-Host "`n[OK] Debug complete" -ForegroundColor Green
