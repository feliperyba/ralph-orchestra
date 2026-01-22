# Debug test 4 - check cache
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\test-helpers.ps1"
. "$PSScriptRoot\message-queue.ps1"

Write-Host "=== Debug Message Queue Test 4 (Cache Check) ===" -ForegroundColor Cyan

$env = New-TestEnvironment -TestName "debug-queue4"
Initialize-MessageQueue -SessionDir $env.SessionDir

# Send a message
$msgId = Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ test = "debug" }
Write-Host "Message ID: $msgId" -ForegroundColor Green

# Wait for cache to expire (500ms)
Write-Host "Waiting 600ms for cache to expire..." -ForegroundColor Gray
Start-Sleep -Milliseconds 600

# Now try Get-PendingMessages
Write-Host "`nGet-PendingMessages after cache expiry:" -ForegroundColor Gray
$pending = Get-PendingMessages -Agent "developer"
Write-Host "Result: $($pending.Count) messages" -ForegroundColor $(if ($pending.Count -gt 0) { "Green" } else { "Red" })

# Check if we can bypass the cache
$inbox = Join-Path $Script:MessageQueueDir "developer"
Write-Host "`nDirect Get-ChildItem:" -ForegroundColor Gray
$files = Get-ChildItem -Path $inbox -Filter "*.json" -ErrorAction SilentlyContinue
Write-Host "Files: $($files.Count)" -ForegroundColor Gray

# Cleanup
& $env.Cleanup
Write-Host "`n[OK] Debug 4 complete" -ForegroundColor Green
